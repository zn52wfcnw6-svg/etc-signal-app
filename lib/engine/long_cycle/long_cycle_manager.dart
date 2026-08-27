import '../../models/market_data.dart';
import '../../utils/constants.dart';
import '../../data/market_data_manager.dart';
import 'structure_analyzer.dart';
import 'key_levels.dart';
import 'volatility_oi.dart';

/// 长周期分析结果
class LongCycleResult {
  final LongCycleState state;
  final StructureAnalysis structure;
  final List<KeyLevel> supportLevels;
  final List<KeyLevel> resistanceLevels;
  final VolatilityAnalysis volatility;
  final String fundingState;
  final bool hasOIDivergence;
  final double currentPrice;
  final String? description;

  LongCycleResult({
    required this.state,
    required this.structure,
    required this.supportLevels,
    required this.resistanceLevels,
    required this.volatility,
    required this.fundingState,
    required this.hasOIDivergence,
    required this.currentPrice,
    this.description,
  });

  KeyLevel? get nearestSupport => supportLevels.isNotEmpty ? supportLevels.first : null;
  KeyLevel? get nearestResistance => resistanceLevels.isNotEmpty ? resistanceLevels.first : null;

  bool get allowsLong => state == LongCycleState.supportValid || state == LongCycleState.trendExhaustion;
  bool get allowsShort => state == LongCycleState.resistanceValid || state == LongCycleState.trendExhaustion;
}

/// 长周期状态管理器
class LongCycleManager {
  final MarketDataManager _dataManager;
  final List<double> _oiHistory = [];

  LongCycleManager(this._dataManager);

  /// 执行长周期分析
  LongCycleResult analyze() {
    final eth4h = _dataManager.getEth4h();
    final eth1d = _dataManager.getEth1d();
    final ethData = _dataManager.ethData;

    if (eth4h.length < 20) {
      return LongCycleResult(
        state: LongCycleState.neutral,
        structure: StructureAnalysis(structure: MarketStructure.ranging, swingHighs: [], swingLows: []),
        supportLevels: [],
        resistanceLevels: [],
        volatility: VolatilityAnalysis(atrValue: 0, state: 'normal'),
        fundingState: 'neutral',
        hasOIDivergence: false,
        currentPrice: ethData?.price ?? 0,
        description: '4H K线数据不足',
      );
    }

    // 结构分析（4H为主，1D辅助）
    final structure = StructureAnalyzer.analyze(eth4h);

    // 关键位（4H + 1D合并）
    final support4h = KeyLevelDrawer.drawSupportLevels(eth4h);
    final resistance4h = KeyLevelDrawer.drawResistanceLevels(eth4h);
    final support1d = eth1d.length >= 20 ? KeyLevelDrawer.drawSupportLevels(eth1d) : <KeyLevel>[];
    final resistance1d = eth1d.length >= 20 ? KeyLevelDrawer.drawResistanceLevels(eth1d) : <KeyLevel>[];

    // 合并4H和1D关键位，去重
    final allSupports = [...support4h, ...support1d];
    final allResistances = [...resistance4h, ...resistance1d];
    allSupports.sort((a, b) => b.strength.compareTo(a.strength));
    allResistances.sort((a, b) => b.strength.compareTo(a.strength));

    // 波动率
    final volatility = VolatilityAnalyzer.analyze(eth4h);

    // 资金费率
    final fundingRate = ethData?.fundingRate ?? 0;
    final fundingState = OIFundingAnalyzer.fundingState(fundingRate);

    // OI历史与背离
    if (ethData?.openInterest != null && ethData!.openInterest > 0) {
      _oiHistory.add(ethData.openInterest);
      if (_oiHistory.length > 100) _oiHistory.removeAt(0);
    }
    final hasOIDivergence = OIFundingAnalyzer.detectOIDivergence(
      eth4h.sublist(eth4h.length > 20 ? eth4h.length - 20 : 0),
      _oiHistory,
      bullish: structure.structure == MarketStructure.downtrend,
    );

    // 判定长周期状态
    final currentPrice = ethData?.price ?? eth4h.last.close;
    final state = _determineState(
      currentPrice,
      allSupports.isNotEmpty ? allSupports.first : null,
      allResistances.isNotEmpty ? allResistances.first : null,
      structure,
      hasOIDivergence,
      fundingState,
    );

    return LongCycleResult(
      state: state,
      structure: structure,
      supportLevels: allSupports.take(3).toList(),
      resistanceLevels: allResistances.take(3).toList(),
      volatility: volatility,
      fundingState: fundingState,
      hasOIDivergence: hasOIDivergence,
      currentPrice: currentPrice,
      description: _describeState(state, structure),
    );
  }

  LongCycleState _determineState(
    double price,
    KeyLevel? support,
    KeyLevel? resistance,
    StructureAnalysis structure,
    bool oiDivergence,
    String fundingState,
  ) {
    // 趋势衰竭：关键位 + OI背离 + 资金费率极端
    final isExtremeFunding = fundingState.startsWith('extreme');
    if (oiDivergence && isExtremeFunding) {
      return LongCycleState.trendExhaustion;
    }

    // 结构破位中 → 中性
    if (structure.structure == MarketStructure.reversalPending) {
      return LongCycleState.neutral;
    }

    // 价格在支撑带内
    if (support != null && support.contains(price) && !structure.isCHoCH) {
      return LongCycleState.supportValid;
    }

    // 价格在压力带内
    if (resistance != null && resistance.contains(price) && !structure.isCHoCH) {
      return LongCycleState.resistanceValid;
    }

    return LongCycleState.neutral;
  }

  String _describeState(LongCycleState state, StructureAnalysis structure) {
    switch (state) {
      case LongCycleState.supportValid: return '支撑区有效，允许抓底';
      case LongCycleState.resistanceValid: return '压力区有效，允许抓顶';
      case LongCycleState.neutral: return '中性/趋势中，禁止逆势';
      case LongCycleState.trendExhaustion: return '趋势衰竭预警，高优先级反转';
    }
  }
}
