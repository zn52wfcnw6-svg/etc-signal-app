/// 最终信号决策（双引擎级联）
class FinalSignalDecision {
  final bool hasSignal;
  final String direction; // 'long' / 'short' / 'none'
  final double confidence; // 最终自信度0-100（双引擎综合）

  // 双引擎状态
  final bool multiDimensionPassed; // 多维度决策引擎是否通过
  final bool originalSignalPassed; // 原信号引擎是否通过

  // 各引擎评分
  final double multiScore; // 多维度引擎综合评分
  final double multiConfidence; // 多维度引擎可信度
  final double originalConfidence; // 原信号引擎置信度

  // 点位
  final double entryLower;
  final double entryUpper;
  final double stopLoss;
  final double tp1;
  final double tp2;

  // 建议
  final String positionAdvice; // 仓位建议
  final String status; // 状态描述
  final List<String> failedFilters; // 未通过的过滤条件
  final String recommendation; // 推荐操作

  FinalSignalDecision({
    required this.hasSignal,
    required this.direction,
    required this.confidence,
    required this.multiDimensionPassed,
    required this.originalSignalPassed,
    required this.multiScore,
    required this.multiConfidence,
    required this.originalConfidence,
    required this.entryLower,
    required this.entryUpper,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.positionAdvice,
    required this.status,
    required this.failedFilters,
    required this.recommendation,
  });

  /// 获取自信度等级
  String get confidenceLevel {
    if (confidence >= 85) return '极高';
    if (confidence >= 75) return '高';
    if (confidence >= 65) return '中';
    if (confidence >= 50) return '低';
    return '无';
  }

  /// 获取双引擎通过状态描述
  String get engineStatus {
    if (multiDimensionPassed && originalSignalPassed) return '双引擎通过';
    if (multiDimensionPassed) return '仅多维度通过';
    if (originalSignalPassed) return '仅原信号通过';
    return '双引擎未通过';
  }

  /// 计算盈亏比
  double get riskRewardRatio {
    if (stopLoss == 0 || entryUpper == 0) return 0;
    final risk = (entryUpper - stopLoss).abs();
    if (risk == 0) return 0;
    final reward = (tp2 - entryUpper).abs();
    return reward / risk;
  }
}
