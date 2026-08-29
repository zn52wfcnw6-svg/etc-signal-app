import '../models/market_data.dart';
import '../data/apis/exchange_api.dart';
import 'advanced_features.dart';

/// ============================================================
/// 多维度信号决策引擎
/// 整合5大维度所有数据，让每个数据都真正为推单区服务
/// ============================================================

/// 维度类型
enum DimensionType {
  technical, // 技术面
  orderFlow, // 订单流
  sentiment, // 情绪面
  macro, // 宏观面
  capital, // 资金面
}

/// 维度分析结果
class DimensionResult {
  final DimensionType type;
  final String name;
  final double score; // 0-100分
  final String bias; // 'long' / 'short' / 'neutral'
  final bool filterPassed; // 是否通过过滤（极端情况不通过）
  final double weight; // 权重（对最终信号的影响）
  final String description; // 描述
  final Map<String, dynamic> details; // 详细数据

  DimensionResult({
    required this.type,
    required this.name,
    required this.score,
    required this.bias,
    required this.filterPassed,
    required this.weight,
    required this.description,
    this.details = const {},
  });

  double get contribution => score * weight / 100; // 贡献度
}

/// 最终信号决策结果
class SignalDecision {
  final bool hasSignal;
  final String direction; // 'long' / 'short' / 'none'
  final double finalScore; // 0-100最终评分
  final double confidence; // 可信度0-100
  final List<DimensionResult> dimensions; // 各维度结果
  final List<String> failedFilters; // 未通过的过滤条件
  final String recommendation; // 推荐操作
  final double entryLower;
  final double entryUpper;
  final double stopLoss;
  final double tp1;
  final double tp2;

  SignalDecision({
    required this.hasSignal,
    required this.direction,
    required this.finalScore,
    required this.confidence,
    required this.dimensions,
    required this.failedFilters,
    required this.recommendation,
    this.entryLower = 0,
    this.entryUpper = 0,
    this.stopLoss = 0,
    this.tp1 = 0,
    this.tp2 = 0,
  });

  /// 获取各维度贡献度排序
  List<DimensionResult> get sortedByContribution =>
      List.from(dimensions)..sort((a, b) => b.contribution.compareTo(a.contribution));

  /// 获取通过的维度
  List<DimensionResult> get passedDimensions =>
      dimensions.where((d) => d.filterPassed).toList();

  /// 获取未通过的维度
  List<DimensionResult> get failedDimensions =>
      dimensions.where((d) => !d.filterPassed).toList();
}

/// 多维度信号决策引擎
class MultiDimensionSignalEngine {
  /// 综合分析所有维度，给出最终信号决策
  static SignalDecision analyze({
    required List<Kline> klines5m,
    required List<Kline> klines1h,
    required List<Kline> klines4h,
    required double currentPrice,
    required double? support,
    required double? resistance,
    // 订单流数据
    required double cvd,
    required double buyVolume,
    required double sellVolume,
    required List<LiquidationOrder> liquidations,
    required OrderBookDepth? orderBook,
    // 情绪面数据
    required double fearGreedIndex,
    required double longShortRatio,
    required List<dynamic> news,
    // 宏观面数据
    required double sp500Change,
    required double goldChange,
    required double dxyChange,
    required double treasuryYield,
    // 资金面数据
    required double fundingRate,
    required double openInterest,
    required double openInterestChange,
    required double stablecoinMarketCapChange,
  }) {
    final dimensions = <DimensionResult>[];

    // ============================================================
    // 维度1：技术面分析（权重30%）
    // ============================================================
    final technical = _analyzeTechnical(
      klines5m: klines5m,
      klines1h: klines1h,
      klines4h: klines4h,
      currentPrice: currentPrice,
      support: support,
      resistance: resistance,
    );
    dimensions.add(technical);

    // ============================================================
    // 维度2：订单流分析（权重25%）
    // ============================================================
    final orderFlow = _analyzeOrderFlow(
      cvd: cvd,
      buyVolume: buyVolume,
      sellVolume: sellVolume,
      liquidations: liquidations,
      orderBook: orderBook,
      currentPrice: currentPrice,
    );
    dimensions.add(orderFlow);

    // ============================================================
    // 维度3：情绪面分析（权重15%）
    // ============================================================
    final sentiment = _analyzeSentiment(
      fearGreedIndex: fearGreedIndex,
      longShortRatio: longShortRatio,
      news: news,
    );
    dimensions.add(sentiment);

    // ============================================================
    // 维度4：宏观面分析（权重15%）
    // ============================================================
    final macro = _analyzeMacro(
      sp500Change: sp500Change,
      goldChange: goldChange,
      dxyChange: dxyChange,
      treasuryYield: treasuryYield,
    );
    dimensions.add(macro);

    // ============================================================
    // 维度5：资金面分析（权重15%）
    // ============================================================
    final capital = _analyzeCapital(
      fundingRate: fundingRate,
      openInterest: openInterest,
      openInterestChange: openInterestChange,
      stablecoinMarketCapChange: stablecoinMarketCapChange,
    );
    dimensions.add(capital);

    // ============================================================
    // 综合决策
    // ============================================================
    return _makeDecision(
      dimensions: dimensions,
      currentPrice: currentPrice,
      support: support,
      resistance: resistance,
    );
  }

