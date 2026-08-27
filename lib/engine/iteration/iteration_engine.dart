import '../../models/signal.dart';
import '../../storage/database_helper.dart';
import '../../utils/constants.dart';
import 'backtest_engine.dart';

/// 参数调整提议
class ParamAdjustment {
  final String paramName;
  final double oldValue;
  final double newValue;
  final String reason;
  final double expectedImprovement;

  ParamAdjustment({
    required this.paramName,
    required this.oldValue,
    required this.newValue,
    required this.reason,
    required this.expectedImprovement,
  });
}

/// 迭代状态
enum IterationState { idle, analyzing, backtesting, observing, switched, rolledBack }

/// 自动迭代引擎：结果跟踪 → 场景分析 → 受限调参 → 灰度验证 → 切换/回滚
class IterationEngine {
  final DatabaseHelper _db;
  IterationState _state = IterationState.idle;
  ParamAdjustment? _pendingAdjustment;
  ParamAdjustment? _activeAdjustment;
  int _lastIterationTime = 0;
  int _consecutiveRollbacks = 0;

  // 可调整参数白名单及范围
  static const Map<String, Map<String, double>> _adjustableParams = {
    'confidence_threshold': {'min': 65, 'max': 80, 'step': 1},
    'confirmation_polls': {'min': 2, 'max': 4, 'step': 1},
    'pinbar_wick_ratio': {'min': 1.5, 'max': 3.0, 'step': 0.1},
    'cvd_divergence_threshold': {'min': 0.90, 'max': 0.98, 'step': 0.01},
    'signal_expiry_minutes': {'min': 10, 'max': 30, 'step': 5},
  };

  IterationEngine(this._db);

  IterationState get state => _state;
  ParamAdjustment? get pendingAdjustment => _pendingAdjustment;
  ParamAdjustment? get activeAdjustment => _activeAdjustment;

  /// 执行一次迭代分析
  Future<IterationState> runAnalysis() async {
    // 冷却期检查
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastIterationTime < AppConstants.iterationCooldownDays * 86400000) {
      return _state;
    }

    // 连续回滚熔断
    if (_consecutiveRollbacks >= 3) {
      _state = IterationState.idle;
      return _state;
    }

    _state = IterationState.analyzing;
    final signals = await _db.getRecentSignals(limit: 200);
    final executedSignals = signals.where((s) => s.userExecuted == true).toList();

    if (executedSignals.length < AppConstants.iterationMinSignals) {
      _state = IterationState.idle;
      return _state;
    }

    // 场景化分析
    final byConfidence = BacktestEngine.runByConfidence(executedSignals);
    final byRegime = BacktestEngine.runByRegime(executedSignals);

    // 生成调整提议
    final adjustment = _proposeAdjustment(executedSignals, byConfidence, byRegime);
    if (adjustment == null) {
      _state = IterationState.idle;
      return _state;
    }

    _pendingAdjustment = adjustment;
    _state = IterationState.backtesting;

    // 回测验证（简化：用历史数据模拟）
    final baseline = BacktestEngine.runFromSignals(executedSignals);
    // 这里应该用新参数重跑回测，简化为记录
    await _db.logIteration(
      paramName: adjustment.paramName,
      oldValue: adjustment.oldValue,
      newValue: adjustment.newValue,
      winrate: baseline.winRate,
      drawdown: baseline.maxDrawdown,
      status: 'backtesting',
      reason: adjustment.reason,
    );

