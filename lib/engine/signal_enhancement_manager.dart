import 'dart:async';
import '../models/market_data.dart';
import '../engine/signal_history_tracker.dart';

/// 推单区增强管理器
/// 整合：执行跟踪、历史统计、技术面深度分析、订单流深度分析、风险管理、时间因素
class SignalEnhancementManager {
  // ========== 1. 信号执行跟踪 ==========
  SignalExecution? _currentExecution;
  SignalExecution? get currentExecution => _currentExecution;

  void startExecution({
    required String direction,
    required double entryPrice,
    required double sl,
    required double tp1,
    required double tp2,
    required double size,
  }) {
    _currentExecution = SignalExecution(
      direction: direction,
      entryPrice: entryPrice,
      sl: sl,
      tp1: tp1,
      tp2: tp2,
      size: size,
      startTime: DateTime.now(),
      status: ExecutionStatus.waiting,
    );
  }

  void updateExecutionPrice(double currentPrice) {
    if (_currentExecution == null) return;
    _currentExecution!.currentPrice = currentPrice;
    _currentExecution!.updateStatus();
  }

  void closeExecution() {
    _currentExecution = null;
  }

  // ========== 2. 信号历史统计 ==========
  final SignalHistoryTracker _historyTracker = SignalHistoryTracker();
  SignalHistoryTracker get historyTracker => _historyTracker;

  void recordSignal({
    required String direction,
    required double entryPrice,
    required double sl,
    required double tp1,
    required double tp2,
    required double score,
  }) {
    _historyTracker.addSignal(SignalRecord(
      direction: direction,
      entryPrice: entryPrice,
      sl: sl,
      tp1: tp1,
      tp2: tp2,
      score: score,
      timestamp: DateTime.now(),
    ));
  }

  SignalStats getHistoryStats() => _historyTracker.getStats();

  // ========== 3. 技术面深度分析 ==========
  TechnicalDeepAnalysis analyzeTechnical({
    required List<Kline> klines,
    required String direction,
  }) {
    if (klines.length < 30) {
      return TechnicalDeepAnalysis(
        pattern: '数据不足',
        rsi: 50,
        macdStatus: '中性',
        bollingerPosition: '中性',
        mtfResonance: 0,
        liquiditySweep: false,
        overallBias: 'neutral',
      );
    }

    // RSI计算（14周期）
    final rsi = _calculateRSI(klines, 14);

    // MACD状态
    final macdStatus = _calculateMACDStatus(klines);

    // 布林带位置
    final bollingerPos = _calculateBollingerPosition(klines);

    // K线形态识别
    final pattern = _identifyPattern(klines);

    // 流动性清扫检测（最近3根K线是否有长影线扫过前高/前低）
    final liquiditySweep = _detectLiquiditySweep(klines);

    // 多周期共振（简化：基于不同周期均线方向）
    final mtfResonance = _calculateMTFResonance(klines);

    // 综合偏向
    String overallBias = 'neutral';
    int bullish = 0, bearish = 0;
    if (rsi < 30) bullish++;
    if (rsi > 70) bearish++;
    if (macdStatus.contains('金叉') || macdStatus.contains('多头')) bullish++;
    if (macdStatus.contains('死叉') || macdStatus.contains('空头')) bearish++;
    if (bollingerPos == '下轨') bullish++;
    if (bollingerPos == '上轨') bearish++;
    if (bullish > bearish) overallBias = 'bullish';
    else if (bearish > bullish) overallBias = 'bearish';

    return TechnicalDeepAnalysis(
      pattern: pattern,
      rsi: rsi,
      macdStatus: macdStatus,
      bollingerPosition: bollingerPos,
      mtfResonance: mtfResonance,
      liquiditySweep: liquiditySweep,
      overallBias: overallBias,
    );
  }

  double _calculateRSI(List<Kline> klines, int period) {
    if (klines.length < period + 1) return 50;
    double gains = 0, losses = 0;
    for (int i = klines.length - period; i < klines.length; i++) {
      final change = klines[i].close - klines[i - 1].close;
      if (change > 0) gains += change;
      else losses -= change;
    }
    if (losses == 0) return 100;
    final rs = gains / losses;
    return 100 - (100 / (1 + rs));
  }