  /// ============================================================
  /// 维度1：技术面分析
  /// ============================================================
  static DimensionResult _analyzeTechnical({
    required List<Kline> klines5m,
    required List<Kline> klines1h,
    required List<Kline> klines4h,
    required double currentPrice,
    required double? support,
    required double? resistance,
  }) {
    double score = 50;
    String bias = 'neutral';
    bool filterPassed = true;
    final details = <String, dynamic>{};

    // 1. RSI分析
    if (klines5m.length >= 20) {
      final rsi = _calculateRSI(klines5m, 14);
      details['rsi'] = rsi;
      if (rsi < 30) {
        score += 15;
        bias = 'long';
      } else if (rsi > 70) {
        score -= 15;
        bias = 'short';
      }
    }

    // 2. 支撑压力位分析
    if (support != null && resistance != null) {
      final distanceToSupport = (currentPrice - support).abs() / currentPrice * 100;
      final distanceToResistance = (resistance - currentPrice).abs() / currentPrice * 100;
      details['distanceToSupport'] = distanceToSupport;
      details['distanceToResistance'] = distanceToResistance;

      if (distanceToSupport < 0.5) {
        score += 20;
        bias = 'long';
      } else if (distanceToResistance < 0.5) {
        score -= 20;
        bias = 'short';
      }
    }

    // 3. 多周期趋势分析
    if (klines1h.length >= 20 && klines4h.length >= 20) {
      final trend1h = _getTrend(klines1h);
      final trend4h = _getTrend(klines4h);
      details['trend1h'] = trend1h;
      details['trend4h'] = trend4h;

      if (trend1h == 'up' && trend4h == 'up') {
        score += 10;
        if (bias == 'neutral') bias = 'long';
      } else if (trend1h == 'down' && trend4h == 'down') {
        score -= 10;
        if (bias == 'neutral') bias = 'short';
      }
    }

    // 4. 过滤条件：极端行情过滤
    if (klines5m.length >= 10) {
      final volatility = _calculateVolatility(klines5m);
      details['volatility'] = volatility;
      if (volatility > 5) {
        filterPassed = false; // 极端波动，过滤信号
      }
    }

    score = score.clamp(0, 100).toDouble();

    return DimensionResult(
      type: DimensionType.technical,
      name: '技术面',
      score: score,
      bias: bias,
      filterPassed: filterPassed,
      weight: 0.30,
      description: 'RSI/支撑压力/多周期趋势/波动率',
      details: details,
    );
  }

