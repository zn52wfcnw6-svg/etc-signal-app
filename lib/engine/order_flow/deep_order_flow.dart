import '../../models/market_data.dart';
import '../../data/websocket_manager.dart';

/// 大单分析结果
class LargeOrderAnalysis {
  final int buyLargeOrders;
  final int sellLargeOrders;
  final double buyLargeVolume;
  final double sellLargeVolume;
  final double largeOrderRatio; // 买大单/卖大单
  final bool bullishPressure;
  final bool bearishPressure;
  final String description;

  LargeOrderAnalysis({
    required this.buyLargeOrders,
    required this.sellLargeOrders,
    required this.buyLargeVolume,
    required this.sellLargeVolume,
    required this.largeOrderRatio,
    required this.bullishPressure,
    required this.bearishPressure,
    required this.description,
  });
}

/// 成交密度分析
class VolumeDensityAnalysis {
  final double highestDensityPrice; // 成交最密集价位
  final double densityZoneLower;
  final double densityZoneUpper;
  final bool isSupport; // 成交密集区在当前价下方=支撑
  final bool isResistance;
  final String description;

  VolumeDensityAnalysis({
    required this.highestDensityPrice,
    required this.densityZoneLower,
    required this.densityZoneUpper,
    required this.isSupport,
    required this.isResistance,
    required this.description,
  });
}

/// 清算挤压分析（基于波动率和OI模拟）
class LiquidationAnalysis {
  final double estimatedLongLiquidationZone;
  final double estimatedShortLiquidationZone;
  final double longLiquidationPressure; // 0-1
  final double shortLiquidationPressure;
  final bool longSqueezeRisk; // 多头清算挤压风险（价格可能被推高）
  final bool shortSqueezeRisk;
  final String description;

  LiquidationAnalysis({
    required this.estimatedLongLiquidationZone,
    required this.estimatedShortLiquidationZone,
    required this.longLiquidationPressure,
    required this.shortLiquidationPressure,
    required this.longSqueezeRisk,
    required this.shortSqueezeRisk,
    required this.description,
  });
}

/// 盘口失衡分析（基于K线影线和成交模拟）
class OrderBookImbalance {
  final double bidAskRatio; // 买盘/卖盘深度比
  final bool bidHeavy; // 买盘重
  final bool askHeavy; // 卖盘重
  final double imbalanceScore; // 0-1，越高越失衡
  final String description;

  OrderBookImbalance({
    required this.bidAskRatio,
    required this.bidHeavy,
    required this.askHeavy,
    required this.imbalanceScore,
    required this.description,
  });
}

/// 深度订单流综合分析结果
class DeepOrderFlowResult {
  final LargeOrderAnalysis largeOrders;
  final VolumeDensityAnalysis volumeDensity;
  final LiquidationAnalysis liquidation;
  final OrderBookImbalance orderBook;
  final int bullishSignals;
  final int bearishSignals;
  final String summary;
  final bool confirmsLong;
  final bool confirmsShort;

  DeepOrderFlowResult({
    required this.largeOrders,
    required this.volumeDensity,
    required this.liquidation,
    required this.orderBook,
    required this.bullishSignals,
    required this.bearishSignals,
    required this.summary,
    required this.confirmsLong,
    required this.confirmsShort,
  });
}

/// 深度订单流分析器
class DeepOrderFlowAnalyzer {
  /// 综合分析
  static DeepOrderFlowResult analyze(
    List<Kline> klines,
    List<OrderFlowBar> orderFlowBars, {
    double? currentPrice,
    double? openInterest,
  }) {
    final price = currentPrice ?? (klines.isNotEmpty ? klines.last.close : 0);
    final oi = openInterest ?? 0;

    final largeOrders = _analyzeLargeOrders(orderFlowBars);
    final volumeDensity = _analyzeVolumeDensity(klines, price);
    final liquidation = _analyzeLiquidation(klines, price, oi);
    final orderBook = _analyzeOrderBookImbalance(klines, orderFlowBars);

    int bullish = 0;
    int bearish = 0;

    if (largeOrders.bullishPressure) bullish++;
    if (largeOrders.bearishPressure) bearish++;
    if (volumeDensity.isSupport) bullish++;
    if (volumeDensity.isResistance) bearish++;
    if (liquidation.shortSqueezeRisk) bullish++;
    if (liquidation.longSqueezeRisk) bearish++;
    if (orderBook.bidHeavy) bullish++;
    if (orderBook.askHeavy) bearish++;

    final confirmsLong = bullish >= 3;
    final confirmsShort = bearish >= 3;

    String summary;
    if (confirmsLong) {
      summary = '订单流多头确认：$bullish项看多/$bearish项看空';
    } else if (confirmsShort) {
      summary = '订单流空头确认：$bullish项看多/$bearish项看空';
    } else {
      summary = '订单流分歧：$bullish项看多/$bearish项看空，未达确认';
    }

    return DeepOrderFlowResult(
      largeOrders: largeOrders,
      volumeDensity: volumeDensity,
      liquidation: liquidation,
      orderBook: orderBook,
      bullishSignals: bullish,
      bearishSignals: bearish,
      summary: summary,
      confirmsLong: confirmsLong,
      confirmsShort: confirmsShort,
    );
  }

