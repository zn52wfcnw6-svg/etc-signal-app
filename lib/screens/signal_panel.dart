import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/signal.dart';
import '../engine/long_cycle/long_cycle_manager.dart';
import '../engine/risk/risk_manager.dart';

class SignalPanel extends StatelessWidget {
  const SignalPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        if (!app.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final signal = app.currentSignal;
        final riskLevel = app.riskState?.level ?? RiskLevel.L0;
        final longCycle = app.longCycleResult;
        final regime = app.marketRegime;
        final mtf = app.mtfResult;
        final orderFlow = app.deepOrderFlow;
        final adaptive = app.adaptiveParams;

        return RefreshIndicator(
          onRefresh: () => app.manualRefresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (signal != null && signal.status == SignalStatus.confirmed && riskLevel != RiskLevel.L3)
                _signalCard(signal, app)
              else
                _marketAnalysisCard(app, longCycle, regime, riskLevel),
              const SizedBox(height: 16),
              if (regime != null) _regimeCard(regime),
              const SizedBox(height: 16),
              if (mtf != null) _mtfCard(mtf),
              const SizedBox(height: 16),
              if (orderFlow != null) _orderFlowCard(orderFlow),
              const SizedBox(height: 16),
              if (longCycle != null) _keyLevelsCard(longCycle, app),
              const SizedBox(height: 16),
              if (adaptive != null) _adaptiveCard(adaptive),
              const SizedBox(height: 16),
              if (longCycle != null) _structureCard(longCycle),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _marketAnalysisCard(AppState app, LongCycleResult? longCycle, dynamic regime, RiskLevel riskLevel) {
    final currentPrice = app.ethPrice;
    String outlook = '数据加载中...';
    String suggestion = '正在获取K线和订单流数据，请稍候。';
    Color outlookColor = Colors.grey;

    if (longCycle != null) {
      final state = longCycle.state;
      final structure = longCycle.structure.structure;

      if (riskLevel == RiskLevel.L3) {
        outlook = '极端风险，观望';
        suggestion = '当前触发极端风险条件，禁止开仓。等待风险解除。';
        outlookColor = Colors.red;
      } else if (riskLevel == RiskLevel.L2) {
        outlook = '高危：仅逆势反转';
        suggestion = 'BTC结构破位，只允许抓顶抓底反转信号，顺势信号已屏蔽。仓位1/3。';
        outlookColor = Colors.orange;
      } else if (state == LongCycleState.supportValid) {
        outlook = '接近支撑区，关注多头';
        suggestion = '价格进入支撑带，等待流动性清扫+CVD底背离确认。';
        outlookColor = Colors.green;
      } else if (state == LongCycleState.resistanceValid) {
        outlook = '接近压力区，关注空头';
        suggestion = '价格进入压力带，等待流动性清扫+CVD顶背离确认。';
        outlookColor = Colors.red;
      } else if (state == LongCycleState.trendExhaustion) {
        outlook = '趋势衰竭，反转概率高';
        suggestion = 'OI背离+资金费率极端，密切关注订单流反转信号。';
        outlookColor = Colors.purple;
      } else {
        outlook = '中性区间，等待机会';
        suggestion = '价格远离关键位，耐心等待进入支撑/压力区。';
        outlookColor = Colors.grey;
      }

      if (structure == MarketStructure.uptrend) {
        suggestion += ' 大趋势向上。';
      } else if (structure == MarketStructure.downtrend) {
        suggestion += ' 大趋势向下。';
      }
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: outlookColor.withOpacity(0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: outlookColor, size: 24),
                const SizedBox(width: 8),
                const Text('行情预判', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: outlookColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(outlook, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: outlookColor)),
            ),
            const SizedBox(height: 12),
            Text(suggestion, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _regimeCard(dynamic regime) {
    final color = _regimeColor(regime.regime);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: color, size: 20),
                const SizedBox(width: 8),
                const Text('市场状态', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text(_regimeLabel(regime.regime), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(regime.description, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 8),
            Text('策略: ${regime.recommendedStrategy}', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip('趋势强度 ${(regime.trendStrength * 100).toStringAsFixed(0)}%'),
                const SizedBox(width: 8),
                _chip('区间 ${(regime.rangeBound * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mtfCard(dynamic mtf) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('多周期共振', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${mtf.bullishCount}多/${mtf.bearishCount}空/${mtf.neutralCount}中',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _tfColumn('1D', mtf.bias1d),
                _tfColumn('4H', mtf.bias4h),
                _tfColumn('1H', mtf.bias1h),
                _tfColumn('5m', mtf.bias5m),
                _tfColumn('1m', mtf.bias1m),
              ],
            ),
            const SizedBox(height: 12),
            Text(mtf.description, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _tfColumn(String label, dynamic bias) {
    final isBull = bias.name == 'bullish';
    final isBear = bias.name == 'bearish';
    final color = isBull ? Colors.green : (isBear ? Colors.red : Colors.grey);
    final icon = isBull ? Icons.arrow_upward : (isBear ? Icons.arrow_downward : Icons.remove);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Icon(icon, color: color, size: 20),
      ],
    );
  }

  Widget _orderFlowCard(dynamic of) {
    final biasColor = of.largeOrderBias.name == 'buy' ? Colors.green :
                      of.largeOrderBias.name == 'sell' ? Colors.red : Colors.grey;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz, size: 20, color: Colors.cyan),
                const SizedBox(width: 8),
                const Text('深度订单流', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(of.summary, style: TextStyle(fontSize: 11, color: biasColor, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _ofStat('大单买入', '${of.largeBuyCount}笔', '\$${of.largeBuyVolume.toStringAsFixed(0)}', Colors.green)),
                Expanded(child: _ofStat('大单卖出', '${of.largeSellCount}笔', '\$${of.largeSellVolume.toStringAsFixed(0)}', Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _ofStat('盘口失衡', '${(of.orderBookImbalance * 100).toStringAsFixed(1)}%', of.orderBookImbalance > 0 ? '买强' : '卖强', of.orderBookImbalance > 0 ? Colors.green : Colors.red)),
                Expanded(child: _ofStat('CVD斜率', of.cvdSlope > 0 ? '流入+' : '流出', of.cvdSlope.toStringAsFixed(2), of.cvdSlope > 0 ? Colors.green : Colors.red)),
                Expanded(child: _ofStat('成交密度', '${(of.tradeDensity * 100).toStringAsFixed(1)}%', '当前价附近', Colors.blue)),
              ],
            ),
            if (of.liquidationZones.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('清算密集区', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: of.liquidationZones.map((z) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (z.isLongLiquidation ? Colors.red : Colors.green).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${z.isLongLiquidation ? "多" : "空"}清算 \$${z.price.toStringAsFixed(0)} ${'★' * z.intensity}',
                    style: TextStyle(fontSize: 10, color: z.isLongLiquidation ? Colors.red : Colors.green),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ofStat(String label, String value, String sub, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(sub, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  Widget _keyLevelsCard(LongCycleResult longCycle, AppState app) {
    final supports = longCycle.supportLevels;
    final resistances = longCycle.resistanceLevels;
    final currentPrice = app.ethPrice;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('关键价位 & 预估开仓区', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('压力位（做空目标区）', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (resistances.isEmpty)
              const Text('计算中...', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ...resistances.take(2).map((level) => _levelRow(level.mid, level.strength, 'resistance', currentPrice)),
            const Divider(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text('当前价 \$${currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            ),
            const Divider(height: 20),
            const Text('支撑位（做多目标区）', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (supports.isEmpty)
              const Text('计算中...', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ...supports.take(2).map((level) => _levelRow(level.mid, level.strength, 'support', currentPrice)),
          ],
        ),
      ),
    );
  }

  Widget _levelRow(double price, int strength, String type, double currentPrice) {
    final color = type == 'support' ? Colors.green : Colors.red;
    final distance = currentPrice > 0 ? ((price - currentPrice).abs() / currentPrice * 100) : 0;
    final stars = '★' * strength + '☆' * (3 - strength);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(type == 'support' ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 16),
          const SizedBox(width: 6),
          Text('\$${price.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(width: 8),
          Text(stars, style: const TextStyle(fontSize: 12, color: Colors.amber)),
          const Spacer(),
          Text('${distance.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _adaptiveCard(dynamic adaptive) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 20, color: Colors.purple),
                const SizedBox(width: 8),
                const Text('自适应参数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(adaptive.volatilityLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip('盈亏比≥${adaptive.minRiskReward.toStringAsFixed(1)}'),
                const SizedBox(width: 8),
                _chip('确认${adaptive.confirmationCount}次'),
                const SizedBox(width: 8),
                _chip('BTC阈值${(adaptive.btcVolThreshold * 100).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            Text('ATR: ${(adaptive.atrPercent * 100).toStringAsFixed(2)}% | 波动比: ${adaptive.volatilityRatio.toStringAsFixed(2)}x',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _structureCard(LongCycleResult longCycle) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('市场结构', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow('长周期状态', longCycle.state.name),
            _infoRow('市场结构', longCycle.structure.structure.name),
            _infoRow('结构描述', longCycle.structure.description ?? '-'),
            _infoRow('波动率', longCycle.volatility.state),
            _infoRow('ATR', '\$${longCycle.volatility.atrValue.toStringAsFixed(3)}'),
            _infoRow('资金费率', longCycle.fundingState),
            _infoRow('OI背离', longCycle.hasOIDivergence ? '是 ⚠️' : '否'),
          ],
        ),
      ),
    );
  }

  Widget _signalCard(TradingSignal signal, AppState app) {
    final isLong = signal.direction == SignalDirection.long;
    final color = isLong ? Colors.green : Colors.red;
    final suggestedSize = app.riskManager.suggestedPositionSize(
      (signal.entryLower + signal.entryUpper) / 2,
      signal.stopLoss,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isLong ? Icons.trending_up : Icons.trending_down, color: color, size: 28),
                const SizedBox(width: 8),
                Text(isLong ? '多头候选' : '空头候选', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('置信度 ${signal.confidenceScore}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _priceRow('开仓区间', '\$${signal.entryLower.toStringAsFixed(2)} - \$${signal.entryUpper.toStringAsFixed(2)}', Colors.blue),
            _priceRow('止损 SL', '\$${signal.stopLoss.toStringAsFixed(2)}', Colors.red),
            _priceRow('止盈 TP1', '\$${signal.tp1.toStringAsFixed(2)} (减仓60%)', Colors.orange),
            _priceRow('止盈 TP2', '\$${signal.tp2.toStringAsFixed(2)} (全平)', Colors.green),
            _priceRow('盈亏比', '${signal.riskRewardRatio.toStringAsFixed(2)}:1', signal.riskRewardRatio >= 4 ? Colors.green : Colors.orange),
            const Divider(height: 24),
            _infoRow('建议仓位', '${suggestedSize.toStringAsFixed(4)} 张'),
            _infoRow('单笔风险', '1% × ${app.riskState?.positionMultiplier.toStringAsFixed(2) ?? "1.00"}'),
            _infoRow('市场环境', '${signal.marketRegime} / ${signal.volatilityState}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.check),
                    label: const Text('已执行'),
                    onPressed: () => app.markSignalExecuted(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
                    icon: const Icon(Icons.close),
                    label: const Text('忽略'),
                    onPressed: () => app.markSignalExecuted(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }

  Color _regimeColor(dynamic regime) {
    switch (regime.name) {
      case 'trendingUp': return Colors.green;
      case 'trendingDown': return Colors.red;
      case 'ranging': return Colors.grey;
      case 'extreme': return Colors.deepOrange;
      case 'preBreakout': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _regimeLabel(dynamic regime) {
    switch (regime.name) {
      case 'trendingUp': return '上升趋势';
      case 'trendingDown': return '下降趋势';
      case 'ranging': return '震荡';
      case 'extreme': return '极端';
      case 'preBreakout': return '变盘前夜';
      default: return regime.name;
    }
  }
}
