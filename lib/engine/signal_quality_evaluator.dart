import './news/news_analyzer.dart';

/// 信号质量等级
enum SignalQuality {
  sss, // SSS级：顶级信号，多维度强确认
  ss, // SS级：优质信号，多维度确认
  s, // S级：良好信号，主要维度确认
  a, // A级：一般信号，部分维度确认
  b, // B级：谨慎信号，弱确认
}

/// 信号质量评估结果
class SignalQualityResult {
  final SignalQuality quality;
  final double totalScore; // 0-100
  final double technicalScore; // 技术面评分
  final double orderFlowScore; // 订单流评分
  final double newsScore; // 消息面评分
  final double multiTimeframeScore; // 多周期评分
  final double riskRewardScore; // 风控评分
  final String recommendation; // 操作建议
  final List<String> strongPoints; // 优势
  final List<String> weakPoints; // 劣势

  const SignalQualityResult({
    required this.quality,
    required this.totalScore,
    required this.technicalScore,
    required this.orderFlowScore,
    required this.newsScore,
    required this.multiTimeframeScore,
    required this.riskRewardScore,
    required this.recommendation,
    required this.strongPoints,
    required this.weakPoints,
  });

  String get qualityLabel {
    switch (quality) {
      case SignalQuality.sss: return 'SSS级';
      case SignalQuality.ss: return 'SS级';
      case SignalQuality.s: return 'S级';
      case SignalQuality.a: return 'A级';
      case SignalQuality.b: return 'B级';
    }
  }

  String get qualityColor {
    switch (quality) {
      case SignalQuality.sss: return 'FFD700'; // 金色
      case SignalQuality.ss: return 'C0C0C0'; // 银色
      case SignalQuality.s: return 'CD7F32'; // 铜色
      case SignalQuality.a: return '00FF00'; // 绿色
      case SignalQuality.b: return 'FFA500'; // 橙色
    }
  }
}

/// SSS级信号质量评估引擎
/// 综合技术面+订单流+消息面+多周期+风控，给出顶级信号评级
class SignalQualityEvaluator {
  /// 评估信号质量
  static SignalQualityResult evaluate({
    required double technicalScore, // 技术面评分 0-100
    required double orderFlowScore, // 订单流评分 0-100
    required NewsAnalysisResult? newsResult, // 消息面分析
    required double multiTimeframeScore, // 多周期评分 0-100
    required double riskRewardRatio, // 盈亏比
    required String direction, // 'long' or 'short'
  }) {
    // 消息面评分（基于情绪评分和方向一致性）
    double newsScore = 50; // 默认中性
    if (newsResult != null) {
      final sentimentScore = newsResult.overallSentimentScore; // -100到100
      if (direction == 'long') {
        newsScore = 50 + sentimentScore * 0.5; // 利好加分
      } else {
        newsScore = 50 - sentimentScore * 0.5; // 利空加分（做空）
      }
      newsScore = newsScore.clamp(0.0, 100.0);
    }

    // 风控评分（基于盈亏比）
    double riskRewardScore = 0;
    if (riskRewardRatio >= 5) riskRewardScore = 100;
    else if (riskRewardRatio >= 4) riskRewardScore = 90;
    else if (riskRewardRatio >= 3) riskRewardScore = 75;
    else if (riskRewardRatio >= 2) riskRewardScore = 60;
    else if (riskRewardRatio >= 1.5) riskRewardScore = 40;
    else riskRewardScore = 20;

    // 加权综合评分
    final totalScore = (
      technicalScore * 0.25 + // 技术面25%
      orderFlowScore * 0.25 + // 订单流25%
      newsScore * 0.15 + // 消息面15%
      multiTimeframeScore * 0.20 + // 多周期20%
      riskRewardScore * 0.15 // 风控15%
    ).clamp(0.0, 100.0);

    // 质量评级
    SignalQuality quality;
    if (totalScore >= 90 && technicalScore >= 85 && orderFlowScore >= 85 && multiTimeframeScore >= 80) {
      quality = SignalQuality.sss;
    } else if (totalScore >= 80 && technicalScore >= 75 && orderFlowScore >= 75) {
      quality = SignalQuality.ss;
    } else if (totalScore >= 70) {
      quality = SignalQuality.s;
    } else if (totalScore >= 55) {
      quality = SignalQuality.a;
    } else {
      quality = SignalQuality.b;
    }

    // 优势和劣势
    final strongPoints = <String>[];
    final weakPoints = <String>[];

    if (technicalScore >= 80) strongPoints.add('技术面强确认');
    else if (technicalScore < 60) weakPoints.add('技术面确认不足');

    if (orderFlowScore >= 80) strongPoints.add('订单流强确认');
    else if (orderFlowScore < 60) weakPoints.add('订单流确认不足');

    if (newsScore >= 70) strongPoints.add('消息面配合');
    else if (newsScore < 40) weakPoints.add('消息面不利');

    if (multiTimeframeScore >= 80) strongPoints.add('多周期共振');
    else if (multiTimeframeScore < 60) weakPoints.add('多周期共振不足');

    if (riskRewardScore >= 80) strongPoints.add('盈亏比优秀(≥4:1)');
    else if (riskRewardScore < 60) weakPoints.add('盈亏比一般');

    // 操作建议
    String recommendation;
    switch (quality) {
      case SignalQuality.sss:
        recommendation = 'SSS级顶级信号，可重仓执行，严格止损';
        break;
      case SignalQuality.ss:
        recommendation = 'SS级优质信号，可正常仓位执行';
        break;
      case SignalQuality.s:
        recommendation = 'S级良好信号，可轻仓执行';
        break;
      case SignalQuality.a:
        recommendation = 'A级一般信号，谨慎操作，小仓位试单';
        break;
      case SignalQuality.b:
        recommendation = 'B级谨慎信号，建议观望，等待更好机会';
        break;
    }

    return SignalQualityResult(
      quality: quality,
      totalScore: totalScore,
      technicalScore: technicalScore,
      orderFlowScore: orderFlowScore,
      newsScore: newsScore,
      multiTimeframeScore: multiTimeframeScore,
      riskRewardScore: riskRewardScore,
      recommendation: recommendation,
      strongPoints: strongPoints,
      weakPoints: weakPoints,
    );
  }
}