  String _calculateMACDStatus(List<Kline> klines) {
    if (klines.length < 26) return '数据不足';
    final ema12 = _calculateEMA(klines, 12);
    final ema26 = _calculateEMA(klines, 26);
    final macd = ema12 - ema26;
    final signal = macd * 0.2 + (ema12 - ema26) * 0.8; // 简化
    if (macd > signal && macd > 0) return '多头金叉';
    if (macd > signal && macd < 0) return '底部金叉';
    if (macd < signal && macd < 0) return '空头死叉';
    if (macd < signal && macd > 0) return '顶部死叉';
    return '中性';
  }

  double _calculateEMA(List<Kline> klines, int period) {
    if (klines.length < period) return klines.last.close;
    double ema = klines.sublist(0, period).map((k) => k.close).reduce((a, b) => a + b) / period;
    final multiplier = 2 / (period + 1);
    for (int i = period; i < klines.length; i++) {
      ema = (klines[i].close - ema) * multiplier + ema;
    }
    return ema;
  }

  String _calculateBollingerPosition(List<Kline> klines) {
    if (klines.length < 20) return '数据不足';
    final closes = klines.sublist(klines.length - 20).map((k) => k.close).toList();
    final mean = closes.reduce((a, b) => a + b) / 20;
    final variance = closes.map((c) => (c - mean) * (c - mean)).reduce((a, b) => a + b) / 20;
    final stdDev = variance.sqrt();
    final upper = mean + 2 * stdDev;
    final lower = mean - 2 * stdDev;
    final current = klines.last.close;
    if (current > upper) return '上轨上方（超买）';
    if (current > mean) return '上轨';
    if (current < lower) return '下轨下方（超卖）';
    if (current < mean) return '下轨';
    return '中轨';
  }

  String _identifyPattern(List<Kline> klines) {
    if (klines.length < 3) return '数据不足';
    final last = klines.last;
    final prev = klines[klines.length - 2];
    final body = (last.close - last.open).abs();
    final upperWick = last.high - (last.close > last.open ? last.close : last.open);
    final lowerWick = (last.close > last.open ? last.open : last.close) - last.low;
    final range = last.high - last.low;

    if (range == 0) return '无明显形态';

    // 锤子线（下影线长，实体小，在底部）
    if (lowerWick > body * 2 && upperWick < body * 0.5 && last.close > last.open) {
      return '锤子线（看涨反转）';
    }
    // 射击之星（上影线长，实体小，在顶部）
    if (upperWick > body * 2 && lowerWick < body * 0.5 && last.close < last.open) {
      return '射击之星（看跌反转）';
    }
    // 看涨吞没
    if (prev.close < prev.open && last.close > last.open && last.close > prev.open && last.open < prev.close) {
      return '看涨吞没（强势反转）';
    }
    // 看跌吞没
    if (prev.close > prev.open && last.close < last.open && last.close < prev.open && last.open > prev.close) {
      return '看跌吞没（强势反转）';
    }
    // Pin Bar
    if (upperWick > body * 2.5 || lowerWick > body * 2.5) {
      return 'Pin Bar（关键反转）';
    }
    // 大阳线
    if (body > range * 0.7 && last.close > last.open) {
      return '大阳线（强势多头）';
    }
    // 大阴线
    if (body > range * 0.7 && last.close < last.open) {
      return '大阴线（强势空头）';
    }
    return '无明显形态';
  }

  bool _detectLiquiditySweep(List<Kline> klines) {
    if (klines.length < 5) return false;
    final last = klines.last;
    final prevHigh = klines.sublist(klines.length - 5, klines.length - 1).map((k) => k.high).reduce((a, b) => a > b ? a : b);
    final prevLow = klines.sublist(klines.length - 5, klines.length - 1).map((k) => k.low).reduce((a, b) => a < b ? a : b);
    // 扫过前高后回落，或扫过前低后反弹
    if (last.high > prevHigh && last.close < prevHigh) return true;
    if (last.low < prevLow && last.close > prevLow) return true;
    return false;
  }

