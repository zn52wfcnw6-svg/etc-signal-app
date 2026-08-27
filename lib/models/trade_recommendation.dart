/// 推单推荐方向
enum TradeRecommendationDirection { long, short, wait }

/// 推单推荐模型
class TradeRecommendation {
  final TradeRecommendationDirection direction;
  final double entryLower;
  final double entryUpper;
  final double stopLoss;
  final double tp1;
  final double tp2;
  final double riskRewardRatio;
  final double positionSize; // 仓位比例 0-1
  final String triggerCondition;
  final String reason;
  final bool isConfirmed; // 是否为确认信号，还是候选推单

  const TradeRecommendation({
    required this.direction,
    required this.entryLower,
    required this.entryUpper,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.riskRewardRatio,
    required this.positionSize,
    required this.triggerCondition,
    required this.reason,
    this.isConfirmed = false,
  });

  /// 观望推荐
  factory TradeRecommendation.wait(String reason) {
    return TradeRecommendation(
      direction: TradeRecommendationDirection.wait,
      entryLower: 0,
      entryUpper: 0,
      stopLoss: 0,
      tp1: 0,
      tp2: 0,
      riskRewardRatio: 0,
      positionSize: 0,
      triggerCondition: '等待价格到达关键价位',
      reason: reason,
    );
  }

  String get directionText {
    switch (direction) {
      case TradeRecommendationDirection.long:
        return '做多';
      case TradeRecommendationDirection.short:
        return '做空';
      case TradeRecommendationDirection.wait:
        return '观望';
    }
  }

  String get entryText {
    if (direction == TradeRecommendationDirection.wait) return '-';
    return '\$${entryLower.toStringAsFixed(2)} - \$${entryUpper.toStringAsFixed(2)}';
  }

  String get slText {
    if (direction == TradeRecommendationDirection.wait) return '-';
    return '\$${stopLoss.toStringAsFixed(2)}';
  }

  String get tp1Text {
    if (direction == TradeRecommendationDirection.wait) return '-';
    return '\$${tp1.toStringAsFixed(2)}';
  }

  String get tp2Text {
    if (direction == TradeRecommendationDirection.wait) return '-';
    return '\$${tp2.toStringAsFixed(2)}';
  }

  String get rrText {
    if (direction == TradeRecommendationDirection.wait) return '-';
    return '1:${riskRewardRatio.toStringAsFixed(1)}';
  }

  String get positionText {
    if (direction == TradeRecommendationDirection.wait) return '-';
    return '${(positionSize * 100).toStringAsFixed(0)}%';
  }
}
