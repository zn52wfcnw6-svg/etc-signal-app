import '../../models/market_data.dart';
import '../../utils/indicators.dart';

/// 自适应参数：根据近期波动率动态调整所有阈值
class AdaptiveParams {
  final double atrPercent; // ATR/价格 波动率百分比
  final double volatilityRatio; // 当前波动/24h平均波动
  final bool isHighVolatility;
  final bool isLowVolatility;

  // 动态阈值
  final double minRiskReward; // 最低盈亏比
  final double sweepDepth; // 流动性清扫刺穿深度（ATR倍数）
  final double bandWidth; // 支撑压力带宽度（百分比）
  final int confirmationCount; // 需要确认的轮询次数
  final double btcVolThreshold; // BTC波动冻结阈值
  final double priceDeviationThreshold; // 行情偏离阈值

  AdaptiveParams({
    required this.atrPercent,
    required this.volatilityRatio,
    required this.isHighVolatility,
    required this.isLowVolatility,
    required this.minRiskReward,
    required this.sweepDepth,
    required this.bandWidth,
    required this.confirmationCount,
    required this.btcVolThreshold,
    required this.priceDeviationThreshold,
  });

  /// 根据K线数据计算自适应参数
  static AdaptiveParams calculate(List<Kline> klines) {
    if (klines.length < 30) {
      return _default();
    }

    final atrValues = Indicators.atr(klines, 14);
    final atr = atrValues.isNotEmpty ? (atrValues.last ?? 0) : 0.0;
    final currentPrice = klines.last.close;
    final atrPercent = currentPrice > 0 ? atr / currentPrice : 0.0;

    // 计算24h平均波动率（用48根5m K线 = 4h，简化）
    final recentVol = _averageTrueRange(klines.sublist(
        klines.length > 20 ? klines.length - 20 : 0));
    final olderVol = _averageTrueRange(klines.sublist(
        0, klines.length > 40 ? klines.length - 20 : klines.length ~/ 2));
    final volatilityRatio = olderVol > 0 ? recentVol / olderVol : 1.0;

    final isHighVol = atrPercent > 0.008 || volatilityRatio > 1.5; // >0.8%或波动放大50%
    final isLowVol = atrPercent < 0.002 && volatilityRatio < 0.7; // <0.2%且波动缩小

    // 高波动：提高盈亏比要求，放宽清扫深度，增加确认次数
    // 低波动：降低盈亏比要求，收窄清扫深度，减少确认次数
    double minRR = 4.0;
    double sweepDepth = 0.5; // ATR倍数
    double bandWidth = 0.005; // 0.5%
    int confirmCount = 3;
    double btcVolThresh = 0.018; // 1.8%
    double priceDevThresh = 0.004; // 0.4%

    if (isHighVol) {
      minRR = 5.0;
      sweepDepth = 0.8;
      bandWidth = 0.008;
      confirmCount = 5;
      btcVolThresh = 0.025; // 高波动时放宽BTC阈值到2.5%
    } else if (isLowVol) {
      minRR = 3.0;
      sweepDepth = 0.3;
      bandWidth = 0.003;
      confirmCount = 2;
      btcVolThresh = 0.012; // 低波动时收紧到1.2%
    }

    return AdaptiveParams(
      atrPercent: atrPercent,
      volatilityRatio: volatilityRatio,
      isHighVolatility: isHighVol,
      isLowVolatility: isLowVol,
      minRiskReward: minRR,
      sweepDepth: sweepDepth,
      bandWidth: bandWidth,
      confirmationCount: confirmCount,
      btcVolThreshold: btcVolThresh,
      priceDeviationThreshold: priceDevThresh,
    );
  }

  static AdaptiveParams _default() {
    return AdaptiveParams(
      atrPercent: 0.005,
      volatilityRatio: 1.0,
      isHighVolatility: false,
      isLowVolatility: false,
      minRiskReward: 4.0,
      sweepDepth: 0.5,
      bandWidth: 0.005,
      confirmationCount: 3,
      btcVolThreshold: 0.018,
      priceDeviationThreshold: 0.004,
    );
  }

  static double _averageTrueRange(List<Kline> klines) {
    if (klines.length < 2) return 0;
    double sum = 0;
    for (int i = 1; i < klines.length; i++) {
      final tr = _calcTrueRange(klines[i], klines[i - 1]);
      sum += tr;
    }
    return sum / (klines.length - 1);
  }

  String get volatilityLabel {
    if (isHighVolatility) return '高波动';
    if (isLowVolatility) return '低波动';
    return '正常波动';
  }

  static double _calcTrueRange(Kline current, Kline previous) {
    final highLow = current.high - current.low;
    final highClose = (current.high - previous.close).abs();
    final lowClose = (current.low - previous.close).abs();
    return [highLow, highClose, lowClose].reduce((a, b) => a > b ? a : b);
  }
}
