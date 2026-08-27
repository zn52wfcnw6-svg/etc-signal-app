import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/signal.dart';
import '../utils/constants.dart';

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
        final isFrozen = app.freezeState?.isFrozen ?? false;
        final longCycle = app.longCycleResult;

        return RefreshIndicator(
          onRefresh: () => app.manualRefresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (signal != null && signal.status == SignalStatus.confirmed && !isFrozen)
                _signalCard(signal, app)
              else
                _marketAnalysisCard(app, longCycle, isFrozen),
              const SizedBox(height: 16),
              if (longCycle != null) _keyLevelsCard(longCycle, app),
              const SizedBox(height: 16),
              _marketInfoCard(app, longCycle),
            ],
          ),
        );
      },
    );
  }

  // === 市场分析卡片（无信号/冻结时显示）===
  Widget _marketAnalysisCard(AppState app, dynamic longCycle, bool isFrozen) {
    final currentPrice = app.ethPrice;
    String outlook = '';
    String suggestion = '';
    Color outlookColor = Colors.grey;

    if (longCycle != null) {
      final state = longCycle.state;
      final structure = longCycle.structure.structure;

      if (isFrozen) {
        outlook = '大盘冻结，观望为主';
        suggestion = '当前触发冻结条件，禁止开仓。等待冻结解除后再寻找机会。';
        outlookColor = Colors.orange;
      } else if (state == LongCycleState.supportValid) {
        outlook = '接近支撑区，关注多头机会';
        suggestion = '价格进入支撑带，若出现流动性清扫+CVD底背离可考虑做多。止损设在支撑带下沿。';
        outlookColor = Colors.green;
      } else if (state == LongCycleState.resistanceValid) {
        outlook = '接近压力区，关注空头机会';
        suggestion = '价格进入压力带，若出现流动性清扫+CVD顶背离可考虑做空。止损设在压力带上沿。';
        outlookColor = Colors.red;
      } else if (state == LongCycleState.trendExhaustion) {
        outlook = '趋势衰竭，反转概率上升';
        suggestion = 'OI背离+资金费率极端，趋势可能反转。密切关注订单流变化，准备反向布局。';
        outlookColor = Colors.purple;
      } else {
        outlook = '中性区间，无明确机会';
        suggestion = '价格远离关键位，趋势结构未破。耐心等待价格进入支撑/压力区。';
        outlookColor = Colors.grey;
      }

      if (structure == MarketStructure.uptrend) {
        suggestion += ' 大趋势向上，优先做多。';
      } else if (structure == MarketStructure.downtrend) {
        suggestion += ' 大趋势向下，优先做空。';
      }
    } else {
      outlook = '数据加载中...';
      suggestion = '正在获取K线和订单流数据，请稍候。';
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
              child: Text(
                outlook,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: outlookColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              suggestion,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (currentPrice > 0)
              Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text('当前价: \$${currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // === 关键价位卡片 ===
  Widget _keyLevelsCard(dynamic longCycle, AppState app) {
    final supports = longCycle.supportLevels as List;
    final resistances = longCycle.resistanceLevels as List;
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

            // 压力位
            const Text('压力位（做空目标区）', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (resistances.isEmpty)
              const Text('暂无数据', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ...resistances.take(2).map((level) => _levelRow(
                    level.mid,
                    level.strength,
                    'resistance',
                    currentPrice,
                    level.lower,
                    level.upper,
                  )),

            const Divider(height: 20),

            // 当前价
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('当前价 \$${currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            ),

            const Divider(height: 20),

            // 支撑位
            const Text('支撑位（做多目标区）', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (supports.isEmpty)
              const Text('暂无数据', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ...supports.take(2).map((level) => _levelRow(
                    level.mid,
                    level.strength,
                    'support',
                    currentPrice,
                    level.lower,
                    level.upper,
                  )),

            const SizedBox(height: 12),
            const Text('预估开仓策略', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _strategyHint(longCycle, currentPrice),
          ],
        ),
      ),
    );
  }

  Widget _levelRow(double price, int strength, String type, double currentPrice, double lower, double upper) {
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
          Text(stars, style: TextStyle(fontSize: 12, color: Colors.amber)),
          const Spacer(),
          Text('${distance.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Text('区间 \$${lower.toStringAsFixed(2)}-${upper.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _strategyHint(dynamic longCycle, double currentPrice) {
    final state = longCycle.state;
    final support = longCycle.nearestSupport;
    final resistance = longCycle.nearestResistance;

    if (state == LongCycleState.supportValid && support != null) {
      return Text(
        '若价格回落至 \$${support.lower.toStringAsFixed(2)}-${support.upper.toStringAsFixed(2)} 区间，且出现流动性清扫+订单流反转，可考虑分批做多。止损 \$${(support.lower * 0.99).toStringAsFixed(2)}，目标看最近压力位。',
        style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
      );
    } else if (state == LongCycleState.resistanceValid && resistance != null) {
      return Text(
        '若价格反弹至 \$${resistance.lower.toStringAsFixed(2)}-${resistance.upper.toStringAsFixed(2)} 区间，且出现流动性清扫+订单流反转，可考虑分批做空。止损 \$${(resistance.upper * 1.01).toStringAsFixed(2)}，目标看最近支撑位。',
        style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
      );
    } else {
      return const Text(
        '当前价格远离关键位，建议观望。等待价格接近支撑或压力区后再评估入场机会。',
        style: TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
      );
    }
  }

  // === 市场结构信息卡片 ===
  Widget _marketInfoCard(AppState app, dynamic longCycle) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('市场结构', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow('长周期状态', longCycle?.state?.name ?? '加载中'),
            _infoRow('市场结构', longCycle?.structure?.structure?.name ?? '-'),
            _infoRow('结构描述', longCycle?.structure?.description ?? '-'),
            _infoRow('波动率', longCycle?.volatility?.state ?? '-'),
            _infoRow('ATR', longCycle?.volatility?.atrValue != null ? '\$${longCycle.volatility.atrValue.toStringAsFixed(3)}' : '-'),
            _infoRow('资金费率状态', longCycle?.fundingState ?? '-'),
            _infoRow('OI背离', longCycle?.hasOIDivergence == true ? '是 ⚠️' : '否'),
            if (app.signalStatus['confirmationCount'] != null && app.signalStatus['confirmationCount'] > 0)
              _infoRow('信号确认', '${app.signalStatus['pendingDirection']} ${app.signalStatus['confirmationCount']}/${AppConstants.confirmationPolls}'),
          ],
        ),
      ),
    );
  }

  // === 有信号时的信号卡片 ===
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
            _infoRow('单笔风险', '1% 账户净值'),
            _infoRow('市场环境', '${signal.marketRegime} / ${signal.volatilityState}'),
            _infoRow('资金费率', '${(signal.fundingRateAtSignal * 100).toStringAsFixed(4)}%'),
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
}
