import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../utils/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      _balanceController.text = app.accountBalance.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('账户设置'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('账户净值（用于风险计算）', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        child: const Text('保存'),
                        onPressed: () {
                          final balance = double.tryParse(_balanceController.text) ?? 0;
                          app.setAccountBalance(balance);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            _sectionTitle('风控参数'),
            Card(
              child: Column(
                children: [
                  _paramRow('单笔最大风险', '${(AppConstants.singleTradeRiskLimit * 100).toStringAsFixed(0)}%'),
                  _paramRow('账户总风险上限', '${(AppConstants.accountRiskLimit * 100).toStringAsFixed(0)}%'),
                  _paramRow('最低盈亏比', '${AppConstants.minRiskRewardRatio.toStringAsFixed(1)}:1'),
                  _paramRow('目标盈亏比', '${AppConstants.targetRiskRewardRatio.toStringAsFixed(1)}:1'),
                  _paramRow('TP1减仓比例', '${(AppConstants.tp1ReduceRatio * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _sectionTitle('交易偏好（可修改）'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('风险偏好', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _riskButton('保守', app.riskPreference == 'conservative', () => app.setRiskPreference('conservative')),
                        _riskButton('稳健', app.riskPreference == 'moderate', () => app.setRiskPreference('moderate')),
                        _riskButton('激进', app.riskPreference == 'aggressive', () => app.setRiskPreference('aggressive')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('轮询间隔（秒）', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Slider(
                      value: app.pollInterval.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 25,
                      label: '${app.pollInterval}秒',
                      onChanged: (v) => app.setPollInterval(v.toInt()),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('信号声音提醒', style: TextStyle(fontSize: 14)),
                      value: app.soundEnabled,
                      onChanged: (v) => app.setSoundEnabled(v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('信号震动提醒', style: TextStyle(fontSize: 14)),
                      value: app.vibrationEnabled,
                      onChanged: (v) => app.setVibrationEnabled(v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            _sectionTitle('信号参数'),
            Card(
              child: Column(
                children: [
                  _paramRow('轮询间隔', '${AppConstants.pollIntervalSeconds}秒'),
                  _paramRow('确认轮询次数', '${AppConstants.confirmationPolls}次'),
                  _paramRow('信号有效期', '${AppConstants.signalExpiryMinutes}分钟'),
                  _paramRow('最低置信度', '${AppConstants.minConfidenceScore}分'),
                  _paramRow('BTC 5m波动阈值', '${(AppConstants.btc5mVolatilityThreshold * 100).toStringAsFixed(1)}%'),
                  _paramRow('BTC 15m波动阈值', '${(AppConstants.btc15mVolatilityThreshold * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _sectionTitle('系统状态'),
            Card(
              child: Column(
                children: [
                  _paramRow('运行状态', app.isRunning ? '运行中' : '已停止'),
                  _paramRow('初始化', app.isInitialized ? '已完成' : '未完成'),
                  _paramRow('风险等级', app.riskState?.level.name ?? 'L0'),
                  _paramRow('当前持仓', '${app.positions.length}笔'),
                  _paramRow('自优化样本', '${app.signalEngine.optimizer.records.length}条'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _sectionTitle('关于'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ETH永续信号监控系统', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('版本: 1.0.0', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('策略: 双周期抓顶抓底 + 订单流确认', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('交易所: Binance / OKX / Bybit / Bitget / Gate', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('免责声明: 本APP仅输出信号，不构成投资建议，交易风险自担', style: TextStyle(fontSize: 11, color: Colors.red)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _riskButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? Colors.blue : Colors.grey, width: 1),
        ),
        child: Text(label, style: TextStyle(color: isActive ? Colors.blue : Colors.grey, fontSize: 13)),
      ),
    );
  }

  Widget _paramRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue)),
        ],
      ),
    );
  }
}
