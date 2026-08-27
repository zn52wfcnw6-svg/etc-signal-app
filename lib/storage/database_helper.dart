import '../models/signal.dart';
import '../models/position.dart';
import '../utils/constants.dart';

/// 本地数据库管理器（内存模式，用于Web兼容性测试）
class DatabaseHelper {
  static final Map<String, dynamic> _memoryStore = {};
  static bool _initialized = false;

  Future<void> init() async {
    _initialized = true;
  }

  Future<void> insertSignal(TradingSignal signal) async {
    _memoryStore['signal_${signal.id}'] = signal.toMap();
  }

  Future<void> updateSignal(TradingSignal signal) async {
    _memoryStore['signal_${signal.id}'] = signal.toMap();
  }

  Future<List<TradingSignal>> getRecentSignals({int limit = 50}) async {
    final signals = _memoryStore.entries
        .where((e) => e.key.startsWith('signal_'))
        .map((e) => TradingSignal.fromMap(Map<String, dynamic>.from(e.value as Map)))
        .toList();
    signals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return signals.take(limit).toList();
  }

  Future<void> insertPosition(Position position) async {
    _memoryStore['pos_${position.id}'] = position.toMap();
  }

  Future<void> updatePosition(Position position) async {
    _memoryStore['pos_${position.id}'] = position.toMap();
  }

  Future<List<Position>> getOpenPositions() async {
    return _memoryStore.entries
        .where((e) => e.key.startsWith('pos_'))
        .map((e) => Position.fromMap(Map<String, dynamic>.from(e.value as Map)))
        .where((p) => p.status == 'open')
        .toList();
  }

  Future<void> logHealth(String module, bool isHealthy, String issue, String action) async {
    _memoryStore['health_${DateTime.now().millisecondsSinceEpoch}'] = {
      'module': module,
      'is_healthy': isHealthy,
      'issue': issue,
      'action': action,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<void> logIteration(String version, Map<String, dynamic> changes, double performanceScore) async {
    _memoryStore['iter_${DateTime.now().millisecondsSinceEpoch}'] = {
      'version': version,
      'changes': changes,
      'performance_score': performanceScore,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<Map<String, dynamic>> getStrategyParams() async {
    final params = _memoryStore['params'] as Map<String, dynamic>?;
    if (params != null) return params;
    return {
      'confidence_threshold': AppConstants.minConfidenceScore.toDouble(),
      'confirmation_polls': AppConstants.confirmationPolls.toDouble(),
    };
  }

  Future<void> updateStrategyParam(String key, dynamic value) async {
    final params = _memoryStore['params'] as Map<String, dynamic>? ?? {};
    params[key] = value;
    _memoryStore['params'] = params;
  }
}
