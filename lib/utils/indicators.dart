import '../models/market_data.dart';

/// 技术指标计算工具
class Indicators {
  /// 简单移动平均
  static List<double?> sma(List<double> values, int period) {
    final result = List<double?>.filled(values.length, null);
    for (int i = period - 1; i < values.length; i++) {
      double sum = 0;
      for (int j = i - period + 1; j <= i; j++) {
        sum += values[j];
      }
      result[i] = sum / period;
    }
    return result;
  }

  /// 指数移动平均
  static List<double?> ema(List<double> values, int period) {
    final result = List<double?>.filled(values.length, null);
    if (values.length < period) return result;
    final multiplier = 2.0 / (period + 1);
    double prevEma = 0;
    for (int i = 0; i < values.length; i++) {
      if (i < period - 1) continue;
      if (i == period - 1) {
        double sum = 0;
        for (int j = 0; j < period; j++) sum += values[j];
        prevEma = sum / period;
        result[i] = prevEma;
      } else {
        prevEma = (values[i] - prevEma) * multiplier + prevEma;
        result[i] = prevEma;
      }
    }
    return result;
  }

  /// 真实波幅 ATR
  static List<double?> atr(List<Kline> klines, int period) {
    final result = List<double?>.filled(klines.length, null);
    if (klines.length < period + 1) return result;
    final trList = <double>[];
    for (int i = 0; i < klines.length; i++) {
      double tr;
      if (i == 0) {
        tr = klines[i].high - klines[i].low;
      } else {
        final hl = klines[i].high - klines[i].low;
        final hc = (klines[i].high - klines[i - 1].close).abs();
        final lc = (klines[i].low - klines[i - 1].close).abs();
        tr = [hl, hc, lc].reduce((a, b) => a > b ? a : b);
      }
      trList.add(tr);
    }
    for (int i = period - 1; i < trList.length; i++) {
      if (i == period - 1) {
        double sum = 0;
        for (int j = 0; j < period; j++) sum += trList[j];
        result[i] = sum / period;
      } else {
        result[i] = (result[i - 1]! * (period - 1) + trList[i]) / period;
      }
    }
    return result;
  }

  /// ATR百分位（252周期滚动）
  static double? atrPercentile(List<double?> atrValues, int period, int lookback) {
    final validAtr = atrValues.where((v) => v != null).cast<double>().toList();
    if (validAtr.length < lookback) return null;
    final recent = validAtr.sublist(validAtr.length - lookback);
    final current = recent.last;
    final below = recent.where((v) => v < current).length;
    return below / recent.length;
  }

