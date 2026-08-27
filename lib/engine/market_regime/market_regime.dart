import '../../models/market_data.dart';
import '../../utils/indicators.dart';
import '../../utils/constants.dart';
import '../long_cycle/structure_analyzer.dart';
import '../adaptive/adaptive_params.dart';

/// 市场状态类型
enum MarketRegime {
  trendingUp,    // 上升趋势市
  trendingDown,  // 下降趋势市
  ranging,       // 震荡市
  extreme,       // 极端市（高波动+方向极端）
  preBreakout,   // 变盘前夜（低波动+收缩）
}

/// 市场状态分析结果
class MarketRegimeResult {
  final MarketRegime regime;
  final String description;
  final double trendStrength; // 0-1 趋势强度
  final double rangeBound; // 震荡区间宽度百分比
  final bool allowsCounterTrend; // 是否允许逆势交易（抓顶抓底）
  final bool allowsTrendFollow; // 是否允许顺势交易
  final String recommendedStrategy;

  MarketRegimeResult({
    required this.regime,
    required this.description,
    required this.trendStrength,
    required this.rangeBound,
    required this.allowsCounterTrend,
    required this.allowsTrendFollow,
    required this.recommendedStrategy,
  });
}

/// 市场状态识别引擎
class MarketRegimeAnalyzer {
  /// 分析当前市场状态
  static MarketRegimeResult analyze(List<Kline> klines, AdaptiveParams params) {
    if (klines.length < 50) {
      return MarketRegimeResult(
        regime: MarketRegime.ranging,
        description: '数据不足，默认震荡',
        trendStrength: 0,
        rangeBound: 0,
        allowsCounterTrend: true,
        allowsTrendFollow: true,
        recommendedStrategy: '等待数据',
      );
    }

    final structure = StructureAnalyzer.analyze(klines);
    final atrPercent = params.atrPercent;
    final volRatio = params.volatilityRatio;

    // 计算趋势强度：ADX简化版
    final trendStrength = _calcTrendStrength(klines);

    // 计算震荡区间：最近20根K线的高低点范围
    final recent = klines.sublist(klines.length - 20);
    final highest = recent.map((k) => k.high).reduce((a, b) => a > b ? a : b);
    final lowest = recent.map((k) => k.low).reduce((a, b) => a < b ? a : b);
    final rangeBound = (highest - lowest) / klines.last.close;

    // 判定逻辑
    // 极端市：高波动 + 强趋势 + 波动率放大
    if (params.isHighVolatility && trendStrength > 0.6 && volRatio > 1.3) {
      return MarketRegimeResult(
        regime: MarketRegime.extreme,
        description: '极端行情：高波动+强趋势，只做反转不做追势',
        trendStrength: trendStrength,
        rangeBound: rangeBound,
        allowsCounterTrend: true,
        allowsTrendFollow: false,
        recommendedStrategy: '仅逆势反转，仓位减半',
      );
    }

    // 变盘前夜：低波动 + 区间收缩 + 波动率下降
    if (params.isLowVolatility && rangeBound < 0.015 && volRatio < 0.7) {
      return MarketRegimeResult(
        regime: MarketRegime.preBreakout,
        description: '变盘前夜：波动率收缩，等待方向选择',
        trendStrength: trendStrength,
        rangeBound: rangeBound,
        allowsCounterTrend: true,
        allowsTrendFollow: false,
        recommendedStrategy: '区间高抛低吸，突破后跟进',
      );
    }

    // 上升趋势市：结构上升 + 趋势强度>0.4
    if (structure.structure == MarketStructure.uptrend && trendStrength > 0.4) {
      return MarketRegimeResult(
        regime: MarketRegime.trendingUp,
        description: '上升趋势：只做多回踩，不做空抓顶',
        trendStrength: trendStrength,
        rangeBound: rangeBound,
        allowsCounterTrend: false,
        allowsTrendFollow: true,
        recommendedStrategy: '回踩支撑做多，不逆势做空',
      );
    }

    // 下降趋势市
    if (structure.structure == MarketStructure.downtrend && trendStrength > 0.4) {
      return MarketRegimeResult(
        regime: MarketRegime.trendingDown,
        description: '下降趋势：只做空反弹，不做多抓底',
        trendStrength: trendStrength,
        rangeBound: rangeBound,
        allowsCounterTrend: false,
        allowsTrendFollow: true,
        recommendedStrategy: '反弹压力做空，不逆势做多',
      );
    }

    // 震荡市：默认
    return MarketRegimeResult(
      regime: MarketRegime.ranging,
      description: '震荡区间：高抛低吸，抓顶抓底主力场景',
      trendStrength: trendStrength,
      rangeBound: rangeBound,
      allowsCounterTrend: true,
      allowsTrendFollow: false,
      recommendedStrategy: '支撑做多/压力做空，区间操作',
    );
  }

  /// 简化趋势强度计算（类ADX）
  static double _calcTrendStrength(List<Kline> klines) {
    if (klines.length < 30) return 0;

    double plusDM = 0, minusDM = 0, tr = 0;
    for (int i = klines.length - 20; i < klines.length; i++) {
      final upMove = klines[i].high - klines[i - 1].high;
      final downMove = klines[i - 1].low - klines[i].low;
      if (upMove > downMove && upMove > 0) plusDM += upMove;
      if (downMove > upMove && downMove > 0) minusDM += downMove;
      final highLow = klines[i].high - klines[i].low;
      final highClose = (klines[i].high - klines[i-1].close).abs();
      final lowClose = (klines[i].low - klines[i-1].close).abs();
      tr += [highLow, highClose, lowClose].reduce((a, b) => a > b ? a : b);
    }

    if (tr == 0) return 0;
    final plusDI = plusDM / tr;
    final minusDI = minusDM / tr;
    final dx = (plusDI - minusDI).abs() / (plusDI + minusDI > 0 ? plusDI + minusDI : 1);
    return dx.clamp(0.0, 1.0);
  }
}
