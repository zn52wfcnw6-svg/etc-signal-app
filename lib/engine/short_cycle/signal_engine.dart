import 'dart:async';
import '../../models/signal.dart';
import '../../utils/constants.dart';
import '../../data/market_data_manager.dart';
import '../long_cycle/long_cycle_manager.dart';
import '../adaptive/adaptive_params.dart';
import '../market_regime/market_regime.dart';
import '../multi_timeframe/mtf_analyzer.dart';
import '../order_flow/deep_order_flow.dart';
import '../optimization/signal_optimizer.dart';
import '../risk/risk_manager.dart';
import 'signal_detector.dart';

/// 综合分析结果（用于UI展示）
class AnalysisResult {
  final LongCycleResult longCycle;
  final AdaptiveParams adaptiveParams;
  final MarketRegimeResult regime;
  final MultiTimeframeResult mtf;
  final DeepOrderFlowResult orderFlow;
  final String statusMessage;
  final int confirmationCount;
  final int requiredConfirmations;
  final SignalDirection? pendingDirection;

  AnalysisResult({
    required this.longCycle,
    required this.adaptiveParams,
    required this.regime,
    required this.mtf,
    required this.orderFlow,
    required this.statusMessage,
    required this.confirmationCount,
    required this.requiredConfirmations,
    this.pendingDirection,
  });
}

/// 信号引擎：整合所有分析模块
class SignalEngine {
  final MarketDataManager _dataManager;
  final LongCycleManager _longCycle;
  final SignalDetector _detector;
  final SignalOptimizer _optimizer = SignalOptimizer();

  TradingSignal? _currentSignal;
  final List<ConfirmationResult> _confirmationBuffer = [];
  SignalDirection? _pendingDirection;
  int _confirmationCount = 0;

  AnalysisResult? _lastAnalysis;

  final StreamController<TradingSignal> _signalController = StreamController<TradingSignal>.broadcast();
  final StreamController<AnalysisResult> _analysisController = StreamController<AnalysisResult>.broadcast();

  Stream<TradingSignal> get signalStream => _signalController.stream;
  Stream<AnalysisResult> get analysisStream => _analysisController.stream;
  TradingSignal? get currentSignal => _currentSignal;
  LongCycleManager get longCycle => _longCycle;
  SignalOptimizer get optimizer => _optimizer;
  AnalysisResult? get lastAnalysis => _lastAnalysis;

  SignalEngine(this._dataManager)
      : _longCycle = LongCycleManager(_dataManager),
        _detector = SignalDetector(_dataManager.orderFlow);

  /// 每次轮询调用
  Future<void> tick() async {
    _checkExpiry();

    // 1. 自适应参数
    final eth5m = _dataManager.getEth5m();
    final adaptive = AdaptiveParams.calculate(eth5m);

    // 2. 长周期分析
    final longCycle = _longCycle.analyze();

    // 3. 市场状态识别
    final eth4h = _dataManager.getEth4h();
    final regime = MarketRegimeAnalyzer.analyze(eth4h, adaptive);

    // 4. 多周期共振
    final mtf = MultiTimeframeAnalyzer.analyze(
      k1d: _dataManager.getEth1d(),
      k4h: eth4h,
      k1h: _dataManager.getEth1h(),
      k5m: eth5m,
      k1m: _dataManager.getEth1m(),
    );

    // 5. 深度订单流（Web版无逐笔成交，用K线近似）
    final orderFlow = DeepOrderFlowAnalyzer.analyze(eth5m, []);

    // 保存分析结果
    _lastAnalysis = AnalysisResult(
      longCycle: longCycle,
      adaptiveParams: adaptive,
      regime: regime,
      mtf: mtf,
      orderFlow: orderFlow,
      statusMessage: '分析中',
      confirmationCount: _confirmationCount,
      requiredConfirmations: adaptive.confirmationCount,
      pendingDirection: _pendingDirection,
    );

    // 检查市场状态是否允许交易
    if (!_isTradingAllowed(regime, longCycle)) {
      _pendingDirection = null;
      _confirmationCount = 0;
      _confirmationBuffer.clear();
      _emitAnalysis(longCycle, adaptive, regime, mtf, orderFlow, regime.recommendedStrategy);
      return;
    }

    final eth1m = _dataManager.getEth1m();
    if (eth1m.length < 10 || eth5m.length < 10) {
      _emitAnalysis(longCycle, adaptive, regime, mtf, orderFlow, 'K线数据不足');
      return;
    }

    // 6. 短周期信号检测
    ConfirmationResult? result;

    if (_pendingDirection == SignalDirection.long) {
      result = _detector.detectLong(longCycle, eth1m, eth5m, adaptive: adaptive);
    } else if (_pendingDirection == SignalDirection.short) {
      result = _detector.detectShort(longCycle, eth1m, eth5m, adaptive: adaptive);
    } else {
      // 新检测：根据市场状态决定优先方向
      if (regime.allowsCounterTrend && longCycle.allowsLong) {
        result = _detector.detectLong(longCycle, eth1m, eth5m, adaptive: adaptive);
        if (result.allPassed) _pendingDirection = SignalDirection.long;
      }
      if (result == null || !result.allPassed) {
        if (regime.allowsCounterTrend && longCycle.allowsShort) {
          result = _detector.detectShort(longCycle, eth1m, eth5m, adaptive: adaptive);
          if (result.allPassed) _pendingDirection = SignalDirection.short;
        }
      }
    }

    if (result != null && result.allPassed) {
      // 7. 多周期共振过滤
      final resonance = mtf.resonanceStrength(_pendingDirection == SignalDirection.long);
      if (resonance < 2) {
        _pendingDirection = null;
        _confirmationCount = 0;
        _emitAnalysis(longCycle, adaptive, regime, mtf, orderFlow, '多周期共振不足($resonance/5)');
        return;
      }

      // 8. 自优化过滤
      if (_optimizer.shouldFilter(
        regime: regime.regime.name,
        mtfResonance: resonance,
        confidenceScore: result.confidenceScore ?? 0,
        gates: result.gates,
      )) {
        _pendingDirection = null;
        _confirmationCount = 0;
        _emitAnalysis(longCycle, adaptive, regime, mtf, orderFlow, '历史胜率过滤');
        return;
      }

      _confirmationCount++;
      _confirmationBuffer.add(result);

      if (_confirmationCount >= adaptive.confirmationCount) {
        _generateSignal(result, longCycle, regime, mtf, adaptive);
        _pendingDirection = null;
        _confirmationCount = 0;
        _confirmationBuffer.clear();
      } else {
        _emitAnalysis(
          longCycle, adaptive, regime, mtf, orderFlow,
          '${_pendingDirection == SignalDirection.long ? "多头" : "空头"}确认中 $_confirmationCount/${adaptive.confirmationCount}',
        );
      }
    } else {
      if (_pendingDirection != null) {
        _pendingDirection = null;
        _confirmationCount = 0;
        _confirmationBuffer.clear();
      }
      _emitAnalysis(longCycle, adaptive, regime, mtf, orderFlow, '无有效信号');
    }
  }

