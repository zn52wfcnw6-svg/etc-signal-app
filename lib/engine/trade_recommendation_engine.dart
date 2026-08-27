import '../models/market_data.dart';
import '../models/trade_recommendation.dart';
import '../models/signal.dart';
import '../utils/constants.dart';
import '../engine/long_cycle/long_cycle_manager.dart';
import '../engine/order_flow/deep_order_flow.dart';

/// 推单推荐引擎
/// 基于关键价位、市场结构、订单流生成推荐交易区域
class TradeRecommendationEngine {
  /// 生成推单推荐
  static TradeRecommendation generate({
    required double currentPrice,
    required LongCycleResult? longCycle,
    required DeepOrderFlowResult? orderFlow,
    required int riskLevel,
    TradingSignal? confirmedSignal,
  }) {
    // 如果有确认信号，直接使用
    if (confirmedSignal != null) {
      return _fromConfirmedSignal(confirmedSignal, riskLevel);
    }

    // 没有确认信号时，基于关键价位生成候选推单
    if (currentPrice <= 0) {
      return TradeRecommendation.wait('行情数据加载中');
    }

    final supports = longCycle?.supportLevels ?? [];
    final resistances = longCycle?.resistanceLevels ?? [];

    if (supports.isEmpty && resistances.isEmpty) {
      return TradeRecommendation.wait('关键价位计算中');
    }

    // 找最近的支撑位和压力位
    final nearestSupport = supports.isNotEmpty
        ? supports.reduce((a, b) =>
            (currentPrice - a.mid).abs() < (currentPrice - b.mid).abs() ? a : b)
        : null;
    final nearestResistance = resistances.isNotEmpty
        ? resistances.reduce((a, b) =>
            (a.mid - currentPrice).abs() < (b.mid - currentPrice).abs() ? a : b)
        : null;

    // 计算距离百分比
    final supportDist = nearestSupport != null
        ? (currentPrice - nearestSupport.mid) / currentPrice
        : double.infinity;
    final resistanceDist = nearestResistance != null
        ? (nearestResistance.mid - currentPrice) / currentPrice
        : double.infinity;

    // 接近压力位 → 候选做空
    if (nearestResistance != null && resistanceDist < 0.02 && resistanceDist < supportDist) {
      return _generateShortRecommendation(
        currentPrice: currentPrice,
        entryZone: nearestResistance.mid,
        targetSupport: nearestSupport?.mid ?? currentPrice * 0.95,
        orderFlow: orderFlow,
        riskLevel: riskLevel,
      );
    }

    // 接近支撑位 → 候选做多
    if (nearestSupport != null && supportDist < 0.02 && supportDist < resistanceDist) {
      return _generateLongRecommendation(
        currentPrice: currentPrice,
        entryZone: nearestSupport.mid,
        targetResistance: nearestResistance?.mid ?? currentPrice * 1.05,
        orderFlow: orderFlow,
        riskLevel: riskLevel,
      );
    }

    // 在中间位置 → 观望，但给出等待的价位
    final waitReason = StringBuffer('价格在区间中部，等待');
    if (nearestResistance != null) {
      waitReason.write('压力位\$${nearestResistance.mid.toStringAsFixed(0)}做空');
    }
    if (nearestSupport != null) {
      if (nearestResistance != null) waitReason.write('或');
      waitReason.write('支撑位\$${nearestSupport.mid.toStringAsFixed(0)}做多');
    }
    return TradeRecommendation.wait(waitReason.toString());
  }

