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
import '../monitor/performance_monitor.dart';
import '../data/multi_dimension_data_manager.dart';
import '../engine/sss/sss_analyzer.dart';
import '../engine/signal_history_tracker.dart';
import '../engine/signal_enhancement_manager.dart';
import '../engine/signal_lifecycle_manager.dart';
import '../engine/system_closed_loop_manager.dart';
import '../engine/advanced_features.dart';
import '../engine/multi_dimension_signal_engine.dart';
import '../models/final_signal_decision.dart';
import '../storage/database_helper.dart';
import '../models/signal.dart';
import '../models/position.dart';
import '../models/trading_pair.dart';
import '../utils/constants.dart';

/// 应用全局状态
class AppState extends ChangeNotifier {
  final MarketDataManager marketData = MarketDataManager();
  SignalEngine? signalEngine;
  RiskManager? riskManager;
  SelfHealingMonitor? selfHealing;
  final MultiDimensionDataManager multiDimensionData = MultiDimensionDataManager();
  final SignalHistoryTracker signalHistory = SignalHistoryTracker();
  final SignalEnhancementManager enhancement = SignalEnhancementManager();
  final SignalLifecycleManager lifecycle = SignalLifecycleManager();
  final AccountRiskManager accountRisk = AccountRiskManager();
  final AlertNotificationManager alerts = AlertNotificationManager();
  final MLParameterOptimizer mlOptimizer = MLParameterOptimizer();
  BacktestResult? _backtestResult;
  BacktestResult? get backtestResult => _backtestResult;
  Map<String, double>? _optimizedParams;
  Map<String, double>? get optimizedParams => _optimizedParams;
  SignalDecision? _multiDimensionDecision;
  SignalDecision? get multiDimensionDecision => _multiDimensionDecision;

  /// 最终信号决策（双引擎级联）
  FinalSignalDecision? _finalSignal;
  FinalSignalDecision? get finalSignal => _finalSignal;
  SSSResult? _sssResult;
  SSSResult? get sssResult => _sssResult;
  final DatabaseHelper database = DatabaseHelper();

  bool _isInitialized = false;
  String? _initError;
  bool _isRunning = false;
  bool _klinesReady = false;
  bool get klinesReady => _klinesReady;

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
  List<Position> get positions => riskManager?.positions ?? [];
  double get accountBalance => riskManager?.accountBalance ?? 0;
  double get totalRisk => riskManager?.totalRisk ?? 0;

  StreamSubscription? _ethSub;
  StreamSubscription? _btcSub;
  StreamSubscription? _signalSub;
  StreamSubscription? _analysisSub;
  StreamSubscription? _riskSub;
  StreamSubscription? _errorSub;
  Timer? _mainTimer;

