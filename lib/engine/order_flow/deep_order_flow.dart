import '../../models/market_data.dart';
import '../../utils/indicators.dart';

/// 大单方向
enum LargeOrderDirection { buy, sell, neutral }

/// 深度订单流分析结果
class DeepOrderFlowResult {
  final LargeOrderDirection largeOrderBias; // 大单方向
  final int largeBuyCount;
  final int largeSellCount;
  final double largeBuyVolume;
  final double largeSellVolume;
  final double orderBookImbalance; // 盘口失衡 -1到1，正=买盘强
  final double tradeDensity; // 成交密度（当前价附近成交量占比）
  final List<LiquidationZone> liquidationZones; // 清算密集区
  final double cvdSlope; // CVD斜率
  final double deltaRatio; // Delta占比
  final String summary;

  DeepOrderFlowResult({
    required this.largeOrderBias,
    required this.largeBuyCount,
    required this.largeSellCount,
    required this.largeBuyVolume,
    required this.largeSellVolume,
    required this.orderBookImbalance,
    required this.tradeDensity,
    required this.liquidationZones,
    required this.cvdSlope,
    required this.deltaRatio,
    required this.summary,
  });

  bool get isBullish => largeOrderBias == LargeOrderDirection.buy && orderBookImbalance > 0.1;
  bool get isBearish => largeOrderBias == LargeOrderDirection.sell && orderBookImbalance < -0.1;
}

/// 清算密集区
class LiquidationZone {
  final double price;
  final double width; // 区间宽度
  final bool isLongLiquidation; // true=多头清算区(价格下方), false=空头清算区(价格上方)
  final int intensity; // 1-3 强度

  LiquidationZone({
    required this.price,
    required this.width,
    required this.isLongLiquidation,
    required this.intensity,
  });
}

/// 深度订单流分析器
class DeepOrderFlowAnalyzer {
  /// 基于K线和成交数据分析
  static DeepOrderFlowResult analyze(List<Kline> klines, List<Trade> trades) {
    final currentPrice = klines.isNotEmpty ? klines.last.close : 0;

    // 1. 大单追踪
    final largeOrderResult = _analyzeLargeOrders(trades);

    // 2. 盘口失衡（基于主动买卖比例）
    final imbalance = _calcOrderBookImbalance(trades, klines);

    // 3. 成交密度
    final density = _calcTradeDensity(klines, currentPrice);

    // 4. 清算热力图
    final liqZones = _detectLiquidationZones(klines, currentPrice);

    // 5. CVD斜率
    final cvdSlope = _calcCVDSlope(klines);

    // 6. Delta比率
    final deltaRatio = _calcDeltaRatio(trades, klines);

    // 综合判断
    LargeOrderDirection bias = LargeOrderDirection.neutral;
    if (largeOrderResult['buyVol'] > largeOrderResult['sellVol'] * 1.3) {
      bias = LargeOrderDirection.buy;
    } else if (largeOrderResult['sellVol'] > largeOrderResult['buyVol'] * 1.3) {
      bias = LargeOrderDirection.sell;
    }

    String summary;
    if (bias == LargeOrderDirection.buy && imbalance > 0.15) {
      summary = '大单主动买入+盘口买强，短期偏多';
    } else if (bias == LargeOrderDirection.sell && imbalance < -0.15) {
      summary = '大单主动卖出+盘口卖强，短期偏空';
    } else if (cvdSlope > 0.01) {
      summary = 'CVD持续流入，买盘累积';
    } else if (cvdSlope < -0.01) {
      summary = 'CVD持续流出，卖盘累积';
    } else {
      summary = '订单流中性，多空均衡';
    }

    return DeepOrderFlowResult(
      largeOrderBias: bias,
      largeBuyCount: largeOrderResult['buyCount'] as int,
      largeSellCount: largeOrderResult['sellCount'] as int,
      largeBuyVolume: largeOrderResult['buyVol'] as double,
      largeSellVolume: largeOrderResult['sellVol'] as double,
      orderBookImbalance: imbalance,
      tradeDensity: density,
      liquidationZones: liqZones,
      cvdSlope: cvdSlope,
      deltaRatio: deltaRatio,
      summary: summary,
    );
  }

  /// 大单追踪：超过平均成交量5倍的成交
  static Map<String, dynamic> _analyzeLargeOrders(List<Trade> trades) {
    if (trades.isEmpty) {
      return {'buyCount': 0, 'sellCount': 0, 'buyVol': 0.0, 'sellVol': 0.0};
    }

    final avgVol = trades.map((t) => t.quantity).reduce((a, b) => a + b) / trades.length;
    final threshold = avgVol * 5;

    int buyCount = 0, sellCount = 0;
    double buyVol = 0, sellVol = 0;

    for (final t in trades) {
      if (t.quantity >= threshold) {
        if (!t.isBuyerMaker) {
          // 主动买
          buyCount++;
          buyVol += t.quantity;
        } else {
          // 主动卖
          sellCount++;
          sellVol += t.quantity;
        }
      }
    }

    return {
      'buyCount': buyCount,
      'sellCount': sellCount,
      'buyVol': buyVol,
      'sellVol': sellVol,
    };
  }

