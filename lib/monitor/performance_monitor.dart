import 'dart:collection';

/// 性能监控模块
/// S级标准：实时监控各模块响应时间、数据完整度、信号频率
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  // 模块响应时间统计
  final Map<String, List<int>> _responseTimes = {};
  // 模块调用次数
  final Map<String, int> _callCounts = {};
  // 模块错误次数
  final Map<String, int> _errorCounts = {};
  // 数据完整度
  final Map<String, double> _dataCompleteness = {};
  // 信号统计
  int _longSignalCount = 0;
  int _shortSignalCount = 0;
  int _confirmedSignalCount = 0;
  int _totalTicks = 0;
  // 启动时间
  final DateTime _startTime = DateTime.now();
  // 最近错误信息
  final Queue<String> _recentErrors = Queue<String>();
  static const int _maxErrorHistory = 50;

  /// 记录模块响应时间
  void recordResponseTime(String module, int milliseconds) {
    _responseTimes.putIfAbsent(module, () => []);
    _responseTimes[module]!.add(milliseconds);
    if (_responseTimes[module]!.length > 100) {
      _responseTimes[module]!.removeAt(0);
    }
    _callCounts[module] = (_callCounts[module] ?? 0) + 1;
  }

  /// 记录模块错误
  void recordError(String module, String error) {
    _errorCounts[module] = (_errorCounts[module] ?? 0) + 1;
    _recentErrors.add('[$module] $error');
    if (_recentErrors.length > _maxErrorHistory) {
      _recentErrors.removeFirst();
    }
  }

  /// 记录数据完整度
  void recordDataCompleteness(String dataType, double completeness) {
    _dataCompleteness[dataType] = completeness;
  }

  /// 记录信号
  void recordSignal(String direction, bool confirmed) {
    if (direction == 'long') {
      _longSignalCount++;
    } else if (direction == 'short') {
      _shortSignalCount++;
    }
    if (confirmed) {
      _confirmedSignalCount++;
    }
  }

  /// 记录tick
  void recordTick() {
    _totalTicks++;
  }

  /// 获取模块平均响应时间
  double getAverageResponseTime(String module) {
    final times = _responseTimes[module];
    if (times == null || times.isEmpty) return 0;
    return times.reduce((a, b) => a + b) / times.length;
  }

  /// 获取模块最大响应时间
  int getMaxResponseTime(String module) {
    final times = _responseTimes[module];
    if (times == null || times.isEmpty) return 0;
    return times.reduce((a, b) => a > b ? a : b);
  }

  /// 获取模块最小响应时间
  int getMinResponseTime(String module) {
    final times = _responseTimes[module];
    if (times == null || times.isEmpty) return 0;
    return times.reduce((a, b) => a < b ? a : b);
  }

  /// 获取模块调用次数
  int getCallCount(String module) => _callCounts[module] ?? 0;

  /// 获取模块错误次数
  int getErrorCount(String module) => _errorCounts[module] ?? 0;

  /// 获取数据完整度
  double getDataCompleteness(String dataType) => _dataCompleteness[dataType] ?? 0;

  /// 获取运行时长（秒）
  int getUptimeSeconds() => DateTime.now().difference(_startTime).inSeconds;

  /// 获取运行时长（格式化）
  String getUptimeFormatted() {
    final seconds = getUptimeSeconds();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  /// 获取所有模块性能统计
  Map<String, Map<String, dynamic>> getAllModuleStats() {
    final result = <String, Map<String, dynamic>>{};
    final allModules = <String>{..._responseTimes.keys, ..._callCounts.keys, ..._errorCounts.keys};
    for (final module in allModules) {
      result[module] = {
        'avgResponseTime': getAverageResponseTime(module),
        'maxResponseTime': getMaxResponseTime(module),
        'minResponseTime': getMinResponseTime(module),
        'callCount': getCallCount(module),
        'errorCount': getErrorCount(module),
        'errorRate': getCallCount(module) > 0
            ? (getErrorCount(module) / getCallCount(module) * 100)
            : 0.0,
      };
    }
    return result;
  }

  /// 获取信号统计
  Map<String, dynamic> getSignalStats() {
    return {
      'longSignals': _longSignalCount,
      'shortSignals': _shortSignalCount,
      'confirmedSignals': _confirmedSignalCount,
      'totalTicks': _totalTicks,
      'signalRate': _totalTicks > 0
          ? ((_longSignalCount + _shortSignalCount) / _totalTicks * 100)
          : 0.0,
      'confirmationRate': (_longSignalCount + _shortSignalCount) > 0
          ? (_confirmedSignalCount / (_longSignalCount + _shortSignalCount) * 100)
          : 0.0,
    };
  }

  /// 获取最近错误
  List<String> getRecentErrors({int count = 20}) {
    return _recentErrors.toList().reversed.take(count).toList();
  }

  /// 获取系统健康评分（0-100）
  int getHealthScore() {
    int score = 100;
    // 错误率扣分
    final allStats = getAllModuleStats();
    for (final stat in allStats.values) {
      final errorRate = stat['errorRate'] as double;
      if (errorRate > 50) score -= 20;
      else if (errorRate > 20) score -= 10;
      else if (errorRate > 5) score -= 5;
    }
    // 数据完整度扣分
    for (final completeness in _dataCompleteness.values) {
      if (completeness < 50) score -= 10;
      else if (completeness < 80) score -= 5;
    }
    // 响应时间扣分
    for (final module in _responseTimes.keys) {
      final avg = getAverageResponseTime(module);
      if (avg > 5000) score -= 10;
      else if (avg > 2000) score -= 5;
      else if (avg > 1000) score -= 2;
    }
    return score.clamp(0, 100);
  }

  /// 获取健康状态
  String getHealthStatus() {
    final score = getHealthScore();
    if (score >= 90) return '优秀';
    if (score >= 75) return '良好';
    if (score >= 60) return '一般';
    if (score >= 40) return '较差';
    return '危险';
  }

  /// 重置统计
  void reset() {
    _responseTimes.clear();
    _callCounts.clear();
    _errorCounts.clear();
    _dataCompleteness.clear();
    _longSignalCount = 0;
    _shortSignalCount = 0;
    _confirmedSignalCount = 0;
    _totalTicks = 0;
    _recentErrors.clear();
  }
}

/// 性能监控计时器 - 用于自动记录模块响应时间
class PerformanceTimer {
  final String module;
  final DateTime _startTime = DateTime.now();
  bool _finished = false;

  PerformanceTimer(this.module);

  /// 完成计时并记录
  void finish({bool hasError = false, String? error}) {
    if (_finished) return;
    _finished = true;
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    PerformanceMonitor().recordResponseTime(module, elapsed);
    if (hasError && error != null) {
      PerformanceMonitor().recordError(module, error);
    }
  }
}