  /// 大单追踪分析
  /// 用K线数据模拟订单流bar
  static LargeOrderAnalysis _analyzeLargeOrders(List<OrderFlowBar> bars) {
    if (bars.isEmpty) {
      return LargeOrderAnalysis(
        buyLargeOrders: 0, sellLargeOrders: 0,
        buyLargeVolume: 0, sellLargeVolume: 0,
        largeOrderRatio: 1, bullishPressure: false, bearishPressure: false,
        description: '无订单流数据',
      );
    }

    // 计算平均成交量作为大单阈值
    final avgVolume = bars.map((b) => b.buyVolume + b.sellVolume).reduce((a, b) => a + b) / bars.length;
    final largeThreshold = avgVolume * 3; // 3倍平均为大单

    int buyLarge = 0;
    int sellLarge = 0;
    double buyVol = 0;
    double sellVol = 0;

    for (final bar in bars) {
      final barVolume = bar.buyVolume + bar.sellVolume;
      if (barVolume >= largeThreshold) {
        if (bar.delta > 0) {
          buyLarge++;
          buyVol += barVolume;
        } else if (bar.delta < 0) {
          sellLarge++;
          sellVol += barVolume;
        }
      }
    }

    final ratio = sellLarge > 0 ? buyLarge / sellLarge : (buyLarge > 0 ? 99.0 : 1.0);
    final bullish = ratio > 1.5 && buyLarge >= 2;
    final bearish = ratio < 0.67 && sellLarge >= 2;

    return LargeOrderAnalysis(
      buyLargeOrders: buyLarge,
      sellLargeOrders: sellLarge,
      buyLargeVolume: buyVol,
      sellLargeVolume: sellVol,
      largeOrderRatio: ratio,
      bullishPressure: bullish,
      bearishPressure: bearish,
      description: bullish ? '大单持续买入，多头主动' : (bearish ? '大单持续卖出，空头主动' : '大单多空均衡'),
    );
  }

  /// 成交密度分析（VPVR）
  static VolumeDensityAnalysis _analyzeVolumeDensity(List<Kline> klines, double currentPrice) {
    if (klines.length < 30) {
      return VolumeDensityAnalysis(
        highestDensityPrice: currentPrice,
        densityZoneLower: currentPrice * 0.99,
        densityZoneUpper: currentPrice * 1.01,
        isSupport: false, isResistance: false,
        description: '数据不足',
      );
    }

    // 价格分箱统计成交量
    final high = klines.map((k) => k.high).reduce((a, b) => a > b ? a : b);
    final low = klines.map((k) => k.low).reduce((a, b) => a < b ? a : b);
    final binCount = 50;
    final binSize = (high - low) / binCount;
    final volumes = List<double>.filled(binCount, 0);

    for (final k in klines) {
      final midBin = ((k.close - low) / binSize).floor().clamp(0, binCount - 1).toInt();
      volumes[midBin] += k.volume;
    }

    // 找成交最密集的bin
    int maxBin = 0;
    double maxVol = 0;
    for (int i = 0; i < binCount; i++) {
      if (volumes[i] > maxVol) {
        maxVol = volumes[i];
        maxBin = i;
      }
    }

    final densityPrice = low + (maxBin + 0.5) * binSize;
    final zoneLower = densityPrice - binSize * 2;
    final zoneUpper = densityPrice + binSize * 2;
    final isSupport = densityPrice < currentPrice;
    final isResistance = densityPrice > currentPrice;

    return VolumeDensityAnalysis(
      highestDensityPrice: densityPrice,
      densityZoneLower: zoneLower,
      densityZoneUpper: zoneUpper,
      isSupport: isSupport,
      isResistance: isResistance,
      description: '成交密集区 \$${densityPrice.toStringAsFixed(2)}，${isSupport ? "构成支撑" : "构成压力"}',
    );
  }

