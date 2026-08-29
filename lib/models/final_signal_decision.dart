/// 最终信号决策（双引擎级联）
class FinalSignalDecision {
  final bool hasSignal;
  final String direction; // 'long' / 'short' / 'none'
  final double confidence; // 最终自信度0-100（双引擎综合）

  // 双引擎状态
  final bool multiDimensionPassed;
  final bool originalSignalPassed;

  // 各引擎评分
  final double multiScore;
  final double multiConfidence;
  final double originalConfidence;

  // 信号点位（有信号时）
  final double entryLower;
  final double entryUpper;
  final double stopLoss;
  final double tp1;
  final double tp2;

  // 关键价位（始终计算）
  final double supportPrice; // 支撑位
  final double resistancePrice; // 压力位
  final double currentPrice; // 当前价

  // 文字分析（始终输出）
  final String trendAnalysis; // 趋势分析
  final String marketOutlook; // 市场展望
  final String entryAdvice; // 入场建议
  final String stopLossAdvice; // 止损建议
  final String takeProfitAdvice; // 止盈建议

  // 建议
  final String positionAdvice;
  final String status;
  final List<String> failedFilters;
  final String recommendation;

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
    required this.supportPrice,
    required this.resistancePrice,
    required this.currentPrice,
    required this.trendAnalysis,
    required this.marketOutlook,
    required this.entryAdvice,
    required this.stopLossAdvice,
    required this.takeProfitAdvice,
    required this.positionAdvice,
    required this.status,
    required this.failedFilters,
    required this.recommendation,
  });

  String get confidenceLevel {
    if (confidence >= 85) return '极高';
    if (confidence >= 75) return '高';
    if (confidence >= 65) return '中';
    if (confidence >= 50) return '低';
    return '无';
  }

  String get engineStatus {
    if (multiDimensionPassed && originalSignalPassed) return '双引擎通过';
    if (multiDimensionPassed) return '仅多维度通过';
    if (originalSignalPassed) return '仅原信号通过';
    return '双引擎未通过';
  }

  double get riskRewardRatio {
    if (stopLoss == 0 || entryUpper == 0) return 0;
    final risk = (entryUpper - stopLoss).abs();
    if (risk == 0) return 0;
    final reward = (tp2 - entryUpper).abs();
    return reward / risk;
  }

  /// 距离支撑位的百分比
  double get distanceToSupport {
    if (supportPrice == 0 || currentPrice == 0) return 0;
    return (currentPrice - supportPrice).abs() / currentPrice * 100;
  }

  /// 距离压力位的百分比
  double get distanceToResistance {
    if (resistancePrice == 0 || currentPrice == 0) return 0;
    return (resistancePrice - currentPrice).abs() / currentPrice * 100;
  }
}
