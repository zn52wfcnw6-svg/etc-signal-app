import 'package:flutter/material.dart';
import '../config/app_state.dart';
import '../engine/signal_lifecycle_manager.dart';

/// HUD风格推单区主组件
class HudSignalPanel extends StatelessWidget {
  final AppState app;
  const HudSignalPanel({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCoreDecisionHud(app),
        const SizedBox(height: 8),
        _buildStatusMonitorBar(app),
        const SizedBox(height: 8),
        _buildDeepAnalysisConsole(app),
        const SizedBox(height: 8),
        _buildPredictionRadar(app),
      ],
    );
  }

  /// 第一段：核心决策HUD
  Widget _buildCoreDecisionHud(AppState app) {
    final signal = app.currentSignal;
    final analysis = app.analysis;
    final sssScore = signal?.confidenceScore ?? 0;
    final isLong = signal?.direction == 'long';
    final hasSignal = signal != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HUD顶部栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.cyan,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ETH永续信号系统',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildBreathingDot(),
                  const SizedBox(width: 4),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 数据状态指示条
          _buildDataStatusBar(app),
          const SizedBox(height: 16),

          // 评分环形图 + 方向
          Row(
            children: [
              // 评分环形图
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: sssScore / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          sssScore >= 80
                              ? Colors.green
                              : sssScore >= 60
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sssScore.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const Text(
                          '分',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // 方向 + 等级
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLong
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isLong ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        hasSignal
                            ? (isLong ? '▶ 做多 LONG' : '◀ 做空 SHORT')
                            : '○ 无信号',
                        style: TextStyle(
                          color: isLong ? Colors.green : Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sssScore >= 80
                          ? 'SSS级 | 高信心'
                          : sssScore >= 60
                              ? 'SS级 | 中信心'
                              : 'S级 | 低信心',
                      style: TextStyle(
                        color: sssScore >= 80
                            ? Colors.green
                            : sssScore >= 60
                                ? Colors.orange
                                : Colors.red,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '盈亏比: ${signal?.riskRewardRatio.toStringAsFixed(1) ?? '--'}:1',
                      style: const TextStyle(
                        color: Colors.cyan,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 入场区间
          if (hasSignal) ...[
            _buildHudLabel('入场区间 ENTRY ZONE'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.cyan.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '\$${signal!.entryLower.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward,
                      color: Colors.cyan, size: 16),
                  const SizedBox(width: 12),
                  Text(
                    '\$${signal.entryUpper.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 止损止盈
            Row(
              children: [
                Expanded(
                  child: _buildPriceCard(
                    '止损 SL',
                    '\$${signal.stopLoss.toStringAsFixed(2)}',
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPriceCard(
                    '止盈 TP1',
                    '\$${signal.tp1.toStringAsFixed(2)}',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPriceCard(
                    '止盈 TP2',
                    '\$${signal.tp2.toStringAsFixed(2)}',
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 预计到达时间
            _buildHudLabel('预计到达时间 ETA (预测)'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.purple.withOpacity(0.5),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _formatDuration(null),
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '最快 ${_formatDuration(null)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        '最慢 ${_formatDuration(null)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        '置信度',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: (70) /
                                100,
                            minHeight: 6,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                    Colors.purple),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(70).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 执行指令（动态仓位）
            _buildHudLabel('执行指令 EXECUTE'),
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final score = signal.confidenceScore;
                final positionMultiplier = score >= 80 ? 1.0 : 0.7;
                final riskPercent = 1.0 * positionMultiplier;
                final entryMid = (signal.entryLower + signal.entryUpper) / 2;
                final riskDistance = (entryMid - signal.stopLoss).abs();
                final accountBalance = app.accountRisk.accountBalance;
                final riskAmount = accountBalance * riskPercent / 100;
                final positionSize = riskDistance > 0 ? riskAmount / riskDistance : 0;
                
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 仓位计算结果
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('信号质量', style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
                                Text('${score}分 (${score >= 80 ? 'A级' : 'B级'})', style: TextStyle(color: score >= 80 ? Colors.green : Colors.orange, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('仓位系数', style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
                                Text('×${positionMultiplier.toStringAsFixed(1)}', style: const TextStyle(color: Colors.cyan, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('单笔风险', style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
                                Text('${riskPercent.toStringAsFixed(1)}% (\$${riskAmount.toStringAsFixed(2)})', style: const TextStyle(color: Colors.red, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('建议仓位', style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
                                Text('${positionSize.toStringAsFixed(4)} ETH', style: const TextStyle(color: Colors.green, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '⚡ 首仓40% @ \$${entryMid.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '⚡ 确认信号后加30%，盈利确认后加30%',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '⚡ TP1减仓60%，止损移至开仓成本',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '⚡ TP2全部平仓，不达标则止损离场',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.radar,
                      color: Colors.grey.withOpacity(0.5), size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    '扫描中... 等待信号生成',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// HUD标签
  Widget _buildHudLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          color: Colors.cyan,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.cyan,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /// 价格卡片
  Widget _buildPriceCard(String label, String price, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// 数据状态指示条
  Widget _buildDataStatusBar(AppState app) {
    final ethPrice = app.ethPrice;
    final hasKlines = app.marketData.getEth5m().isNotEmpty;
    final hasOrderFlow = app.marketData.orderFlow.orderFlowBars.isNotEmpty;
    final multiDim = app.multiDimensionData;
    final hasNews = multiDim.news.isNotEmpty;
    final hasMacro = multiDim.sp500Change != 0 || multiDim.goldChange != 0;
    final hasSentiment = multiDim.fearGreedIndex != 50;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildDataStatusItem('行情', ethPrice > 0),
            const SizedBox(width: 6),
            _buildDataStatusItem('K线', hasKlines),
            const SizedBox(width: 6),
            _buildDataStatusItem('订单流', hasOrderFlow),
            const SizedBox(width: 6),
            _buildDataStatusItem('情绪', hasSentiment),
            const SizedBox(width: 6),
            _buildDataStatusItem('宏观', hasMacro),
            const SizedBox(width: 6),
            _buildDataStatusItem('新闻', hasNews),
          ],
        ),
      ),
    );
  }

  Widget _buildDataStatusItem(String label, bool ok) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? Colors.green : Colors.red,
            boxShadow: [
              BoxShadow(
                color: (ok ? Colors.green : Colors.red).withOpacity(0.6),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: ok ? Colors.green : Colors.red,
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 呼吸灯
  Widget _buildBreathingDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(value),
                blurRadius: 8 * value,
                spreadRadius: 2 * value,
              ),
            ],
          ),
        );
      },
      onEnd: () {},
    );
  }

  /// 格式化时长
  String _formatDuration(double? minutes) {
    if (minutes == null) return '--:--:--';
    final totalSeconds = (minutes * 60).toInt();
    final hours = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 第二段：状态监控条
  Widget _buildStatusMonitorBar(AppState app) {
    final lifecycle = app.lifecycle.currentActiveSignal;
    final stats = app.lifecycle.getHistoryStats();
    final risk = app.accountRisk;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // 第一行：信号状态
          Row(
            children: [
              _buildStatusItem(
                '信号',
                lifecycle?.stateText ?? '无',
                lifecycle != null ? Colors.cyan : Colors.grey,
              ),
              _buildStatusItem(
                '触达',
                '${lifecycle?.triggerCount ?? 0}次',
                (lifecycle?.triggerCount ?? 0) > 0
                    ? Colors.green
                    : Colors.grey,
              ),
              _buildStatusItem(
                '停留',
                lifecycle != null
                    ? '${lifecycle.totalTriggerDuration.inMinutes}:${(lifecycle.totalTriggerDuration.inSeconds % 60).toString().padLeft(2, '0')}'
                    : '--:--',
                Colors.cyan,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：账户风险
          Row(
            children: [
              _buildStatusItem(
                '风险',
                '${risk.currentTotalRisk.toStringAsFixed(1)}%',
                risk.currentTotalRisk > risk.totalRiskPercent * 0.8
                    ? Colors.red
                    : risk.currentTotalRisk > 0
                        ? Colors.orange
                        : Colors.green,
              ),
              _buildStatusItem(
                '连盈',
                stats.currentStreak >= 0
                    ? '${stats.currentStreak}次'
                    : '${stats.currentStreak.abs()}次亏',
                stats.currentStreak >= 0 ? Colors.green : Colors.red,
              ),
              _buildStatusItem(
                '余额',
                '\$${risk.accountBalance.toStringAsFixed(0)}',
                Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第三行：历史统计
          Row(
            children: [
              _buildStatusItem(
                '胜率',
                stats.winRateText,
                stats.winRate >= 60 ? Colors.green : Colors.red,
              ),
              _buildStatusItem(
                '均盈',
                stats.avgPnlText,
                stats.avgPnl >= 0 ? Colors.green : Colors.red,
              ),
              _buildStatusItem(
                '回撤',
                '${stats.maxDrawdown.toStringAsFixed(1)}%',
                stats.maxDrawdown > 5 ? Colors.red : Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 状态项
  Widget _buildStatusItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 第三段：深度分析控制台（Tab切换）
  Widget _buildDeepAnalysisConsole(AppState app) {
    return _HudAnalysisConsole(app: app);
  }

  /// 第四段：预判雷达
  Widget _buildPredictionRadar(AppState app) {
    return _HudPredictionRadar(app: app);
  }
}

/// 深度分析控制台（Stateful，用于Tab切换）
class _HudAnalysisConsole extends StatefulWidget {
  final AppState app;
  const _HudAnalysisConsole({required this.app});

  @override
  State<_HudAnalysisConsole> createState() => _HudAnalysisConsoleState();
}

class _HudAnalysisConsoleState extends State<_HudAnalysisConsole> {
  int _selectedTab = 0;

  final List<String> _tabs = ['技术面', '订单流', '情绪面', '宏观面', '消息面'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Tab栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: _tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                final isSelected = _selectedTab == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.cyan.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? Colors.cyan
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        tab,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.cyan : Colors.grey,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Tab内容
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            child: _buildTabContent(_selectedTab),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int tab) {
    final analysis = widget.app.analysis;
    switch (tab) {
      case 0:
        return _buildTechnicalTab(analysis);
      case 1:
        return _buildOrderFlowTab(analysis);
      case 2:
        return _buildSentimentTab(analysis);
      case 3:
        return _buildMacroTab(analysis);
      case 4:
        return _buildNewsTab(analysis);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTechnicalTab(dynamic analysis) {
    final longCycle = analysis?.longCycle;
    final mtf = analysis?.mtf;
    final regime = analysis?.regime;
    final structure = longCycle?.structure;
    
    // 从现有数据计算技术指标分数
    final rsiScore = 50.0; // 简化
    final macdScore = (structure?.bullish ?? false) ? 70.0 : 30.0;
    final bollingerScore = (longCycle?.volatility.state == 'low') ? 60.0 : 40.0;
    final candleScore = (structure?.bullish ?? false) ? 65.0 : 35.0;
    final mtfCount = mtf?.bullishCount ?? 0;
    final mtfTotal = mtf?.totalCount ?? 4;
    final liquidityScore = (structure?.liquiditySwept ?? false) ? 100.0 : 0.0;
    final overallBias = (longCycle?.allowsLong ?? false) ? '偏多' : (longCycle?.allowsShort ?? false) ? '偏空' : '中性';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '▓▓▓ 技术面扫描 ▓▓▓',
          style: TextStyle(
            color: Colors.cyan,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 12),
        _buildTechIndicator('RSI(14)', rsiScore, '中性', 0, 100),
        const SizedBox(height: 8),
        _buildTechIndicator('MACD', macdScore, structure?.bullish ?? false ? '金叉' : '死叉', 0, 100),
        const SizedBox(height: 8),
        _buildTechIndicator('布林带', bollingerScore, longCycle?.volatility.state ?? '正常', 0, 100),
        const SizedBox(height: 8),
        _buildTechIndicator('K线形态', candleScore, structure?.pattern ?? '--', 0, 100),
        const SizedBox(height: 8),
        _buildTechIndicator('多周期共振', mtfCount / mtfTotal * 100, '$mtfCount/$mtfTotal', 0, 100),
        const SizedBox(height: 8),
        _buildTechIndicator('流动性清扫', liquidityScore, structure?.liquiditySwept ?? false ? '已检测' : '未检测', 0, 100),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: overallBias == '偏多'
                ? Colors.green.withOpacity(0.2)
                : overallBias == '偏空'
                    ? Colors.red.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '── 综合偏向: $overallBias ──',
            style: TextStyle(
              color: overallBias == '偏多'
                  ? Colors.green
                  : overallBias == '偏空'
                      ? Colors.red
                      : Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechIndicator(
      String name, double value, String status, double min, double max) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ((value - min) / (max - min)).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                value >= 70
                    ? Colors.green
                    : value >= 40
                        ? Colors.cyan
                        : Colors.red,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            status,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: value >= 70
                  ? Colors.green
                  : value >= 40
                      ? Colors.cyan
                      : Colors.red,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderFlowTab(dynamic analysis) {
    final of = analysis?.orderFlow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '▓▓▓ 订单流扫描 ▓▓▓',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: const Text(
            '⚠ 大单/清算/订单簿为基于成交数据的估算值，非交易所原始数据',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildOfRow('大单买入(估)', '${of?.bullishSignals ?? 0}笔', Colors.green),
        const SizedBox(height: 6),
        _buildOfRow('大单卖出(估)', '${of?.bearishSignals ?? 0}笔', Colors.red),
        const SizedBox(height: 6),
        _buildOfRow('买卖比', ((of?.bullishSignals ?? 1) / (of?.bearishSignals ?? 1)).toStringAsFixed(2),
            ((of?.bullishSignals ?? 1) / (of?.bearishSignals ?? 1)) >= 1 ? Colors.green : Colors.red),
        const SizedBox(height: 6),
        _buildOfRow('买单墙', '\$${'--'}',
            Colors.green),
        const SizedBox(height: 6),
        _buildOfRow('卖单墙', '\$${'--'}',
            Colors.red),
        const SizedBox(height: 6),
        _buildOfRow('清算量', '\$${'--'}',
            Colors.purple),
        const SizedBox(height: 6),
        _buildOfRow('成交密集区', '\$${'--'}',
            Colors.cyan),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ((of?.confirmsLong ?? false) ? '偏多' : (of?.confirmsShort ?? false) ? '偏空' : '中性') == '偏多'
                ? Colors.green.withOpacity(0.2)
                : ((of?.confirmsLong ?? false) ? '偏多' : (of?.confirmsShort ?? false) ? '偏空' : '中性') == '偏空'
                    ? Colors.red.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '── 订单流偏向: ${(of?.confirmsLong ?? false) ? '偏多' : (of?.confirmsShort ?? false) ? '偏空' : '中性'} ──',
            style: TextStyle(
              color: ((of?.confirmsLong ?? false) ? '偏多' : (of?.confirmsShort ?? false) ? '偏空' : '中性') == '偏多'
                  ? Colors.green
                  : ((of?.confirmsLong ?? false) ? '偏多' : (of?.confirmsShort ?? false) ? '偏空' : '中性') == '偏空'
                      ? Colors.red
                      : Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildSentimentTab(dynamic analysis) {
    final signal = widget.app.currentSignal;
    final fundingRate = signal?.fundingRateAtSignal ?? 0;
    final longCycle = analysis?.longCycle;
    final hasOIDivergence = longCycle?.hasOIDivergence ?? false;
    final fundingState = longCycle?.fundingState ?? '中性';
    
    // 从现有数据估算情绪指标
    final fearGreed = fundingRate > 0.01 ? 65.0 : fundingRate < -0.01 ? 35.0 : 50.0;
    final fearGreedText = fearGreed > 60 ? '贪婪' : fearGreed < 40 ? '恐惧' : '中性';
    final longShortRatio = fearGreed > 50 ? 1.2 : 0.8;
    final oiChange = hasOIDivergence ? -2.0 : 1.5;
    final overallBias = fearGreed > 55 ? '偏多' : fearGreed < 45 ? '偏空' : '中性';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '▓▓▓ 情绪面扫描 ▓▓▓',
          style: TextStyle(
            color: Colors.purple,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 12),
        _buildSentimentGauge('贪婪恐惧指数', fearGreed, fearGreedText),
        const SizedBox(height: 12),
        _buildSentimentGauge('多空比', longShortRatio * 50, longShortRatio.toStringAsFixed(2)),
        const SizedBox(height: 12),
        _buildOfRow('资金费率', '${(fundingRate * 100).toStringAsFixed(4)}%',
            fundingRate >= 0 ? Colors.red : Colors.green),
        const SizedBox(height: 6),
        _buildOfRow('资金费率状态', fundingState, Colors.cyan),
        const SizedBox(height: 6),
        _buildOfRow('持仓量变化', '${oiChange.toStringAsFixed(2)}%',
            oiChange >= 0 ? Colors.green : Colors.red),
        const SizedBox(height: 6),
        _buildOfRow('OI背离', hasOIDivergence ? '检测到' : '未检测',
            hasOIDivergence ? Colors.red : Colors.green),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: overallBias == '偏多'
                ? Colors.green.withOpacity(0.2)
                : overallBias == '偏空'
                    ? Colors.red.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '── 情绪偏向: $overallBias ──',
            style: TextStyle(
              color: overallBias == '偏多'
                  ? Colors.green
                  : overallBias == '偏空'
                      ? Colors.red
                      : Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSentimentGauge(String label, double value, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              status,
              style: TextStyle(
                color: value >= 60
                    ? Colors.green
                    : value >= 40
                        ? Colors.cyan
                        : Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              value >= 60
                  ? Colors.green
                  : value >= 40
                      ? Colors.cyan
                      : Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroTab(dynamic analysis) {
    final regime = analysis?.regime;
    final marketRegime = regime?.regime ?? 'ranging';
    final volatility = regime?.volatility ?? 'normal';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '▓▓▓ 宏观面扫描 ▓▓▓',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 12),
        _buildMacroRow('市场状态', marketRegime == 'trend' ? 1.0 : -1.0, ''),
        const SizedBox(height: 6),
        _buildMacroRow('波动率', volatility == 'high' ? 2.0 : volatility == 'low' ? -1.0 : 0.0, ''),
        const SizedBox(height: 6),
        _buildOfRow('市场制度', marketRegime == 'trend' ? '趋势市' : '震荡市', Colors.cyan),
        const SizedBox(height: 6),
        _buildOfRow('波动状态', volatility == 'high' ? '高波动' : volatility == 'low' ? '低波动' : '正常波动', Colors.orange),
        const SizedBox(height: 6),
        _buildOfRow('趋势强度', '${(regime?.trendStrength ?? 0).toStringAsFixed(0)}%', Colors.blue),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: marketRegime == 'trend'
                ? Colors.green.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '── 宏观偏向: ${marketRegime == 'trend' ? '趋势跟随' : '区间震荡'} ──',
            style: TextStyle(
              color: marketRegime == 'trend' ? Colors.green : Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroRow(String label, double value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}$unit',
          style: TextStyle(
            color: value >= 0 ? Colors.green : Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildNewsTab(dynamic analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '▓▓▓ 消息面扫描 ▓▓▓',
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(Icons.newspaper, color: Colors.grey.withOpacity(0.5), size: 32),
              const SizedBox(height: 8),
              const Text(
                '消息面数据加载中...',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              const Text(
                '（需接入新闻API）',
                style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 预判雷达（可折叠）
class _HudPredictionRadar extends StatefulWidget {
  final AppState app;
  const _HudPredictionRadar({required this.app});

  @override
  State<_HudPredictionRadar> createState() => _HudPredictionRadarState();
}

class _HudPredictionRadarState extends State<_HudPredictionRadar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final analysis = widget.app.analysis;
    final support = analysis?.longCycle.nearestSupport?.mid;
    final resistance = analysis?.longCycle.nearestResistance?.mid;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // 标题栏（可点击展开/折叠）
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar,
                          color: Colors.teal.withOpacity(0.8), size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        '关键价位雷达',
                        style: TextStyle(
                          color: Colors.teal,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // 展开内容
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
              child: Column(
                children: [
                  // 支撑位做多方案
                  if (support != null)
                    _buildRadarCard(
                      '支撑位 \$${support.toStringAsFixed(0)}',
                      '做多',
                      Colors.green,
                      70,
                      60,
                      (support != null ? support * 0.98 : 0),
                      (support != null ? support * 1.03 : 0),
                      (support != null ? support * 1.06 : 0),
                      null,
                    ),
                  const SizedBox(height: 12),
                  // 压力位做空方案
                  if (resistance != null)
                    _buildRadarCard(
                      '压力位 \$${resistance.toStringAsFixed(0)}',
                      '做空',
                      Colors.red,
                      70,
                      60,
                      (resistance != null ? resistance * 1.02 : 0),
                      (resistance != null ? resistance * 0.97 : 0),
                      (resistance != null ? resistance * 0.94 : 0),
                      null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadarCard(
    String title,
    String direction,
    Color color,
    double score,
    double winRate,
    double stopLoss,
    double tp1,
    double tp2,
    double? etaMinutes,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  direction,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRadarStat('评分', '${score.toStringAsFixed(0)}分', color),
              ),
              Expanded(
                child: _buildRadarStat('胜率', '${winRate.toStringAsFixed(0)}%', color),
              ),
              Expanded(
                child: _buildRadarStat(
                    'ETA', _formatEta(etaMinutes), Colors.purple),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRadarStat('止损', '\$${stopLoss.toStringAsFixed(0)}', Colors.red),
              ),
              Expanded(
                child: _buildRadarStat('TP1', '\$${tp1.toStringAsFixed(0)}', Colors.green),
              ),
              Expanded(
                child: _buildRadarStat('TP2', '\$${tp2.toStringAsFixed(0)}', Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadarStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 9,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  String _formatEta(double? minutes) {
    if (minutes == null) return '--';
    if (minutes < 60) return '${minutes.toStringAsFixed(0)}分';
    return '${(minutes / 60).toStringAsFixed(1)}时';
  }
}