  /// 清算挤压分析
  static LiquidationAnalysis _analyzeLiquidation(List<Kline> klines, double currentPrice, double oi) {
    if (klines.length < 20) {
      return LiquidationAnalysis(
        estimatedLongLiquidationZone: currentPrice * 0.95,
        estimatedShortLiquidationZone: currentPrice * 1.05,
        longLiquidationPressure: 0.5, shortLiquidationPressure: 0.5,
        longSqueezeRisk: false, shortSqueezeRisk: false,
        description: '数据不足',
      );
    }

    // 基于ATR估算清算区（高杠杆仓位通常在1-3%波动被清算）
    final atr = _calcATR(klines, 14);
    final atrPct = atr / currentPrice;

    // 多头清算区：当前价下方1.5-3倍ATR
    final longLiqZone = currentPrice * (1 - atrPct * 2);
    // 空头清算区：当前价上方1.5-3倍ATR
    final shortLiqZone = currentPrice * (1 + atrPct * 2);

    // 基于近期K线方向判断挤压风险
    final recentCloses = klines.sublist(klines.length - 5).map((k) => k.close).toList();
    final isRising = recentCloses.last > recentCloses.first;
    final isFalling = recentCloses.last < recentCloses.first;

    // 上升中+OI高=空头挤压风险（价格可能继续涨爆空头）
    final shortSqueeze = isRising && oi > 0 && atrPct > 0.008;
    // 下降中+OI高=多头清算挤压风险（价格可能继续跌爆多头）
    final longSqueeze = isFalling && oi > 0 && atrPct > 0.008;

    final longPressure = isFalling ? 0.7 : 0.3;
    final shortPressure = isRising ? 0.7 : 0.3;

    return LiquidationAnalysis(
      estimatedLongLiquidationZone: longLiqZone,
      estimatedShortLiquidationZone: shortLiqZone,
      longLiquidationPressure: longPressure,
      shortLiquidationPressure: shortPressure,
      longSqueezeRisk: longSqueeze,
      shortSqueezeRisk: shortSqueeze,
      description: shortSqueeze ? '空头挤压风险，价格可能继续上行' : (longSqueeze ? '多头清算风险，价格可能继续下行' : '无明显挤压风险'),
    );
  }

  /// 盘口失衡分析
  static OrderBookImbalance _analyzeOrderBookImbalance(List<Kline> klines, List<OrderFlowBar> bars) {
    if (bars.isEmpty || klines.length < 10) {
      return OrderBookImbalance(
        bidAskRatio: 1, bidHeavy: false, askHeavy: false,
        imbalanceScore: 0, description: '数据不足',
      );
    }

    // 用Delta和影线模拟盘口失衡
    final recentBars = bars.length > 20 ? bars.sublist(bars.length - 20) : bars;
    final totalDelta = recentBars.map((b) => b.delta).reduce((a, b) => a + b);
    final totalVolume = recentBars.map((b) => b.buyVolume + b.sellVolume).reduce((a, b) => a + b);

    // 影线分析：上影线长=卖盘重，下影线长=买盘重
    final recentKlines = klines.sublist(klines.length - 10);
    double totalUpperWick = 0;
    double totalLowerWick = 0;
    for (final k in recentKlines) {
      final body = (k.close - k.open).abs();
      final upperWick = k.high - (k.close > k.open ? k.close : k.open);
      final lowerWick = (k.close > k.open ? k.open : k.close) - k.low;
      totalUpperWick += upperWick;
      totalLowerWick += lowerWick;
    }

    // 综合：Delta正+下影线长=买盘重
    final deltaRatio = totalVolume > 0 ? totalDelta / totalVolume : 0;
    final wickRatio = totalUpperWick + totalLowerWick > 0
        ? (totalLowerWick - totalUpperWick) / (totalUpperWick + totalLowerWick)
        : 0;

    final combinedScore = (deltaRatio * 0.6 + wickRatio * 0.4);
    final bidAskRatio = 1 + combinedScore;
    final bidHeavy = combinedScore > 0.15;
    final askHeavy = combinedScore < -0.15;
    final imbalanceScore = combinedScore.abs().clamp(0.0, 1.0);

    return OrderBookImbalance(
      bidAskRatio: bidAskRatio,
      bidHeavy: bidHeavy,
      askHeavy: askHeavy,
      imbalanceScore: imbalanceScore,
      description: bidHeavy ? '买盘较重，下方承接强' : (askHeavy ? '卖盘较重，上方抛压大' : '买卖盘均衡'),
    );
  }

  static double _calcATR(List<Kline> klines, int period) {
    if (klines.length < period + 1) return 0;
    double sum = 0;
    for (int i = klines.length - period; i < klines.length; i++) {
      final tr = [
        klines[i].high - klines[i].low,
        (klines[i].high - klines[i - 1].close).abs(),
        (klines[i].low - klines[i - 1].close).abs(),
      ].reduce((a, b) => a > b ? a : b);
      sum += tr;
    }
    return sum / period;
  }
}
