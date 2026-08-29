import 'dart:async';
import 'signal_lifecycle_manager.dart';

/// 账户风险管理器
class AccountRiskManager {
  double _accountBalance = 10000; // 账户余额（美元）
  double _singleRiskPercent = 1.0; // 单笔风险百分比
  double _totalRiskPercent = 5.0; // 总风险百分比
  double _minRiskReward = 4.0; // 最低盈亏比
  int _maxConcurrentPositions = 3; // 最大同时持仓数
  int _consecutiveLosses = 0; // 连续亏损次数
  double _currentTotalRisk = 0; // 当前总风险占用
  final List<OpenPosition> _openPositions = [];

  // 风险参数变化回调
  void Function(double totalRisk)? onRiskChange;

  double get accountBalance => _accountBalance;
  double get singleRiskPercent => _singleRiskPercent;
  double get totalRiskPercent => _totalRiskPercent;
  double get minRiskReward => _minRiskReward;
  int get maxConcurrentPositions => _maxConcurrentPositions;
  int get consecutiveLosses => _consecutiveLosses;
  double get currentTotalRisk => _currentTotalRisk;
  List<OpenPosition> get openPositions => List.unmodifiable(_openPositions);

  /// 设置账户余额
  void setAccountBalance(double balance) {
    _accountBalance = balance;
  }

  /// 设置单笔风险百分比
  void setSingleRiskPercent(double percent) {
    _singleRiskPercent = percent.clamp(0.1, 5.0);
  }

  /// 设置总风险百分比
  void setTotalRiskPercent(double percent) {
    _totalRiskPercent = percent.clamp(1.0, 20.0);
  }

  /// 计算单笔风险金额
  double get singleRiskAmount => _accountBalance * (_singleRiskPercent / 100);

  /// 计算总风险金额
  double get totalRiskAmount => _accountBalance * (_totalRiskPercent / 100);

  /// 计算建议仓位大小
  double calculatePositionSize({
    required double entryPrice,
    required double stopLoss,
  }) {
    final riskDistance = (entryPrice - stopLoss).abs();
    if (riskDistance <= 0) return 0;
    final positionSize = singleRiskAmount / riskDistance;
    return positionSize;
  }

  /// 检查是否可以开仓
  bool canOpenPosition({
    required double entryPrice,
    required double stopLoss,
    required double riskReward,
  }) {
    // 1. 检查盈亏比
    if (riskReward < _minRiskReward) return false;

    // 2. 检查最大持仓数
    if (_openPositions.length >= _maxConcurrentPositions) return false;

    // 3. 检查总风险
    final positionRisk = singleRiskPercent;
    if (_currentTotalRisk + positionRisk > _totalRiskPercent) return false;

    // 4. 连续亏损保护：连续亏损3次后，风险减半
    if (_consecutiveLosses >= 3) {
      // 仍然可以开仓，但风险自动减半（在计算仓位时处理）
    }

    return true;
  }

  /// 开仓
  OpenPosition? openPosition({
    required String direction,
    required double entryPrice,
    required double stopLoss,
    required double tp1,
    required double tp2,
    required String signalId,
  }) {
    final positionSize = calculatePositionSize(
      entryPrice: entryPrice,
      stopLoss: stopLoss,
    );

    // 连续亏损保护：连续亏损3次后，仓位减半
    double actualSize = positionSize;
    if (_consecutiveLosses >= 3) {
      actualSize = positionSize / 2;
    }

    final position = OpenPosition(
      id: 'POS-${DateTime.now().millisecondsSinceEpoch}',
      signalId: signalId,
      direction: direction,
      entryPrice: entryPrice,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      size: actualSize,
      openedAt: DateTime.now(),
    );

    _openPositions.add(position);
    _currentTotalRisk += _singleRiskPercent;
    onRiskChange?.call(_currentTotalRisk);

    return position;
  }

  /// 更新持仓浮动盈亏
  void updatePositions(double currentPrice) {
    for (final position in _openPositions) {
      position.updatePnl(currentPrice);
    }
  }

