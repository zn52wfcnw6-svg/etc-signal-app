import 'dart:async';
import '../../models/signal.dart';
import '../../utils/constants.dart';
import '../../data/market_data_manager.dart';
import '../long_cycle/long_cycle_manager.dart';
import 'signal_detector.dart';

/// 信号引擎：协调长周期+短周期，管理连续确认和信号生命周期
class SignalEngine {
  final MarketDataManager _dataManager;
  final LongCycleManager _longCycle;
  final SignalDetector _detector;

  TradingSignal? _currentSignal;
  final List<ConfirmationResult> _confirmationBuffer = [];
  SignalDirection? _pendingDirection;
  int _confirmationCount = 0;

  final StreamController<TradingSignal> _signalController = StreamController<TradingSignal>.broadcast();
  final StreamController<Map<String, dynamic>> _statusController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<TradingSignal> get signalStream => _signalController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  TradingSignal? get currentSignal => _currentSignal;
  LongCycleManager get longCycle => _longCycle;

  SignalEngine(this._dataManager)
      : _longCycle = LongCycleManager(_dataManager),
        _detector = SignalDetector(_dataManager.orderFlow);

  /// 每次轮询调用
  Future<void> tick() async {
    // 检查当前信号是否过期
    _checkExpiry();

    // 长周期分析
    final longCycle = _longCycle.analyze();

    // 如果长周期不允许任何方向，清空待确认
    if (!longCycle.allowsLong && !longCycle.allowsShort) {
      _pendingDirection = null;
      _confirmationCount = 0;
      _confirmationBuffer.clear();
      _emitStatus(longCycle: longCycle, message: longCycle.description ?? '无有效信号');
      return;
    }

    final eth1m = _dataManager.getEth1m();
    final eth5m = _dataManager.getEth5m();

    if (eth1m.length < 10 || eth5m.length < 10) {
      _emitStatus(longCycle: longCycle, message: 'K线数据不足');
      return;
    }

    ConfirmationResult? result;

    // 优先检测待确认方向
    if (_pendingDirection == SignalDirection.long && longCycle.allowsLong) {
      result = _detector.detectLong(longCycle, eth1m, eth5m);
    } else if (_pendingDirection == SignalDirection.short && longCycle.allowsShort) {
      result = _detector.detectShort(longCycle, eth1m, eth5m);
    } else {
      // 新检测：优先尝试多头
      if (longCycle.allowsLong) {
        result = _detector.detectLong(longCycle, eth1m, eth5m);
        if (result.allPassed) {
          _pendingDirection = SignalDirection.long;
        }
      }
      if (result == null || !result.allPassed) {
        if (longCycle.allowsShort) {
          result = _detector.detectShort(longCycle, eth1m, eth5m);
          if (result.allPassed) {
            _pendingDirection = SignalDirection.short;
          }
        }
      }
    }

    if (result != null && result.allPassed) {
      _confirmationCount++;
      _confirmationBuffer.add(result);

      if (_confirmationCount >= AppConstants.confirmationPolls) {
        // 连续确认通过，生成信号
        _generateSignal(result, longCycle);
        _pendingDirection = null;
        _confirmationCount = 0;
        _confirmationBuffer.clear();
      } else {
        _emitStatus(
          longCycle: longCycle,
          message: '${_pendingDirection == SignalDirection.long ? "多头" : "空头"}确认中 $_confirmationCount/${AppConstants.confirmationPolls}',
          pendingResult: result,
        );
      }
    } else {
      // 确认中断，重置
      if (_pendingDirection != null) {
        _pendingDirection = null;
        _confirmationCount = 0;
        _confirmationBuffer.clear();
      }
      _emitStatus(longCycle: longCycle, message: '无有效信号');
    }
  }

  void _generateSignal(ConfirmationResult result, LongCycleResult longCycle) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final direction = _pendingDirection!;

    final signal = TradingSignal(
      id: 'sig_${now}_${direction.name}',
      direction: direction,
      status: SignalStatus.confirmed,
      createdAt: now - AppConstants.confirmationPolls * AppConstants.pollIntervalSeconds * 1000,
      confirmedAt: now,
      expiresAt: now + AppConstants.signalExpiryMinutes * 60 * 1000,
      entryLower: result.entryLower!,
      entryUpper: result.entryUpper!,
      stopLoss: result.stopLoss!,
      tp1: result.tp1!,
      tp2: result.tp2!,
      confidenceScore: result.confidenceScore!,
      confidenceBreakdown: result.confidenceBreakdown!.map((k, v) => MapEntry(k, v)),
      confirmationGates: result.gates,
      marketRegime: longCycle.structure.structure.name,
      volatilityState: longCycle.volatility.state,
      fundingRateAtSignal: _dataManager.ethData?.fundingRate ?? 0,
    );

    _currentSignal = signal;
    _signalController.add(signal);
    _emitStatus(longCycle: longCycle, message: '${direction == SignalDirection.long ? "多头" : "空头"}候选信号已生成', signal: signal);
  }

  void _checkExpiry() {
    if (_currentSignal != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > _currentSignal!.expiresAt) {
        _currentSignal = _currentSignal!.copyWith(status: SignalStatus.expired);
        _currentSignal = null;
      }
    }
  }

  void _emitStatus({
    required LongCycleResult longCycle,
    required String message,
    ConfirmationResult? pendingResult,
    TradingSignal? signal,
  }) {
    _statusController.add({
      'longCycleState': longCycle.state.name,
      'structure': longCycle.structure.structure.name,
      'currentPrice': longCycle.currentPrice,
      'support': longCycle.nearestSupport?.mid,
      'resistance': longCycle.nearestResistance?.mid,
      'volatility': longCycle.volatility.state,
      'fundingState': longCycle.fundingState,
      'confirmationCount': _confirmationCount,
      'pendingDirection': _pendingDirection?.name,
      'message': message,
      'signal': signal?.id,
      'confidence': pendingResult?.confidenceScore ?? signal?.confidenceScore,
    });
  }

  /// 手动标记信号已执行
  void markSignalExecuted(String signalId, bool executed, {double? pnl, String? note}) {
    if (_currentSignal?.id == signalId) {
      _currentSignal = _currentSignal!.copyWith(
        userExecuted: executed,
        actualPnl: pnl,
        resultNote: note,
        status: executed ? SignalStatus.active : SignalStatus.archived,
      );
    }
  }

  /// 归档信号
  void archiveSignal() {
    if (_currentSignal != null) {
      _currentSignal = _currentSignal!.copyWith(status: SignalStatus.archived);
      _currentSignal = null;
    }
  }

  void dispose() {
    _signalController.close();
    _statusController.close();
  }
}
