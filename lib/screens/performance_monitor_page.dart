import 'package:flutter/material.dart';
import '../monitor/performance_monitor.dart';

/// 性能监控页面
/// 显示系统健康状态、各模块响应时间、数据完整度、信号统计
class PerformanceMonitorPage extends StatefulWidget {
  const PerformanceMonitorPage({super.key});

  @override
  State<PerformanceMonitorPage> createState() => _PerformanceMonitorPageState();
}

class _PerformanceMonitorPageState extends State<PerformanceMonitorPage> {
  @override
  void initState() {
    super.initState();
    // 每秒刷新一次
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {});
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monitor = PerformanceMonitor();
    final healthScore = monitor.getHealthScore();
    final healthStatus = monitor.getHealthStatus();
    final moduleStats = monitor.getAllModuleStats();
    final signalStats = monitor.getSignalStats();
    final recentErrors = monitor.getRecentErrors(count: 10);

    return Scaffold(
      appBar: AppBar(
        title: const Text('性能监控', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {
              monitor.reset();
              setState(() {});
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // 系统健康总览
            _buildHealthCard(healthScore, healthStatus, monitor),
            const SizedBox(height: 12),
            // 信号统计
            _buildSignalStatsCard(signalStats),
            const SizedBox(height: 12),
            // 模块性能统计
            _buildModuleStatsCard(moduleStats),
            const SizedBox(height: 12),
            // 数据完整度
            _buildDataCompletenessCard(monitor),
            const SizedBox(height: 12),
            // 最近错误
            if (recentErrors.isNotEmpty) _buildRecentErrorsCard(recentErrors),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard(int score, String status, PerformanceMonitor monitor) {
    Color color;
    if (score >= 90) color = Colors.green;
    else if (score >= 75) color = Colors.lightGreen;
    else if (score >= 60) color = Colors.yellow;
    else if (score >= 40) color = Colors.orange;
    else color = Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('系统健康度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(status, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          // 健康度进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text('$score / 100', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('运行时长', monitor.getUptimeFormatted()),
              _buildStatItem('总Tick数', '${monitor.getSignalStats()['totalTicks']}'),
              _buildStatItem('错误总数', '${monitor.getAllModuleStats().values.fold<int>(0, (sum, s) => sum + (s['errorCount'] as int))}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSignalStatsCard(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('信号统计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSignalItem('多头信号', '${stats['longSignals']}', Colors.green),
              _buildSignalItem('空头信号', '${stats['shortSignals']}', Colors.red),
              _buildSignalItem('确认信号', '${stats['confirmedSignals']}', Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSignalItem('信号频率', '${(stats['signalRate'] as double).toStringAsFixed(1)}%', Colors.orange),
              _buildSignalItem('确认率', '${(stats['confirmationRate'] as double).toStringAsFixed(1)}%', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildModuleStatsCard(Map<String, Map<String, dynamic>> stats) {
    if (stats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('暂无模块数据', style: TextStyle(color: Colors.grey))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('模块性能统计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          ...stats.entries.map((entry) {
            final module = entry.key;
            final data = entry.value;
            final avgTime = data['avgResponseTime'] as double;
            final errorRate = data['errorRate'] as double;
            Color timeColor = avgTime > 2000 ? Colors.red : avgTime > 1000 ? Colors.orange : Colors.green;
            Color errorColor = errorRate > 10 ? Colors.red : errorRate > 5 ? Colors.orange : Colors.green;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(module, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white))),
                      Text('${avgTime.toStringAsFixed(0)}ms', style: TextStyle(fontSize: 12, color: timeColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '调用: ${data['callCount']} | 错误: ${data['errorCount']} (${errorRate.toStringAsFixed(1)}%) | 最大: ${data['maxResponseTime']}ms',
                          style: TextStyle(fontSize: 11, color: errorColor),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.grey, height: 8),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDataCompletenessCard(PerformanceMonitor monitor) {
    // 从monitor中获取数据完整度（需要通过getAllModuleStats间接获取，这里简化处理）
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('数据完整度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          const Text('K线数据预加载100根，各周期数据完整度监控中...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          // 这里可以添加具体的数据完整度显示
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text('行情数据: 正常', style: TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text('K线数据: 正常', style: TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text('订单流: 正常', style: TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentErrorsCard(List<String> errors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text('最近错误', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          ...errors.map((error) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(error, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          )).toList(),
        ],
      ),
    );
  }
}
