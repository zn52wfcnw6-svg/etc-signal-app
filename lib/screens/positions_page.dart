import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/position.dart';
import '../utils/constants.dart';

class PositionsPage extends StatefulWidget {
  const PositionsPage({super.key});

  @override
  State<PositionsPage> createState() => _PositionsPageState();
}

class _PositionsPageState extends State<PositionsPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        final positions = app.positions;
        return Column(
          children: [
            _summaryCard(app),
            // 添加持仓按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('手动记录持仓'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  onPressed: () => _showAddPositionDialog(app),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: positions.isEmpty
                  ? const Center(child: Text('暂无持仓，点击上方按钮手动记录', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: positions.length,
                      itemBuilder: (context, i) => _positionCard(positions[i], app, context),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAddPositionDialog(AppState app) {
    final directionController = TextEditingController(text: 'long');
    final entryController = TextEditingController(text: app.ethPrice.toStringAsFixed(2));
    final slController = TextEditingController();
    final tp1Controller = TextEditingController();
    final tp2Controller = TextEditingController();
    final qtyController = TextEditingController(text: '0.1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('手动记录持仓', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: directionController.text,
                decoration: const InputDecoration(labelText: '方向', labelStyle: TextStyle(color: Colors.grey)),
                dropdownColor: Colors.grey.shade800,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'long', child: Text('做多')),
                  DropdownMenuItem(value: 'short', child: Text('做空')),
                ],
                onChanged: (v) => directionController.text = v ?? 'long',
              ),
              TextField(controller: entryController, decoration: const InputDecoration(labelText: '开仓价', labelStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
              TextField(controller: slController, decoration: const InputDecoration(labelText: '止损价', labelStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
              TextField(controller: tp1Controller, decoration: const InputDecoration(labelText: 'TP1', labelStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
              TextField(controller: tp2Controller, decoration: const InputDecoration(labelText: 'TP2', labelStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
              TextField(controller: qtyController, decoration: const InputDecoration(labelText: '数量', labelStyle: TextStyle(color: Colors.grey)), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            child: const Text('添加'),
            onPressed: () {
              final entry = double.tryParse(entryController.text) ?? 0;
              final sl = double.tryParse(slController.text) ?? 0;
              final tp1 = double.tryParse(tp1Controller.text) ?? 0;
              final tp2 = double.tryParse(tp2Controller.text) ?? 0;
              final qty = double.tryParse(qtyController.text) ?? 0;
              if (entry > 0 && sl > 0 && tp1 > 0 && qty > 0) {
                app.addManualPosition(
                  direction: directionController.text,
                  entryPrice: entry,
                  stopLoss: sl,
                  tp1: tp1,
                  tp2: tp2 > 0 ? tp2 : tp1 * 1.5,
                  quantity: qty,
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(AppState app) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('账户净值', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('\$${app.accountBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('总风险占用', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text(
                '${(app.totalRisk * 100).toStringAsFixed(2)}%',
                style: TextStyle(color: app.totalRisk > 0.04 ? Colors.red : Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('持仓数量', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('${app.positions.length} 笔', style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _positionCard(Position pos, AppState app, BuildContext context) {
    final isLong = pos.direction == SignalDirection.long;
    final color = isLong ? Colors.green : Colors.red;
    final currentPrice = app.ethPrice;
    final pnl = pos.unrealizedPnl(currentPrice);
    final pnlColor = pnl >= 0 ? Colors.green : Colors.red;

    // 平仓提醒：价格接近止损或止盈
    final nearSL = isLong ? (currentPrice - pos.stopLoss).abs() / pos.stopLoss < 0.005 : (pos.stopLoss - currentPrice).abs() / pos.stopLoss < 0.005;
    final nearTP1 = isLong ? (pos.tp1 - currentPrice).abs() / pos.tp1 < 0.005 : (currentPrice - pos.tp1).abs() / pos.tp1 < 0.005;
    final alertColor = nearSL ? Colors.red : (nearTP1 ? Colors.orange : null);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: alertColor != null ? alertColor.withOpacity(0.15) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text(isLong ? '多' : '空', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('批次 ${pos.batchNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                Text('\$${pnl.toStringAsFixed(2)}', style: TextStyle(color: pnlColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            _row('开仓价', '\$${pos.entryPrice.toStringAsFixed(2)}'),
            _row('当前价', '\$${currentPrice.toStringAsFixed(2)}'),
            _row('止损', '\$${pos.stopLoss.toStringAsFixed(2)}', color: Colors.red),
            _row('TP1', '\$${pos.tp1.toStringAsFixed(2)}', color: Colors.orange),
            _row('TP2', '\$${pos.tp2.toStringAsFixed(2)}', color: Colors.green),
            _row('数量', '${pos.quantity.toStringAsFixed(4)}'),
            _row('风险', '\$${pos.riskAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            Row(
              children: [
                if (pos.shouldTakeProfit1(currentPrice))
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('TP1减仓60%+移止损'),
                      onPressed: () {
                        app.riskManager?.updateStopLoss(pos.id, pos.entryPrice);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('止损已移至开仓成本')));
                      },
                    ),
                  ),
                if (pos.shouldStopLoss(currentPrice))
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('止损离场'),
                      onPressed: () => app.closePosition(pos.id, currentPrice, pnl),
                    ),
                  ),
                if (pos.shouldTakeProfit2(currentPrice))
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('TP2全部平仓'),
                      onPressed: () => app.closePosition(pos.id, currentPrice, pnl),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
