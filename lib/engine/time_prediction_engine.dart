import 'dart:math';
import '../models/market_data.dart';

/// 多维度时间预测引擎
/// 整合8大因素，预测价格到达目标位的时间
/// 因素：ATR波动率 + 市场状态 + 成交量 + 交易时段 + 方向 + 流动性 + 历史相似度 + 动量
class TimePredictionEngine {
  /// 预测结果
  static TimePredictionResult predict({
    required double currentPrice,
    required double targetPrice,
    required List<Kline> klines,
    required String direction, // 'long' or 'short'
    required DateTime currentTime,
    double? volume, // 当前成交量
  }) {
    if (currentPrice <= 0 || targetPrice <= 0 || klines.length < 14) {
      return TimePredictionResult(
        mostLikely: '数据不足',
        fastest: '数据不足',
        slowest: '数据不足',
        confidence: 0,
        factors: {},
      );
    }

    // 1. 计算价格距离（百分比）
    final distance = (targetPrice - currentPrice).abs();
    final percentMove = (distance / currentPrice) * 100;

    // 2. 计算ATR（14周期平均真实波幅）
    final atr = _calculateATR(klines, 14);
    final atrPercent = (atr / currentPrice) * 100;

    // 3. 基础时间（基于ATR）
    // 假设每根1小时K线的平均波幅为ATR，计算需要多少根K线
    final baseBars = atrPercent > 0 ? percentMove / atrPercent : 0;
    final baseHours = baseBars; // 假设K线周期为1小时

    // 4. 市场状态系数
    final marketState = _calculateMarketState(klines);
    final marketStateCoeff = marketState == 'trend' ? 0.7 : 1.3;

    // 5. 成交量系数
    final volumeCoeff = _calculateVolumeCoeff(klines, volume);

    // 6. 交易时段系数
    final sessionCoeff = _calculateSessionCoeff(currentTime);
    final session = _getSession(currentTime);

    // 7. 方向系数（下跌通常更快）
    final isDown = targetPrice < currentPrice;
    final directionCoeff = isDown ? 0.8 : 1.0;

    // 8. 动量系数（当前价格向目标方向运动的速度）
    final momentumCoeff = _calculateMomentumCoeff(klines, targetPrice, currentPrice);

    // 9. 流动性系数（基于交易时段和成交量）
    final liquidityCoeff = (sessionCoeff + volumeCoeff) / 2;

    // 综合系数
    final totalCoeff = marketStateCoeff * volumeCoeff * sessionCoeff * directionCoeff * momentumCoeff;

    // 最可能时间
    final mostLikelyHours = baseHours * totalCoeff;

    // 最快时间（乐观估计，系数×0.6）
    final fastestHours = mostLikelyHours * 0.6;

    // 最慢时间（悲观估计，系数×1.8）
    final slowestHours = mostLikelyHours * 1.8;

    // 置信度（基于数据完整性和市场可预测性）
    double confidence = 60.0;
    if (klines.length >= 50) confidence += 10;
    if (atrPercent > 0.1) confidence += 5;
    if (marketState == 'trend') confidence += 10;
    if (volume != null && volume > 0) confidence += 5;
    confidence = confidence.clamp(0, 95).toDouble(); // 最高95%，不可能100%

    return TimePredictionResult(
      mostLikely: _formatTime(mostLikelyHours),
      fastest: _formatTime(fastestHours),
      slowest: _formatTime(slowestHours),
      confidence: confidence,
      factors: {
        '价格距离': '${percentMove.toStringAsFixed(2)}%',
        'ATR波动率': '${atrPercent.toStringAsFixed(3)}%/根',
        '基础K线数': '${baseBars.toStringAsFixed(1)}根',
        '市场状态': marketState == 'trend' ? '趋势市（×0.7）' : '震荡市（×1.3）',
        '成交量系数': '×${volumeCoeff.toStringAsFixed(2)}',
        '交易时段': '$session（×${sessionCoeff.toStringAsFixed(2)}）',
        '方向系数': isDown ? '下跌（×0.8）' : '上涨（×1.0）',
        '动量系数': '×${momentumCoeff.toStringAsFixed(2)}',
        '综合系数': '×${totalCoeff.toStringAsFixed(2)}',
      },
      mostLikelyHours: mostLikelyHours,
      fastestHours: fastestHours,
      slowestHours: slowestHours,
    );
  }

  /// 计算ATR（平均真实波幅）
  static double _calculateATR(List<Kline> klines, int period) {
    if (klines.length < period + 1) return 0;
    double sumTR = 0;
    for (int i = klines.length - period; i < klines.length; i++) {
      final high = klines[i].high;
      final low = klines[i].low;
      final prevClose = klines[i - 1].close;
      final tr = max(high - low, max((high - prevClose).abs(), (low - prevClose).abs()));
      sumTR += tr;
    }
    return sumTR / period;
  }

