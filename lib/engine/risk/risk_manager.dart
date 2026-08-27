import 'dart:async';
import '../../models/position.dart';
import '../../utils/constants.dart';
import '../../data/market_data_manager.dart';
import '../long_cycle/structure_analyzer.dart';
import '../long_cycle/volatility_oi.dart';

/// 全局冻结状态
class FreezeState {
  final bool isFrozen;
  final List<FreezeReason> reasons;
  final int frozenSince;
  final int consecutiveUnfreezeChecks;

  FreezeState({
    required this.isFrozen,
    this.reasons = const [],
    this.frozenSince = 0,
    this.consecutiveUnfreezeChecks = 0,
  });

  String get reasonText {
    if (reasons.isEmpty) return '无';
    return reasons.map((r) => _reasonText(r)).join(', ');
  }

  String _reasonText(FreezeReason r) {
    switch (r) {
      case FreezeReason.btcVolatility: return 'BTC剧烈波动';
      case FreezeReason.btcStructureBreak: return 'BTC结构破位';
      case FreezeReason.dataValidationFailed: return '行情校验失败';
      case FreezeReason.accountRiskExceeded: return '账户风险超限';
      case FreezeReason.liquidationSqueeze: return '清算挤压';
      case FreezeReason.none: return '无';
    }
  }

  FreezeState copyWith({
    bool? isFrozen,
    List<FreezeReason>? reasons,
    int? frozenSince,
    int? consecutiveUnfreezeChecks,
  }) {
    return FreezeState(
      isFrozen: isFrozen ?? this.isFrozen,
      reasons: reasons ?? this.reasons,
      frozenSince: frozenSince ?? this.frozenSince,
      consecutiveUnfreezeChecks: consecutiveUnfreezeChecks ?? this.consecutiveUnfreezeChecks,
    );
  }
}

/// 风控管理器：全局冻结状态机 + 账户风险计算
class RiskManager {
  final MarketDataManager _dataManager;
  final List<Position> _positions = [];
  double _accountBalance = 10000; // 默认账户净值，用户可配置

  FreezeState _freezeState = FreezeState(isFrozen: false);
  final List<double> _oiHistory = [];

  final StreamController<FreezeState> _freezeController = StreamController<FreezeState>.broadcast();
  Stream<FreezeState> get freezeStream => _freezeController.stream;
  FreezeState get freezeState => _freezeState;
  List<Position> get positions => List.unmodifiable(_positions);
  double get accountBalance => _accountBalance;

  RiskManager(this._dataManager);

  void setAccountBalance(double balance) {
    _accountBalance = balance;
  }

  /// 添加持仓
  void addPosition(Position pos) {
    _positions.add(pos);
    _checkAccountRisk();
  }

