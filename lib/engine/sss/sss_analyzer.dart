import '../models/market_data.dart';

/// SSS级推单区综合分析模块
/// 整合：技术面 + 消息面 + 宏观面 + 情绪面 + 资金面
/// 输出：信号质量综合评分（0-100），只输出>=80分的高置信度信号
class SSSAnalyzer {
  /// 技术面评分（0-100）
  static double calculateTechnicalScore({
    required bool structurePass,
    required bool liquiditySweepPass,
    required bool orderFlowPass,
    required bool patternPass,
    required double riskReward,
    required int confirmationCount,
    required int requiredConfirmations,
    required double mtfResonance,
  }) {
    double score = 0;
    // 结构分析（20分）
    score += structurePass ? 20 : 0;
    // 流动性清扫（15分）
    score += liquiditySweepPass ? 15 : 0;
    // 订单流（20分）
    score += orderFlowPass ? 20 : 0;
    // K线形态（15分）
    score += patternPass ? 15 : 0;
    // 盈亏比（15分）
    if (riskReward >= 5) score += 15;
    else if (riskReward >= 4) score += 12;
    else if (riskReward >= 3) score += 8;
    else if (riskReward >= 2) score += 4;
    // 确认次数（10分）
    final confirmRatio = confirmationCount / requiredConfirmations;
    score += (confirmRatio * 10).clamp(0, 10);
    // 多周期共振（5分加分项）
    if (mtfResonance >= 4) score += 5;
    else if (mtfResonance >= 3) score += 3;
    else if (mtfResonance >= 2) score += 1;

    return score.clamp(0, 100);
  }

  /// 消息面评分（0-100）
  static double calculateNewsScore({
    required List<NewsItem> news,
    required String direction, // 'long' or 'short'
  }) {
    if (news.isEmpty) return 50; // 无消息时中性

    double bullishScore = 0;
    double bearishScore = 0;
    int importantCount = 0;

    for (final item in news) {
      final impact = item.impact; // 1-5，5影响最大
      final sentiment = item.sentiment; // -1到1，1看涨，-1看跌
      if (sentiment > 0) {
        bullishScore += sentiment * impact * 10;
      } else if (sentiment < 0) {
        bearishScore += sentiment.abs() * impact * 10;
      }
      if (impact >= 4) importantCount++;
    }

    final totalScore = bullishScore + bearishScore;
    if (totalScore == 0) return 50;

    // 重大事件加分/减分
    double adjustment = 0;
    if (importantCount > 0) {
      adjustment = importantCount * 5;
    }

    if (direction == 'long') {
      final score = (bullishScore / totalScore * 100) + adjustment;
      return score.clamp(0, 100);
    } else {
      final score = (bearishScore / totalScore * 100) + adjustment;
      return score.clamp(0, 100);
    }
  }

  /// 宏观面评分（0-100）
  static double calculateMacroScore({
    required double sp500Change, // 标普500涨跌幅%
    required double dxyChange, // 美元指数涨跌幅%
    required double treasuryYield, // 美债收益率
    required double goldChange, // 黄金涨跌幅%
    required String direction,
  }) {
    double score = 50; // 中性

    // 美股联动（加密货币与美股正相关）
    if (direction == 'long') {
      score += sp500Change * 5; // 美股涨利好加密
    } else {
      score -= sp500Change * 5;
    }

    // 美元指数（美元强利空加密）
    if (direction == 'long') {
      score -= dxyChange * 8;
    } else {
      score += dxyChange * 8;
    }

    // 美债收益率（收益率高利空风险资产）
    if (treasuryYield > 4.5) {
      if (direction == 'long') score -= 10;
      else score += 10;
    } else if (treasuryYield < 3.5) {
      if (direction == 'long') score += 10;
      else score -= 10;
    }

    // 黄金（避险资产，黄金涨说明风险情绪低）
    if (goldChange > 1) {
      if (direction == 'long') score -= 5;
      else score += 5;
    }

    return score.clamp(0, 100);
  }

  /// 情绪面评分（0-100）
  static double calculateSentimentScore({
    required double fearGreedIndex, // 0-100，0极度恐惧，100极度贪婪
    required double longShortRatio, // 多空比
    required double leverageRatio, // 杠杆率
    required String direction,
  }) {
    double score = 50;

    // 贪婪恐惧指数（逆向指标：恐惧时买，贪婪时卖）
    if (direction == 'long') {
      if (fearGreedIndex < 25) score += 20; // 极度恐惧，抄底机会
      else if (fearGreedIndex < 40) score += 10;
      else if (fearGreedIndex > 75) score -= 15; // 极度贪婪，见顶风险
      else if (fearGreedIndex > 60) score -= 5;
    } else {
      if (fearGreedIndex > 75) score += 20; // 极度贪婪，做空机会
      else if (fearGreedIndex > 60) score += 10;
      else if (fearGreedIndex < 25) score -= 15;
      else if (fearGreedIndex < 40) score -= 5;
    }

    // 多空比（逆向指标：多头过多时做空）
    if (direction == 'long') {
      if (longShortRatio > 2) score -= 10; // 多头过多
      else if (longShortRatio < 0.8) score += 10; // 空头过多，反向做多
    } else {
      if (longShortRatio > 2) score += 10;
      else if (longShortRatio < 0.8) score -= 10;
    }

    // 杠杆率（高杠杆=高风险）
    if (leverageRatio > 2) {
      if (direction == 'long') score -= 5;
      else score += 5;
    }

    return score.clamp(0, 100);
  }