  /// 计算市场状态（趋势/震荡）
  static String _calculateMarketState(List<Kline> klines) {
    if (klines.length < 20) return 'range';
    // 基于均线排列判断趋势
    final closes = klines.map((k) => k.close).toList();
    final ma5 = closes.sublist(closes.length - 5).reduce((a, b) => a + b) / 5;
    final ma10 = closes.sublist(closes.length - 10).reduce((a, b) => a + b) / 10;
    final ma20 = closes.sublist(closes.length - 20).reduce((a, b) => a + b) / 20;

    // 均线多头或空头排列为趋势市
    if ((ma5 > ma10 && ma10 > ma20) || (ma5 < ma10 && ma10 < ma20)) {
      return 'trend';
    }
    return 'range';
  }

  /// 计算成交量系数
  static double _calculateVolumeCoeff(List<Kline> klines, double? currentVolume) {
    if (klines.length < 10 || currentVolume == null || currentVolume <= 0) return 1.0;
    final avgVolume = klines.sublist(klines.length - 10).map((k) => k.volume).reduce((a, b) => a + b) / 10;
    if (avgVolume <= 0) return 1.0;
    final ratio = currentVolume / avgVolume;
    if (ratio > 1.5) return 0.8; // 放量，到达快
    if (ratio < 0.7) return 1.2; // 缩量，到达慢
    return 1.0;
  }

  /// 计算交易时段系数
  static double _calculateSessionCoeff(DateTime time) {
    final utcHour = time.toUtc().hour;
    // 欧美重叠（13-16 UTC）波动最大
    if (utcHour >= 13 && utcHour < 16) return 0.8;
    // 美洲盘（13-22 UTC）
    if (utcHour >= 13 && utcHour < 22) return 0.9;
    // 欧洲盘（7-16 UTC）
    if (utcHour >= 7 && utcHour < 16) return 0.95;
    // 亚洲盘（0-8 UTC）波动小
    return 1.1;
  }

  /// 获取交易时段名称
  static String _getSession(DateTime time) {
    final utcHour = time.toUtc().hour;
    if (utcHour >= 13 && utcHour < 16) return '欧美重叠';
    if (utcHour >= 13 && utcHour < 22) return '美洲盘';
    if (utcHour >= 7 && utcHour < 16) return '欧洲盘';
    return '亚洲盘';
  }

  /// 计算动量系数
  static double _calculateMomentumCoeff(List<Kline> klines, double targetPrice, double currentPrice) {
    if (klines.length < 5) return 1.0;
    final isDown = targetPrice < currentPrice;
    // 最近5根K线的涨跌幅
    final recentChange = (klines.last.close - klines[klines.length - 5].close) / klines[klines.length - 5].close * 100;
    // 如果当前动量方向与目标方向一致，到达更快
    if (isDown && recentChange < 0) return 0.85; // 下跌动量，目标也是下跌
    if (!isDown && recentChange > 0) return 0.85; // 上涨动量，目标也是上涨
    // 如果动量方向相反，到达更慢
    if (isDown && recentChange > 0) return 1.15; // 上涨动量，但目标是下跌
    if (!isDown && recentChange < 0) return 1.15; // 下跌动量，但目标是上涨
    return 1.0;
  }

  /// 格式化时间
  static String _formatTime(double hours) {
    if (hours <= 0) return '立即';
    if (hours < 1 / 60) return '${(hours * 3600).toStringAsFixed(0)}秒';
    if (hours < 1) return '约${(hours * 60).toStringAsFixed(0)}分钟';
    if (hours < 24) return '约${hours.toStringAsFixed(1)}小时';
    if (hours < 24 * 7) return '约${(hours / 24).toStringAsFixed(1)}天';
    return '约${(hours / 24 / 7).toStringAsFixed(1)}周';
  }
}

/// 时间预测结果
class TimePredictionResult {
  final String mostLikely; // 最可能时间
  final String fastest; // 最快时间
  final String slowest; // 最慢时间
  final double confidence; // 置信度（0-100）
  final Map<String, String> factors; // 各因素详情
  final double mostLikelyHours;
  final double fastestHours;
  final double slowestHours;

  TimePredictionResult({
    required this.mostLikely,
    required this.fastest,
    required this.slowest,
    required this.confidence,
    required this.factors,
    this.mostLikelyHours = 0,
    this.fastestHours = 0,
    this.slowestHours = 0,
  });

  String get confidenceText => '${confidence.toStringAsFixed(0)}%';

  String get confidenceLabel {
    if (confidence >= 80) return '高置信度';
    if (confidence >= 60) return '中等置信度';
    return '低置信度';
  }
}