  /// 平仓
  void closePosition(String positionId, double exitPrice) {
    final position = _openPositions.firstWhere(
      (p) => p.id == positionId,
      orElse: () => throw 'Position not found',
    );

    position.close(exitPrice);
    _openPositions.remove(position);
    _currentTotalRisk -= _singleRiskPercent;
    if (_currentTotalRisk < 0) _currentTotalRisk = 0;

    // 更新连续亏损计数
    if (position.pnlPercent <= 0) {
      _consecutiveLosses++;
    } else {
      _consecutiveLosses = 0;
    }

    onRiskChange?.call(_currentTotalRisk);
  }

  /// 获取风险状态文本
  String get riskStatusText {
    final riskPercent = _currentTotalRisk;
    if (riskPercent == 0) return '无风险敞口';
    if (riskPercent < _totalRiskPercent * 0.5) return '低风险';
    if (riskPercent < _totalRiskPercent * 0.8) return '中等风险';
    return '高风险（接近上限）';
  }

  /// 获取连续亏损保护状态
  String get consecutiveLossProtectionText {
    if (_consecutiveLosses == 0) return '正常';
    if (_consecutiveLosses < 3) return '连续亏损$_consecutiveLosses次';
    return '连续亏损$_consecutiveLosses次，仓位自动减半';
  }

  /// 重置连续亏损计数
  void resetConsecutiveLosses() {
    _consecutiveLosses = 0;
  }

  /// 清空所有持仓
  void clearAllPositions() {
    _openPositions.clear();
    _currentTotalRisk = 0;
    onRiskChange?.call(0);
  }
}

/// 持仓
class OpenPosition {
  final String id;
  final String signalId;
  final String direction; // 'long' or 'short'
  final double entryPrice;
  final double stopLoss;
  final double tp1;
  final double tp2;
  final double size; // 仓位大小（币数）
  final DateTime openedAt;
  double? currentPrice;
  double? exitPrice;
  DateTime? closedAt;
  bool tp1Hit = false; // TP1是否已触及

  OpenPosition({
    required this.id,
    required this.signalId,
    required this.direction,
    required this.entryPrice,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.size,
    required this.openedAt,
  });

  /// 更新浮动盈亏
  void updatePnl(double price) {
    currentPrice = price;

    // 检查TP1是否触及
    if (!tp1Hit) {
      if (direction == 'long' && price >= tp1) {
        tp1Hit = true;
      } else if (direction == 'short' && price <= tp1) {
        tp1Hit = true;
      }
    }
  }

  /// 平仓
  void close(double price) {
    exitPrice = price;
    closedAt = DateTime.now();
  }

  /// 浮动盈亏百分比
  double get pnlPercent {
    final price = currentPrice ?? exitPrice ?? entryPrice;
    if (direction == 'long') {
      return ((price - entryPrice) / entryPrice) * 100;
    } else {
      return ((entryPrice - price) / entryPrice) * 100;
    }
  }

  /// 浮动盈亏金额
  double get pnlAmount => pnlPercent / 100 * size * entryPrice;

  /// 持仓时长
  Duration get holdingDuration =>
      (closedAt ?? DateTime.now()).difference(openedAt);

  /// 状态文本
  String get statusText {
    if (closedAt != null) return '已平仓';
    if (tp1Hit) return 'TP1已触及';
    return '持仓中';
  }
}

/// 预警通知管理器
class AlertNotificationManager {
  final List<AlertRecord> _alerts = [];
  final List<AlertRule> _rules = [];
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _systemNotificationEnabled = true;

  // 预警回调
  void Function(AlertRecord)? onAlert;

  List<AlertRecord> get alerts => List.unmodifiable(_alerts);
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get systemNotificationEnabled => _systemNotificationEnabled;

  /// 添加预警规则
  void addRule(AlertRule rule) {
    _rules.add(rule);
  }