  int _calculateMTFResonance(List<Kline> klines) {
    if (klines.length < 50) return 0;
    int resonance = 0;
    // 短期均线（5）方向
    final ma5 = klines.sublist(klines.length - 5).map((k) => k.close).reduce((a, b) => a + b) / 5;
    final ma5Prev = klines.sublist(klines.length - 10, klines.length - 5).map((k) => k.close).reduce((a, b) => a + b) / 5;
    if (ma5 > ma5Prev) resonance++;
    // 中期均线（20）方向
    final ma20 = klines.sublist(klines.length - 20).map((k) => k.close).reduce((a, b) => a + b) / 20;
    final ma20Prev = klines.sublist(klines.length - 40, klines.length - 20).map((k) => k.close).reduce((a, b) => a + b) / 20;
    if (ma20 > ma20Prev) resonance++;
    // 价格在均线上方
    if (klines.last.close > ma5) resonance++;
    if (klines.last.close > ma20) resonance++;
    return resonance;
  }

  // ========== 4. 订单流深度分析 ==========
  OrderflowDeepAnalysis analyzeOrderflow({
    required double cvd,
    required double delta,
    required String bigOrderDirection,
    required double liquidationRisk,
    required double volumeProfile,
  }) {
    return OrderflowDeepAnalysis(
      cvd: cvd,
      cvdTrend: cvd > 0 ? '多头累积' : cvd < 0 ? '空头累积' : '均衡',
      delta: delta,
      deltaPressure: delta > 0 ? '买压强' : delta < 0 ? '卖压强' : '均衡',
      bigOrderDirection: bigOrderDirection,
      liquidationRisk: liquidationRisk,
      liquidationZone: liquidationRisk > 0.5 ? '上方清算密集' : liquidationRisk < -0.5 ? '下方清算密集' : '无明显挤压',
      volumeProfile: volumeProfile,
    );
  }

  // ========== 5. 风险管理计算器 ==========
  RiskCalculation calculateRisk({
    required double accountBalance,
    required double entryPrice,
    required double sl,
    required double tp1,
    required double tp2,
    double riskPercent = 1.0,
  }) {
    final riskAmount = accountBalance * (riskPercent / 100);
    final riskDistance = (entryPrice - sl).abs();
    final positionSize = riskDistance > 0 ? riskAmount / riskDistance : 0;
    final rr1 = riskDistance > 0 ? (tp1 - entryPrice).abs() / riskDistance : 0;
    final rr2 = riskDistance > 0 ? (tp2 - entryPrice).abs() / riskDistance : 0;

    return RiskCalculation(
      accountBalance: accountBalance,
      riskAmount: riskAmount,
      riskPercent: riskPercent,
      positionSize: positionSize,
      entryPrice: entryPrice,
      sl: sl,
      tp1: tp1,
      tp2: tp2,
      rr1: rr1,
      rr2: rr2,
      batch1Size: positionSize * 0.4,
      batch2Size: positionSize * 0.3,
      batch3Size: positionSize * 0.3,
    );
  }

  // ========== 6. 时间因素管理器 ==========
  TimeFactor getTimeFactor({
    required DateTime signalTime,
    required int pollIntervalSeconds,
  }) {
    final now = DateTime.now();
    final elapsed = now.difference(signalTime).inSeconds;
    final remaining = pollIntervalSeconds - elapsed;

    // 交易时段判断（基于UTC时间简化）
    final utcHour = now.toUtc().hour;
    String session = '亚洲盘';
    if (utcHour >= 7 && utcHour < 16) session = '欧洲盘';
    if (utcHour >= 13 && utcHour < 22) session = '美洲盘';
    if (utcHour >= 13 && utcHour < 16) session = '欧美重叠（高波动）';

    return TimeFactor(
      signalTime: signalTime,
      elapsedSeconds: elapsed,
      remainingSeconds: remaining.clamp(0, pollIntervalSeconds),
      session: session,
      isHighVolatility: session.contains('重叠'),
    );
  }

  void dispose() {
    _currentExecution = null;
  }
}

// ========== 数据模型 ==========

enum ExecutionStatus { waiting, entered, tp1Hit, closed, stopped }

class SignalExecution {
  final String direction;
  final double entryPrice;
  final double sl;
  final double tp1;
  final double tp2;
  final double size;
  final DateTime startTime;
  double currentPrice;
  ExecutionStatus status;

  SignalExecution({
    required this.direction,
    required this.entryPrice,
    required this.sl,
    required this.tp1,
    required this.tp2,
    required this.size,
    required this.startTime,
    this.currentPrice = 0,
    this.status = ExecutionStatus.waiting,
  });

