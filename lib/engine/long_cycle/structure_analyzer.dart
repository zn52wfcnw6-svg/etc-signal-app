import '../../models/market_data.dart';
import '../../utils/constants.dart';
import '../../utils/indicators.dart';

/// 市场结构分析结果
class StructureAnalysis {
  final MarketStructure structure;
  final List<SwingPoint> swingHighs;
  final List<SwingPoint> swingLows;
  final SwingPoint? lastSwingHigh;
  final SwingPoint? lastSwingLow;
  final bool isBOS; // 趋势延续
  final bool isCHoCH; // 趋势反转
  final String? description;

  StructureAnalysis({
    required this.structure,
    required this.swingHighs,
    required this.swingLows,
    this.lastSwingHigh,
    this.lastSwingLow,
    this.isBOS = false,
    this.isCHoCH = false,
    this.description,
  });
}

/// 长周期结构分析器：BOS/CHoCH判定
class StructureAnalyzer {
  /// 分析4H/1D级别市场结构
  static StructureAnalysis analyze(List<Kline> klines, {int lookback = AppConstants.swingLookback}) {
    if (klines.length < lookback * 2 + 5) {
      return StructureAnalysis(
        structure: MarketStructure.ranging,
        swingHighs: [],
        swingLows: [],
        description: 'K线数据不足',
      );
    }

    final swingPoints = Indicators.findSwingPoints(klines, lookback: lookback);
    final swingHighs = swingPoints.where((p) => p.isHigh).toList();
    final swingLows = swingPoints.where((p) => !p.isHigh).toList();

    if (swingHighs.isEmpty || swingLows.isEmpty) {
      return StructureAnalysis(
        structure: MarketStructure.ranging,
        swingHighs: swingHighs,
        swingLows: swingLows,
      );
    }

    final lastHigh = swingHighs.last;
    final lastLow = swingLows.last;
    final currentPrice = klines.last.close;

    // 判断BOS和CHoCH
    bool isBOS = false;
    bool isCHoCH = false;
    MarketStructure structure;

    // 上升趋势：高点抬高，低点抬高
    final higherHighs = swingHighs.length >= 2 &&
        swingHighs.last.price > swingHighs[swingHighs.length - 2].price;
    final higherLows = swingLows.length >= 2 &&
        swingLows.last.price > swingLows[swingLows.length - 2].price;
    final lowerHighs = swingHighs.length >= 2 &&
        swingHighs.last.price < swingHighs[swingHighs.length - 2].price;
    final lowerLows = swingLows.length >= 2 &&
        swingLows.last.price < swingLows[swingLows.length - 2].price;

    // BOS：价格突破最近同向摆动点
    if (higherHighs && higherLows) {
      // 上升趋势中，突破最近高点 = BOS
      isBOS = currentPrice > lastHigh.price;
      structure = MarketStructure.uptrend;
      // CHoCH：上升趋势中跌破最近低点
      isCHoCH = currentPrice < lastLow.price;
      if (isCHoCH) structure = MarketStructure.reversalPending;
    } else if (lowerHighs && lowerLows) {
      // 下降趋势中，跌破最近低点 = BOS
      isBOS = currentPrice < lastLow.price;
      structure = MarketStructure.downtrend;
      // CHoCH：下降趋势中突破最近高点
      isCHoCH = currentPrice > lastHigh.price;
      if (isCHoCH) structure = MarketStructure.reversalPending;
    } else {
      structure = MarketStructure.ranging;
    }

    return StructureAnalysis(
      structure: structure,
      swingHighs: swingHighs,
      swingLows: swingLows,
      lastSwingHigh: lastHigh,
      lastSwingLow: lastLow,
      isBOS: isBOS,
      isCHoCH: isCHoCH,
      description: _describe(structure, isBOS, isCHoCH),
    );
  }

  /// BTC关键结构破位判定：4H出现CHoCH或跌破最近2个摆动低点
  static bool isBtcStructureBroken(List<Kline> btc4hKlines) {
    if (btc4hKlines.length < 30) return false;
    final analysis = analyze(btc4hKlines);
    if (analysis.isCHoCH) return true;

    // 跌破最近2个摆动低点
    if (analysis.swingLows.length >= 2) {
      final currentPrice = btc4hKlines.last.close;
      final secondLastLow = analysis.swingLows[analysis.swingLows.length - 2].price;
      if (currentPrice < secondLastLow) return true;
    }
    return false;
  }

  static String _describe(MarketStructure s, bool bos, bool choch) {
    if (choch) return '趋势反转确认中(CHoCH)';
    if (bos) return '趋势延续(BOS)';
    switch (s) {
      case MarketStructure.uptrend: return '上升趋势';
      case MarketStructure.downtrend: return '下降趋势';
      case MarketStructure.ranging: return '震荡';
      case MarketStructure.reversalPending: return '反转 pending';
    }
  }
}
