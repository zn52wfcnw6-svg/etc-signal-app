import '../../models/market_data.dart';
import '../../utils/constants.dart';
import '../long_cycle/structure_analyzer.dart';
/// 单个周期分析
class TimeframeResult {
  final String timeframe;
  final MarketStructure structure;
  final bool bullish;
  final bool bearish;
  final double trendStrength;
  final String description;

  TimeframeResult({
    required this.timeframe,
    required this.structure,
    required this.bullish,
    required this.bearish,
    required this.trendStrength,
    required this.description,
  });
}

/// 多周期共振结果
class MultiTimeframeResult {
  final List<TimeframeResult> timeframes;
  final int bullishCount;
  final int bearishCount;
  final int neutralCount;
  final String description;

  MultiTimeframeResult({
    required this.timeframes,
    required this.bullishCount,
    required this.bearishCount,
    required this.neutralCount,
    required this.description,
  });

  /// 共振强度评分（0-5），isLong=true计算多头共振
  int resonanceStrength(bool isLong) {
    int score = 0;
    final weights = [3, 2, 1, 1, 1]; // 1D权重最高
    for (int i = 0; i < timeframes.length && i < weights.length; i++) {
      if (isLong && timeframes[i].bullish) score += weights[i];
      if (!isLong && timeframes[i].bearish) score += weights[i];
    }
    return score;
  }

  bool get longResonance => resonanceStrength(true) >= 3;
  bool get shortResonance => resonanceStrength(false) >= 3;
}

/// 多周期共振分析器
class MultiTimeframeAnalyzer {
  static MultiTimeframeResult analyze({
    required List<Kline> k1d,
    required List<Kline> k4h,
    required List<Kline> k1h,
    required List<Kline> k5m,
    required List<Kline> k1m,
  }) {
    final analyses = [
      _analyze('1D', k1d),
      _analyze('4H', k4h),
      _analyze('1H', k1h),
      _analyze('5m', k5m),
      _analyze('1m', k1m),
    ];

    int bullish = 0, bearish = 0, neutral = 0;
    for (final a in analyses) {
      if (a.bullish) bullish++;
      else if (a.bearish) bearish++;
      else neutral++;
    }

    String desc;
    if (bullish >= 4) desc = '强多头共振：$bullish/5周期看多';
    else if (bearish >= 4) desc = '强空头共振：$bearish/5周期看空';
    else if (bullish > bearish) desc = '偏多：$bullish多/$bearish空/$neutral中性';
    else if (bearish > bullish) desc = '偏空：$bullish多/$bearish空/$neutral中性';
    else desc = '多空分歧：$bullish多/$bearish空';

    return MultiTimeframeResult(
      timeframes: analyses,
      bullishCount: bullish,
      bearishCount: bearish,
      neutralCount: neutral,
      description: desc,
    );
  }

  static TimeframeResult _analyze(String tf, List<Kline> klines) {
    if (klines.length < 10) {
      return TimeframeResult(
        timeframe: tf, structure: MarketStructure.ranging,
        bullish: false, bearish: false, trendStrength: 0,
        description: '$tf 数据不足',
      );
    }

    final structure = StructureAnalyzer.analyze(klines, lookback: 2);
    final closes = klines.map((k) => k.close).toList();
    final sma5 = closes.length >= 5
        ? closes.sublist(closes.length - 5).reduce((a, b) => a + b) / 5
        : closes.last;

    bool bullish = false;
    bool bearish = false;

    if (structure.structure == MarketStructure.uptrend) {
      bullish = true;
    } else if (structure.structure == MarketStructure.downtrend) {
      bearish = true;
    } else if (structure.isCHoCH) {
      bullish = closes.last > closes[closes.length - 5.clamp(0, closes.length - 1)];
      bearish = !bullish;
    } else {
      bullish = closes.last > sma5;
      bearish = closes.last < sma5;
    }

    return TimeframeResult(
      timeframe: tf,
      structure: structure.structure,
      bullish: bullish,
      bearish: bearish,
      trendStrength: structure.isBOS ? 0.8 : 0.5,
      description: '$tf ${structure.structure.name}',
    );
  }
}
