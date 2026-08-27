import '../../models/market_data.dart';
import '../../utils/indicators.dart';

/// 波动率分析结果
class VolatilityAnalysis {
  final double atrValue;
  final double? atrPercentile;
  final String state; // low / normal / high
  final double? bollingerWidth;
  final bool isExtreme;

  VolatilityAnalysis({
    required this.atrValue,
    this.atrPercentile,
    required this.state,
    this.bollingerWidth,
    this.isExtreme = false,
  });
}

/// 波动率分析器
class VolatilityAnalyzer {
  static VolatilityAnalysis analyze(List<Kline> klines, {int atrPeriod = 14, int lookback = 252}) {
    if (klines.length < atrPeriod + 1) {
      return VolatilityAnalysis(atrValue: 0, state: 'normal');
    }

    final atrValues = Indicators.atr(klines, atrPeriod);
    final currentAtr = atrValues.last ?? 0;
    final percentile = Indicators.atrPercentile(atrValues, atrPeriod, lookback);

    String state = 'normal';
    if (percentile != null) {
      if (percentile < 0.2) state = 'low';
      else if (percentile > 0.7) state = 'high';
    }

    final closes = klines.map((k) => k.close).toList();
    final bbWidth = Indicators.bollingerWidth(closes, 20);
    final isExtreme = bbWidth != null && state == 'high';

    return VolatilityAnalysis(
      atrValue: currentAtr,
      atrPercentile: percentile,
      state: state,
      bollingerWidth: bbWidth,
      isExtreme: isExtreme,
    );
  }

  /// ATR缓冲（用于止损位计算）
  static double atrBuffer(List<Kline> klines, {double multiplier = 0.5}) {
    if (klines.length < 15) return 0;
    final atrValues = Indicators.atr(klines, 14);
    final atr = atrValues.last ?? 0;
    return atr * multiplier;
  }
}

/// OI与资金费率分析
class OIFundingAnalyzer {
  /// OI背离检测
  static bool detectOIDivergence(List<Kline> klines, List<double> oiValues, {required bool bullish}) {
    if (klines.length < 10 || oiValues.length < 10) return false;

    final minLen = klines.length < oiValues.length ? klines.length : oiValues.length;
    final recentKlines = klines.sublist(klines.length - minLen);
    final recentOI = oiValues.sublist(oiValues.length - minLen);

    final priceChange = (recentKlines.last.close - recentKlines.first.close) / recentKlines.first.close;
    final oiChange = (recentOI.last - recentOI.first) / (recentOI.first > 0 ? recentOI.first : 1);

    if (bullish) {
      // 看底背离：价格下跌但OI上升（空头建仓，可能被挤压）
      return priceChange < -0.01 && oiChange > 0.01;
    } else {
      // 看顶背离：价格上涨但OI下降（多头离场）
      return priceChange > 0.01 && oiChange < -0.01;
    }
  }

  /// 资金费率状态判定
  static String fundingState(double fundingRate8h) {
    if (fundingRate8h > 0.0008) return 'extreme_long'; // 多头极度拥挤
    if (fundingRate8h > 0.0005) return 'crowded_long';
    if (fundingRate8h < -0.0008) return 'extreme_short';
    if (fundingRate8h < -0.0005) return 'crowded_short';
    return 'neutral';
  }

  /// 72h加权资金费率（简化：用当前费率×3近似）
  static double weightedFunding72h(double currentRate) => currentRate * 3;

  /// 清算挤压检测（三选二代理指标）
  static bool detectLiquidationSqueeze({
    required double fundingRate,
    required double oiChange5m,
    required double activeBuyRatio,
  }) {
    int conditions = 0;
    // 资金费率极端且攀升
    if (fundingRate.abs() > 0.0005) conditions++;
    // OI 5m骤降>3%
    if (oiChange5m.abs() > 0.03) conditions++;
    // 主动买卖比极端
    if (activeBuyRatio > 3 || activeBuyRatio < 1 / 3) conditions++;
    return conditions >= 2;
  }
}
