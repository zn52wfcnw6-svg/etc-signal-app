import '../../models/market_data.dart';
import '../../utils/constants.dart';
import '../../utils/indicators.dart';
import '../../data/websocket_manager.dart';
import '../long_cycle/long_cycle_manager.dart';
import '../long_cycle/volatility_oi.dart';

/// 确认链检测结果
class ConfirmationResult {
  final bool allPassed;
  final Map<String, bool> gates;
  final String? failedGate;
  final double? entryLower;
  final double? entryUpper;
  final double? stopLoss;
  final double? tp1;
  final double? tp2;
  final Map<String, int>? confidenceBreakdown;
  final int? confidenceScore;

  ConfirmationResult({
    required this.allPassed,
    required this.gates,
    this.failedGate,
    this.entryLower,
    this.entryUpper,
    this.stopLoss,
    this.tp1,
    this.tp2,
    this.confidenceBreakdown,
    this.confidenceScore,
  });
}

/// 短周期信号检测器：六闸门确认链
class SignalDetector {
  final OrderFlowManager _orderFlow;

  SignalDetector(this._orderFlow);

  /// 检测多头候选（抓底）
  ConfirmationResult detectLong(LongCycleResult longCycle, List<Kline> eth1m, List<Kline> eth5m) {
    final gates = <String, bool>{};
    final currentPrice = longCycle.currentPrice;
    final support = longCycle.nearestSupport;

    // G1: 价格在支撑带内
    gates['G1_position'] = support != null && support.contains(currentPrice);
    if (!gates['G1_position']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G1_position');
    }

    // G2: 流动性清扫（下影线刺穿支撑带下沿后收回）
    gates['G2_liquidity_sweep'] = _checkLiquiditySweep(eth5m, support!, isLong: true);
    if (!gates['G2_liquidity_sweep']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G2_liquidity_sweep');
    }

    // G3: CVD底背离
    gates['G3_cvd_divergence'] = _orderFlow.checkCVDBullishDivergence(eth5m);
    if (!gates['G3_cvd_divergence']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G3_cvd_divergence');
    }

    // G4: Delta反转（卖盘衰竭，买盘介入）
    gates['G4_delta_reversal'] = _orderFlow.checkDeltaReversal(eth1m, bullish: true);
    if (!gates['G4_delta_reversal']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G4_delta_reversal');
    }

    // G5: K线反转形态
    gates['G5_pattern'] = _checkBullishPattern(eth1m);
    if (!gates['G5_pattern']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G5_pattern');
    }

    // G6由外部轮询确认机制处理，这里先标记
    gates['G6_poll_confirm'] = true; // 占位，由SignalEngine管理连续确认

    // 计算点位
    final sweepLow = _findSweepLow(eth5m, support);
    final atrBuf = VolatilityAnalyzer.atrBuffer(eth5m);
    final stopLoss = sweepLow - atrBuf;
    final entryLower = support.lower;
    final entryUpper = support.mid;
    final entryMid = (entryLower + entryUpper) / 2;
    final risk = entryMid - stopLoss;

    // TP1: 盈亏比2:1
    final tp1 = entryMid + risk * 2;
    // TP2: 下一个压力位
    final resistance = longCycle.nearestResistance;
    final tp2 = resistance != null ? resistance.mid : entryMid + risk * 4;

    // 盈亏比检查
    final rr = (tp2 - entryMid) / risk;
    if (rr < AppConstants.minRiskRewardRatio) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'risk_reward_too_low');
    }

    // 置信度评分
    final breakdown = _calcConfidence(
      longCycle: longCycle,
      support: support,
      eth1m: eth1m,
      eth5m: eth5m,
      isLong: true,
    );
    final score = breakdown.values.reduce((a, b) => a + b);

    return ConfirmationResult(
      allPassed: true,
      gates: gates,
      entryLower: entryLower,
      entryUpper: entryUpper,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      confidenceBreakdown: breakdown,
      confidenceScore: score,
    );
  }

  /// 检测空头候选（抓顶）
  ConfirmationResult detectShort(LongCycleResult longCycle, List<Kline> eth1m, List<Kline> eth5m) {
    final gates = <String, bool>{};
    final currentPrice = longCycle.currentPrice;
    final resistance = longCycle.nearestResistance;

    gates['G1_position'] = resistance != null && resistance.contains(currentPrice);
    if (!gates['G1_position']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G1_position');
    }

    gates['G2_liquidity_sweep'] = _checkLiquiditySweep(eth5m, resistance!, isLong: false);
    if (!gates['G2_liquidity_sweep']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G2_liquidity_sweep');
    }

    gates['G3_cvd_divergence'] = _orderFlow.checkCVDBearishDivergence(eth5m);
    if (!gates['G3_cvd_divergence']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G3_cvd_divergence');
    }

    gates['G4_delta_reversal'] = _orderFlow.checkDeltaReversal(eth1m, bullish: false);
    if (!gates['G4_delta_reversal']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G4_delta_reversal');
    }

    gates['G5_pattern'] = _checkBearishPattern(eth1m);
    if (!gates['G5_pattern']!) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'G5_pattern');
    }

    gates['G6_poll_confirm'] = true;

    final sweepHigh = _findSweepHigh(eth5m, resistance);
    final atrBuf = VolatilityAnalyzer.atrBuffer(eth5m);
    final stopLoss = sweepHigh + atrBuf;
    final entryLower = resistance.mid;
    final entryUpper = resistance.upper;
    final entryMid = (entryLower + entryUpper) / 2;
    final risk = stopLoss - entryMid;

    final tp1 = entryMid - risk * 2;
    final support = longCycle.nearestSupport;
    final tp2 = support != null ? support.mid : entryMid - risk * 4;

    final rr = (entryMid - tp2) / risk;
    if (rr < AppConstants.minRiskRewardRatio) {
      return ConfirmationResult(allPassed: false, gates: gates, failedGate: 'risk_reward_too_low');
    }

    final breakdown = _calcConfidence(
      longCycle: longCycle,
      support: resistance,
      eth1m: eth1m,
      eth5m: eth5m,
      isLong: false,
    );
    final score = breakdown.values.reduce((a, b) => a + b);

    return ConfirmationResult(
      allPassed: true,
      gates: gates,
      entryLower: entryLower,
      entryUpper: entryUpper,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      confidenceBreakdown: breakdown,
      confidenceScore: score,
    );
  }

  // G2: 流动性清扫检测
  bool _checkLiquiditySweep(List<Kline> klines, KeyLevel level, {required bool isLong}) {
    if (klines.length < 5) return false;
    final recent = klines.sublist(klines.length - 5);
    for (final k in recent) {
      if (isLong) {
        // 下影线刺穿支撑带下沿，收盘价回到支撑带内
        if (k.low < level.lower && k.close >= level.lower && k.close <= level.upper * 1.01) {
          return true;
        }
      } else {
        if (k.high > level.upper && k.close <= level.upper && k.close >= level.lower * 0.99) {
          return true;
        }
      }
    }
    return false;
  }

  double _findSweepLow(List<Kline> klines, KeyLevel level) {
    double lowest = level.lower;
    for (final k in klines.sublist(klines.length > 10 ? klines.length - 10 : 0)) {
      if (k.low < level.lower && k.low < lowest) lowest = k.low;
    }
    return lowest;
  }

  double _findSweepHigh(List<Kline> klines, KeyLevel level) {
    double highest = level.upper;
    for (final k in klines.sublist(klines.length > 10 ? klines.length - 10 : 0)) {
      if (k.high > level.upper && k.high > highest) highest = k.high;
    }
    return highest;
  }

  // G5: 看涨形态
  bool _checkBullishPattern(List<Kline> klines) {
    if (klines.length < 3) return false;
    final last = klines.last;
    final prev = klines[klines.length - 2];

    // Pin bar
    if (last.isPinBar(ratio: AppConstants.pinBarWickRatio) && last.lowerWick > last.upperWick) {
      return true;
    }
    // 看涨吞没
    if (last.isBullishEngulfing(prev)) return true;
    // FVG回补后反弹
    final fvg = Indicators.detectFVG(klines);
    if (fvg != null && fvg['type'] == 1 && last.close > fvg['upper']!) return true;

    return false;
  }

  // G5: 看跌形态
  bool _checkBearishPattern(List<Kline> klines) {
    if (klines.length < 3) return false;
    final last = klines.last;
    final prev = klines[klines.length - 2];

    if (last.isPinBar(ratio: AppConstants.pinBarWickRatio) && last.upperWick > last.lowerWick) {
      return true;
    }
    if (last.isBearishEngulfing(prev)) return true;
    final fvg = Indicators.detectFVG(klines);
    if (fvg != null && fvg['type'] == -1 && last.close < fvg['lower']!) return true;

    return false;
  }

  /// 置信度评分
  Map<String, int> _calcConfidence({
    required LongCycleResult longCycle,
    required KeyLevel support,
    required List<Kline> eth1m,
    required List<Kline> eth5m,
    required bool isLong,
  }) {
    final breakdown = <String, int>{};

    // 关键位强度 (0-30)
    int levelScore = 0;
    switch (support.strength) {
      case 3: levelScore = 30; break;
      case 2: levelScore = 20; break;
      default: levelScore = 10;
    }
    if (support.hasLiquidityPool) levelScore += 5;
    breakdown['key_level'] = levelScore.clamp(0, 30);

    // 订单流强度 (0-30)
    final bars = _orderFlow.getRecentBars(10);
    int ofScore = 15;
    if (bars.length >= 5) {
      final deltas = bars.map((b) => b.delta).toList();
      final avgDelta = deltas.reduce((a, b) => a + b) / deltas.length;
      if (isLong && avgDelta > 0) ofScore = 25;
      if (!isLong && avgDelta < 0) ofScore = 25;
    }
    breakdown['order_flow'] = ofScore;

    // 多周期共振 (0-20)
    int resonanceScore = 10;
    // 1m和5m都在关键位附近
    final price1m = eth1m.isNotEmpty ? eth1m.last.close.toDouble() : 0.0;
    final price5m = eth5m.isNotEmpty ? eth5m.last.close.toDouble() : 0.0;
    if (support.contains(price1m) && support.contains(price5m)) {
      resonanceScore = 20;
    }
    breakdown['multi_timeframe'] = resonanceScore;

    // 环境清洁度 (0-20)
    int envScore = 0;
    final funding = longCycle.fundingState;
    if ((isLong && (funding == 'extreme_short' || funding == 'crowded_short')) ||
        (!isLong && (funding == 'extreme_long' || funding == 'crowded_long'))) {
      envScore += 10; // 资金费率配合
    }
    if (longCycle.volatility.state == 'normal') envScore += 10;
    breakdown['environment'] = envScore;

    return breakdown;
  }
}