  /// ============================================================
  /// 维度2：订单流分析
  /// ============================================================
  static DimensionResult _analyzeOrderFlow({
    required double cvd,
    required double buyVolume,
    required double sellVolume,
    required List<LiquidationOrder> liquidations,
    required OrderBookDepth? orderBook,
    required double currentPrice,
  }) {
    double score = 50;
    String bias = 'neutral';
    bool filterPassed = true;
    final details = <String, dynamic>{};

    // 1. CVD分析
    details['cvd'] = cvd;
    if (cvd > 0) {
      score += 10;
      bias = 'long';
    } else if (cvd < 0) {
      score -= 10;
      bias = 'short';
    }

    // 2. 买卖量分析
    final totalVolume = buyVolume + sellVolume;
    if (totalVolume > 0) {
      final buyRatio = buyVolume / totalVolume;
      details['buyRatio'] = buyRatio;
      if (buyRatio > 0.6) {
        score += 10;
        if (bias == 'neutral') bias = 'long';
      } else if (buyRatio < 0.4) {
        score -= 10;
        if (bias == 'neutral') bias = 'short';
      }
    }

    // 3. 清算数据分析（真实数据）
    if (liquidations.isNotEmpty) {
      final recentLiquidations = liquidations.where((l) {
        final timeDiff = DateTime.now().millisecondsSinceEpoch - (l.time ?? 0);
        return timeDiff < 3600000; // 1小时内
      }).toList();

      final longLiquidations = recentLiquidations.where((l) => l.side == 'sell').fold(0.0, (sum, l) => sum + (l.price ?? 0) * (l.quantity ?? 0));
      final shortLiquidations = recentLiquidations.where((l) => l.side == 'buy').fold(0.0, (sum, l) => sum + (l.price ?? 0) * (l.quantity ?? 0));

      details['longLiquidations'] = longLiquidations;
      details['shortLiquidations'] = shortLiquidations;

      // 多头清算多 → 可能见底（反向指标）
      if (longLiquidations > shortLiquidations * 2) {
        score += 15;
        bias = 'long';
      }
      // 空头清算多 → 可能见顶（反向指标）
      else if (shortLiquidations > longLiquidations * 2) {
        score -= 15;
        bias = 'short';
      }

      // 过滤条件：极端清算（1小时内清算超过1000万美元）
      final totalLiquidation = longLiquidations + shortLiquidations;
      if (totalLiquidation > 10000000) {
        filterPassed = false; // 极端清算，市场不稳定，过滤信号
      }
    }

    // 4. 订单簿深度分析（真实数据）
    if (orderBook != null && orderBook.bids.isNotEmpty && orderBook.asks.isNotEmpty) {
      final bidAskRatio = orderBook.bidAskRatio;
      details['bidAskRatio'] = bidAskRatio;
      details['bestBid'] = orderBook.bestBid;
      details['bestAsk'] = orderBook.bestAsk;
      details['spread'] = orderBook.spread;

      if (bidAskRatio > 1.5) {
        score += 10;
        if (bias == 'neutral') bias = 'long';
      } else if (bidAskRatio < 0.67) {
        score -= 10;
        if (bias == 'neutral') bias = 'short';
      }

      // 过滤条件：价差过大（流动性不足）
      if (orderBook.spread > currentPrice * 0.001) {
        filterPassed = false; // 流动性不足，过滤信号
      }
    }

    score = score.clamp(0, 100).toDouble();

    return DimensionResult(
      type: DimensionType.orderFlow,
      name: '订单流',
      score: score,
      bias: bias,
      filterPassed: filterPassed,
      weight: 0.25,
      description: 'CVD/买卖量/清算/订单簿深度',
      details: details,
    );
  }

  /// ============================================================
  /// 维度3：情绪面分析
  /// ============================================================
  static DimensionResult _analyzeSentiment({
    required double fearGreedIndex,
    required double longShortRatio,
    required List<dynamic> news,
  }) {
    double score = 50;
    String bias = 'neutral';
    bool filterPassed = true;
    final details = <String, dynamic>{};

    // 1. 贪婪恐惧指数（反向指标）
    details['fearGreedIndex'] = fearGreedIndex;
    if (fearGreedIndex < 25) {
      score += 20; // 极度恐惧，可能见底
      bias = 'long';
    } else if (fearGreedIndex > 75) {
      score -= 20; // 极度贪婪，可能见顶
      bias = 'short';
    } else if (fearGreedIndex < 40) {
      score += 10;
      bias = 'long';
    } else if (fearGreedIndex > 60) {
      score -= 10;
      bias = 'short';
    }

    // 2. 多空比（反向指标）
    details['longShortRatio'] = longShortRatio;
    if (longShortRatio > 2.0) {
      score -= 15; // 多头过于拥挤，可能回调
      if (bias == 'neutral') bias = 'short';
    } else if (longShortRatio < 0.5) {
      score += 15; // 空头过于拥挤，可能反弹
      if (bias == 'neutral') bias = 'long';
    }

    // 3. NLP新闻情绪分析（真实数据）
    if (news.isNotEmpty) {
      final newsSentiment = AdvancedSentimentAnalyzer.analyzeBatch(news);
      details['newsSentiment'] = newsSentiment;

      if (newsSentiment > 65) {
        score += 10;
        if (bias == 'neutral') bias = 'long';
      } else if (newsSentiment < 35) {
        score -= 10;
        if (bias == 'neutral') bias = 'short';
      }

      // 过滤条件：极端新闻情绪（黑天鹅事件）
      if (newsSentiment < 15 || newsSentiment > 90) {
        filterPassed = false; // 极端情绪，市场不稳定，过滤信号
      }
    }

    score = score.clamp(0, 100).toDouble();

    return DimensionResult(
      type: DimensionType.sentiment,
      name: '情绪面',
      score: score,
      bias: bias,
      filterPassed: filterPassed,
      weight: 0.15,
      description: '贪婪恐惧/多空比/NLP新闻情绪',
      details: details,
    );
  }