  /// RSI 相对强弱指标
  static List<double?> rsi(List<double> closes, int period) {
    final result = List<double?>.filled(closes.length, null);
    if (closes.length < period + 1) return result;
    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final change = closes[i] - closes[i - 1];
      if (change > 0) avgGain += change;
      else avgLoss += change.abs();
    }
    avgGain /= period;
    avgLoss /= period;
    result[period] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
    for (int i = period + 1; i < closes.length; i++) {
      final change = closes[i] - closes[i - 1];
      final gain = change > 0 ? change : 0;
      final loss = change < 0 ? change.abs() : 0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      result[i] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
    }
    return result;
  }

  /// 布林带宽度
  static double? bollingerWidth(List<double> closes, int period, {double stdDev = 2}) {
    if (closes.length < period) return null;
    final recent = closes.sublist(closes.length - period);
    final mean = recent.reduce((a, b) => a + b) / period;
    double variance = 0;
    for (final v in recent) variance += (v - mean) * (v - mean);
    final std = (variance / period);
    final upper = mean + stdDev * std;
    final lower = mean - stdDev * std;
    return mean > 0 ? (upper - lower) / mean : null;
  }

  /// 波动率（N周期涨跌幅）
  static double? volatilityN(List<Kline> klines, int periods) {
    if (klines.length < periods + 1) return null;
    final current = klines.last.close;
    final past = klines[klines.length - 1 - periods].close;
    return (current - past) / past;
  }

  /// 成交量分布 VPVR 高成交量节点
  static List<Map<String, double>> vpvrNodes(List<Kline> klines, {int bins = 50}) {
    if (klines.isEmpty) return [];
    double minPrice = double.infinity, maxPrice = 0;
    for (final k in klines) {
      if (k.low < minPrice) minPrice = k.low;
      if (k.high > maxPrice) maxPrice = k.high;
    }
    final binSize = (maxPrice - minPrice) / bins;
    final volumeBins = List<double>.filled(bins, 0);
    for (final k in klines) {
      final lowBin = ((k.low - minPrice) / binSize).clamp(0, bins - 1).toInt();
      final highBin = ((k.high - minPrice) / binSize).clamp(0, bins - 1).toInt();
      final volPerBin = k.volume / (highBin - lowBin + 1);
      for (int b = lowBin; b <= highBin; b++) volumeBins[b] += volPerBin;
    }
    final meanVol = volumeBins.reduce((a, b) => a + b) / bins;
    double stdSum = 0;
    for (final v in volumeBins) stdSum += (v - meanVol) * (v - meanVol);
    final stdVol = (stdSum / bins);
    final threshold = meanVol + 1.5 * stdVol;
    final nodes = <Map<String, double>>[];
    for (int i = 0; i < bins; i++) {
      if (volumeBins[i] > threshold) {
        nodes.add({
          'price': minPrice + (i + 0.5) * binSize,
          'volume': volumeBins[i],
        });
      }
    }
    return nodes;
  }

  /// 中位数
  static double median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// 中位数绝对偏差 MAD
  static double mad(List<double> values) {
    final med = median(values);
    final deviations = values.map((v) => (v - med).abs()).toList();
    return median(deviations);
  }

  /// 相对强度 RS（ETH vs BTC）
  static double relativeStrength(List<double> ethCloses, List<double> btcCloses, int period) {
    if (ethCloses.length < period + 1 || btcCloses.length < period + 1) return 0;
    final ethChange = (ethCloses.last - ethCloses[ethCloses.length - 1 - period]) /
        ethCloses[ethCloses.length - 1 - period];
    final btcChange = (btcCloses.last - btcCloses[btcCloses.length - 1 - period]) /
        btcCloses[btcCloses.length - 1 - period];
    return ethChange - btcChange;
  }

  /// 识别摆动点
  static List<SwingPoint> findSwingPoints(List<Kline> klines, {int lookback = 2}) {
    final points = <SwingPoint>[];
    for (int i = lookback; i < klines.length - lookback; i++) {
      bool isHigh = true, isLow = true;
      for (int j = i - lookback; j <= i + lookback; j++) {
        if (j == i) continue;
        if (klines[j].high >= klines[i].high) isHigh = false;
        if (klines[j].low <= klines[i].low) isLow = false;
      }
      if (isHigh) {
        points.add(SwingPoint(
          index: i,
          time: klines[i].closeTime,
          price: klines[i].high,
          isHigh: true,
        ));
      }
      if (isLow) {
        points.add(SwingPoint(
          index: i,
          time: klines[i].closeTime,
          price: klines[i].low,
          isHigh: false,
        ));
      }
    }
    return points;
  }

  /// FVG 公允价值缺口检测
  static Map<String, double>? detectFVG(List<Kline> klines) {
    if (klines.length < 3) return null;
    final k1 = klines[klines.length - 3];
    final k3 = klines.last;
    // 看涨FVG: k1.high < k3.low
    if (k1.high < k3.low) {
      return {'type': 1, 'lower': k1.high, 'upper': k3.low};
    }
    // 看跌FVG: k1.low > k3.high
    if (k1.low > k3.high) {
      return {'type': -1, 'lower': k3.high, 'upper': k1.low};
    }
    return null;
  }
}