  /// 资金面评分（0-100）
  static double calculateCapitalScore({
    required double exchangeFlow, // 交易所资金净流入（正=流入）
    required double whaleAccumulation, // 巨鲸增持（正=增持）
    required double stablecoinMarketCapChange, // 稳定币市值变化
    required double openInterestChange, // 持仓量变化
    required String direction,
  }) {
    double score = 50;

    // 交易所资金流（流入=抛压增加，流出=抛压减少）
    if (direction == 'long') {
      if (exchangeFlow < -100) score += 15; // 大额流出，抛压减少
      else if (exchangeFlow < 0) score += 5;
      else if (exchangeFlow > 100) score -= 10; // 大额流入，抛压增加
    } else {
      if (exchangeFlow > 100) score += 10;
      else if (exchangeFlow > 0) score += 5;
      else if (exchangeFlow < -100) score -= 15;
    }

    // 巨鲸增持（增持=看涨）
    if (direction == 'long') {
      score += whaleAccumulation * 10;
    } else {
      score -= whaleAccumulation * 10;
    }

    // 稳定币市值（增加=购买力增加，看涨）
    if (direction == 'long') {
      score += stablecoinMarketCapChange * 5;
    } else {
      score -= stablecoinMarketCapChange * 5;
    }

    // 持仓量变化（增加=行情可能延续）
    if (openInterestChange > 5) {
      if (direction == 'long') score += 5;
      else score += 5; // 持仓增加对多空都可能有利
    }

    return score.clamp(0, 100);
  }

  /// SSS级综合评分（0-100）
  /// 权重：技术面40% + 消息面20% + 宏观面15% + 情绪面15% + 资金面10%
  static SSSResult calculateSSSScore({
    required double technicalScore,
    required double newsScore,
    required double macroScore,
    required double sentimentScore,
    required double capitalScore,
  }) {
    final totalScore = technicalScore * 0.40 +
        newsScore * 0.20 +
        macroScore * 0.15 +
        sentimentScore * 0.15 +
        capitalScore * 0.10;

    String grade;
    String recommendation;
    if (totalScore >= 90) {
      grade = 'SSS+';
      recommendation = '极高置信度，强烈推荐';
    } else if (totalScore >= 85) {
      grade = 'SSS';
      recommendation = '超高置信度，推荐执行';
    } else if (totalScore >= 80) {
      grade = 'SS+';
      recommendation = '高置信度，可以执行';
    } else if (totalScore >= 75) {
      grade = 'SS';
      recommendation = '较高置信度，谨慎执行';
    } else if (totalScore >= 70) {
      grade = 'S+';
      recommendation = '一般置信度，观望为主';
    } else if (totalScore >= 60) {
      grade = 'S';
      recommendation = '低置信度，不建议执行';
    } else {
      grade = 'A';
      recommendation = '信号质量不足，禁止执行';
    }

    return SSSResult(
      totalScore: totalScore,
      grade: grade,
      recommendation: recommendation,
      technicalScore: technicalScore,
      newsScore: newsScore,
      macroScore: macroScore,
      sentimentScore: sentimentScore,
      capitalScore: capitalScore,
      isHighConfidence: totalScore >= 80,
    );
  }
}

/// SSS级分析结果
class SSSResult {
  final double totalScore;
  final String grade;
  final String recommendation;
  final double technicalScore;
  final double newsScore;
  final double macroScore;
  final double sentimentScore;
  final double capitalScore;
  final bool isHighConfidence;

  const SSSResult({
    required this.totalScore,
    required this.grade,
    required this.recommendation,
    required this.technicalScore,
    required this.newsScore,
    required this.macroScore,
    required this.sentimentScore,
    required this.capitalScore,
    required this.isHighConfidence,
  });
}

/// 新闻条目
class NewsItem {
  final String title;
  final String source;
  final DateTime publishedAt;
  final double impact; // 1-5，5影响最大
  final double sentiment; // -1到1，1看涨，-1看跌
  final String url;

  const NewsItem({
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.impact,
    required this.sentiment,
    required this.url,
  });
}
