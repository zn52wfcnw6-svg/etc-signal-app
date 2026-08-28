import 'dart:async';
import '../storage/database_helper.dart';
import '../utils/constants.dart';

/// 健康检查结果
class HealthCheckResult {
  final String module;
  final bool isHealthy;
  final String? issue;
  final String? action;

  HealthCheckResult({
    required this.module,
    required this.isHealthy,
    this.issue,
    this.action,
  });
}

/// 自修复监控层：三层健康检查 + 自动修复
class SelfHealingMonitor {
  final DatabaseHelper _db;
  Timer? _checkTimer;
  final Map<String, int> _failureCounts = {};
  final Map<String, int> _healAttempts = {};

  final StreamController<HealthCheckResult> _healthStream = StreamController.broadcast();
  bool _isDisposed = false;
  Stream<HealthCheckResult> get healthStream => _healthStream.stream;

  // 外部注入的检查函数
  final List<Future<HealthCheckResult> Function()> _checks = [];
  final Map<String, Future<bool> Function()> _healers = {};

  SelfHealingMonitor(this._db);

  /// 注册健康检查
  void registerCheck(String name, Future<HealthCheckResult> Function() check) {
    _checks.add(check);
  }

  /// 注册修复函数
  void registerHealer(String module, Future<bool> Function() healer) {
    _healers[module] = healer;
  }

  void start() {
    _checkTimer = Timer.periodic(
      const Duration(seconds: AppConstants.healthCheckIntervalSeconds),
      (_) => _runChecks(),
    );
  }

  Future<void> _runChecks() async {
    for (final check in _checks) {
      try {
        final result = await check();
        if (!_isDisposed && !_healthStream.isClosed) _healthStream.add(result);

        if (!result.isHealthy) {
          _failureCounts[result.module] = (_failureCounts[result.module] ?? 0) + 1;
          await _db.logHealth(
            module: result.module,
            type: 'issue',
            message: result.issue ?? '未知异常',
            action: result.action ?? '',
            success: false,
          );

          // 尝试自动修复
          await _attemptHeal(result.module);
        } else {
          _failureCounts[result.module] = 0;
          _healAttempts[result.module] = 0;
        }
      } catch (e) {
        await _db.logHealth(
          module: 'monitor',
          type: 'error',
          message: '健康检查异常: $e',
          success: false,
        );
      }
    }
  }

  Future<void> _attemptHeal(String module) async {
    final attempts = _healAttempts[module] ?? 0;
    if (attempts >= AppConstants.maxHealAttempts) {
      await _db.logHealth(
        module: module,
        type: 'heal_failed',
        message: '自动修复连续失败${AppConstants.maxHealAttempts}次，需人工介入',
        success: false,
      );
      return;
    }

    final healer = _healers[module];
    if (healer != null) {
      _healAttempts[module] = attempts + 1;
      try {
        final success = await healer();
        await _db.logHealth(
          module: module,
          type: 'heal_attempt',
          message: '第${attempts + 1}次自动修复',
          action: '执行修复函数',
          success: success,
        );
        if (success) {
          _healAttempts[module] = 0;
          _failureCounts[module] = 0;
        }
      } catch (e) {
        await _db.logHealth(
          module: module,
          type: 'heal_error',
          message: '修复异常: $e',
          success: false,
        );
      }
    }
  }

  /// 手动触发一次检查
  Future<void> manualCheck() async {
    await _runChecks();
  }

  /// 获取模块失败次数
  int getFailureCount(String module) => _failureCounts[module] ?? 0;

  void stop() {
    _checkTimer?.cancel();
  }

  void dispose() {
    stop();
    _healthStream.close();
  }
}
