import '../models/market_data.dart';
import '../utils/constants.dart';
import '../utils/indicators.dart';

/// 行情交叉校验结果
class ValidationResult {
  final ValidatedMarketData? data;
  final bool isFailed;
  final List<String> abnormalSources;
  final String? reason;

  ValidationResult({
    this.data,
    this.isFailed = false,
    this.abnormalSources = const [],
    this.reason,
  });
}

/// MAD动态交叉校验器
class MarketValidator {
  /// 校验多源价格，返回校验后的基准数据
  static ValidationResult validate(List<MarketSnapshot> snapshots) {
    if (snapshots.isEmpty) {
      return ValidationResult(isFailed: true, reason: '无行情数据');
    }

    // 提取有效价格
    final priceMap = <String, double>{};
    for (final s in snapshots) {
      if (s.price > 0) priceMap[s.exchange] = s.price;
    }

    if (priceMap.length < 1) {
      return ValidationResult(isFailed: true, reason: '无有效行情数据源');
    }

    final prices = priceMap.values.toList();
    final medianPrice = Indicators.median(prices);
    final deviations = prices.map((p) => (p - medianPrice).abs() / medianPrice).toList();
    final mad = Indicators.mad(deviations);
    final threshold = mad * AppConstants.madThresholdMultiplier;
    final effectiveThreshold = threshold > AppConstants.minAbnormalDeviation
        ? threshold
        : AppConstants.minAbnormalDeviation;

    // 识别异常源
    final abnormalSources = <String>[];
    final validSources = <String>[];
    for (final entry in priceMap.entries) {
      final dev = (entry.value - medianPrice).abs() / medianPrice;
      if (dev > effectiveThreshold) {
        abnormalSources.add(entry.key);
      } else {
        validSources.add(entry.key);
      }
    }

    // 异常源超过上限 → 校验失败
    if (abnormalSources.length > AppConstants.maxDegradedSources) {
      return ValidationResult(
        isFailed: true,
        abnormalSources: abnormalSources,
        reason: '${abnormalSources.length}家交易所价格异常: ${abnormalSources.join(", ")}',
      );
    }

    // 用有效源重新计算中位数
    final validPrices = validSources.map((s) => priceMap[s]!).toList();
    final finalPrice = Indicators.median(validPrices);

    // 资金费率和OI取有效源的平均
    final validSnapshots = snapshots.where((s) => validSources.contains(s.exchange)).toList();
    final fundingRates = validSnapshots.where((s) => s.fundingRate != 0).map((s) => s.fundingRate).toList();
    final ois = validSnapshots.where((s) => s.openInterest != 0).map((s) => s.openInterest).toList();

    final avgFunding = fundingRates.isNotEmpty
        ? fundingRates.reduce((a, b) => a + b) / fundingRates.length
        : 0.0;
    final avgOI = ois.isNotEmpty
        ? ois.reduce((a, b) => a + b) / ois.length
        : 0.0;

    return ValidationResult(
      data: ValidatedMarketData(
        price: finalPrice,
        fundingRate: avgFunding,
        openInterest: avgOI,
        validSources: validSources,
        excludedSources: abnormalSources,
        isDegraded: abnormalSources.isNotEmpty,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
      abnormalSources: abnormalSources,
    );
  }

  /// 价格跳变检测（单源8秒内变动>2%且其他源无跟随）
  static bool detectPriceJump(MarketSnapshot current, MarketSnapshot? previous, List<MarketSnapshot> others) {
    if (previous == null) return false;
    final change = (current.price - previous.price).abs() / previous.price;
    if (change < 0.02) return false;

    // 检查其他源是否有类似变动
    for (final o in others) {
      if (o.exchange == current.exchange) continue;
      // 简化：其他源价格与当前源接近则不算异常
      if ((o.price - current.price).abs() / current.price < 0.01) return false;
    }
    return true;
  }
}