  /// 从确认信号生成推单
  static TradeRecommendation _fromConfirmedSignal(TradingSignal signal, int riskLevel) {
    final positionSize = riskLevel >= 2 ? 0.33 : 1.0;
    final entryPrice = (signal.entryLower + signal.entryUpper) / 2;
    final risk = (entryPrice - signal.stopLoss).abs();
    final reward1 = (signal.tp1 - entryPrice).abs();
    final rr = risk > 0 ? reward1 / risk : 0.0;

    return TradeRecommendation(
      direction: signal.direction == SignalDirection.long
          ? TradeRecommendationDirection.long
          : TradeRecommendationDirection.short,
      entryLower: signal.entryLower,
      entryUpper: signal.entryUpper,
      stopLoss: signal.stopLoss,
      tp1: signal.tp1,
      tp2: signal.tp2,
      riskRewardRatio: rr,
      positionSize: positionSize,
      triggerCondition: '信号已确认，可立即执行',
      reason: '${signal.direction == SignalDirection.long ? "多头" : "空头"}信号确认，置信度${signal.confidenceScore}/100',
      isConfirmed: true,
    );
  }

  /// 生成做多推荐
  static TradeRecommendation _generateLongRecommendation({
    required double currentPrice,
    required double entryZone,
    required double targetResistance,
    required DeepOrderFlowResult? orderFlow,
    required int riskLevel,
  }) {
    final entryLower = entryZone * 0.995;
    final entryUpper = entryZone * 1.005;
    final entryPrice = (entryLower + entryUpper) / 2;
    // 止损在支撑位下方1.5%
    final stopLoss = entryZone * 0.985;
    // TP1在第一压力位（当前价和目标压力位的中间）
    final tp1 = entryPrice + (targetResistance - entryPrice) * 0.5;
    // TP2在目标压力位
    final tp2 = targetResistance;

    final risk = entryPrice - stopLoss;
    final reward = tp2 - entryPrice;
    final rr = risk > 0 ? reward / risk : 0.0;

    final positionSize = riskLevel >= 2 ? 0.33 : 0.5;

    String reason = '价格接近支撑位\$${entryZone.toStringAsFixed(0)}，抓底做多';
    if (orderFlow != null) {
      if (orderFlow.orderBook.bidHeavy) reason += '，买盘较重';
      if (orderFlow.volumeDensity.isSupport) reason += '，成交密集区支撑';
    }

    return TradeRecommendation(
      direction: TradeRecommendationDirection.long,
      entryLower: entryLower,
      entryUpper: entryUpper,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      riskRewardRatio: rr,
      positionSize: positionSize,
      triggerCondition: '价格回落至\$${entryLower.toStringAsFixed(0)}-\$${entryUpper.toStringAsFixed(0)}区间，且出现止跌信号',
      reason: reason,
    );
  }

  /// 生成做空推荐
  static TradeRecommendation _generateShortRecommendation({
    required double currentPrice,
    required double entryZone,
    required double targetSupport,
    required DeepOrderFlowResult? orderFlow,
    required int riskLevel,
  }) {
    final entryLower = entryZone * 0.995;
    final entryUpper = entryZone * 1.005;
    final entryPrice = (entryLower + entryUpper) / 2;
    // 止损在压力位上方1.5%
    final stopLoss = entryZone * 1.015;
    // TP1在第一支撑位（当前价和目标支撑位的中间）
    final tp1 = entryPrice - (entryPrice - targetSupport) * 0.5;
    // TP2在目标支撑位
    final tp2 = targetSupport;

    final risk = stopLoss - entryPrice;
    final reward = entryPrice - tp2;
    final rr = risk > 0 ? reward / risk : 0.0;

    final positionSize = riskLevel >= 2 ? 0.33 : 0.5;

    String reason = '价格接近压力位\$${entryZone.toStringAsFixed(0)}，抓顶做空';
    if (orderFlow != null) {
      if (orderFlow.orderBook.askHeavy) reason += '，卖盘较重';
      if (orderFlow.volumeDensity.isResistance) reason += '，成交密集区压力';
    }

    return TradeRecommendation(
      direction: TradeRecommendationDirection.short,
      entryLower: entryLower,
      entryUpper: entryUpper,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      riskRewardRatio: rr,
      positionSize: positionSize,
      triggerCondition: '价格反弹至\$${entryLower.toStringAsFixed(0)}-\$${entryUpper.toStringAsFixed(0)}区间，且出现滞涨信号',
      reason: reason,
    );
  }
}