  /// 盘口失衡估算：基于主动买卖比例
  static double _calcOrderBookImbalance(List<Trade> trades, List<Kline> klines) {
    if (trades.isNotEmpty) {
      double buyVol = 0, sellVol = 0;
      for (final t in trades) {
        if (!t.isBuyerMaker) buyVol += t.quantity;
        else sellVol += t.quantity;
      }
      final total = buyVol + sellVol;
      if (total == 0) return 0;
      return (buyVol - sellVol) / total;
    }

    // 无成交数据时，用K线近似：上涨K线的成交量 vs 下跌K线的成交量
    if (klines.length < 10) return 0;
    final recent = klines.sublist(klines.length - 20);
    double upVol = 0, downVol = 0;
    for (final k in recent) {
      if (k.close >= k.open) upVol += k.volume;
      else downVol += k.volume;
    }
    final total = upVol + downVol;
    if (total == 0) return 0;
    return (upVol - downVol) / total;
  }

  /// 成交密度：当前价±0.5%范围内的成交量占比
  static double _calcTradeDensity(List<Kline> klines, double currentPrice) {
    if (klines.length < 20 || currentPrice == 0) return 0;

    final range = currentPrice * 0.005;
    double nearVolume = 0;
    double totalVolume = 0;

    for (final k in klines.sublist(klines.length - 50)) {
      totalVolume += k.volume;
      // 如果K线的典型价格在当前价附近
      final typicalPrice = (k.high + k.low + k.close) / 3;
      if ((typicalPrice - currentPrice).abs() < range) {
        nearVolume += k.volume;
      }
    }

    return totalVolume > 0 ? nearVolume / totalVolume : 0;
  }

  /// 清算密集区检测：基于影线集中区域
  static List<LiquidationZone> _detectLiquidationZones(List<Kline> klines, double currentPrice) {
    final zones = <LiquidationZone>[];
    if (klines.length < 30) return zones;

    final recent = klines.sublist(klines.length - 100);

    // 检测下方多头清算区（下影线集中的区域）
    final lowWickZones = _countWickClusters(recent, isUpper: false);
    for (final zone in lowWickZones) {
      if (zone['price'] < currentPrice) {
        zones.add(LiquidationZone(
          price: zone['price'] as double,
          width: currentPrice * 0.003,
          isLongLiquidation: true,
          intensity: zone['count'] as int >= 5 ? 3 : (zone['count'] as int >= 3 ? 2 : 1),
        ));
      }
    }

    // 检测上方空头清算区（上影线集中的区域）
    final highWickZones = _countWickClusters(recent, isUpper: true);
    for (final zone in highWickZones) {
      if (zone['price'] > currentPrice) {
        zones.add(LiquidationZone(
          price: zone['price'] as double,
          width: currentPrice * 0.003,
          isLongLiquidation: false,
          intensity: zone['count'] as int >= 5 ? 3 : (zone['count'] as int >= 3 ? 2 : 1),
        ));
      }
    }

    zones.sort((a, b) => b.intensity.compareTo(a.intensity));
    return zones.take(3).toList();
  }

  static List<Map<String, dynamic>> _countWickClusters(List<Kline> klines, {required bool isUpper}) {
    final wickPrices = <double>[];
    for (final k in klines) {
      final wickPrice = isUpper ? k.high : k.low;
      final bodyTop = k.close > k.open ? k.close : k.open;
      final bodyBottom = k.close > k.open ? k.open : k.close;
      final wickSize = isUpper ? k.high - bodyTop : bodyBottom - k.low;
      if (wickSize > (bodyTop - bodyBottom).abs() * 0.5) {
        wickPrices.add(wickPrice);
      }
    }

    // 聚类：±0.3%内的算同一区域
    final clusters = <Map<String, dynamic>>[];
    for (final price in wickPrices) {
      bool found = false;
      for (final c in clusters) {
        if ((c['price'] as double - price).abs() / price < 0.003) {
          c['count'] = (c['count'] as int) + 1;
          found = true;
          break;
        }
      }
      if (!found) {
        clusters.add({'price': price, 'count': 1});
      }
    }

    return clusters.where((c) => (c['count'] as int) >= 2).toList();
  }

  /// CVD斜率：最近10根K线的CVD变化趋势
  static double _calcCVDSlope(List<Kline> klines) {
    if (klines.length < 15) return 0;

    final recent = klines.sublist(klines.length - 10);
    double cvd = 0;
    final cvdValues = <double>[];
    for (final k in recent) {
      // 近似CVD：上涨K线加成交量，下跌K线减成交量
      cvd += k.close >= k.open ? k.volume : -k.volume;
      cvdValues.add(cvd);
    }

    // 线性回归斜率
    final n = cvdValues.length;
    final xMean = (n - 1) / 2;
    final yMean = cvdValues.reduce((a, b) => a + b) / n;
    double numerator = 0, denominator = 0;
    for (int i = 0; i < n; i++) {
      numerator += (i - xMean) * (cvdValues[i] - yMean);
      denominator += (i - xMean) * (i - xMean);
    }
    return denominator > 0 ? numerator / denominator : 0;
  }

  /// Delta比率：主动买占比
  static double _calcDeltaRatio(List<Trade> trades, List<Kline> klines) {
    if (trades.isNotEmpty) {
      double buyVol = 0, totalVol = 0;
      for (final t in trades) {
        totalVol += t.quantity;
        if (!t.isBuyerMaker) buyVol += t.quantity;
      }
      return totalVol > 0 ? buyVol / totalVol : 0.5;
    }

    // 用K线近似
    if (klines.length < 5) return 0.5;
    final recent = klines.sublist(klines.length - 10);
    double upVol = 0, totalVol = 0;
    for (final k in recent) {
      totalVol += k.volume;
      if (k.close >= k.open) upVol += k.volume;
    }
    return totalVol > 0 ? upVol / totalVol : 0.5;
  }
}
