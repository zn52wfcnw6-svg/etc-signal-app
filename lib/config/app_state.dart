import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/market_data_manager.dart';
import '../engine/long_cycle/long_cycle_manager.dart';
import '../engine/short_cycle/signal_engine.dart';
import '../engine/risk/risk_manager.dart';
import '../engine/iteration/iteration_engine.dart';
import '../monitor/self_healing.dart';
import '../storage/database_helper.dart';
import '../models/signal.dart';
import '../models/position.dart';
import '../utils/constants.dart';

/// 应用全局状态
class AppState extends ChangeNotifier {
  final MarketDataManager marketData = MarketDataManager();
  late final SignalEngine signalEngine;
  late final RiskManager riskManager;
  late final IterationEngine iterationEngine;
  late final SelfHealingMonitor selfHealing;
  final DatabaseHelper database = DatabaseHelper();

  bool _isInitialized = false;
  bool _isRunning = false;
  AppStateTag _appState = AppStateTag.noSignal;
  String _statusMessage = '初始化中...';
  TradingSignal? _currentSignal;
  FreezeState? _freezeState;
  double _ethPrice = 0;
  double _btcPrice = 0;
  double _ethBtcRatio = 0;
  Map<String, dynamic> _signalStatus = {};
  LongCycleResult? _longCycleResult;

  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
  AppStateTag get appState => _appState;
  String get statusMessage => _statusMessage;
  TradingSignal? get currentSignal => _currentSignal;
  FreezeState? get freezeState => _freezeState;
  double get ethPrice => _ethPrice;
  double get btcPrice => _btcPrice;
  double get ethBtcRatio => _ethBtcRatio;
  Map<String, dynamic> get signalStatus => _signalStatus;
  LongCycleResult? get longCycleResult => _longCycleResult;
  List<Position> get positions => riskManager.positions;
  double get accountBalance => riskManager.accountBalance;
  double get totalRisk => riskManager.totalRisk;

  StreamSubscription? _ethSub;
  StreamSubscription? _btcSub;
  StreamSubscription? _signalSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _freezeSub;
  StreamSubscription? _errorSub;
  Timer? _mainTimer;

  Future<void> init() async {
    if (_isInitialized) return;

    await database.init();

    signalEngine = SignalEngine(marketData);
    riskManager = RiskManager(marketData);
    iterationEngine = IterationEngine(database);
    selfHealing = SelfHealingMonitor(database);

    await marketData.init();

    // 注册自修复检查
    _registerHealthChecks();

    // 订阅数据流
    _ethSub = marketData.ethDataStream.listen((data) {
      _ethPrice = data.price;
      _updateAppState();
    });

    _btcSub = marketData.btcDataStream.listen((data) {
      _btcPrice = data.price;
    });

    _signalSub = signalEngine.signalStream.listen((signal) {
      _currentSignal = signal;
      database.insertSignal(signal);
      _updateAppState();
      notifyListeners();
    });

    _statusSub = signalEngine.statusStream.listen((status) {
      _signalStatus = status;
      _statusMessage = status['message'] ?? '';
      _updateAppState();
    });

    _freezeSub = riskManager.freezeStream.listen((state) {
      _freezeState = state;
      _updateAppState();
    });

    _errorSub = marketData.errorStream.listen((error) {
      _statusMessage = error;
      _updateAppState();
    });

    _isInitialized = true;
    _statusMessage = '初始化完成，等待启动';
    notifyListeners();
  }

  void _registerHealthChecks() {
    selfHealing.registerCheck('data', () async {
      final etc = marketData.ethData;
      final btc = marketData.btcData;
      if (etc == null || btc == null) {
        return HealthCheckResult(
          module: 'data',
          isHealthy: false,
          issue: '行情数据缺失',
          action: '重新拉取',
        );
      }
      return HealthCheckResult(module: 'data', isHealthy: true);
    });

    selfHealing.registerHealer('data', () async {
      await marketData.manualRefresh();
      return marketData.ethData != null;
    });
  }

  void start() {
    if (!_isInitialized || _isRunning) return;
    _isRunning = true;
    marketData.startPolling();
    selfHealing.start();

    _mainTimer = Timer.periodic(
      const Duration(seconds: AppConstants.pollIntervalSeconds),
      (_) => _tick(),
    );

    _statusMessage = '运行中';
    notifyListeners();
  }

  Future<void> _tick() async {
    // 风控检查
    await riskManager.checkFreezeConditions();

    // 始终更新长周期分析（即使冻结也显示市场结构和关键位）
    _longCycleResult = signalEngine.longCycle.analyze();

    // 计算ETH/BTC强弱比（始终计算）
    if (_ethPrice > 0 && _btcPrice > 0) {
      _ethBtcRatio = _ethPrice / _btcPrice;
    }

    // 如果冻结，不生成信号
    if (_freezeState?.isFrozen ?? false) {
      _statusMessage = '冻结中: ${_freezeState!.reasonText}';
      _updateAppState();
      return;
    }

    // 信号引擎
    await signalEngine.tick();
  }

  void _updateAppState() {
    if (_freezeState?.isFrozen ?? false) {
      final reasons = _freezeState!.reasons;
      if (reasons.contains(FreezeReason.dataValidationFailed)) {
        _appState = AppStateTag.dataAbnormal;
      } else {
        _appState = AppStateTag.marketFrozen;
      }
    } else if (_currentSignal != null && _currentSignal!.status == SignalStatus.confirmed) {
      _appState = _currentSignal!.direction == SignalDirection.long
          ? AppStateTag.longCandidate
          : AppStateTag.shortCandidate;
    } else {
      _appState = AppStateTag.noSignal;
    }
    notifyListeners();
  }

  Future<void> manualRefresh() async {
    await marketData.manualRefresh();
    await _tick();
  }

  void setAccountBalance(double balance) {
    riskManager.setAccountBalance(balance);
    notifyListeners();
  }

  void addPosition(Position pos) {
    riskManager.addPosition(pos);
    database.insertPosition(pos);
    notifyListeners();
  }

  void closePosition(String id, double closePrice, double pnl) {
    riskManager.closePosition(id, closePrice, pnl);
    notifyListeners();
  }

  void markSignalExecuted(bool executed, {double? pnl}) {
    if (_currentSignal != null) {
      signalEngine.markSignalExecuted(_currentSignal!.id, executed, pnl: pnl);
      database.updateSignal(_currentSignal!);
      notifyListeners();
    }
  }

  void stop() {
    _isRunning = false;
    _mainTimer?.cancel();
    marketData.stopPolling();
    selfHealing.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _ethSub?.cancel();
    _btcSub?.cancel();
    _signalSub?.cancel();
    _statusSub?.cancel();
    _freezeSub?.cancel();
    _errorSub?.cancel();
    marketData.dispose();
    signalEngine.dispose();
    riskManager.dispose();
    selfHealing.dispose();
    super.dispose();
  }
}
