import 'package:hive_flutter/hive_flutter.dart';
import '../models/signal.dart';
import '../models/position.dart';
import '../utils/constants.dart';

/// 本地数据库管理器（Hive实现，支持Web/Android/iOS）
class DatabaseHelper {
  static const String _signalsBox = 'signals';
  static const String _positionsBox = 'positions';
  static const String _healthBox = 'health_logs';
  static const String _iterationBox = 'iteration_logs';
  static const String _paramsBox = 'strategy_params';

  static bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Hive.openBox(_signalsBox);
    await Hive.openBox(_positionsBox);
    await Hive.openBox(_healthBox);
    await Hive.openBox(_iterationBox);
    await Hive.openBox(_paramsBox);
    await _insertDefaultParams();
    _initialized = true;
  }

  Future<void> _insertDefaultParams() async {
    final box = Hive.box(_paramsBox);
    if (box.isEmpty) {
      final defaults = {
        'confidence_threshold': AppConstants.minConfidenceScore.toDouble(),
        'confirmation_polls': AppConstants.confirmationPolls.toDouble(),
        'pinbar_wick_ratio': AppConstants.pinBarWickRatio,
        'cvd_divergence_threshold': AppConstants.cvdDivergenceThreshold,
        'signal_expiry_minutes': AppConstants.signalExpiryMinutes.toDouble(),
      };
      for (final entry in defaults.entries) {
        box.put(entry.key, {'value': entry.value, 'version': 1, 'is_active': true, 'created_at': DateTime.now().millisecondsSinceEpoch});
      }
    }
  }

  // === 信号 CRUD ===

  Future<void> insertSignal(TradingSignal signal) async {
    final box = Hive.box(_signalsBox);
    await box.put(signal.id, signal.toMap());
  }

  Future<void> updateSignal(TradingSignal signal) async {
    final box = Hive.box(_signalsBox);
    await box.put(signal.id, signal.toMap());
  }

  Future<List<TradingSignal>> getRecentSignals({int limit = 50}) async {
    final box = Hive.box(_signalsBox);
    final all = box.values.map((e) => _signalFromMap(Map<String, dynamic>.from(e as Map))).toList();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(limit).toList();
  }

  TradingSignal _signalFromMap(Map<String, dynamic> m) {
    return TradingSignal(
      id: m['id'] as String,
      direction: SignalDirection.values.firstWhere((e) => e.name == m['direction']),
      status: SignalStatus.values.firstWhere((e) => e.name == m['status']),
      createdAt: m['created_at'] as int,
      confirmedAt: m['confirmed_at'] as int,
      expiresAt: m['expires_at'] as int,
      entryLower: (m['entry_lower'] as num).toDouble(),
      entryUpper: (m['entry_upper'] as num).toDouble(),
      stopLoss: (m['stop_loss'] as num).toDouble(),
      tp1: (m['tp1'] as num).toDouble(),
      tp2: (m['tp2'] as num).toDouble(),
      confidenceScore: m['confidence_score'] as int,
      confidenceBreakdown: {},
      confirmationGates: {},
      marketRegime: m['market_regime'] as String? ?? 'unknown',
      volatilityState: m['volatility_state'] as String? ?? 'normal',
      fundingRateAtSignal: (m['funding_rate'] as num?)?.toDouble() ?? 0,
      userExecuted: m['user_executed'] == null ? null : m['user_executed'] == 1,
      actualPnl: (m['actual_pnl'] as num?)?.toDouble(),
      resultNote: m['result_note'] as String?,
    );
  }

  // === 持仓 CRUD ===

  Future<void> insertPosition(Position pos) async {
    final box = Hive.box(_positionsBox);
    await box.put(pos.id, pos.toMap());
  }

  Future<void> updatePosition(Position pos) async {
    final box = Hive.box(_positionsBox);
    await box.put(pos.id, pos.toMap());
  }

  Future<List<Position>> getOpenPositions() async {
    final box = Hive.box(_positionsBox);
    return box.values
        .map((e) => _positionFromMap(Map<String, dynamic>.from(e as Map)))
        .where((p) => !p.isClosed)
        .toList();
  }

  Position _positionFromMap(Map<String, dynamic> m) {
    return Position(
      id: m['id'] as String,
      signalId: m['signal_id'] as String?,
      direction: SignalDirection.values.firstWhere((e) => e.name == m['direction']),
      entryPrice: (m['entry_price'] as num).toDouble(),
      quantity: (m['quantity'] as num).toDouble(),
      stopLoss: (m['stop_loss'] as num).toDouble(),
      tp1: (m['tp1'] as num).toDouble(),
      tp2: (m['tp2'] as num).toDouble(),
      openedAt: m['opened_at'] as int,
      closedAt: m['closed_at'] as int?,
      closePrice: (m['close_price'] as num?)?.toDouble(),
      isClosed: m['is_closed'] == 1,
      realizedPnl: (m['realized_pnl'] as num?)?.toDouble(),
      batchNumber: m['batch_number'] as int? ?? 1,
    );
  }

  // === 健康日志 ===

  Future<void> logHealth({
    required String module,
    required String type,
    required String message,
    String action = '',
    bool success = true,
  }) async {
    final box = Hive.box(_healthBox);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(id, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'module': module,
      'type': type,
      'message': message,
      'action': action,
      'success': success ? 1 : 0,
    });
  }

  // === 迭代日志 ===

  Future<void> logIteration({
    required String paramName,
    required double oldValue,
    required double newValue,
    double? winrate,
    double? drawdown,
    required String status,
    String reason = '',
  }) async {
    final box = Hive.box(_iterationBox);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(id, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'param_name': paramName,
      'old_value': oldValue,
      'new_value': newValue,
      'backtest_winrate': winrate,
      'backtest_drawdown': drawdown,
      'status': status,
      'reason': reason,
    });
  }

  // === 策略参数 ===

  Future<Map<String, double>> getActiveParams() async {
    final box = Hive.box(_paramsBox);
    final result = <String, double>{};
    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map && val['is_active'] == true) {
        result[key as String] = (val['value'] as num).toDouble();
      }
    }
    return result;
  }

  Future<void> updateParam(String name, double value, int version) async {
    final box = Hive.box(_paramsBox);
    // 停用旧版本
    final old = box.get(name);
    if (old is Map) {
      old['is_active'] = false;
      await box.put(name, old);
    }
    // 插入新版本
    await box.put('${name}_v$version', {
      'value': value,
      'version': version,
      'is_active': true,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> close() async {
    await Hive.close();
  }
}
