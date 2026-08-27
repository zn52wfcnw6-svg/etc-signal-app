import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/signal.dart';
import '../utils/constants.dart';
import '../engine/long_cycle/long_cycle_manager.dart';
import '../engine/risk/risk_manager.dart';
import '../models/trade_recommendation.dart';

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
        final isFrozen = riskLevel == RiskLevel.L3;
        final longCycle = app.longCycleResult;
        final currentPrice = app.ethPrice;

        return RefreshIndicator(
          onRefresh: () => app.manualRefresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 状态卡片
              _buildStatusCard(app, riskLevel, longCycle, currentPrice),
              const SizedBox(height: 16),
              // 信号或市场分析
              if (signal != null && signal.status == SignalStatus.confirmed && !isFrozen)
                _buildSignalCard(signal, app)
              else
                _buildMarketAnalysisCard(app, longCycle, riskLevel, currentPrice),
              const SizedBox(height: 16),
              // 推单区
              _buildTradeRecommendationCard(app),
              const SizedBox(height: 16),
              // 关键价位
              if (longCycle != null)
                _buildKeyLevelsCard(longCycle, currentPrice),
              const SizedBox(height: 16),
              // 市场结构
              _buildMarketInfoCard(app, longCycle),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(AppState app, RiskLevel riskLevel, LongCycleResult? longCycle, double currentPrice) {
    final color = _riskColor(riskLevel);
    final regime = app.marketRegime;
    final mtf = app.mtfResult;

    return Card(
      elevation: 2,
      color: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: color, size: 20),
                const SizedBox(width: 8),
                Text('风险等级: ${riskLevel.name}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Text(app.riskState?.reasonText ?? '正常', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            if (regime != null)
              Text('市场状态: ${regime.description}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
            if (mtf != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('多周期: ${mtf.description}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ),
            if (app.adaptiveParams != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('波动率: ${app.adaptiveParams!.volatilityLabel} | 确认次数: ${app.adaptiveParams!.confirmationCount} | 最低盈亏比: ${app.adaptiveParams!.minRiskReward.toStringAsFixed(1)}:1',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketAnalysisCard(AppState app, LongCycleResult? longCycle, RiskLevel riskLevel, double currentPrice) {
    String outlook = '数据加载中...';
    String suggestion = '正在获取K线和订单流数据，请稍候。';
    Color outlookColor = Colors.grey;

    if (longCycle != null) {
      final state = longCycle.state;
      final structure = longCycle.structure.structure;

      if (riskLevel == RiskLevel.L3) {
        outlook = '极端风险，观望为主';
        suggestion = '当前触发极端风险条件，禁止开仓。';
        outlookColor = Colors.red;
      } else if (riskLevel == RiskLevel.L2) {
        outlook = '高危环境，只做逆势反转';
        suggestion = 'BTC结构破位，顺势信号屏蔽，只抓反转机会。仓位降至1/3。';
        outlookColor = Colors.orange;
      } else if (state == LongCycleState.supportValid) {
        outlook = '接近支撑区，关注多头机会';
        suggestion = '价格进入支撑带，等待流动性清扫+订单流反转确认。';
        outlookColor = Colors.green;
      } else if (state == LongCycleState.resistanceValid) {
        outlook = '接近压力区，关注空头机会';
        suggestion = '价格进入压力带，等待流动性清扫+订单流反转确认。';
        outlookColor = Colors.red;
      } else if (state == LongCycleState.trendExhaustion) {
        outlook = '趋势衰竭，反转概率上升';
        suggestion = 'OI背离+资金费率极端，密切关注订单流变化。';
        outlookColor = Colors.purple;
      } else {
        outlook = '中性区间，无明确机会';
        suggestion = '价格远离关键位，耐心等待。';
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
            const SizedBox(height: 8),
            if (currentPrice > 0)
              Text('当前价: \$${currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Colors.blue)),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeRecommendationCard(AppState app) {
    final rec = app.tradeRecommendation;
    final isLong = rec.direction == TradeRecommendationDirection.long;
    final isShort = rec.direction == TradeRecommendationDirection.short;
    final isWait = rec.direction == TradeRecommendationDirection.wait;

    Color accentColor;
    if (isLong) {
      accentColor = Colors.green;
    } else if (isShort) {
      accentColor = Colors.red;
    } else {
      accentColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('推单区', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor, width: 1),
                  ),
                  child: Text(
                    rec.directionText,
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rec.isConfirmed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('已确认信号', style: TextStyle(color: Colors.orange, fontSize: 11)),
              ),
            const SizedBox(height: 12),
            if (!isWait) ...[
              _recRow('开仓区间', rec.entryText, Colors.blue),
              const SizedBox(height: 8),
              _recRow('止损 SL', rec.slText, Colors.red),
              const SizedBox(height: 8),
              _recRow('止盈 TP1', rec.tp1Text, Colors.green),
              const SizedBox(height: 8),
              _recRow('止盈 TP2', rec.tp2Text, Colors.green),
              const SizedBox(height: 8),
              _recRow('盈亏比', rec.rrText, Colors.orange),
              const SizedBox(height: 8),
              _recRow('建议仓位', rec.positionText, Colors.purple),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('触发条件', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(rec.triggerCondition, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(rec.reason, style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ),
            ],
            const SizedBox(height: 8),
            Text(rec.reason, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _recRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white60)),
        Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildKeyLevelsCard(LongCycleResult longCycle, double currentPrice) {
    final supports = longCycle.supportLevels;
    final resistances = longCycle.resistanceLevels;

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
                child: Text('当前价 \$${currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
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

  Widget _buildMarketInfoCard(AppState app, LongCycleResult? longCycle) {
    final orderFlow = app.deepOrderFlow;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('市场结构 & 订单流', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow('长周期状态', longCycle?.state.name ?? '加载中'),
            _infoRow('市场结构', longCycle?.structure.structure.name ?? '-'),
            _infoRow('结构描述', longCycle?.structure.description ?? '-'),
            _infoRow('波动率', longCycle?.volatility.state ?? '-'),
            _infoRow('资金费率状态', longCycle?.fundingState ?? '-'),
            _infoRow('OI背离', (longCycle?.hasOIDivergence ?? false) ? '是 ⚠️' : '否'),
            if (orderFlow != null) ...[
              const Divider(height: 16),
              _infoRow('订单流', orderFlow.summary),
              _infoRow('WS连接', app.marketData.orderFlow.isConnected ? '已连接' : '连接中...'),
              _infoRow('大单方向', orderFlow.largeOrders.description),
              _infoRow('成交密集区', '\$${orderFlow.volumeDensity.highestDensityPrice.toStringAsFixed(2)}'),
              _infoRow('清算风险', orderFlow.liquidation.description),
              _infoRow('盘口状态', orderFlow.orderBook.description),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignalCard(TradingSignal signal, AppState app) {
    final isLong = signal.direction == SignalDirection.long;
    final color = isLong ? Colors.green : Colors.red;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.L0: return Colors.green;
      case RiskLevel.L1: return Colors.yellow;
      case RiskLevel.L2: return Colors.orange;
      case RiskLevel.L3: return Colors.red;
    }
  }
}