  bool _isTradingAllowed(MarketRegimeResult regime, LongCycleResult longCycle) {
    // 趋势市只做顺势
    if (regime.regime == MarketRegime.trendingUp && !longCycle.allowsLong) return false;
    if (regime.regime == MarketRegime.trendingDown && !longCycle.allowsShort) return false;
    // 极端市只做反转
    if (regime.regime == MarketRegime.extreme &&
        longCycle.state != LongCycleState.trendExhaustion) return false;
    return true;
  }

  void _generateSignal(
    ConfirmationResult result,
    LongCycleResult longCycle,
    MarketRegimeResult regime,
    MultiTimeframeResult mtf,
    AdaptiveParams adaptive,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final direction = _pendingDirection!;

    final signal = TradingSignal(
      id: 'sig_${now}_${direction.name}',
      direction: direction,
      status: SignalStatus.confirmed,
      createdAt: now - adaptive.confirmationCount * AppConstants.pollIntervalSeconds * 1000,
      confirmedAt: now,
      expiresAt: now + AppConstants.signalExpiryMinutes * 60 * 1000,
      entryLower: result.entryLower!,
      entryUpper: result.entryUpper!,
      stopLoss: result.stopLoss!,
      tp1: result.tp1!,
      tp2: result.tp2!,
      confidenceScore: result.confidenceScore!,
      confidenceBreakdown: result.confidenceBreakdown!,
      confirmationGates: result.gates,
      marketRegime: regime.regime.name,
      volatilityState: adaptive.volatilityLabel,
      fundingRateAtSignal: _dataManager.ethData?.fundingRate ?? 0,
    );

    _currentSignal = signal;
    _signalController.add(signal);

    // 记录到自优化引擎
    _optimizer.recordSignal(SignalRecord(
      id: signal.id,
      timestamp: DateTime.now(),
      direction: direction,
      entryPrice: (signal.entryLower + signal.entryUpper) / 2,
      stopLoss: signal.stopLoss,
      tp1: signal.tp1,
      tp2: signal.tp2,
      marketRegime: regime.description,
      regime: regime.regime.name,
      mtfResonance: mtf.resonanceStrength(direction == SignalDirection.long),
      confidenceScore: signal.confidenceScore.toDouble(),
      gates: signal.confirmationGates,
    ));
  }

  void _emitAnalysis(
    LongCycleResult longCycle,
    AdaptiveParams adaptive,
    MarketRegimeResult regime,
    MultiTimeframeResult mtf,
    DeepOrderFlowResult orderFlow,
    String message,
  ) {
    _lastAnalysis = AnalysisResult(
      longCycle: longCycle,
      adaptiveParams: adaptive,
      regime: regime,
      mtf: mtf,
      orderFlow: orderFlow,
      statusMessage: message,
      confirmationCount: _confirmationCount,
      requiredConfirmations: adaptive.confirmationCount,
      pendingDirection: _pendingDirection,
    );
    _analysisController.add(_lastAnalysis!);
  }

  void _checkExpiry() {
    if (_currentSignal != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > _currentSignal!.expiresAt) {
        _optimizer.updateOutcome(_currentSignal!.id, SignalOutcome.expired, 0);
        _currentSignal = null;
      }
    }
  }

  void markSignalExecuted(String signalId, bool executed, {double? pnl}) {
    if (_currentSignal?.id == signalId) {
      if (executed && pnl != null) {
        _optimizer.updateOutcome(
          signalId,
          pnl >= 0 ? SignalOutcome.tp1Hit : SignalOutcome.stopLoss,
          pnl,
        );
      }
      _currentSignal = _currentSignal!.copyWith(
        userExecuted: executed,
        actualPnl: pnl,
        status: executed ? SignalStatus.active : SignalStatus.archived,
      );
    }
  }

  void archiveSignal() {
    if (_currentSignal != null) {
      _currentSignal = _currentSignal!.copyWith(status: SignalStatus.archived);
      _currentSignal = null;
    }
  }

  void dispose() {
    _signalController.close();
    _analysisController.close();
  }
}
