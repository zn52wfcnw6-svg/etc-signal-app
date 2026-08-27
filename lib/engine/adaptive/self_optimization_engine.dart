import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 信号结果记录
class SignalResult {
  final String id;
  final String direction; // long/short
  final double entryPrice;
  final double stopLoss;
  final double tp1;
  final double tp2;
  final int createdAt;
  final String? result; // 'tp1', 'tp2', 'sl', 'timeout', null(未平仓)
  final double? pnlPercent;

  SignalResult({
    required this.id,
    required this.direction,
    required this.entryPrice,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.createdAt,
    this.result,
    this.pnlPercent,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'direction': direction,
    'entryPrice': entryPrice,
    'stopLoss': stopLoss,
    'tp1': tp1,
    'tp2': tp2,
    'createdAt': createdAt,
    'result': result,
    'pnlPercent': pnlPercent,
  };

  factory SignalResult.fromJson(Map<String, dynamic> json) => SignalResult(
    id: json['id'],
    direction: json['direction'],
    entryPrice: json['entryPrice'],
    stopLoss: json['stopLoss'],
    tp1: json['tp1'],
    tp2: json['tp2'],
    createdAt: json['createdAt'],
    result: json['result'],
    pnlPercent: json['pnlPercent'],
  );
}

/// 自优化引擎
/// S级标准：基于历史信号胜率自动调整参数阈值
class SelfOptimizationEngine {
  static const String _storageKey = 'signal_results';
  static const int _maxResults = 200; // 最多保留200条记录

  List<SignalResult> _results = [];
  double _winRate = 0.0;
  double _avgPnl = 0.0;
  int _totalSignals = 0;
  int _winningSignals = 0;

  List<SignalResult> get results => List.unmodifiable(_results);
  double get winRate => _winRate;
  double get avgPnl => _avgPnl;
  int get totalSignals => _totalSignals;
  int get winningSignals => _winningSignals;

  /// 加载历史结果
  Future<void> loadResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_storageKey);
      if (dataStr != null) {
        final List<dynamic> data = json.decode(dataStr);
        _results = data.map((e) => SignalResult.fromJson(e)).toList();
        _calculateStats();
      }
    } catch (_) {}
  }

  /// 保存结果
  Future<void> _saveResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _results.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(data));
    } catch (_) {}
  }

  /// 记录新信号
  Future<void> recordSignal({
    required String id,
    required String direction,
    required double entryPrice,
    required double stopLoss,
    required double tp1,
    required double tp2,
  }) async {
    final result = SignalResult(
      id: id,
      direction: direction,
      entryPrice: entryPrice,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _results.insert(0, result);
    if (_results.length > _maxResults) {
      _results = _results.sublist(0, _maxResults);
    }
    await _saveResults();
    _calculateStats();
  }

  /// 更新信号结果
  Future<void> updateSignalResult(String id, String result, double pnlPercent) async {
    final index = _results.indexWhere((r) => r.id == id);
    if (index != -1) {
      _results[index] = SignalResult(
        id: _results[index].id,
        direction: _results[index].direction,
        entryPrice: _results[index].entryPrice,
        stopLoss: _results[index].stopLoss,
        tp1: _results[index].tp1,
        tp2: _results[index].tp2,
        createdAt: _results[index].createdAt,
        result: result,
        pnlPercent: pnlPercent,
      );
      await _saveResults();
      _calculateStats();
    }
  }

  /// 计算统计指标
  void _calculateStats() {
    final closed = _results.where((r) => r.result != null).toList();
    _totalSignals = closed.length;
    _winningSignals = closed.where((r) => r.pnlPercent != null && r.pnlPercent! > 0).length;
    _winRate = _totalSignals > 0 ? _winningSignals / _totalSignals : 0.0;
    final pnls = closed.where((r) => r.pnlPercent != null).map((r) => r.pnlPercent!).toList();
    _avgPnl = pnls.isNotEmpty ? pnls.reduce((a, b) => a + b) / pnls.length : 0.0;
  }

  /// 获取优化建议
  OptimizationSuggestion getSuggestion() {
    if (_totalSignals < 10) {
      return OptimizationSuggestion(
        level: '数据不足',
        message: '需要至少10个已平仓信号才能生成优化建议',
        suggestedMinRiskReward: 4.0,
        suggestedConfirmationCount: 3,
      );
    }

    // 胜率低于40%：提高盈亏比要求，增加确认次数
    if (_winRate < 0.4) {
      return OptimizationSuggestion(
        level: '保守优化',
        message: '胜率${(_winRate*100).toStringAsFixed(1)}%偏低，建议提高盈亏比要求和确认次数',
        suggestedMinRiskReward: 5.0,
        suggestedConfirmationCount: 4,
      );
    }

    // 胜率40-55%：保持标准
    if (_winRate < 0.55) {
      return OptimizationSuggestion(
        level: '标准配置',
        message: '胜率${(_winRate*100).toStringAsFixed(1)}%正常，保持标准参数',
        suggestedMinRiskReward: 4.0,
        suggestedConfirmationCount: 3,
      );
    }

    // 胜率高于55%：可以适当降低要求，增加信号频率
    return OptimizationSuggestion(
      level: '激进优化',
      message: '胜率${(_winRate*100).toStringAsFixed(1)}%较高，可适当降低盈亏比要求，增加信号频率',
      suggestedMinRiskReward: 3.0,
      suggestedConfirmationCount: 2,
    );
  }

  /// 清除所有记录
  Future<void> clearAll() async {
    _results = [];
    _winRate = 0;
    _avgPnl = 0;
    _totalSignals = 0;
    _winningSignals = 0;
    await _saveResults();
  }
}

/// 优化建议
class OptimizationSuggestion {
  final String level;
  final String message;
  final double suggestedMinRiskReward;
  final int suggestedConfirmationCount;

  OptimizationSuggestion({
    required this.level,
    required this.message,
    required this.suggestedMinRiskReward,
    required this.suggestedConfirmationCount,
  });
}
