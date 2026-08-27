import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/market_data.dart';

/// 订单流高级指标可视化组件
/// S级标准：CVD趋势 + Delta柱状图 + 多空信号对比
class OrderFlowVisualization extends StatelessWidget {
  final List<OrderFlowBar> bars;
  final int bullishSignals;
  final int bearishSignals;
  final double height;

  const OrderFlowVisualization({
    super.key,
    required this.bars,
    required this.bullishSignals,
    required this.bearishSignals,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('订单流数据加载中...', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );
    }

    final showBars = bars.length > 30 ? bars.sublist(bars.length - 30) : bars;

    // 计算CVD范围
    double minCvd = double.infinity;
    double maxCvd = double.negativeInfinity;
    double maxDelta = 0;
    for (final bar in showBars) {
      if (bar.cvd < minCvd) minCvd = bar.cvd;
      if (bar.cvd > maxCvd) maxCvd = bar.cvd;
      if (bar.delta.abs() > maxDelta) maxDelta = bar.delta.abs();
    }
    final cvdRange = maxCvd - minCvd;
    minCvd -= cvdRange * 0.1;
    maxCvd += cvdRange * 0.1;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // 多空信号对比
          _buildSignalComparison(),
          const SizedBox(height: 8),
          // CVD + Delta图表
          Expanded(
            child: Row(
              children: [
                // CVD趋势
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CVD累积', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            minY: minCvd,
                            maxY: maxCvd,
                            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: cvdRange / 4),
                            titlesData: FlTitlesData(
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: cvdRange / 4, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 9, color: Colors.grey)))),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: showBars.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.cvd)).toList(),
                                isCurved: true,
                                color: _cvdColor(showBars),
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(show: true, color: _cvdColor(showBars).withOpacity(0.1)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Delta柱状图
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delta', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            minY: -maxDelta,
                            maxY: maxDelta,
                            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxDelta / 2),
                            titlesData: FlTitlesData(
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: maxDelta / 2, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 9, color: Colors.grey)))),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: showBars.asMap().entries.map((e) {
                              final isPositive = e.value.delta >= 0;
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: e.value.delta,
                                    color: isPositive ? Colors.green : Colors.red,
                                    width: 3,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalComparison() {
    final total = bullishSignals + bearishSignals;
    final bullPct = total > 0 ? bullishSignals / total : 0.5;
    return Row(
      children: [
        const Text('多空对比', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  Expanded(flex: (bullPct * 100).toInt(), child: Container(color: Colors.green.withOpacity(0.7))),
                  Expanded(flex: ((1 - bullPct) * 100).toInt(), child: Container(color: Colors.red.withOpacity(0.7))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('多$bullishSignals/空$bearishSignals', style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Color _cvdColor(List<OrderFlowBar> bars) {
    if (bars.length < 2) return Colors.blue;
    return bars.last.cvd >= bars.first.cvd ? Colors.green : Colors.red;
  }
}
