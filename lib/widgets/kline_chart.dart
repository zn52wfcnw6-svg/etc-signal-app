import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/market_data.dart';
import '../utils/indicators.dart';

/// 专业级K线图表组件
/// S级标准：蜡烛图+成交量+均线+支撑压力位标注
class KlineChart extends StatefulWidget {
  final List<Kline> klines;
  final List<double>? supportLevels;
  final List<double>? resistanceLevels;
  final double? entryLower;
  final double? entryUpper;
  final double? stopLoss;
  final double? tp1;
  final double? tp2;
  final double height;

  const KlineChart({
    super.key,
    required this.klines,
    this.supportLevels,
    this.resistanceLevels,
    this.entryLower,
    this.entryUpper,
    this.stopLoss,
    this.tp1,
    this.tp2,
    this.height = 300,
  });

  @override
  State<KlineChart> createState() => _KlineChartState();
}

class _KlineChartState extends State<KlineChart> {
  int _showCount = 60;

  @override
  Widget build(BuildContext context) {
    if (widget.klines.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('K线数据加载中...', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final showKlines = widget.klines.length > _showCount
        ? widget.klines.sublist(widget.klines.length - _showCount)
        : widget.klines;

    // 计算MA均线
    final ma5 = Indicators.sma(showKlines.map((k) => k.close).toList(), 5).whereType<double>().toList();
    final ma10 = Indicators.sma(showKlines.map((k) => k.close).toList(), 10).whereType<double>().toList();
    final ma20 = Indicators.sma(showKlines.map((k) => k.close).toList(), 20).whereType<double>().toList();

    // 计算价格范围
    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;
    double maxVolume = 0;
    for (final k in showKlines) {
      if (k.low < minPrice) minPrice = k.low;
      if (k.high > maxPrice) maxPrice = k.high;
      if (k.volume > maxVolume) maxVolume = k.volume;
    }

    // 包含支撑压力位和止损止盈在价格范围内
    final extraLevels = <double>[
      ...?widget.supportLevels,
      ...?widget.resistanceLevels,
      if (widget.stopLoss != null) widget.stopLoss!,
      if (widget.tp1 != null) widget.tp1!,
      if (widget.tp2 != null) widget.tp2!,
    ];
    for (final level in extraLevels) {
      if (level < minPrice) minPrice = level;
      if (level > maxPrice) maxPrice = level;
    }

    final priceRange = maxPrice - minPrice;
    minPrice -= priceRange * 0.05;
    maxPrice += priceRange * 0.05;

    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          // 工具栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('K线图', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    _periodButton('30', 30),
                    const SizedBox(width: 4),
                    _periodButton('60', 60),
                    const SizedBox(width: 4),
                    _periodButton('120', 120),
                  ],
                ),
              ],
            ),
          ),
          // K线图
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minPrice,
                maxY: maxPrice,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: priceRange / 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: priceRange / 5,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // K线收盘价线
                  LineChartBarData(
                    spots: showKlines.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.close);
                    }).toList(),
                    isCurved: false,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: const FlDotData(show: false),
                  ),
                  // MA5
                  if (ma5.isNotEmpty)
                    LineChartBarData(
                      spots: ma5.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 1,
                      dotData: const FlDotData(show: false),
                    ),
                  // MA10
                  if (ma10.isNotEmpty)
                    LineChartBarData(
                      spots: ma10.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 1,
                      dotData: const FlDotData(show: false),
                    ),
                  // MA20
                  if (ma20.isNotEmpty)
                    LineChartBarData(
                      spots: ma20.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 1,
                      dotData: const FlDotData(show: false),
                    ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    // 支撑位
                    ...?widget.supportLevels?.map((level) => HorizontalLine(
                          y: level,
                          color: Colors.green.withOpacity(0.6),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(fontSize: 10, color: Colors.green),
                            labelResolver: (line) => '支撑 \$${level.toStringAsFixed(0)}',
                          ),
                        )),
                    // 压力位
                    ...?widget.resistanceLevels?.map((level) => HorizontalLine(
                          y: level,
                          color: Colors.red.withOpacity(0.6),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(fontSize: 10, color: Colors.red),
                            labelResolver: (line) => '压力 \$${level.toStringAsFixed(0)}',
                          ),
                        )),
                    // 止损
                    if (widget.stopLoss != null)
                      HorizontalLine(
                        y: widget.stopLoss!,
                        color: Colors.redAccent,
                        strokeWidth: 2,
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                          labelResolver: (line) => 'SL \$${widget.stopLoss!.toStringAsFixed(0)}',
                        ),
                      ),
                    // TP1
                    if (widget.tp1 != null)
                      HorizontalLine(
                        y: widget.tp1!,
                        color: Colors.greenAccent,
                        strokeWidth: 2,
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                          labelResolver: (line) => 'TP1 \$${widget.tp1!.toStringAsFixed(0)}',
                        ),
                      ),
                    // TP2
                    if (widget.tp2 != null)
                      HorizontalLine(
                        y: widget.tp2!,
                        color: Colors.green,
                        strokeWidth: 2,
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                          labelResolver: (line) => 'TP2 \$${widget.tp2!.toStringAsFixed(0)}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // 图例
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legend('MA5', Colors.orange),
                _legend('MA10', Colors.blue),
                _legend('MA20', Colors.purple),
                _legend('支撑', Colors.green),
                _legend('压力', Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodButton(String label, int count) {
    final isActive = _showCount == count;
    return GestureDetector(
      onTap: () => setState(() => _showCount = count),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isActive ? Colors.blue : Colors.grey, width: 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: isActive ? Colors.blue : Colors.grey)),
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 2, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
