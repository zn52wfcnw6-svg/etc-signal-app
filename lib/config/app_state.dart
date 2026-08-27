import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/market_data_manager.dart';
import '../engine/long_cycle/long_cycle_manager.dart';
import '../engine/short_cycle/signal_engine.dart';
import '../engine/risk/risk_manager.dart';
import '../engine/trade_recommendation_engine.dart';
import '../models/trade_recommendation.dart';
import '../engine/adaptive/adaptive_params.dart';
import '../engine/market_regime/market_regime.dart';
import '../engine/multi_timeframe/mtf_analyzer.dart';
import '../engine/order_flow/deep_order_flow.dart';
import '../monitor/self_healing.dart';
import '../storage/database_helper.dart';
import '../models/signal.dart';
import '../models/position.dart';
import '../models/trading_pair.dart';
import '../utils/constants.dart';

/// 应用全局状态
class AppState extends ChangeNotifier {
  final MarketDataManager marketData = MarketDataManager();
  late final SignalEngine signalEngine;
  late final RiskManager riskManager;
  late final SelfHealingMonitor selfHealing;
  final DatabaseHelper database = DatabaseHelper();

  bool _isInitialized = false;
  bool _isRunning = false;

  // 用户可配置参数
  String _riskPreference = 'moderate'; // conservative/moderate/aggressive
  int _pollInterval = AppConstants.pollIntervalSeconds;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  TradingPair _currentPair = TradingPair.supportedPairs.first;

  String get riskPreference => _riskPreference;
  int get pollInterval => _pollInterval;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  TradingPair get currentPair => _currentPair;
  List<TradingPair> get supportedPairs => TradingPair.supportedPairs;

  void setRiskPreference(String pref) {
    _riskPreference = pref;
    // 根据风险偏好调整参数
    switch (pref) {
      case 'conservative':
        // 保守：更低风险，更高盈亏比要求
        break;
      case 'aggressive':
        // 激进：更高风险，更低盈亏比要求
        break;
    }
    notifyListeners();
  }

  void setPollInterval(int seconds) {
    _pollInterval = seconds;
    notifyListeners();
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    notifyListeners();
  }

  void setCurrentPair(TradingPair pair) {
    _currentPair = pair;
    notifyListeners();
    // 重新加载行情数据
    manualRefresh();
  }

  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
    notifyListeners();
  }
  String _statusMessage = '初始化中...';
  TradingSignal? _currentSignal;
  RiskState? _riskState;
  double _ethPrice = 0;
  double _btcPrice = 0;
  double _ethBtcRatio = 0;
  AnalysisResult? _analysis;

  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
  String get statusMessage => _statusMessage;
  TradingSignal? get currentSignal => _currentSignal;
  RiskState? get riskState => _riskState;
  double get ethPrice => _ethPrice;
  double get btcPrice => _btcPrice;
  double get ethBtcRatio => _ethBtcRatio;
  AnalysisResult? get analysis => _analysis;
  LongCycleResult? get longCycleResult => _analysis?.longCycle;
  AdaptiveParams? get adaptiveParams => _analysis?.adaptiveParams;
  MarketRegimeResult? get marketRegime => _analysis?.regime;
  MultiTimeframeResult? get mtfResult => _analysis?.mtf;
  DeepOrderFlowResult? get deepOrderFlow => _analysis?.orderFlow;
  int get riskLevelIndex => _riskState?.level.index ?? 0;
  TradeRecommendation get tradeRecommendation {
    return TradeRecommendationEngine.generate(
      currentPrice: _ethPrice,
      longCycle: _analysis?.longCycle,
      orderFlow: _analysis?.orderFlow,
      riskLevel: riskLevelIndex,
      confirmedSignal: _currentSignal,
    );
  }
  List<Position> get positions => riskManager.positions;
  double get accountBalance => riskManager.accountBalance;
  double get totalRisk => riskManager.totalRisk;

  StreamSubscription? _ethSub;
  StreamSubscription? _btcSub;
  StreamSubscription? _signalSub;
  StreamSubscription? _analysisSub;
  StreamSubscription? _riskSub;
  StreamSubscription? _errorSub;
  Timer? _mainTimer;

  Future<void> init() async {
    if (_isInitialized) return;
    await database.init();
    signalEngine = SignalEngine(marketData);
    riskManager = RiskManager(marketData);
    selfHealing = SelfHealingMonitor(database);
    await marketData.init();
    _registerHealthChecks();

    _ethSub = marketData.ethDataStream.listen((data) {
      _ethPrice = data.price;
      notifyListeners();
    });
    _btcSub = marketData.btcDataStream.listen((data) {
      _btcPrice = data.price;
    });
    _signalSub = signalEngine.signalStream.listen((signal) {
      _currentSignal = signal;
      database.insertSignal(signal);
      notifyListeners();
    });
    _analysisSub = signalEngine.analysisStream.listen((analysis) {
      _analysis = analysis;
      _statusMessage = analysis.statusMessage;
      notifyListeners();
    });
    _riskSub = riskManager.riskStream.listen((state) {
      _riskState = state;
      notifyListeners();
    });
    _errorSub = marketData.errorStream.listen((error) {
      _statusMessage = error;
      notifyListeners();
    });

    _isInitialized = true;
    _statusMessage = '初始化完成，自动启动';
    notifyListeners();
    // 自动启动
    start();
  }

  void _registerHealthChecks() {
    selfHealing.registerCheck('data', () async {
      final eth = marketData.ethData;
      final btc = marketData.btcData;
      if (eth == null || btc == null) {
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
    await riskManager.checkRiskConditions();

    // 更新自适应参数给风控
    final eth5m = marketData.getEth5m();
    final adaptive = AdaptiveParams.calculate(eth5m);
    riskManager.setAdaptiveParams(adaptive);

    // 计算ETH/BTC强弱比
    if (_ethPrice > 0 && _btcPrice > 0) {
      _ethBtcRatio = _ethPrice / _btcPrice;
    }

    // L3极端风险时不生成信号，但仍更新分析
    if ((_riskState?.level ?? RiskLevel.L0) == RiskLevel.L3) {
      _statusMessage = '极端风险: ${_riskState?.reasonText ?? ''}';
      // 仍然运行分析以更新UI数据
      await signalEngine.tick();
      notifyListeners();
      return;
    }

    // 信号引擎（内部整合所有分析模块）
    await signalEngine.tick();
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

  /// 手动记录持仓
  void addManualPosition({
    required String direction,
    required double entryPrice,
    required double stopLoss,
    required double tp1,
    required double tp2,
    required double quantity,
  }) {
    final pos = Position(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      signalId: null,
      direction: direction == 'long' ? SignalDirection.long : SignalDirection.short,
      entryPrice: entryPrice,
      quantity: quantity,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      openedAt: DateTime.now().millisecondsSinceEpoch,
      batchNumber: positions.length + 1,
    );
    addPosition(pos);
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
    _analysisSub?.cancel();
    _riskSub?.cancel();
    _errorSub?.cancel();
    marketData.dispose();
    signalEngine.dispose();
    riskManager.dispose();
    selfHealing.dispose();
    super.dispose();
  }
}
