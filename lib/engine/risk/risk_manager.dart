import 'dart:async';
import '../../models/position.dart';
import '../../utils/constants.dart';
import '../../data/market_data_manager.dart';
import '../long_cycle/structure_analyzer.dart';
import '../long_cycle/volatility_oi.dart';
import '../adaptive/adaptive_params.dart';

/// 风险等级
enum RiskLevel {
  L0, // 正常 - 绿灯
  L1, // 谨慎 - 黄灯
  L2, // 高危 - 橙灯
  L3, // 极端 - 红灯（完全屏蔽）
}

/// 风险状态
class RiskState {
  final RiskLevel level;
  final List<String> reasons;
  final double positionMultiplier; // 仓位倍数
  final double minRiskReward; // 最低盈亏比要求
  final bool allowsSignals; // 是否允许输出信号
  final bool allowsTrendFollow; // 是否允许顺势
  final bool allowsCounterTrend; // 是否允许逆势（抓顶抓底）

  RiskState({
    required this.level,
    this.reasons = const [],
    this.positionMultiplier = 1.0,
    this.minRiskReward = 4.0,
    this.allowsSignals = true,
    this.allowsTrendFollow = true,
    this.allowsCounterTrend = true,
  });

  String get levelText {
    switch (level) {
      case RiskLevel.L0: return '正常';
      case RiskLevel.L1: return '谨慎';
      case RiskLevel.L2: return '高危';
      case RiskLevel.L3: return '极端';
    }
  }

  String get reasonText => reasons.isEmpty ? '无' : reasons.join(', ');
}

/// 风控管理器：风险分级 + 账户风险计算
class RiskManager {
  final MarketDataManager _dataManager;
  final List<Position> _positions = [];
  double _accountBalance = 10000;
  RiskState _riskState = RiskState(level: RiskLevel.L0);
  final List<double> _oiHistory = [];
  AdaptiveParams? _adaptiveParams;

  final StreamController<RiskState> _riskController = StreamController<RiskState>.broadcast();
  Stream<RiskState> get riskStream => _riskController.stream;
  RiskState get riskState => _riskState;
  List<Position> get positions => List.unmodifiable(_positions);
  double get accountBalance => _accountBalance;

  RiskManager(this._dataManager);

  void setAccountBalance(double balance) {
    _accountBalance = balance;
  }

  void setAdaptiveParams(AdaptiveParams params) {
    _adaptiveParams = params;
  }

  void addPosition(Position pos) {
    _positions.add(pos);
  }

  void closePosition(String id, double closePrice, double pnl) {
    _positions.removeWhere((p) => p.id == id);
  }

