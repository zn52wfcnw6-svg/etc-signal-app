import '../../models/market_data.dart';
import '../../utils/constants.dart';
import '../long_cycle/structure_analyzer.dart';
import '../market_regime/market_regime.dart';
import '../adaptive/adaptive_params.dart';

/// 单周期方向
enum TimeframeBias { bullish, bearish, neutral }

/// 多周期分析结果
class MultiTimeframeResult {
  final TimeframeBias bias1d;
  final TimeframeBias bias4h;
  final TimeframeBias bias1h;
  final TimeframeBias bias5m;
  final TimeframeBias bias1m;
  final int bullishCount;
  final int bearishCount;
  final int neutralCount;
  final bool isBullishResonance; // 至少3个周期看多
  final bool isBearishResonance; // 至少3个周期看空
  final String description;

  MultiTimeframeResult({
    required this.bias1d,
    required this.bias4h,
    required this.bias1h,
    required this.bias5m,
    required this.bias1m,
    required this.bullishCount,
    required this.bearishCount,
    required this.neutralCount,
    required this.isBullishResonance,
    required this.isBearishResonance,
    required this.description,
  });

  /// 获取指定方向的共振强度 0-5
  int resonanceStrength(bool isLong) {
    final biases = [bias1d, bias4h, bias1h, bias5m, bias1m];
    final target = isLong ? TimeframeBias.bullish : TimeframeBias.bearish;
    return biases.where((b) => b == target).length;
  }
}

/// 多周期共振分析器
class MultiTimeframeAnalyzer {
  /// 分析五个周期的方向共振
  static MultiTimeframeResult analyze({
    required List<Kline> k1d,
    required List<Kline> k4h,
    required List<Kline> k1h,
    required List<Kline> k5m,
    required List<Kline> k1m,
  }) {
    final bias1d = _analyzeTimeframe(k1d);
    final bias4h = _analyzeTimeframe(k4h);
    final bias1h = _analyzeTimeframe(k1h);
    final bias5m = _analyzeTimeframe(k5m);
    final bias1m = _analyzeTimeframe(k1m);

    final biases = [bias1d, bias4h, bias1h, bias5m, bias1m];
    final bullishCount = biases.where((b) => b == TimeframeBias.bullish).length;
    final bearishCount = biases.where((b) => b == TimeframeBias.bearish).length;
    final neutralCount = biases.where((b) => b == TimeframeBias.neutral).length;

    // 至少3个周期同向才算共振
    final isBullish = bullishCount >= 3;
    final isBearish = bearishCount >= 3;

    String desc;
    if (isBullish) {
      desc = '$bullishCount周期看多共振（1D:${_label(bias1d)} 4H:${_label(bias4h)} 1H:${_label(bias1h)} 5m:${_label(bias5m)} 1m:${_label(bias1m)}）';
    } else if (isBearish) {
      desc = '$bearishCount周期看空共振（1D:${_label(bias1d)} 4H:${_label(bias4h)} 1H:${_label(bias1h)} 5m:${_label(bias5m)} 1m:${_label(bias1m)}）';
    } else {
      desc = '周期分歧，无共振（多$bullishCount/空$bearishCount/中性$neutralCount）';
    }

    return MultiTimeframeResult(
      bias1d: bias1d,
      bias4h: bias4h,
      bias1h: bias1h,
      bias5m: bias5m,
      bias1m: bias1m,
      bullishCount: bullishCount,
      bearishCount: bearishCount,
      neutralCount: neutralCount,
      isBullishResonance: isBullish,
      isBearishResonance: isBearish,
      description: desc,
    );
  }

  /// 分析单个周期的方向
  static TimeframeBias _analyzeTimeframe(List<Kline> klines) {
    if (klines.length < 20) return TimeframeBias.neutral;

    final structure = StructureAnalyzer.analyze(klines);
    final currentPrice = klines.last.close;

    // 用EMA20判断短期方向
    final ema20 = _ema(klines.map((k) => k.close).toList(), 20);

    if (structure.structure == MarketStructure.uptrend && currentPrice > ema20) {
      return TimeframeBias.bullish;
    }
    if (structure.structure == MarketStructure.downtrend && currentPrice < ema20) {
      return TimeframeBias.bearish;
    }

    // 结构震荡时，用价格与EMA关系判断
    if (currentPrice > ema20 * 1.002) return TimeframeBias.bullish;
    if (currentPrice < ema20 * 0.998) return TimeframeBias.bearish;

    return TimeframeBias.neutral;
  }

  static double _ema(List<double> prices, int period) {
    if (prices.length < period) return prices.last;
    final k = 2 / (period + 1);
    double ema = prices.sublist(0, period).reduce((a, b) => a + b) / period;
    for (int i = period; i < prices.length; i++) {
      ema = prices[i] * k + ema * (1 - k);
    }
    return ema;
  }

  static String _label(TimeframeBias b) {
    switch (b) {
      case TimeframeBias.bullish: return '多';
      case TimeframeBias.bearish: return '空';
      case TimeframeBias.neutral: return '中';
    }
  }
}