  double get pnlPercent {
    if (currentPrice == 0) return 0;
    final diff = direction == 'long'
        ? currentPrice - entryPrice
        : entryPrice - currentPrice;
    return (diff / entryPrice) * 100;
  }

  String get pnlText => '${pnlPercent >= 0 ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%';

  Duration get holdingDuration => DateTime.now().difference(startTime);

  String get holdingTimeText {
    final d = holdingDuration;
    if (d.inHours > 0) return '${d.inHours}h${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  void updateStatus() {
    if (currentPrice == 0) return;
    if (direction == 'long') {
      if (currentPrice <= sl) status = ExecutionStatus.stopped;
      else if (currentPrice >= tp1) status = ExecutionStatus.tp1Hit;
      else if (currentPrice >= entryPrice) status = ExecutionStatus.entered;
    } else {
      if (currentPrice >= sl) status = ExecutionStatus.stopped;
      else if (currentPrice <= tp1) status = ExecutionStatus.tp1Hit;
      else if (currentPrice <= entryPrice) status = ExecutionStatus.entered;
    }
  }

  String get statusText {
    switch (status) {
      case ExecutionStatus.waiting: return '等待入场';
      case ExecutionStatus.entered: return '已入场';
      case ExecutionStatus.tp1Hit: return 'TP1已触及';
      case ExecutionStatus.closed: return '已平仓';
      case ExecutionStatus.stopped: return '止损离场';
    }
  }
}

class TechnicalDeepAnalysis {
  final String pattern;
  final double rsi;
  final String macdStatus;
  final String bollingerPosition;
  final int mtfResonance;
  final bool liquiditySweep;
  final String overallBias;

  TechnicalDeepAnalysis({
    required this.pattern,
    required this.rsi,
    required this.macdStatus,
    required this.bollingerPosition,
    required this.mtfResonance,
    required this.liquiditySweep,
    required this.overallBias,
  });

  String get rsiStatus {
    if (rsi >= 70) return '超买（看空）';
    if (rsi <= 30) return '超卖（看涨）';
    if (rsi >= 55) return '偏强';
    if (rsi <= 45) return '偏弱';
    return '中性';
  }

  String get mtfText {
    if (mtfResonance >= 3) return '强共振（$mtfResonance/4）';
    if (mtfResonance >= 2) return '中等共振（$mtfResonance/4）';
    return '弱共振（$mtfResonance/4）';
  }
}

class OrderflowDeepAnalysis {
  final double cvd;
  final String cvdTrend;
  final double delta;
  final String deltaPressure;
  final String bigOrderDirection;
  final double liquidationRisk;
  final String liquidationZone;
  final double volumeProfile;

  OrderflowDeepAnalysis({
    required this.cvd,
    required this.cvdTrend,
    required this.delta,
    required this.deltaPressure,
    required this.bigOrderDirection,
    required this.liquidationRisk,
    required this.liquidationZone,
    required this.volumeProfile,
  });
}

class RiskCalculation {
  final double accountBalance;
  final double riskAmount;
  final double riskPercent;
  final double positionSize;
  final double entryPrice;
  final double sl;
  final double tp1;
  final double tp2;
  final double rr1;
  final double rr2;
  final double batch1Size;
  final double batch2Size;
  final double batch3Size;

  RiskCalculation({
    required this.accountBalance,
    required this.riskAmount,
    required this.riskPercent,
    required this.positionSize,
    required this.entryPrice,
    required this.sl,
    required this.tp1,
    required this.tp2,
    required this.rr1,
    required this.rr2,
    required this.batch1Size,
    required this.batch2Size,
    required this.batch3Size,
  });
}

class TimeFactor {
  final DateTime signalTime;
  final int elapsedSeconds;
  final int remainingSeconds;
  final String session;
  final bool isHighVolatility;

  TimeFactor({
    required this.signalTime,
    required this.elapsedSeconds,
    required this.remainingSeconds,
    required this.session,
    required this.isHighVolatility,
  });

  String get elapsedText {
    if (elapsedSeconds >= 3600) return '${elapsedSeconds ~/ 3600}h${(elapsedSeconds % 3600) ~/ 60}m';
    if (elapsedSeconds >= 60) return '${elapsedSeconds ~/ 60}m${elapsedSeconds % 60}s';
    return '${elapsedSeconds}s';
  }
}
