import '../../models/market_data.dart';
import '../long_cycle/volatility_oi.dart';

/// 自适应参数：根据近期波动率动态调整所有阈值
class AdaptiveParams {
  final double atrPercent; // ATR/价格 波动率百分比
  final double atrValue;
  final double volatilityRatio; // 近期成交量/平均成交量
  final int confirmationCount; // 需要确认的轮询次数
  final double minRiskReward; // 最低盈亏比
  final double sweepDepthPercent; // 流动性清扫刺穿深度百分比
  final double levelBandWidth; // 关键位带宽百分比
  final double btcVolThreshold; // BTC波动冻结阈值
  final double priceDeviationThreshold; // 行情偏离阈值
  final bool isHighVolatility;
  final bool isLowVolatility;

  AdaptiveParams({
    required this.atrPercent,
    required this.atrValue,
    required this.volatilityRatio,
    required this.confirmationCount,
    required this.minRiskReward,
    required this.sweepDepthPercent,
    required this.levelBandWidth,
    required this.btcVolThreshold,
    required this.priceDeviationThreshold,
    required this.isHighVolatility,
    required this.isLowVolatility,
  });

  /// 根据K线数据计算自适应参数
  static AdaptiveParams calculate(List<Kline> klines) {
    if (klines.length < 20) {
      return _default();
    }

    final vol = VolatilityAnalyzer.analyze(klines);
    final atrPct = vol.atrValue / klines.last.close;
    final currentPrice = klines.last.close;

    // 成交量比：近5根平均/近20根平均
    double volRatio = 1.0;
    if (klines.length >= 20) {
      final recentVol = klines.sublist(klines.length - 5).map((k) => k.volume).reduce((a, b) => a + b) / 5;
      final olderVol = klines.sublist(klines.length - 20, klines.length - 5).map((k) => k.volume).reduce((a, b) => a + b) / 15;
      if (olderVol > 0) volRatio = recentVol / olderVol;
    }

    // 波动率分级
    final isHighVol = atrPct > 0.012; // >1.2% 高波动
    final isLowVol = atrPct < 0.004; // <0.4% 低波动

    // 确认次数：高波动要求更多确认
    int confirmCount = 3;
    if (isHighVol) confirmCount = 5;
    if (isLowVol) confirmCount = 2;

    // 盈亏比：高波动要求更高
    double minRR = 4.0;
    if (isHighVol) minRR = 5.5;
    if (isLowVol) minRR = 3.0;

    // 清扫深度：基于ATR
    double sweepDepth = atrPct * 0.8;
    if (sweepDepth < 0.002) sweepDepth = 0.002; // 最低0.2%
    if (sweepDepth > 0.015) sweepDepth = 0.015; // 最高1.5%

    // 关键位带宽：基于波动率
    double bandWidth = atrPct * 0.6;
    if (bandWidth < 0.003) bandWidth = 0.003; // 最低0.3%
    if (bandWidth > 0.012) bandWidth = 0.012; // 最高1.2%

    // BTC波动阈值：高波动时放宽
    double btcVolThresh = 0.018;
    if (isHighVol) btcVolThresh = 0.025;

    // 行情偏离阈值
    double priceDevThresh = 0.004;
    if (isHighVol) priceDevThresh = 0.006;

    return AdaptiveParams(
      atrPercent: atrPct,
      atrValue: vol.atrValue,
      volatilityRatio: volRatio,
      confirmationCount: confirmCount,
      minRiskReward: minRR,
      sweepDepthPercent: sweepDepth,
      levelBandWidth: bandWidth,
      btcVolThreshold: btcVolThresh,
      priceDeviationThreshold: priceDevThresh,
      isHighVolatility: isHighVol,
      isLowVolatility: isLowVol,
    );
  }

  static AdaptiveParams _default() {
    return AdaptiveParams(
      atrPercent: 0.008,
      atrValue: 0,
      volatilityRatio: 1.0,
      confirmationCount: 3,
      minRiskReward: 4.0,
      sweepDepthPercent: 0.005,
      levelBandWidth: 0.005,
      btcVolThreshold: 0.018,
      priceDeviationThreshold: 0.004,
      isHighVolatility: false,
      isLowVolatility: false,
    );
  }

  String get volatilityLabel {
    if (isHighVolatility) return '高波动';
    if (isLowVolatility) return '低波动';
    return '正常波动';
  }

  @override
  String toString() {
    return 'AdaptiveParams(vol=${(atrPercent*100).toStringAsFixed(2)}%, confirm=$confirmationCount, '
        'minRR=$minRiskReward, sweep=${(sweepDepthPercent*100).toStringAsFixed(2)}%, '
        'band=${(levelBandWidth*100).toStringAsFixed(2)}%)';
  }
}