  void updateStopLoss(String id, double newSl) {
    final idx = _positions.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _positions[idx] = _positions[idx].copyWith(stopLoss: newSl);
    }
  }

  double get totalRisk {
    if (_accountBalance <= 0) return 0;
    double totalRiskAmount = 0;
    for (final p in _positions) {
      if (!p.isClosed) totalRiskAmount += p.riskAmount;
    }
    return totalRiskAmount / _accountBalance;
  }

  /// 单笔建议仓位（考虑风险等级倍数）
  double suggestedPositionSize(double entry, double stopLoss) {
    final baseRisk = _accountBalance * AppConstants.singleTradeRiskLimit;
    final adjustedRisk = baseRisk * _riskState.positionMultiplier;
    final riskPerUnit = (entry - stopLoss).abs();
    return riskPerUnit > 0 ? adjustedRisk / riskPerUnit : 0;
  }

  /// 执行风险检查（每次轮询调用）
  Future<RiskState> checkRiskConditions() async {
    final reasons = <String>[];
    RiskLevel level = RiskLevel.L0;

    final btcVolThreshold = _adaptiveParams?.btcVolThreshold ?? AppConstants.btc5mVolatilityThreshold;

    // R1: BTC短周期波动（BTC数据不足时跳过）
    final btc5m = _dataManager.getBtc5m();
    if (btc5m.length >= 6 && _dataManager.btcData != null) {
      final vol5m = (btc5m.last.close - btc5m[btc5m.length - 6].close).abs() / btc5m[btc5m.length - 6].close;
      if (vol5m > btcVolThreshold * 1.5) {
        reasons.add('BTC极端波动(${ (vol5m * 100).toStringAsFixed(1)}%)');
        level = RiskLevel.L3;
      } else if (vol5m > btcVolThreshold) {
        reasons.add('BTC波动较大(${(vol5m * 100).toStringAsFixed(1)}%)');
        if (level.index < RiskLevel.L1.index) level = RiskLevel.L1;
      }
    }

    // R2: BTC结构破位 → L2（BTC数据不足时跳过）
    final btc4h = _dataManager.getBtc4h();
    if (btc4h.length >= 30 && _dataManager.btcData != null && StructureAnalyzer.isBtcStructureBroken(btc4h)) {
      reasons.add('BTC结构破位');
      if (level.index < RiskLevel.L2.index) level = RiskLevel.L2;
    }

    // R3: 行情校验失败 → 只有ETH缺失才L3，BTC缺失只警告（S级容错）
    final ethData = _dataManager.ethData;
    final btcData = _dataManager.btcData;
    if (ethData == null) {
      reasons.add('ETH行情数据异常');
      level = RiskLevel.L3;
    } else if (btcData == null) {
      reasons.add('BTC数据暂不可用，跳过大盘联动');
      // BTC缺失不冻结，只降级到L1（允许交易，但缺少BTC联动判断）
      if (level.index < RiskLevel.L1.index) level = RiskLevel.L1;
    }

    // R4: 账户总风险
    if (totalRisk >= AppConstants.accountRiskLimit) {
      reasons.add('账户风险超限(${ (totalRisk * 100).toStringAsFixed(1)}%)');
      level = RiskLevel.L3;
    }

    // R5: 清算挤压 → L2
    if (ethData != null) {
      if (ethData.openInterest > 0) {
        _oiHistory.add(ethData.openInterest);
        if (_oiHistory.length > 40) _oiHistory.removeAt(0);
      }
      double oiChange = 0.0;
      if (_oiHistory.length >= 2) {
        oiChange = (_oiHistory.last - _oiHistory[_oiHistory.length - 2]) / _oiHistory[_oiHistory.length - 2];
      }
      final bars = _dataManager.orderFlow.getRecentBars(5);
      double buyVol = 0, sellVol = 0;
      for (final b in bars) {
        buyVol += b.buyVolume;
        sellVol += b.sellVolume;
      }
      final activeRatio = sellVol > 0 ? buyVol / sellVol : 0.0;
      if (OIFundingAnalyzer.detectLiquidationSqueeze(
        fundingRate: ethData.fundingRate,
        oiChange5m: oiChange,
        activeBuyRatio: activeRatio,
      )) {
        reasons.add('清算挤压风险');
        if (level.index < RiskLevel.L2.index) level = RiskLevel.L2;
      }
    }

    // 根据等级构建状态
    _riskState = _buildState(level, reasons);
    _riskController.add(_riskState);
    return _riskState;
  }

  RiskState _buildState(RiskLevel level, List<String> reasons) {
    final adaptiveRR = _adaptiveParams?.minRiskReward ?? 4.0;
    switch (level) {
      case RiskLevel.L0:
        return RiskState(
          level: level,
          reasons: reasons,
          positionMultiplier: 1.0,
          minRiskReward: adaptiveRR,
          allowsSignals: true,
          allowsTrendFollow: true,
          allowsCounterTrend: true,
        );
      case RiskLevel.L1:
        return RiskState(
          level: level,
          reasons: reasons,
          positionMultiplier: 0.5,
          minRiskReward: adaptiveRR + 1.0,
          allowsSignals: true,
          allowsTrendFollow: true,
          allowsCounterTrend: true,
        );
      case RiskLevel.L2:
        return RiskState(
          level: level,
          reasons: reasons,
          positionMultiplier: 0.33,
          minRiskReward: adaptiveRR + 2.0,
          allowsSignals: true,
          allowsTrendFollow: false, // 结构破位时只做逆势反转
          allowsCounterTrend: true,
        );
      case RiskLevel.L3:
        return RiskState(
          level: level,
          reasons: reasons,
          positionMultiplier: 0,
          minRiskReward: 99,
          allowsSignals: false,
          allowsTrendFollow: false,
          allowsCounterTrend: false,
        );
    }
  }

  void dispose() {
    _riskController.close();
  }
}