    // 进入观察模式
    _state = IterationState.observing;
    return _state;
  }

  ParamAdjustment? _proposeAdjustment(
    List<TradingSignal> signals,
    Map<String, BacktestResult> byConfidence,
    Map<String, BacktestResult> byRegime,
  ) {
    // 策略1：如果65-69分区间胜率>=70分以上区间，降低置信度门槛
    final lowConf = byConfidence['65-69'];
    final highConf = byConfidence['70-79'];
    if (lowConf != null && highConf != null &&
        lowConf.totalSignals >= 5 && highConf.totalSignals >= 5) {
      if (lowConf.winRate >= highConf.winRate) {
        return ParamAdjustment(
          paramName: 'confidence_threshold',
          oldValue: AppConstants.minConfidenceScore.toDouble(),
          newValue: 65,
          reason: '65-69分区间胜率(${lowConf.winRate.toStringAsFixed(2)})不低于70-79分区间(${highConf.winRate.toStringAsFixed(2)})，可降低门槛增加信号量',
          expectedImprovement: 0.1,
        );
      }
    }

    // 策略2：如果平均盈亏比<3，考虑收紧pinbar比例提高质量
    final avgRR = signals.map((s) => s.riskRewardRatio).reduce((a, b) => a + b) / signals.length;
    if (avgRR < 3.0) {
      return ParamAdjustment(
        paramName: 'pinbar_wick_ratio',
        oldValue: AppConstants.pinBarWickRatio,
        newValue: 2.5,
        reason: '平均盈亏比(${avgRR.toStringAsFixed(2)})偏低，收紧pinbar形态要求提高信号质量',
        expectedImprovement: 0.15,
      );
    }

    // 策略3：如果信号量过少，考虑减少确认次数
    if (signals.length < 10) {
      return ParamAdjustment(
        paramName: 'confirmation_polls',
        oldValue: AppConstants.confirmationPolls.toDouble(),
        newValue: 2,
        reason: '信号量过少(${signals.length}笔)，减少确认次数从3次到2次以增加信号频率',
        expectedImprovement: 0.2,
      );
    }

    return null;
  }

  /// 灰度观察期结束，评估是否切换
  Future<bool> evaluateAndSwitch() async {
    if (_state != IterationState.observing || _pendingAdjustment == null) return false;

    // 简化：直接切换（实际应对比观察期新旧策略表现）
    final adj = _pendingAdjustment!;
    final range = _adjustableParams[adj.paramName];
    if (range == null) return false;

    // 范围校验
    if (adj.newValue < range['min']! || adj.newValue > range['max']!) {
      await _db.logIteration(
        paramName: adj.paramName,
        oldValue: adj.oldValue,
        newValue: adj.newValue,
        status: 'rejected',
        reason: '参数超出允许范围',
      );
      _state = IterationState.idle;
      return false;
    }

    // 步长校验：调整幅度不超过范围的20%
    final rangeSize = range['max']! - range['min']!;
    final changeSize = (adj.newValue - adj.oldValue).abs();
    if (changeSize > rangeSize * 0.2) {
      await _db.logIteration(
        paramName: adj.paramName,
        oldValue: adj.oldValue,
        newValue: adj.newValue,
        status: 'rejected',
        reason: '调整幅度过大',
      );
      _state = IterationState.idle;
      return false;
    }

    // 执行切换
    await _db.updateParam(adj.paramName, adj.newValue, 2);
    _activeAdjustment = adj;
    _pendingAdjustment = null;
    _lastIterationTime = DateTime.now().millisecondsSinceEpoch;
    _state = IterationState.switched;

    await _db.logIteration(
      paramName: adj.paramName,
      oldValue: adj.oldValue,
      newValue: adj.newValue,
      status: 'switched',
      reason: adj.reason,
    );

    return true;
  }

  /// 回滚到上一稳定参数
  Future<void> rollback(String reason) async {
    if (_activeAdjustment == null) return;

    final adj = _activeAdjustment!;
    await _db.updateParam(adj.paramName, adj.oldValue, 1);
    _consecutiveRollbacks++;
    _state = IterationState.rolledBack;

    await _db.logIteration(
      paramName: adj.paramName,
      oldValue: adj.newValue,
      newValue: adj.oldValue,
      status: 'rolled_back',
      reason: reason,
    );

    _activeAdjustment = null;
  }

  /// 重置回滚计数（人工介入后）
  void resetRollbackCounter() {
    _consecutiveRollbacks = 0;
  }

  /// 获取当前活跃参数
  Future<Map<String, double>> getActiveParams() async {
    return _db.getActiveParams();
  }
}