  Future<void> init() async {
    if (_isInitialized) return;
    // 总的初始化超时保护，确保不会无限卡住
    final initCompleter = Completer<void>();
    final timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (!initCompleter.isCompleted) {
        initCompleter.completeError(TimeoutException('初始化超时，使用降级模式'));
      }
    });
    try {
      await database.init().timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (e) {
      _statusMessage = '数据库初始化失败，使用内存模式';
      notifyListeners();
    }
    try {
      signalEngine = SignalEngine(marketData);
      riskManager = RiskManager(marketData);
      selfHealing = SelfHealingMonitor(database);
      await marketData.init();
      _registerHealthChecks();
      // 初始化多维度数据（消息面/宏观面/情绪面/资金面）
      unawaited(multiDimensionData.init());
      // 监听K线加载状态
      _checkKlinesReady();

      _ethSub = marketData.ethDataStream.listen((data) {
        _ethPrice = data.price;
        // 更新信号生命周期状态
        try {
          lifecycle.updateSignals(currentPrice: data.price, currentTime: DateTime.now());
          // 更新账户风险持仓浮动盈亏
          accountRisk.updatePositions(data.price);
          // 运行多维度信号决策（每10秒一次）
          if (DateTime.now().second % 10 < 3) {
            _runMultiDimensionDecision();
          }
        } catch (_) {}
        notifyListeners();
      });
      _btcSub = marketData.btcDataStream.listen((data) {
        _btcPrice = data.price;
      });
      _signalSub = signalEngine?.signalStream.listen((signal) {
        _currentSignal = signal;
        try { database.insertSignal(signal); } catch (_) {}
        notifyListeners();
      });
      _analysisSub = signalEngine?.analysisStream.listen((analysis) {
        _analysis = analysis;
        _statusMessage = analysis.statusMessage;
        notifyListeners();
      });
      _riskSub = riskManager?.riskStream.listen((state) {
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
      // 后台运行回测和参数优化
      _runBacktestInBackground();
      start();
    } catch (e, stack) {
      _statusMessage = '初始化完成（降级模式）';
      _initError = '$e\n$stack';
    } finally {
      timeoutTimer.cancel();
      if (!initCompleter.isCompleted) {
        initCompleter.complete();
      }
      // 无论成功或失败，都标记为已初始化，避免卡住
      if (!_isInitialized) {
        _isInitialized = true;
        if (_statusMessage == '初始化中...') {
          _statusMessage = '初始化完成';
        }
        notifyListeners();
        // 尝试启动（即使部分模块初始化失败）
        if (signalEngine != null && riskManager != null) {
          start();
        }
      }
    }
  }

  /// 检查K线是否加载完成，完成后触发信号计算
  Future<void> _checkKlinesReady() async {
    // 轮询检查K线加载状态，最多等待60秒
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (marketData.klinesLoaded) {
        _klinesReady = true;
        _statusMessage = 'K线数据加载完成，开始信号分析';
        notifyListeners();
        // K线加载完成后立即触发一次信号计算
        if (signalEngine != null) {
          try {
            await signalEngine!.tick();
          } catch (_) {}
        }
        return;
      }
    }
    // 超时后也标记为就绪，使用已有数据
    _klinesReady = true;
    _statusMessage = 'K线数据部分加载，使用已有数据分析';
    notifyListeners();
  }

  void _registerHealthChecks() {
    selfHealing?.registerCheck('data', () async {
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
    selfHealing?.registerHealer('data', () async {
      await marketData.manualRefresh();
      return marketData.ethData != null;
    });
  }

  void start() {
    if (!_isInitialized || _isRunning) return;
    _isRunning = true;
    marketData.startPolling();
    selfHealing?.start();
    _mainTimer = Timer.periodic(
      const Duration(seconds: AppConstants.pollIntervalSeconds),
      (_) => _tick(),
    );
    _statusMessage = '运行中';
    notifyListeners();
  }

  Future<void> _tick() async {
    final timer = PerformanceTimer('tick_total');
    PerformanceMonitor().recordTick();
    // 风控检查
    final riskTimer = PerformanceTimer('risk_check');
    await riskManager?.checkRiskConditions();
    riskTimer.finish();

    // 更新自适应参数给风控
    final eth5m = marketData.getEth5m();
    final adaptive = AdaptiveParams.calculate(eth5m);
    riskManager?.setAdaptiveParams(adaptive);

    // 计算ETH/BTC强弱比
    if (_ethPrice > 0 && _btcPrice > 0) {
      _ethBtcRatio = _ethPrice / _btcPrice;
    }

    // L3极端风险时不生成信号，但仍更新分析
    if ((_riskState?.level ?? RiskLevel.L0) == RiskLevel.L3) {
      _statusMessage = '极端风险: ${_riskState?.reasonText ?? ''}';
      // 仍然运行分析以更新UI数据
      await signalEngine?.tick();
      notifyListeners();
      return;
    }

    // 信号引擎（内部整合所有分析模块）
    final signalTimer = PerformanceTimer('signal_engine');
    await signalEngine?.tick();
    signalTimer.finish();
    
    // 更新信号历史统计（根据当前价格判断止损/止盈）
    signalHistory.updateSignals(_ethPrice);
    
    timer.finish();
  }

  Future<void> manualRefresh() async {
    final timer = PerformanceTimer('manual_refresh');
    await marketData.manualRefresh();
    await _tick();
    timer.finish();
  }

  void setAccountBalance(double balance) {
    riskManager?.setAccountBalance(balance);
    notifyListeners();
  }

  void addPosition(Position pos) {
    riskManager?.addPosition(pos);
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
    riskManager?.closePosition(id, closePrice, pnl);
    notifyListeners();
  }

  void markSignalExecuted(bool executed, {double? pnl}) {
    if (_currentSignal != null) {
      signalEngine?.markSignalExecuted(_currentSignal!.id, executed, pnl: pnl);
      database.updateSignal(_currentSignal!);
      notifyListeners();
    }
  }

  void stop() {
    _isRunning = false;
    _mainTimer?.cancel();
    marketData.stopPolling();
    selfHealing?.stop();
    notifyListeners();
  }

  /// 后台运行回测和参数优化
  Future<void> _runBacktestInBackground() async {
    try {
      await Future.delayed(const Duration(seconds: 10));
      final klines = marketData.getEth1h();
      if (klines.length >= 100) {
        _backtestResult = BacktestEngine.runBacktest(
          klines: klines,
          params: mlOptimizer.currentParams,
        );
        _optimizedParams = mlOptimizer.optimize();
        _statusMessage = '回测完成: \${_backtestResult!.summary}';
        notifyListeners();
      }
    } catch (_) {}
  }

  /// 运行多维度信号决策
  void _runMultiDimensionDecision() {
    try {
      final klines5m = marketData.getEth5m();
      final klines1h = marketData.getEth1h();
      final klines4h = marketData.getEth4h();
      if (klines5m.length < 20) return;

      final longCycle = signalEngine?.longCycle.analyze();
      final support = longCycle?.nearestSupport?.mid;
      final resistance = longCycle?.nearestResistance?.mid;

      final orderFlowBars = marketData.orderFlow.getRecentBars(50);
      double buyVolume = 0, sellVolume = 0;
      for (final bar in orderFlowBars) {
        buyVolume += bar.buyVolume;
        sellVolume += bar.sellVolume;
      }

      final multiDim = multiDimensionData;

      _multiDimensionDecision = MultiDimensionSignalEngine.analyze(
        klines5m: klines5m,
        klines1h: klines1h,
        klines4h: klines4h,
        currentPrice: _ethPrice,
        support: support,
        resistance: resistance,
        cvd: marketData.orderFlow.cumulativeCVD,
        buyVolume: buyVolume,
        sellVolume: sellVolume,
        liquidations: marketData.ethLiquidations,
        orderBook: marketData.ethOrderBook,
        fearGreedIndex: multiDim.fearGreedIndex,
        longShortRatio: multiDim.longShortRatio,
        news: multiDim.news,
        sp500Change: multiDim.sp500Change,
        goldChange: multiDim.goldChange,
        dxyChange: multiDim.dxyChange,
        treasuryYield: multiDim.treasuryYield,
        fundingRate: _ethPrice > 0 ? (marketData.ethData?.fundingRate ?? 0) : 0,
        openInterest: marketData.ethData?.openInterest ?? 0,
        openInterestChange: multiDim.openInterestChange,
        stablecoinMarketCapChange: multiDim.stablecoinMarketCapChange,
      );

      // 双引擎级联决策
      _runFinalSignalDecision();
    } catch (_) {}
  }

  /// 双引擎级联决策（多维度总闸门 → 原信号精确入场 → 最终结论）
  void _runFinalSignalDecision() {
    try {
      final multiDim = _multiDimensionDecision;
      if (multiDim == null) {
        _finalSignal = null;
        return;
      }

      // 第一级：多维度决策引擎（总闸门）
      final multiPassed = multiDim.hasSignal;
      final multiScore = multiDim.finalScore;
      final multiConfidence = multiDim.confidence;
      final direction = multiDim.direction;

      // 第二级：原信号引擎（精确入场）
      final originalSignal = signalEngine?.currentSignal;
      final originalPassed = originalSignal != null && originalSignal.status == SignalStatus.confirmed;
      final originalConfidence = (originalSignal?.confidenceScore ?? 0).toDouble();

      // 计算最终自信度（双引擎综合）
      double finalConfidence;
      if (multiPassed && originalPassed) {
        finalConfidence = (multiConfidence * 0.5 + originalConfidence * 0.5);
      } else if (multiPassed) {
        finalConfidence = multiConfidence * 0.6;
      } else if (originalPassed) {
        finalConfidence = originalConfidence * 0.4;
      } else {
        finalConfidence = 0;
      }

      // 判断最终是否有信号
      final hasFinalSignal = multiPassed && originalPassed && finalConfidence >= 60;

      // 计算点位（优先用原信号引擎的精确点位）
      double entryLower = 0, entryUpper = 0, stopLoss = 0, tp1 = 0, tp2 = 0;
      if (originalSignal != null) {
        entryLower = originalSignal.entryLower;
        entryUpper = originalSignal.entryUpper;
        stopLoss = originalSignal.stopLoss;
        tp1 = originalSignal.tp1;
        tp2 = originalSignal.tp2;
      } else if (multiDim.hasSignal) {
        entryLower = multiDim.entryLower;
        entryUpper = multiDim.entryUpper;
        stopLoss = multiDim.stopLoss;
        tp1 = multiDim.tp1;
        tp2 = multiDim.tp2;
      }

      // 计算仓位建议（根据自信度动态调整）
      String positionAdvice;
      if (finalConfidence >= 85) {
        positionAdvice = '高自信，建议标准仓位1%';
      } else if (finalConfidence >= 75) {
        positionAdvice = '中高自信，建议0.7%仓位';
      } else if (finalConfidence >= 65) {
        positionAdvice = '中等自信，建议0.5%仓位';
      } else if (finalConfidence >= 50) {
        positionAdvice = '低自信，建议观望或0.3%轻仓';
      } else {
        positionAdvice = '无信号，观望';
      }

      // 状态描述
      String status;
      if (hasFinalSignal) {
        status = direction == 'long' ? '强烈做多' : '强烈做空';
      } else if (multiPassed && !originalPassed) {
        status = '大方向确认，等待精确入场';
      } else if (!multiPassed && originalPassed) {
        status = '入场信号出现，但大方向不支持';
      } else if (multiScore >= 60) {
        status = '接近信号阈值，密切关注';
      } else {
        status = '无有效信号，观望';
      }

      _finalSignal = FinalSignalDecision(
        hasSignal: hasFinalSignal,
        direction: hasFinalSignal ? direction : 'none',
        confidence: finalConfidence,
        multiDimensionPassed: multiPassed,
        originalSignalPassed: originalPassed,
        multiScore: multiScore,
        multiConfidence: multiConfidence,
        originalConfidence: originalConfidence,
        entryLower: entryLower,
        entryUpper: entryUpper,
        stopLoss: stopLoss,
        tp1: tp1,
        tp2: tp2,
        positionAdvice: positionAdvice,
        status: status,
        failedFilters: multiDim.failedFilters,
        recommendation: multiDim.recommendation,
      );
    } catch (_) {
      _finalSignal = null;
    }
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
    signalEngine?.dispose();
    riskManager?.dispose();
    selfHealing?.dispose();
    super.dispose();
  }
}
