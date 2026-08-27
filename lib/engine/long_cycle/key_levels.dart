import '../../models/market_data.dart';
import '../../utils/indicators.dart';

/// 关键位绘制器：摆动点 + VPVR + 流动性池三层叠加
class KeyLevelDrawer {
  /// 绘制支撑带
  static List<KeyLevel> drawSupportLevels(List<Kline> klines, {int lookback = 2}) {
    final levels = <KeyLevel>[];
    if (klines.length < 30) return levels;

    final swingPoints = Indicators.findSwingPoints(klines, lookback: lookback);
    final swingLows = swingPoints.where((p) => !p.isHigh).toList();
    final vpvrNodes = Indicators.vpvrNodes(klines, bins: 50);
    final currentPrice = klines.last.close;

    // 收集所有低于当前价的摆动低点
    final supportPrices = swingLows
        .where((p) => p.price < currentPrice)
        .map((p) => p.price)
        .toList()
      ..sort((a, b) => b.compareTo(a)); // 从高到低

    // 合并相近的摆动点（±0.3%内）
    final mergedSwing = _mergeCloseLevels(supportPrices, 0.003);

    for (final price in mergedSwing) {
      final hasVPVR = vpvrNodes.any((n) =>
          (n['price']! - price).abs() / price < 0.005);
      final hasLiquidity = _detectLiquidityPool(klines, price, isSupport: true);

      final strength = (hasVPVR ? 1 : 0) + (hasLiquidity ? 1 : 0) + 1; // swing本身算1层

      levels.add(KeyLevel(
        lower: price * 0.995,
        upper: price * 1.005,
        mid: price,
        strength: strength,
        type: 'support',
        hasSwing: true,
        hasVPVR: hasVPVR,
        hasLiquidityPool: hasLiquidity,
      ));
    }

    // 按强度排序，取最强的3个
    levels.sort((a, b) => b.strength.compareTo(a.strength));
    return levels.take(3).toList();
  }

  /// 绘制压力带
  static List<KeyLevel> drawResistanceLevels(List<Kline> klines, {int lookback = 2}) {
    final levels = <KeyLevel>[];
    if (klines.length < 30) return levels;

    final swingPoints = Indicators.findSwingPoints(klines, lookback: lookback);
    final swingHighs = swingPoints.where((p) => p.isHigh).toList();
    final vpvrNodes = Indicators.vpvrNodes(klines, bins: 50);
    final currentPrice = klines.last.close;

    final resistancePrices = swingHighs
        .where((p) => p.price > currentPrice)
        .map((p) => p.price)
        .toList()
      ..sort();

    final mergedSwing = _mergeCloseLevels(resistancePrices, 0.003);

    for (final price in mergedSwing) {
      final hasVPVR = vpvrNodes.any((n) =>
          (n['price']! - price).abs() / price < 0.005);
      final hasLiquidity = _detectLiquidityPool(klines, price, isSupport: false);

      final strength = (hasVPVR ? 1 : 0) + (hasLiquidity ? 1 : 0) + 1;

      levels.add(KeyLevel(
        lower: price * 0.995,
        upper: price * 1.005,
        mid: price,
        strength: strength,
        type: 'resistance',
        hasSwing: true,
        hasVPVR: hasVPVR,
        hasLiquidityPool: hasLiquidity,
      ));
    }

    levels.sort((a, b) => b.strength.compareTo(a.strength));
    return levels.take(3).toList();
  }

  /// 合并相近价位
  static List<double> _mergeCloseLevels(List<double> prices, double tolerance) {
    if (prices.isEmpty) return [];
    final sorted = List<double>.from(prices)..sort();
    final merged = <double>[];
    double groupSum = sorted.first;
    int groupCount = 1;

    for (int i = 1; i < sorted.length; i++) {
      if ((sorted[i] - sorted[i - 1]).abs() / sorted[i - 1] < tolerance) {
        groupSum += sorted[i];
        groupCount++;
      } else {
        merged.add(groupSum / groupCount);
        groupSum = sorted[i];
        groupCount = 1;
      }
    }
    merged.add(groupSum / groupCount);
    return merged;
  }

  /// 检测流动性池：多个影线集中的区域
  static bool _detectLiquidityPool(List<Kline> klines, double price, {required bool isSupport}) {
    int wickCount = 0;
    final tolerance = price * 0.005;
    for (final k in klines.sublist(klines.length > 100 ? klines.length - 100 : 0)) {
      if (isSupport) {
        if ((k.low - price).abs() < tolerance) wickCount++;
      } else {
        if ((k.high - price).abs() < tolerance) wickCount++;
      }
    }
    return wickCount >= 3;
  }

  /// 获取最强支撑位
  static KeyLevel? getStrongestSupport(List<Kline> klines) {
    final levels = drawSupportLevels(klines);
    return levels.isNotEmpty ? levels.first : null;
  }

  /// 获取最强压力位
  static KeyLevel? getStrongestResistance(List<Kline> klines) {
    final levels = drawResistanceLevels(klines);
    return levels.isNotEmpty ? levels.first : null;
  }
}