  /// 关闭持仓
  void closePosition(String id, double closePrice, double pnl) {
    final idx = _positions.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _positions[idx] = _positions[idx].copyWith(
        isClosed: true,
        closedAt: DateTime.now().millisecondsSinceEpoch,
        closePrice: closePrice,
        realizedPnl: pnl,
      );
      _positions.removeAt(idx);
    }
  }

  /// 更新止损（TP1后移至成本）
  void updateStopLoss(String id, double newSl) {
    final idx = _positions.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _positions[idx] = _positions[idx].copyWith(stopLoss: newSl);
    }
  }

  /// 计算账户总风险占用
  double get totalRisk {
    if (_accountBalance <= 0) return 0;
    double totalRiskAmount = 0;
    for (final p in _positions) {
      if (!p.isClosed) totalRiskAmount += p.riskAmount;
    }
    return totalRiskAmount / _accountBalance;
  }

  /// 单笔建议仓位
  double suggestedPositionSize(double entry, double stopLoss) {
    final maxRiskAmount = _accountBalance * AppConstants.singleTradeRiskLimit;
    final riskPerUnit = (entry - stopLoss).abs();
    return riskPerUnit > 0 ? maxRiskAmount / riskPerUnit : 0;
  }

  /// 检查账户风险
  bool _checkAccountRisk() {
    return totalRisk >= AppConstants.accountRiskLimit;
  }

  /// 执行冻结检查（每次轮询调用）
  Future<FreezeState> checkFreezeConditions() async {
    final reasons = <FreezeReason>[];

    // F1: BTC短周期波动
    final btc5m = _dataManager.getBtc5m();
    final btc15m = _dataManager.getBtc15m();
    if (btc5m.length >= 6) {
      final vol5m = (btc5m.last.close - btc5m[btc5m.length - 6].close).abs() / btc5m[btc5m.length - 6].close;
      if (vol5m > AppConstants.btc5mVolatilityThreshold) {
        reasons.add(FreezeReason.btcVolatility);
      }
    }
    if (btc15m.length >= 2) {
      final vol15m = (btc15m.last.close - btc15m.first.close).abs() / btc15m.first.close;
      if (vol15m > AppConstants.btc15mVolatilityThreshold) {
        reasons.add(FreezeReason.btcVolatility);
      }
    }

    // F2: BTC关键结构破位
    final btc4h = _dataManager.getBtc4h();
    if (btc4h.length >= 30 && StructureAnalyzer.isBtcStructureBroken(btc4h)) {
      reasons.add(FreezeReason.btcStructureBreak);
    }

    // F3: 行情校验失败（由数据层error事件驱动，这里检查数据状态）
    final etcData = _dataManager.etcData;
    final btcData = _dataManager.btcData;
    if (etcData == null || btcData == null) {
      reasons.add(FreezeReason.dataValidationFailed);
    }

    // F4: 账户总风险
    if (_checkAccountRisk()) {
      reasons.add(FreezeReason.accountRiskExceeded);
    }

    // F5: 清算挤压
    final etcData2 = _dataManager.etcData;
    if (etcData2 != null) {
      // OI变化
      if (etcData2.openInterest > 0) {
        _oiHistory.add(etcData2.openInterest);
        if (_oiHistory.length > 40) _oiHistory.removeAt(0);
      }
      double oiChange = 0.0;
      if (_oiHistory.length >= 2) {
        oiChange = (_oiHistory.last - _oiHistory[_oiHistory.length - 2]) / _oiHistory[_oiHistory.length - 2];
      }
      // 主动买卖比（用订单流bar近似）
      final bars = _dataManager.orderFlow.getRecentBars(5);
      double buyVol = 0, sellVol = 0;
      for (final b in bars) {
        buyVol += b.buyVolume;
        sellVol += b.sellVolume;
      }
      final activeRatio = sellVol > 0 ? buyVol / sellVol : 0.0;

      if (OIFundingAnalyzer.detectLiquidationSqueeze(
        fundingRate: etcData2.fundingRate,
        oiChange5m: oiChange,
        activeBuyRatio: activeRatio,
      )) {
        reasons.add(FreezeReason.liquidationSqueeze);
      }
    }

    // 状态机转换
    if (reasons.isNotEmpty) {
      if (!_freezeState.isFrozen) {
        _freezeState = FreezeState(
          isFrozen: true,
          reasons: reasons,
          frozenSince: DateTime.now().millisecondsSinceEpoch,
          consecutiveUnfreezeChecks: 0,
        );
      } else {
        _freezeState = _freezeState.copyWith(reasons: reasons, consecutiveUnfreezeChecks: 0);
      }
    } else {
      if (_freezeState.isFrozen) {
        final newCount = _freezeState.consecutiveUnfreezeChecks + 1;
        if (newCount >= AppConstants.frozenConfirmations) {
          _freezeState = FreezeState(isFrozen: false, consecutiveUnfreezeChecks: 0);
        } else {
          _freezeState = _freezeState.copyWith(consecutiveUnfreezeChecks: newCount);
        }
      }
    }

    _freezeController.add(_freezeState);
    return _freezeState;
  }

  /// 强制解冻（用于测试或手动）
  void forceUnfreeze() {
    _freezeState = FreezeState(isFrozen: false);
    _freezeController.add(_freezeState);
  }

  void dispose() {
    _freezeController.close();
  }
}
