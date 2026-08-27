import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../../models/signal.dart';
import '../../models/position.dart';
import '../../utils/constants.dart';

/// 本地数据库管理器
class DatabaseHelper {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, AppConstants.dbName);
    return openDatabase(
      fullPath,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE signals (
        id TEXT PRIMARY KEY,
        direction TEXT,
        status TEXT,
        created_at INTEGER,
        confirmed_at INTEGER,
        expires_at INTEGER,
        entry_lower REAL,
        entry_upper REAL,
        stop_loss REAL,
        tp1 REAL,
        tp2 REAL,
        confidence_score INTEGER,
        confidence_breakdown TEXT,
        confirmation_gates TEXT,
        market_regime TEXT,
        volatility_state TEXT,
        funding_rate REAL,
        user_executed INTEGER,
        actual_pnl REAL,
        result_note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE positions (
        id TEXT PRIMARY KEY,
        signal_id TEXT,
        direction TEXT,
        entry_price REAL,
        quantity REAL,
        stop_loss REAL,
        tp1 REAL,
        tp2 REAL,
        opened_at INTEGER,
        closed_at INTEGER,
        close_price REAL,
        is_closed INTEGER,
        realized_pnl REAL,
        batch_number INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE health_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER,
        module TEXT,
        type TEXT,
        message TEXT,
        action TEXT,
        success INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE iteration_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER,
        param_name TEXT,
        old_value REAL,
        new_value REAL,
        backtest_winrate REAL,
        backtest_drawdown REAL,
        status TEXT,
        reason TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE strategy_params (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        value REAL,
        version INTEGER,
        is_active INTEGER,
        created_at INTEGER
      )
    ''');

    // 初始化默认参数
    await _insertDefaultParams(db);
  }

  Future<void> _insertDefaultParams(Database db) async {
    final defaults = {
      'confidence_threshold': AppConstants.minConfidenceScore.toDouble(),
      'confirmation_polls': AppConstants.confirmationPolls.toDouble(),
      'pinbar_wick_ratio': AppConstants.pinBarWickRatio,
      'cvd_divergence_threshold': AppConstants.cvdDivergenceThreshold,
      'signal_expiry_minutes': AppConstants.signalExpiryMinutes.toDouble(),
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in defaults.entries) {
      await db.insert('strategy_params', {
        'name': entry.key,
        'value': entry.value,
        'version': 1,
        'is_active': 1,
        'created_at': now,
      });
    }
  }

  // === 信号 CRUD ===

  Future<void> insertSignal(TradingSignal signal) async {
    final db = await database;
    await db.insert('signals', signal.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSignal(TradingSignal signal) async {
    final db = await database;
    await db.update('signals', signal.toMap(), where: 'id = ?', whereArgs: [signal.id]);
  }

  Future<List<TradingSignal>> getRecentSignals({int limit = 50}) async {
    final db = await database;
    final maps = await db.query('signals', orderBy: 'created_at DESC', limit: limit);
    return maps.map((m) => _signalFromMap(m)).toList();
  }

  TradingSignal _signalFromMap(Map<String, dynamic> m) {
    return TradingSignal(
      id: m['id'] as String,
      direction: SignalDirection.values.firstWhere((e) => e.name == m['direction']),
      status: SignalStatus.values.firstWhere((e) => e.name == m['status']),
      createdAt: m['created_at'] as int,
      confirmedAt: m['confirmed_at'] as int,
      expiresAt: m['expires_at'] as int,
      entryLower: m['entry_lower'] as double,
      entryUpper: m['entry_upper'] as double,
      stopLoss: m['stop_loss'] as double,
      tp1: m['tp1'] as double,
      tp2: m['tp2'] as double,
      confidenceScore: m['confidence_score'] as int,
      confidenceBreakdown: {},
      confirmationGates: {},
      marketRegime: m['market_regime'] as String? ?? 'unknown',
      volatilityState: m['volatility_state'] as String? ?? 'normal',
      fundingRateAtSignal: m['funding_rate'] as double? ?? 0,
      userExecuted: m['user_executed'] == null ? null : m['user_executed'] == 1,
      actualPnl: m['actual_pnl'] as double?,
      resultNote: m['result_note'] as String?,
    );
  }

  // === 持仓 CRUD ===

  Future<void> insertPosition(Position pos) async {
    final db = await database;
    await db.insert('positions', pos.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePosition(Position pos) async {
    final db = await database;
    await db.update('positions', pos.toMap(), where: 'id = ?', whereArgs: [pos.id]);
  }

  Future<List<Position>> getOpenPositions() async {
    final db = await database;
    final maps = await db.query('positions', where: 'is_closed = 0', orderBy: 'opened_at DESC');
    return maps.map((m) => _positionFromMap(m)).toList();
  }

  Position _positionFromMap(Map<String, dynamic> m) {
    return Position(
      id: m['id'] as String,
      signalId: m['signal_id'] as String?,
      direction: SignalDirection.values.firstWhere((e) => e.name == m['direction']),
      entryPrice: m['entry_price'] as double,
      quantity: m['quantity'] as double,
      stopLoss: m['stop_loss'] as double,
      tp1: m['tp1'] as double,
      tp2: m['tp2'] as double,
      openedAt: m['opened_at'] as int,
      closedAt: m['closed_at'] as int?,
      closePrice: m['close_price'] as double?,
      isClosed: m['is_closed'] == 1,
      realizedPnl: m['realized_pnl'] as double?,
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
    final db = await database;
    await db.insert('health_logs', {
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
    final db = await database;
    await db.insert('iteration_logs', {
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
    final db = await database;
    final maps = await db.query('strategy_params', where: 'is_active = 1');
    final result = <String, double>{};
    for (final m in maps) {
      result[m['name'] as String] = m['value'] as double;
    }
    return result;
  }

  Future<void> updateParam(String name, double value, int version) async {
    final db = await database;
    await db.update('strategy_params', {'is_active': 0}, where: 'name = ?', whereArgs: [name]);
    await db.insert('strategy_params', {
      'name': name,
      'value': value,
      'version': version,
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