  /// ============================================================
  /// 维度4：宏观面分析
  /// ============================================================
  static DimensionResult _analyzeMacro({
    required double sp500Change,
    required double goldChange,
    required double dxyChange,
    required double treasuryYield,
  }) {
    double score = 50;
    String bias = 'neutral';
    bool filterPassed = true;
    final details = <String, dynamic>{};

    // 1. 标普500（风险偏好指标）
    details['sp500Change'] = sp500Change;
    if (sp500Change > 1) {
      score += 10; // 股市上涨，风险偏好高，利好加密货币
      bias = 'long';
    } else if (sp500Change < -1) {
      score -= 10; // 股市下跌，风险规避，利空加密货币
      bias = 'short';
    }

    // 2. 黄金（避险指标）
    details['goldChange'] = goldChange;
    if (goldChange > 0.5) {
      score -= 5; // 黄金上涨，避险情绪，利空风险资产
    } else if (goldChange < -0.5) {
      score += 5; // 黄金下跌，风险偏好，利好风险资产
    }

    // 3. 美元指数
    details['dxyChange'] = dxyChange;
    if (dxyChange > 0.5) {
      score -= 10; // 美元上涨，利空加密货币
      if (bias == 'neutral') bias = 'short';
    } else if (dxyChange < -0.5) {
      score += 10; // 美元下跌，利好加密货币
      if (bias == 'neutral') bias = 'long';
    }

    // 4. 美债收益率
    details['treasuryYield'] = treasuryYield;
    if (treasuryYield > 4.5) {
      score -= 10; // 高利率，利空风险资产
    } else if (treasuryYield < 3.5) {
      score += 10; // 低利率，利好风险资产
    }

    // 过滤条件：宏观极端波动
    if (sp500Change.abs() > 3 || dxyChange.abs() > 2) {
      filterPassed = false; // 宏观极端波动，过滤信号
    }

    score = score.clamp(0, 100).toDouble();

    return DimensionResult(
      type: DimensionType.macro,
      name: '宏观面',
      score: score,
      bias: bias,
      filterPassed: filterPassed,
      weight: 0.15,
      description: '标普500/黄金/美元指数/美债收益率',
      details: details,
    );
  }

  /// ============================================================
  /// 维度5：资金面分析
  /// ============================================================
  static DimensionResult _analyzeCapital({
    required double fundingRate,
    required double openInterest,
    required double openInterestChange,
    required double stablecoinMarketCapChange,
  }) {
    double score = 50;
    String bias = 'neutral';
    bool filterPassed = true;
    final details = <String, dynamic>{};

    // 1. 资金费率（反向指标）
    details['fundingRate'] = fundingRate;
    if (fundingRate > 0.001) {
      score -= 10; // 多头付费，多头拥挤，可能回调
      bias = 'short';
    } else if (fundingRate < -0.001) {
      score += 10; // 空头付费，空头拥挤，可能反弹
      bias = 'long';
    } else if (fundingRate > 0.0005) {
      score -= 5;
    } else if (fundingRate < -0.0005) {
      score += 5;
    }

    // 2. 持仓量变化
    details['openInterestChange'] = openInterestChange;
    if (openInterestChange > 5) {
      score += 10; // 持仓量增加，新资金入场，趋势可能延续
      if (bias == 'neutral') bias = 'long';
    } else if (openInterestChange < -5) {
      score -= 10; // 持仓量减少，资金离场，趋势可能反转
      if (bias == 'neutral') bias = 'short';
    }

    // 3. 稳定币市值变化（资金流入指标）
    details['stablecoinMarketCapChange'] = stablecoinMarketCapChange;
    if (stablecoinMarketCapChange > 2) {
      score += 10; // 稳定币市值增加，新资金流入，利好
      if (bias == 'neutral') bias = 'long';
    } else if (stablecoinMarketCapChange < -2) {
      score -= 10; // 稳定币市值减少，资金流出，利空
      if (bias == 'neutral') bias = 'short';
    }

    // 过滤条件：资金费率极端
    if (fundingRate.abs() > 0.005) {
      filterPassed = false; // 资金费率极端，市场不稳定，过滤信号
    }

    score = score.clamp(0, 100).toDouble();

    return DimensionResult(
      type: DimensionType.capital,
      name: '资金面',
      score: score,
      bias: bias,
      filterPassed: filterPassed,
      weight: 0.15,
      description: '资金费率/持仓量/稳定币市值',
      details: details,
    );
  }