  /// 移除预警规则
  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
  }

  /// 检查预警规则
  void checkAlerts({
    required double currentPrice,
    required SignalLifecycleState? signalState,
    required double riskLevel,
    required double? supportLevel,
    required double? resistanceLevel,
  }) {
    for (final rule in _rules) {
      if (rule.isTriggered(
        currentPrice: currentPrice,
        signalState: signalState,
        riskLevel: riskLevel,
        supportLevel: supportLevel,
        resistanceLevel: resistanceLevel,
      )) {
        if (!rule.isTriggeredRecently()) {
          _triggerAlert(rule, currentPrice);
          rule.lastTriggeredAt = DateTime.now();
        }
      }
    }
  }

  /// 触发预警
  void _triggerAlert(AlertRule rule, double price) {
    final alert = AlertRecord(
      id: 'ALERT-${DateTime.now().millisecondsSinceEpoch}',
      type: rule.type,
      title: rule.title,
      message: rule.message,
      price: price,
      triggeredAt: DateTime.now(),
    );

    _alerts.insert(0, alert);
    if (_alerts.length > 100) _alerts.removeLast();

    onAlert?.call(alert);

    // 播放声音和震动（在UI层处理）
  }

  /// 手动触发预警
  void triggerManualAlert({
    required AlertType type,
    required String title,
    required String message,
    double? price,
  }) {
    final alert = AlertRecord(
      id: 'ALERT-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      price: price,
      triggeredAt: DateTime.now(),
    );

    _alerts.insert(0, alert);
    if (_alerts.length > 100) _alerts.removeLast();

    onAlert?.call(alert);
  }

  /// 设置声音
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// 设置震动
  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  /// 设置系统通知
  void setSystemNotificationEnabled(bool enabled) {
    _systemNotificationEnabled = enabled;
  }

  /// 清空预警记录
  void clearAlerts() {
    _alerts.clear();
  }
}

/// 预警类型
enum AlertType {
  signalGenerated, // 信号生成
  signalConfirmed, // 信号确认
  signalTriggered, // 信号触发（价格到达入场区）
  signalExpired, // 信号失效
  priceReachSupport, // 价格到达支撑位
  priceReachResistance, // 价格到达压力位
  riskLevelChange, // 风险等级变化
  tp1Hit, // TP1触及
  stopLossHit, // 止损触及
  marketFreeze, // 市场冻结
}

/// 预警记录
class AlertRecord {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final double? price;
  final DateTime triggeredAt;
  bool read = false;

  AlertRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.price,
    required this.triggeredAt,
  });

  String get typeText {
    switch (type) {
      case AlertType.signalGenerated:
        return '信号生成';
      case AlertType.signalConfirmed:
        return '信号确认';
      case AlertType.signalTriggered:
        return '信号触发';
      case AlertType.signalExpired:
        return '信号失效';
      case AlertType.priceReachSupport:
        return '到达支撑位';
      case AlertType.priceReachResistance:
        return '到达压力位';
      case AlertType.riskLevelChange:
        return '风险变化';
      case AlertType.tp1Hit:
        return 'TP1触及';
      case AlertType.stopLossHit:
        return '止损触及';
      case AlertType.marketFreeze:
        return '市场冻结';
    }
  }
}

/// 预警规则
class AlertRule {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final double? targetPrice;
  final double? priceTolerance;
  DateTime? lastTriggeredAt;
  final Duration cooldown;

  AlertRule({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.targetPrice,
    this.priceTolerance = 0.1,
    this.cooldown = const Duration(minutes: 5),
  });

  /// 是否触发
  bool isTriggered({
    required double currentPrice,
    required SignalLifecycleState? signalState,
    required double riskLevel,
    required double? supportLevel,
    required double? resistanceLevel,
  }) {
    switch (type) {
      case AlertType.priceReachSupport:
        if (supportLevel == null) return false;
        return (currentPrice - supportLevel).abs() / supportLevel * 100 <
            (priceTolerance ?? 0.1);
      case AlertType.priceReachResistance:
        if (resistanceLevel == null) return false;
        return (currentPrice - resistanceLevel).abs() / resistanceLevel * 100 <
            (priceTolerance ?? 0.1);
      case AlertType.signalConfirmed:
        return signalState == SignalLifecycleState.confirmed;
      case AlertType.signalTriggered:
        return signalState == SignalLifecycleState.triggered;
      case AlertType.signalExpired:
        return signalState == SignalLifecycleState.expired;
      default:
        return false;
    }
  }

  /// 是否在冷却期内
  bool isTriggeredRecently() {
    if (lastTriggeredAt == null) return false;
    return DateTime.now().difference(lastTriggeredAt!) < cooldown;
  }
}