  /// ============================================================
  /// 综合决策
  /// ============================================================
  static SignalDecision _makeDecision({
    required List<DimensionResult> dimensions,
    required double currentPrice,
    required double? support,
    required double? resistance,
  }) {
    // 1. 检查过滤条件
    final failedFilters = <String>[];
    for (final dim in dimensions) {
      if (!dim.filterPassed) {
        failedFilters.add('${dim.name}:极端行情过滤');
      }
    }

    // 2. 计算最终评分（加权平均）
    double totalWeight = 0;
    double weightedScore = 0;
    for (final dim in dimensions) {
      totalWeight += dim.weight;
      weightedScore += dim.score * dim.weight;
    }
    final finalScore = totalWeight > 0 ? weightedScore / totalWeight : 50.0;

    // 3. 判断方向（多数维度一致）
    int longCount = 0;
    int shortCount = 0;
    for (final dim in dimensions) {
      if (dim.bias == 'long') longCount++;
      else if (dim.bias == 'short') shortCount++;
    }

    String direction = 'none';
    if (longCount >= 3 && longCount > shortCount) direction = 'long';
    else if (shortCount >= 3 && shortCount > longCount) direction = 'short';

    // 4. 计算可信度（维度一致性+评分）
    final consistency = (longCount > shortCount ? longCount : shortCount).toDouble() / dimensions.length;
    final confidence = (finalScore * 0.6 + consistency * 100 * 0.4).clamp(0.0, 100.0).toDouble();

    // 5. 判断是否有信号（评分≥70，方向明确，所有过滤通过）
    final hasSignal = finalScore >= 70 &&
        direction != 'none' &&
        failedFilters.isEmpty &&
        confidence >= 60;

    // 6. 计算点位
    double entryLower = 0, entryUpper = 0, stopLoss = 0, tp1 = 0, tp2 = 0;
    if (hasSignal && direction == 'long' && support != null) {
      entryLower = support * 0.998;
      entryUpper = support * 1.002;
      stopLoss = support * 0.98;
      tp1 = entryUpper + (entryUpper - stopLoss) * 2;
      tp2 = resistance != null ? resistance : entryUpper + (entryUpper - stopLoss) * 4;
    } else if (hasSignal && direction == 'short' && resistance != null) {
      entryLower = resistance * 0.998;
      entryUpper = resistance * 1.002;
      stopLoss = resistance * 1.02;
      tp1 = entryLower - (stopLoss - entryLower) * 2;
      tp2 = support != null ? support : entryLower - (stopLoss - entryLower) * 4;
    }

    // 7. 推荐操作
    String recommendation;
    if (hasSignal) {
      recommendation = direction == 'long'
          ? '建议做多，分批建仓40%/30%/30%，严格止损'
          : '建议做空，分批建仓40%/30%/30%，严格止损';
    } else if (failedFilters.isNotEmpty) {
      recommendation = '极端行情，建议观望，等待市场稳定';
    } else if (finalScore >= 60) {
      recommendation = '接近信号阈值，密切关注，等待确认';
    } else {
      recommendation = '无明确信号，建议观望等待';
    }

    return SignalDecision(
      hasSignal: hasSignal,
      direction: direction,
      finalScore: finalScore,
      confidence: confidence,
      dimensions: dimensions,
      failedFilters: failedFilters,
      recommendation: recommendation,
      entryLower: entryLower,
      entryUpper: entryUpper,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
    );
  }

  /// ============================================================
  /// 辅助方法
  /// ============================================================
  static double _calculateRSI(List<Kline> klines, int period) {
    if (klines.length < period + 1) return 50;
    double gains = 0;
    double losses = 0;
    for (int i = 1; i <= period; i++) {
      final change = klines[i].close - klines[i - 1].close;
      if (change > 0) gains += change;
      else losses += change.abs();
    }
    final avgGain = gains / period;
    final avgLoss = losses / period;
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  static String _getTrend(List<Kline> klines) {
    if (klines.length < 20) return 'neutral';
    final sma5 = _calculateSMA(klines, 5);
    final sma20 = _calculateSMA(klines, 20);
    if (sma5 > sma20 * 1.005) return 'up';
    if (sma5 < sma20 * 0.995) return 'down';
    return 'neutral';
  }

  static double _calculateSMA(List<Kline> klines, int period) {
    if (klines.length < period) return 0;
    final recent = klines.sublist(klines.length - period);
    return recent.map((k) => k.close).reduce((a, b) => a + b) / period;
  }

  static double _calculateVolatility(List<Kline> klines) {
    if (klines.length < 10) return 0;
    final recent = klines.sublist(klines.length - 10);
    final returns = <double>[];
    for (int i = 1; i < recent.length; i++) {
      returns.add((recent[i].close - recent[i - 1].close).abs() / recent[i - 1].close * 100);
    }
    return returns.reduce((a, b) => a + b) / returns.length;
  }
}
