import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/signal.dart';
import '../utils/constants.dart';
import '../engine/long_cycle/long_cycle_manager.dart';
import '../engine/risk/risk_manager.dart';
import '../models/trade_recommendation.dart';
import '../models/market_data.dart';
import '../engine/time_prediction_engine.dart';
import '../widgets/hud_signal_panel.dart';
import '../engine/signal_lifecycle_manager.dart';
import '../widgets/kline_chart.dart';
import '../widgets/order_flow_visualization.dart';
import '../engine/news/news_analyzer.dart';
import '../engine/signal_quality_evaluator.dart';
import '../engine/sss/sss_analyzer.dart';

class SignalPanel extends StatelessWidget {
  const SignalPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        if (!app.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final signal = app.currentSignal;
        final riskLevel = app.riskState?.level ?? RiskLevel.L0;
        final isFrozen = riskLevel == RiskLevel.L3;
        final longCycle = app.longCycleResult;
        final currentPrice = app.ethPrice;

        return RefreshIndicator(
          onRefresh: () => app.manualRefresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 状态卡片
              _buildStatusCard(app, riskLevel, longCycle, currentPrice),
              const SizedBox(height: 16),
              // 信号或市场分析（HUD风格）
              if (signal != null && signal.status == SignalStatus.confirmed && !isFrozen)
                HudSignalPanel(app: app)
              else
                _buildMarketAnalysisCard(app, longCycle, riskLevel, currentPrice),
              const SizedBox(height: 16),
              // K线图表
              if (app.marketData.getEth5m().isNotEmpty)
                KlineChart(
                  klines: app.marketData.getEth5m(),
                  supportLevels: app.longCycleResult?.supportLevels?.map((e) => e.mid).toList(),
                  resistanceLevels: app.longCycleResult?.resistanceLevels?.map((e) => e.mid).toList(),
                  entryLower: app.tradeRecommendation.entryLower,
                  entryUpper: app.tradeRecommendation.entryUpper,
                  stopLoss: app.tradeRecommendation.stopLoss,
                  tp1: app.tradeRecommendation.tp1,
                  tp2: app.tradeRecommendation.tp2,
                  height: 280,
                ),
              if (app.marketData.getEth5m().isNotEmpty)
                const SizedBox(height: 16),
              // 推单区
              _buildTradeRecommendationCard(app),
              const SizedBox(height: 16),
              // 消息面分析（SSS级）
              _buildNewsAnalysisCard(),
              const SizedBox(height: 16),
              // 关键价位
              if (longCycle != null)
                _buildKeyLevelsCard(longCycle, currentPrice),
              const SizedBox(height: 16),
              // 市场结构
              _buildMarketInfoCard(app, longCycle),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(AppState app, RiskLevel riskLevel, LongCycleResult? longCycle, double currentPrice) {
    final color = _riskColor(riskLevel);
    final regime = app.marketRegime;
    final mtf = app.mtfResult;

    return Card(
      elevation: 2,
      color: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: color, size: 20),
                const SizedBox(width: 8),
                Text('风险等级: ${riskLevel.name}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Text(app.riskState?.reasonText ?? '正常', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            if (regime != null)
              Text('市场状态: ${regime.description}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
            if (mtf != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('多周期: ${mtf.description}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ),
            if (app.adaptiveParams != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('波动率: ${app.adaptiveParams!.volatilityLabel} | 确认次数: ${app.adaptiveParams!.confirmationCount} | 最低盈亏比: ${app.adaptiveParams!.minRiskReward.toStringAsFixed(1)}:1',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketAnalysisCard(AppState app, LongCycleResult? longCycle, RiskLevel riskLevel, double currentPrice) {
    String outlook = '数据加载中...';
    String suggestion = '正在获取K线和订单流数据，请稍候。';
    Color outlookColor = Colors.grey;

    if (longCycle != null) {
      final state = longCycle.state;
      final structure = longCycle.structure.structure;

      if (riskLevel == RiskLevel.L3) {
        outlook = '极端风险，观望为主';
        suggestion = '当前触发极端风险条件，禁止开仓。';
        outlookColor = Colors.red;
      } else if (riskLevel == RiskLevel.L2) {
        outlook = '高危环境，只做逆势反转';
        suggestion = 'BTC结构破位，顺势信号屏蔽，只抓反转机会。仓位降至1/3。';
        outlookColor = Colors.orange;
      } else if (state == LongCycleState.supportValid) {
        outlook = '接近支撑区，关注多头机会';
        suggestion = '价格进入支撑带，等待流动性清扫+订单流反转确认。';
        outlookColor = Colors.green;
      } else if (state == LongCycleState.resistanceValid) {
        outlook = '接近压力区，关注空头机会';
        suggestion = '价格进入压力带，等待流动性清扫+订单流反转确认。';
        outlookColor = Colors.red;
      } else if (state == LongCycleState.trendExhaustion) {
        outlook = '趋势衰竭，反转概率上升';
        suggestion = 'OI背离+资金费率极端，密切关注订单流变化。';
        outlookColor = Colors.purple;
      } else {
        outlook = '中性区间，无明确机会';
        suggestion = '价格远离关键位，耐心等待。';
        outlookColor = Colors.grey;
      }

      if (structure == MarketStructure.uptrend) {
        suggestion += ' 大趋势向上。';
      } else if (structure == MarketStructure.downtrend) {
        suggestion += ' 大趋势向下。';
      }
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: outlookColor.withOpacity(0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: outlookColor, size: 24),
                const SizedBox(width: 8),
                const Text('行情预判', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: outlookColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(outlook, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: outlookColor)),
            ),
            const SizedBox(height: 12),
            Text(suggestion, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70)),
            const SizedBox(height: 8),
            if (currentPrice > 0)
              Text('当前价: \$${currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Colors.blue)),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeRecommendationCard(AppState app) {
    final rec = app.tradeRecommendation;
    final isLong = rec.direction == TradeRecommendationDirection.long;
    final isShort = rec.direction == TradeRecommendationDirection.short;
    final isWait = rec.direction == TradeRecommendationDirection.wait;
    final direction = isLong ? 'long' : isShort ? 'short' : 'long';
    final technicalScore = isWait ? 50.0 : (rec.isConfirmed ? 85.0 : 70.0);
    final sssResult = app.multiDimensionData.calculateSSSScore(direction, technicalScore: technicalScore);
    
    // 取消80分限制，所有信号都显示预计入场区间，评分仅作参考
    final isHighConfidence = sssResult.isHighConfidence;
    final showSignal = isLong || isShort; // 取消评分限制，所有信号都显示

    Color accentColor;
    if (showSignal && isLong) {
      accentColor = Colors.green;
    } else if (showSignal && isShort) {
      accentColor = Colors.red;
    } else {
      accentColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('推单区', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _buildQualityBadge(rec),
                    const SizedBox(width: 6),
                    _buildSSSBadge(sssResult),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor, width: 1),
                  ),
                  child: Text(
                    showSignal ? rec.directionText : '观望',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 预判区域：关键价位和预计评分
            _buildPredictionZone(app),
            const SizedBox(height: 8),
            if (rec.isConfirmed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('已确认信号', style: TextStyle(color: Colors.orange, fontSize: 11)),
              ),
            const SizedBox(height: 12),
            if (showSignal) ...[
              _recRow('开仓区间', rec.entryText, Colors.blue),
              const SizedBox(height: 8),
              _recRow('止损 SL', rec.slText, Colors.red),
              const SizedBox(height: 8),
              _recRow('止盈 TP1', rec.tp1Text, Colors.green),
              const SizedBox(height: 8),
              _recRow('止盈 TP2', rec.tp2Text, Colors.green),
              const SizedBox(height: 8),
              _recRow('盈亏比', rec.rrText, Colors.orange),
              const SizedBox(height: 8),
              _recRow('建议仓位', rec.positionText, Colors.purple),
              const SizedBox(height: 12),
              // 预计入场区间详情
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.ads_click, color: Colors.cyan, size: 14),
                        SizedBox(width: 4),
                        Text('预计入场区间', style: TextStyle(fontSize: 12, color: Colors.cyan, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _recRow('开仓区间', rec.entryText, Colors.blue),
                    const SizedBox(height: 6),
                    _recRow('最佳入场', isLong ? '区间下沿附近' : '区间上沿附近', Colors.cyan),
                    const SizedBox(height: 6),
                    _recRow('分批策略', '首仓40% / 确认加30% / 盈利加30%', Colors.purple),
                    const SizedBox(height: 6),
                    _recRow('有效期', '下一次轮询前有效（8秒）', Colors.orange),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('触发条件', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(rec.triggerCondition, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // SSS级多维度分析
              _buildSSSAnalysis(sssResult),
              const SizedBox(height: 12),
              // 情绪面深度分析
              _buildSentimentDeepAnalysis(app),
              const SizedBox(height: 12),
              // 技术面深度分析
              _buildTechnicalDeepAnalysis(app),
              const SizedBox(height: 12),
              // 订单流深度分析
              _buildOrderflowDeepAnalysis(app),
              const SizedBox(height: 12),
              // 风险管理
              _buildRiskManagement(app),
              const SizedBox(height: 12),
              // 时间因素
              _buildTimeFactor(app),
              const SizedBox(height: 12),
              // 信号生命周期状态
              _buildSignalLifecycleStatus(app),
              const SizedBox(height: 12),
              // 信号历史统计
              _buildSignalHistoryStats(app),
              const SizedBox(height: 12),
              // 账户风险状态
              _buildAccountRiskStatus(app),
              const SizedBox(height: 12),
              // 最终总结（所有模块服务于此）
              _buildFinalSummary(app),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHighConfidence ? Colors.grey.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isHighConfidence ? Colors.grey : Colors.orange, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isHighConfidence) ...[
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 16),
                          const SizedBox(width: 6),
                          Text('SSS级评分不足(${sssResult.totalScore.toStringAsFixed(0)}分<80分)，信号质量不达标',
                              style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('薄弱维度：${_getWeakDimensions(sssResult)}',
                          style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      const SizedBox(height: 6),
                    ],
                    Text(rec.reason, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(rec.reason, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  /// SSS级信号质量徽章
  Widget _buildQualityBadge(dynamic rec) {
    SignalQuality quality;
    try {
      final rr = rec.riskRewardRatio as double;
      final confirmed = rec.isConfirmed as bool;
      if (confirmed && rr >= 4) quality = SignalQuality.sss;
      else if (confirmed && rr >= 3) quality = SignalQuality.ss;
      else if (rr >= 3) quality = SignalQuality.s;
      else if (rr >= 2) quality = SignalQuality.a;
      else quality = SignalQuality.b;
    } catch (_) {
      quality = SignalQuality.b;
    }

    Color badgeColor = Colors.orange;
    switch (quality) {
      case SignalQuality.sss: badgeColor = const Color(0xFFFFD700); break;
      case SignalQuality.ss: badgeColor = const Color(0xFFC0C0C0); break;
      case SignalQuality.s: badgeColor = const Color(0xFFCD7F32); break;
      case SignalQuality.a: badgeColor = Colors.green; break;
      case SignalQuality.b: badgeColor = Colors.orange; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        quality.name.toUpperCase(),
        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _recRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white60)),
        Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// 消息面分析卡片（SSS级）
  Widget _buildNewsAnalysisCard() {
    final newsAnalyzer = NewsAnalyzer();
    final result = newsAnalyzer.analyze();

    Color sentimentColor;
    if (result.overallSentiment == NewsSentiment.bullish) sentimentColor = Colors.green;
    else if (result.overallSentiment == NewsSentiment.bearish) sentimentColor = Colors.red;
    else sentimentColor = Colors.grey;

    return Card(
      elevation: 2,
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.newspaper, size: 18, color: Colors.blue),
                    SizedBox(width: 6),
                    Text('消息面分析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sentimentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: sentimentColor),
                  ),
                  child: Text(
                    result.overallSentiment.name.toUpperCase(),
                    style: TextStyle(color: sentimentColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 情绪评分条
            Row(
              children: [
                const Text('情绪评分', style: TextStyle(fontSize: 12, color: Colors.white60)),
                const Spacer(),
                Text('${result.overallSentimentScore.toStringAsFixed(0)}/100',
                    style: TextStyle(fontSize: 12, color: sentimentColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (result.overallSentimentScore + 100) / 200,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(sentimentColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            // 统计
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _newsStat('高影响', '${result.highImpactNewsCount}', Colors.orange),
                _newsStat('利好', '${result.bullishNewsCount}', Colors.green),
                _newsStat('利空', '${result.bearishNewsCount}', Colors.red),
                _newsStat('预估影响', '${result.estimatedPriceImpact.toStringAsFixed(1)}%',
                    result.estimatedPriceImpact >= 0 ? Colors.green : Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            // 建议
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(result.recommendation, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
            const SizedBox(height: 12),
            // 最近新闻
            const Text('最近消息', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 8),
            ...result.recentNews.take(3).map((news) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    color: news.sentiment == NewsSentiment.bullish ? Colors.green
                        : news.sentiment == NewsSentiment.bearish ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(news.title, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text('${news.typeLabel} · ${news.impactLabel} · ${news.source}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _newsStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildKeyLevelsCard(LongCycleResult longCycle, double currentPrice) {
    final supports = longCycle.supportLevels;
    final resistances = longCycle.resistanceLevels;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('关键价位 & 预估开仓区', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('压力位（做空目标区）', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (resistances.isEmpty)
              const Text('计算中...', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ...resistances.take(2).map((level) => _levelRow(level.mid, level.strength, 'resistance', currentPrice)),
            const Divider(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text('当前价 \$${currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            ),
            const Divider(height: 20),
            const Text('支撑位（做多目标区）', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (supports.isEmpty)
              const Text('计算中...', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ...supports.take(2).map((level) => _levelRow(level.mid, level.strength, 'support', currentPrice)),
          ],
        ),
      ),
    );
  }

  Widget _levelRow(double price, int strength, String type, double currentPrice) {
    final color = type == 'support' ? Colors.green : Colors.red;
    final distance = currentPrice > 0 ? ((price - currentPrice).abs() / currentPrice * 100) : 0;
    final stars = '★' * strength + '☆' * (3 - strength);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(type == 'support' ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 16),
          const SizedBox(width: 6),
          Text('\$${price.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(width: 8),
          Text(stars, style: const TextStyle(fontSize: 12, color: Colors.amber)),
          const Spacer(),
          Text('${distance.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMarketInfoCard(AppState app, LongCycleResult? longCycle) {
    final orderFlow = app.deepOrderFlow;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('市场结构 & 订单流', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow('长周期状态', longCycle?.state.name ?? '加载中'),
            _infoRow('市场结构', longCycle?.structure.structure.name ?? '-'),
            _infoRow('结构描述', longCycle?.structure.description ?? '-'),
            _infoRow('波动率', longCycle?.volatility.state ?? '-'),
            _infoRow('资金费率状态', longCycle?.fundingState ?? '-'),
            _infoRow('OI背离', (longCycle?.hasOIDivergence ?? false) ? '是 ⚠️' : '否'),
            if (orderFlow != null) ...[
              const Divider(height: 16),
              _infoRow('订单流', orderFlow.summary),
              _infoRow('WS连接', app.marketData.orderFlow.isConnected ? '已连接' : '连接中...'),
              _infoRow('大单方向', orderFlow.largeOrders.description),
              _infoRow('成交密集区', '\$${orderFlow.volumeDensity.highestDensityPrice.toStringAsFixed(2)}'),
              _infoRow('清算风险', orderFlow.liquidation.description),
              _infoRow('盘口状态', orderFlow.orderBook.description),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignalCard(TradingSignal signal, AppState app) {
    final isLong = signal.direction == SignalDirection.long;
    final color = isLong ? Colors.green : Colors.red;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isLong ? Icons.trending_up : Icons.trending_down, color: color, size: 28),
                const SizedBox(width: 8),
                Text(isLong ? '多头候选' : '空头候选', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('置信度 ${signal.confidenceScore}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _priceRow('开仓区间', '\$${signal.entryLower.toStringAsFixed(2)} - \$${signal.entryUpper.toStringAsFixed(2)}', Colors.blue),
            _priceRow('止损 SL', '\$${signal.stopLoss.toStringAsFixed(2)}', Colors.red),
            _priceRow('止盈 TP1', '\$${signal.tp1.toStringAsFixed(2)} (减仓60%)', Colors.orange),
            _priceRow('止盈 TP2', '\$${signal.tp2.toStringAsFixed(2)} (全平)', Colors.green),
            _priceRow('盈亏比', '${signal.riskRewardRatio.toStringAsFixed(2)}:1', signal.riskRewardRatio >= 4 ? Colors.green : Colors.orange),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.check),
                    label: const Text('已执行'),
                    onPressed: () => app.markSignalExecuted(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
                    icon: const Icon(Icons.close),
                    label: const Text('忽略'),
                    onPressed: () => app.markSignalExecuted(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _getWeakDimensions(SSSResult sss) {
    final weak = <String>[];
    if (sss.technicalScore < 70) weak.add('技术面');
    if (sss.newsScore < 70) weak.add('消息面');
    if (sss.macroScore < 70) weak.add('宏观面');
    if (sss.sentimentScore < 70) weak.add('情绪面');
    if (sss.capitalScore < 70) weak.add('资金面');
    return weak.isEmpty ? '综合评分偏低' : weak.join('、');
  }

  Widget _buildSSSBadge(SSSResult sss) {
    Color color;
    if (sss.totalScore >= 85) color = Colors.purple;
    else if (sss.totalScore >= 75) color = Colors.blue;
    else if (sss.totalScore >= 60) color = Colors.orange;
    else color = Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text('${sss.grade} ${sss.totalScore.toStringAsFixed(0)}分',
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSSSAnalysis(SSSResult sss) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SSS级多维度分析', style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w600)),
              Text(sss.recommendation, style: TextStyle(fontSize: 11, color: sss.isHighConfidence ? Colors.green : Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          _buildScoreBar('技术面', sss.technicalScore, Colors.blue),
          const SizedBox(height: 4),
          _buildScoreBar('消息面', sss.newsScore, Colors.orange),
          const SizedBox(height: 4),
          _buildScoreBar('宏观面', sss.macroScore, Colors.cyan),
          const SizedBox(height: 4),
          _buildScoreBar('情绪面', sss.sentimentScore, Colors.pink),
          const SizedBox(height: 4),
          _buildScoreBar('资金面', sss.capitalScore, Colors.teal),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, double score, Color color) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('${score.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// 情绪面深度分析
  Widget _buildSentimentDeepAnalysis(AppState app) {
    final mdd = app.multiDimensionData;
    final fearGreed = mdd.fearGreedIndex;
    final longShort = mdd.longShortRatio;
    final fundingRate = mdd.exchangeFlow; // 临时存储资金费率
    final openInterest = mdd.openInterestChange; // 临时存储持仓量

    // 贪婪恐惧指数解读
    String fearGreedLabel;
    Color fearGreedColor;
    if (fearGreed >= 75) {
      fearGreedLabel = '极度贪婪（警惕见顶）';
      fearGreedColor = Colors.red;
    } else if (fearGreed >= 55) {
      fearGreedLabel = '贪婪（偏多）';
      fearGreedColor = Colors.orange;
    } else if (fearGreed >= 45) {
      fearGreedLabel = '中性';
      fearGreedColor = Colors.grey;
    } else if (fearGreed >= 25) {
      fearGreedLabel = '恐惧（偏空）';
      fearGreedColor = Colors.blue;
    } else {
      fearGreedLabel = '极度恐惧（警惕见底）';
      fearGreedColor = Colors.green;
    }

    // 多空比解读
    String longShortLabel;
    Color longShortColor;
    if (longShort > 1.5) {
      longShortLabel = '多头拥挤（警惕回调）';
      longShortColor = Colors.red;
    } else if (longShort > 1.2) {
      longShortLabel = '偏多';
      longShortColor = Colors.orange;
    } else if (longShort >= 0.8) {
      longShortLabel = '均衡';
      longShortColor = Colors.grey;
    } else if (longShort >= 0.5) {
      longShortLabel = '偏空';
      longShortColor = Colors.blue;
    } else {
      longShortLabel = '空头拥挤（警惕反弹）';
      longShortColor = Colors.green;
    }

    // 资金费率解读
    String fundingLabel;
    Color fundingColor;
    if (fundingRate > 0.05) {
      fundingLabel = '多头付费高（多头拥挤）';
      fundingColor = Colors.red;
    } else if (fundingRate > 0.01) {
      fundingLabel = '正费率（偏多）';
      fundingColor = Colors.orange;
    } else if (fundingRate >= -0.01) {
      fundingLabel = '中性';
      fundingColor = Colors.grey;
    } else if (fundingRate >= -0.05) {
      fundingLabel = '负费率（偏空）';
      fundingColor = Colors.blue;
    } else {
      fundingLabel = '空头付费高（空头拥挤）';
      fundingColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.pink.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.pink.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: Colors.pink, size: 14),
              SizedBox(width: 4),
              Text('情绪面深度分析', style: TextStyle(fontSize: 12, color: Colors.pink, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _recRow('贪婪恐惧指数', '${fearGreed.toStringAsFixed(0)} - $fearGreedLabel', fearGreedColor),
          const SizedBox(height: 6),
          _recRow('多空比', longShort > 0 ? '${longShort.toStringAsFixed(2)} - $longShortLabel' : '未接入', longShort > 0 ? longShortColor : Colors.grey),
          const SizedBox(height: 6),
          _recRow('资金费率', fundingRate != 0 ? '${(fundingRate / 10000).toStringAsFixed(4)}% - $fundingLabel' : '未接入', fundingRate != 0 ? fundingColor : Colors.grey),
          const SizedBox(height: 6),
          _recRow('持仓量OI', openInterest > 0 ? '${(openInterest / 1000).toStringAsFixed(1)}K 张' : '未接入', Colors.teal),
        ],
      ),
    );
  }

  /// 预判区域：关键价位和预计评分/胜率
  Widget _buildPredictionZone(AppState app) {
    final currentPrice = app.ethPrice;
    final longCycle = app.longCycleResult;
    final nearestSupport = longCycle?.nearestSupport?.mid ?? 0;
    final nearestResistance = longCycle?.nearestResistance?.mid ?? 0;

    // 基于当前市场环境估算到达关键位置时的评分
    // 假设价格到达支撑/压力位时技术面条件改善，评分+15分
    final baseScore = app.multiDimensionData.calculateSSSScore(
      nearestSupport < currentPrice ? 'long' : 'short',
      technicalScore: 70,
    ).totalScore;
    final predictedLongScore = (baseScore + 15).clamp(0, 100).toDouble();
    final predictedShortScore = (baseScore + 15).clamp(0, 100).toDouble();

    // 根据评分估算胜率
    String winRateFromScore(double score) {
      if (score >= 85) return '≥70%';
      if (score >= 80) return '65-70%';
      if (score >= 75) return '60-65%';
      if (score >= 70) return '55-60%';
      if (score >= 60) return '50-55%';
      return '<50%';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.track_changes, color: Colors.amber, size: 14),
              SizedBox(width: 4),
              Text('预判区域（关键价位）', style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _recRow('当前价格', '\$${currentPrice.toStringAsFixed(2)}', Colors.white),
          const SizedBox(height: 6),
          if (nearestSupport > 0) ...[
            _recRow('支撑位（做多）', '\$${nearestSupport.toStringAsFixed(2)}', Colors.green),
            const SizedBox(height: 4),
            _recRow('  预计评分', '${predictedLongScore.toStringAsFixed(0)}分', Colors.green),
            const SizedBox(height: 4),
            _recRow('  预计胜率', winRateFromScore(predictedLongScore), Colors.green),
            const SizedBox(height: 4),
            _recRow('  止损SL', '\$${(nearestSupport * 0.985).toStringAsFixed(2)}', Colors.red),
            const SizedBox(height: 4),
            _recRow('  止盈TP1', '\$${(nearestSupport * 1.04).toStringAsFixed(2)}', Colors.green),
            const SizedBox(height: 4),
            _recRow('  止盈TP2', '\$${(nearestSupport * 1.08).toStringAsFixed(2)}', Colors.green),
            const SizedBox(height: 6),
          ],
          if (nearestResistance > 0) ...[
            _recRow('压力位（做空）', '\$${nearestResistance.toStringAsFixed(2)}', Colors.red),
            const SizedBox(height: 4),
            _recRow('  预计评分', '${predictedShortScore.toStringAsFixed(0)}分', Colors.red),
            const SizedBox(height: 4),
            _recRow('  预计胜率', winRateFromScore(predictedShortScore), Colors.red),
            const SizedBox(height: 4),
            _recRow('  止损SL', '\$${(nearestResistance * 1.015).toStringAsFixed(2)}', Colors.red),
            const SizedBox(height: 4),
            _recRow('  止盈TP1', '\$${(nearestResistance * 0.96).toStringAsFixed(2)}', Colors.green),
            const SizedBox(height: 4),
            _recRow('  止盈TP2', '\$${(nearestResistance * 0.92).toStringAsFixed(2)}', Colors.green),
          ],
          if (nearestSupport == 0 && nearestResistance == 0)
            const Text('关键价位计算中...', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  /// 技术面深度分析
  Widget _buildTechnicalDeepAnalysis(AppState app) {
    final klines = app.marketData.getEth5m(); // 从marketData获取真实5分钟K线
    final analysis = app.enhancement.analyzeTechnical(klines: klines, direction: 'long');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue, size: 14),
              SizedBox(width: 4),
              Text('技术面深度分析', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _recRow('K线形态', analysis.pattern, Colors.white),
          const SizedBox(height: 6),
          _recRow('RSI(14)', '${analysis.rsi.toStringAsFixed(1)} - ${analysis.rsiStatus}', analysis.rsi >= 70 ? Colors.red : analysis.rsi <= 30 ? Colors.green : Colors.grey),
          const SizedBox(height: 6),
          _recRow('MACD', analysis.macdStatus, analysis.macdStatus.contains('金叉') || analysis.macdStatus.contains('多头') ? Colors.green : analysis.macdStatus.contains('死叉') || analysis.macdStatus.contains('空头') ? Colors.red : Colors.grey),
          const SizedBox(height: 6),
          _recRow('布林带', analysis.bollingerPosition, analysis.bollingerPosition.contains('上轨') ? Colors.red : analysis.bollingerPosition.contains('下轨') ? Colors.green : Colors.grey),
          const SizedBox(height: 6),
          _recRow('多周期共振', analysis.mtfText, analysis.mtfResonance >= 3 ? Colors.green : analysis.mtfResonance >= 2 ? Colors.orange : Colors.grey),
          const SizedBox(height: 6),
          _recRow('流动性清扫', analysis.liquiditySweep ? '已检测（反转信号）' : '未检测', analysis.liquiditySweep ? Colors.orange : Colors.grey),
        ],
      ),
    );
  }

  /// 订单流深度分析（从deepOrderFlow获取真实数据）
  Widget _buildOrderflowDeepAnalysis(AppState app) {
    final of = app.deepOrderFlow;
    final largeOrders = of?.largeOrders;
    final volumeDensity = of?.volumeDensity;
    final liquidation = of?.liquidation;
    final orderBook = of?.orderBook;

    // 大单方向
    String bigOrderDir = '数据不足';
    Color bigOrderColor = Colors.grey;
    if (largeOrders != null) {
      if (largeOrders.bullishPressure) {
        bigOrderDir = '买盘主导（买${largeOrders.buyLargeOrders}/卖${largeOrders.sellLargeOrders}）';
        bigOrderColor = Colors.green;
      } else if (largeOrders.bearishPressure) {
        bigOrderDir = '卖盘主导（买${largeOrders.buyLargeOrders}/卖${largeOrders.sellLargeOrders}）';
        bigOrderColor = Colors.red;
      } else {
        bigOrderDir = '多空均衡（买${largeOrders.buyLargeOrders}/卖${largeOrders.sellLargeOrders}）';
      }
    }

    // 清算挤压
    String liquidationText = '数据不足';
    Color liquidationColor = Colors.grey;
    if (liquidation != null) {
      if (liquidation.longSqueezeRisk) {
        liquidationText = '多头挤压风险（可能推高）';
        liquidationColor = Colors.green;
      } else if (liquidation.shortSqueezeRisk) {
        liquidationText = '空头挤压风险（可能砸低）';
        liquidationColor = Colors.red;
      } else {
        liquidationText = '无明显挤压';
      }
    }

    // 订单簿失衡
    String orderBookText = '数据不足';
    Color orderBookColor = Colors.grey;
    if (orderBook != null) {
      if (orderBook.bidHeavy) {
        orderBookText = '买盘较重（承接强）';
        orderBookColor = Colors.green;
      } else if (orderBook.askHeavy) {
        orderBookText = '卖盘较重（抛压大）';
        orderBookColor = Colors.red;
      } else {
        orderBookText = '买卖均衡';
      }
    }

    // 成交密集区
    final densityPrice = volumeDensity?.highestDensityPrice ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.teal, size: 14),
              SizedBox(width: 4),
              Text('订单流深度分析', style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _recRow('大单方向', bigOrderDir, bigOrderColor),
          const SizedBox(height: 6),
          _recRow('大单比例', largeOrders != null ? '${largeOrders.largeOrderRatio.toStringAsFixed(2)}' : '数据不足', Colors.grey),
          const SizedBox(height: 6),
          _recRow('订单簿', orderBookText, orderBookColor),
          const SizedBox(height: 6),
          _recRow('买卖深度比', orderBook != null ? '${orderBook.bidAskRatio.toStringAsFixed(2)}' : '数据不足', Colors.grey),
          const SizedBox(height: 6),
          _recRow('清算挤压', liquidationText, liquidationColor),
          const SizedBox(height: 6),
          _recRow('成交密集区', densityPrice > 0 ? '\$${densityPrice.toStringAsFixed(2)}' : '数据不足', Colors.cyan),
          const SizedBox(height: 6),
          _recRow('综合信号', of != null ? '看涨${of.bullishSignals}/看跌${of.bearishSignals}' : '数据不足', of != null && of.bullishSignals > of.bearishSignals ? Colors.green : of != null && of.bearishSignals > of.bullishSignals ? Colors.red : Colors.grey),
        ],
      ),
    );
  }

  /// 风险管理
  Widget _buildRiskManagement(AppState app) {
    final rec = app.tradeRecommendation;
    final entry = (rec.entryLower + rec.entryUpper) / 2 > 0 ? (rec.entryLower + rec.entryUpper) / 2 : app.ethPrice;
    final sl = rec.stopLoss > 0 ? rec.stopLoss : entry * 0.985;
    final tp1 = rec.tp1 > 0 ? rec.tp1 : entry * 1.04;
    final tp2 = rec.tp2 > 0 ? rec.tp2 : entry * 1.08;

    final risk = app.enhancement.calculateRisk(
      accountBalance: 10000, // 默认账户余额，用户可在设置中修改
      entryPrice: entry,
      sl: sl,
      tp1: tp1,
      tp2: tp2,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield, color: Colors.purple, size: 14),
              SizedBox(width: 4),
              Text('风险管理（1%风险）', style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _recRow('单笔风险金额', '\$${risk.riskAmount.toStringAsFixed(2)}', Colors.red),
          const SizedBox(height: 6),
          _recRow('建议仓位', '${risk.positionSize.toStringAsFixed(4)} ETH', Colors.blue),
          const SizedBox(height: 6),
          _recRow('首批40%', '${risk.batch1Size.toStringAsFixed(4)} ETH', Colors.cyan),
          const SizedBox(height: 6),
          _recRow('二批30%', '${risk.batch2Size.toStringAsFixed(4)} ETH', Colors.cyan),
          const SizedBox(height: 6),
          _recRow('三批30%', '${risk.batch3Size.toStringAsFixed(4)} ETH', Colors.cyan),
          const SizedBox(height: 6),
          _recRow('盈亏比TP1', '${risk.rr1.toStringAsFixed(1)}:1', risk.rr1 >= 4 ? Colors.green : Colors.orange),
          const SizedBox(height: 6),
          _recRow('盈亏比TP2', '${risk.rr2.toStringAsFixed(1)}:1', risk.rr2 >= 4 ? Colors.green : Colors.orange),
        ],
      ),
    );
  }

  /// 时间因素
  Widget _buildTimeFactor(AppState app) {
    final timeFactor = app.enhancement.getTimeFactor(
      signalTime: DateTime.now(), // 信号生成时间
      pollIntervalSeconds: 8,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time, color: Colors.orange, size: 14),
              SizedBox(width: 4),
              Text('时间因素', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _recRow('信号生成', timeFactor.signalTime.toString().substring(11, 19), Colors.white),
          const SizedBox(height: 6),
          _recRow('已过时间', timeFactor.elapsedText, Colors.grey),
          const SizedBox(height: 6),
          _recRow('下次轮询', '${timeFactor.remainingSeconds}秒后', Colors.cyan),
          const SizedBox(height: 6),
          _recRow('交易时段', timeFactor.session, timeFactor.isHighVolatility ? Colors.red : Colors.blue),
          const SizedBox(height: 6),
          _recRow('波动预期', timeFactor.isHighVolatility ? '高波动（谨慎）' : '正常波动', timeFactor.isHighVolatility ? Colors.red : Colors.green),
        ],
      ),
    );
  }

  /// 信号生命周期状态
  Widget _buildSignalLifecycleStatus(AppState app) {
    final signal = app.lifecycle.currentActiveSignal;
    final stats = app.lifecycle.getHistoryStats();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.autorenew, color: Colors.indigo, size: 14),
              SizedBox(width: 4),
              Text('信号生命周期', style: TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (signal != null) ...[
            _recRow('信号ID', signal.id, Colors.grey),
            const SizedBox(height: 4),
            _recRow('当前状态', signal.stateText, _getStateColor(signal.state)),
            const SizedBox(height: 4),
            _recRow('生成时间', signal.generatedAt.toString().substring(11, 19), Colors.grey),
            const SizedBox(height: 4),
            if (signal.confirmedAt != null)
              _recRow('确认时间', signal.confirmedAt.toString().substring(11, 19), Colors.blue),
            if (signal.confirmedAt != null) const SizedBox(height: 4),
            _recRow('触达次数', '${signal.triggerCount}次', signal.triggerCount > 0 ? Colors.green : Colors.grey),
            const SizedBox(height: 4),
            _recRow('累计停留', '${signal.totalTriggerDuration.inMinutes}分${signal.totalTriggerDuration.inSeconds % 60}秒', Colors.cyan),
            const SizedBox(height: 4),
            _recRow('持续时间', '${signal.duration.inMinutes}分${signal.duration.inSeconds % 60}秒', Colors.orange),
            const SizedBox(height: 4),
            _recRow('SSS评分', '${signal.sssScore.toStringAsFixed(0)}分', signal.sssScore >= 80 ? Colors.green : signal.sssScore >= 60 ? Colors.orange : Colors.red),
          ] else ...[
            const Text('当前无活跃信号', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            _recRow('历史信号数', '${stats.totalSignals}个', Colors.grey),
            const SizedBox(height: 4),
            _recRow('历史胜率', stats.winRateText, stats.winRate >= 60 ? Colors.green : Colors.red),
          ],
        ],
      ),
    );
  }

  Color _getStateColor(SignalLifecycleState state) {
    switch (state) {
      case SignalLifecycleState.newlyGenerated:
        return Colors.grey;
      case SignalLifecycleState.candidate:
        return Colors.blue;
      case SignalLifecycleState.confirmed:
        return Colors.orange;
      case SignalLifecycleState.triggered:
        return Colors.green;
      case SignalLifecycleState.closed:
        return Colors.teal;
      case SignalLifecycleState.expired:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// 信号历史统计
  Widget _buildSignalHistoryStats(AppState app) {
    final stats = app.lifecycle.getHistoryStats();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.teal, size: 14),
              SizedBox(width: 4),
              Text('信号历史统计', style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _recRow('总信号数', '${stats.totalSignals}个', Colors.white),
          const SizedBox(height: 4),
          _recRow('历史胜率', stats.winRateText, stats.winRate >= 60 ? Colors.green : Colors.red),
          const SizedBox(height: 4),
          _recRow('平均盈亏', stats.avgPnlText, stats.avgPnl >= 0 ? Colors.green : Colors.red),
          const SizedBox(height: 4),
          _recRow('最大回撤', '${stats.maxDrawdown.toStringAsFixed(2)}%', stats.maxDrawdown > 5 ? Colors.red : Colors.orange),
          const SizedBox(height: 4),
          _recRow('当前连盈亏', stats.currentStreakText, stats.currentStreak >= 0 ? Colors.green : Colors.red),
          const SizedBox(height: 4),
          _recRow('最大连盈', '${stats.maxWinStreak}次', Colors.green),
          const SizedBox(height: 4),
          _recRow('最大连亏', '${stats.maxLossStreak}次', Colors.red),
        ],
      ),
    );
  }

  /// 账户风险状态
  Widget _buildAccountRiskStatus(AppState app) {
    final risk = app.accountRisk;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.deepOrange, size: 14),
              SizedBox(width: 4),
              Text('账户风险状态', style: TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _recRow('账户余额', '\$${risk.accountBalance.toStringAsFixed(2)}', Colors.white),
          const SizedBox(height: 4),
          _recRow('单笔风险', '${risk.singleRiskPercent.toStringAsFixed(1)}% (\$${risk.singleRiskAmount.toStringAsFixed(2)})', Colors.blue),
          const SizedBox(height: 4),
          _recRow('总风险上限', '${risk.totalRiskPercent.toStringAsFixed(1)}% (\$${risk.totalRiskAmount.toStringAsFixed(2)})', Colors.orange),
          const SizedBox(height: 4),
          _recRow('当前风险占用', '${risk.currentTotalRisk.toStringAsFixed(1)}%', risk.currentTotalRisk > risk.totalRiskPercent * 0.8 ? Colors.red : risk.currentTotalRisk > 0 ? Colors.orange : Colors.green),
          const SizedBox(height: 4),
          _recRow('风险状态', risk.riskStatusText, risk.currentTotalRisk > risk.totalRiskPercent * 0.8 ? Colors.red : Colors.green),
          const SizedBox(height: 4),
          _recRow('连续亏损', risk.consecutiveLossProtectionText, risk.consecutiveLosses >= 3 ? Colors.red : risk.consecutiveLosses > 0 ? Colors.orange : Colors.green),
          const SizedBox(height: 4),
          _recRow('当前持仓', '${risk.openPositions.length}个', risk.openPositions.length >= risk.maxConcurrentPositions ? Colors.red : Colors.blue),
        ],
      ),
    );
  }

  /// 最终总结（所有模块服务于此，给出最终订单设计）
  Widget _buildFinalSummary(AppState app) {
    final rec = app.tradeRecommendation;
    final isLong = rec.direction == TradeRecommendationDirection.long;
    final isShort = rec.direction == TradeRecommendationDirection.short;
    final currentPrice = app.ethPrice;
    final entry = (rec.entryLower + rec.entryUpper) / 2;
    final sl = rec.stopLoss;
    final tp1 = rec.tp1;
    final tp2 = rec.tp2;

    // 综合评分（从SSS级获取）
    final direction = isLong ? 'long' : isShort ? 'short' : 'long';
    final technicalScore = isLong || isShort ? 75.0 : 50.0;
    final sssResult = app.multiDimensionData.calculateSSSScore(direction, technicalScore: technicalScore);
    final totalScore = sssResult.totalScore;

    // 信心度
    String confidence;
    Color confidenceColor;
    if (totalScore >= 85) {
      confidence = '极高信心（SSS级）';
      confidenceColor = Colors.green;
    } else if (totalScore >= 75) {
      confidence = '高信心（SS级）';
      confidenceColor = Colors.lightGreen;
    } else if (totalScore >= 65) {
      confidence = '中等信心（S级）';
      confidenceColor = Colors.orange;
    } else {
      confidence = '低信心（谨慎）';
      confidenceColor = Colors.red;
    }

    // 预计到达时间（使用8因素时间预测引擎）
    final klines = app.marketData.getEth5m(); // 从marketData获取真实5分钟K线
    final etaEntryResult = TimePredictionEngine.predict(
      currentPrice: currentPrice,
      targetPrice: entry,
      klines: klines,
      direction: isLong ? 'long' : 'short',
      currentTime: DateTime.now(),
    );
    final etaTp1Result = TimePredictionEngine.predict(
      currentPrice: currentPrice,
      targetPrice: tp1,
      klines: klines,
      direction: isLong ? 'long' : 'short',
      currentTime: DateTime.now(),
    );
    final etaTp2Result = TimePredictionEngine.predict(
      currentPrice: currentPrice,
      targetPrice: tp2,
      klines: klines,
      direction: isLong ? 'long' : 'short',
      currentTime: DateTime.now(),
    );

    // 最终方向
    String finalDirection;
    Color directionColor;
    if (isLong) {
      finalDirection = '最终建议：做多';
      directionColor = Colors.green;
    } else if (isShort) {
      finalDirection = '最终建议：做空';
      directionColor = Colors.red;
    } else {
      finalDirection = '最终建议：观望';
      directionColor = Colors.grey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withOpacity(0.3),
            Colors.purple.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.flag, color: Colors.purpleAccent, size: 16),
                  SizedBox(width: 6),
                  Text('最终总结 & 订单设计', style: TextStyle(fontSize: 14, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: confidenceColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(confidence, style: TextStyle(color: confidenceColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 最终方向
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: directionColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: directionColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(finalDirection, style: TextStyle(color: directionColor, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('综合评分：${totalScore.toStringAsFixed(0)}分', style: TextStyle(color: directionColor, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 订单设计
          if (isLong || isShort) ...[
            _recRow('入场区间', '\$${rec.entryLower.toStringAsFixed(2)} - \$${rec.entryUpper.toStringAsFixed(2)}', Colors.blue),
            const SizedBox(height: 6),
            _recRow('止损SL', '\$${sl.toStringAsFixed(2)}', Colors.red),
            const SizedBox(height: 6),
            _recRow('止盈TP1', '\$${tp1.toStringAsFixed(2)}', Colors.green),
            const SizedBox(height: 6),
            _recRow('止盈TP2', '\$${tp2.toStringAsFixed(2)}', Colors.green),
            const SizedBox(height: 6),
            _recRow('盈亏比', '${rec.riskRewardRatio.toStringAsFixed(1)}:1', rec.riskRewardRatio >= 4 ? Colors.green : Colors.orange),
            const SizedBox(height: 6),
            _recRow('建议仓位', '${(rec.positionSize * 100).toStringAsFixed(0)}%', Colors.purple),
            const SizedBox(height: 10),
            // 预计到达时间（8因素时间预测引擎）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timer, color: Colors.cyan, size: 14),
                          SizedBox(width: 4),
                          Text('预计到达时间（8因素预测引擎）', style: TextStyle(fontSize: 12, color: Colors.cyan, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: etaTp1Result.confidence >= 60 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('置信度 ${etaTp1Result.confidenceText}', style: TextStyle(fontSize: 10, color: etaTp1Result.confidence >= 60 ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _recRow('到达入场区', '${etaEntryResult.mostLikely}（最快${etaEntryResult.fastest}/最慢${etaEntryResult.slowest}）', Colors.blue),
                  const SizedBox(height: 4),
                  _recRow('到达TP1', '${etaTp1Result.mostLikely}（最快${etaTp1Result.fastest}/最慢${etaTp1Result.slowest}）', Colors.green),
                  const SizedBox(height: 4),
                  _recRow('到达TP2', '${etaTp2Result.mostLikely}（最快${etaTp2Result.fastest}/最慢${etaTp2Result.slowest}）', Colors.green),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.cyan, height: 1),
                  const SizedBox(height: 6),
                  const Text('预测因素（8维度）', style: TextStyle(fontSize: 11, color: Colors.cyan, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ...etaTp1Result.factors.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(e.value, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // 执行建议
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('执行建议', style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    totalScore >= 75
                        ? '1. 分批建仓：首仓40%，确认后加30%，盈利后加30%\n2. 严格止损：到达SL立即平仓，不扛单\n3. TP1减仓60%，止损移至成本\n4. TP2全部平仓，落袋为安'
                        : totalScore >= 65
                            ? '1. 轻仓试探：仓位减半，严格止损\n2. 等待确认：信号确认后再加仓\n3. 到达TP1减仓50%\n4. 密切关注行情变化'
                            : '1. 建议观望：信号质量不足，不建议入场\n2. 等待更好时机：价格到达关键位再考虑\n3. 严格控制风险：即使入场也要极小仓位\n4. 关注下一次信号',
                    style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('当前无明确交易机会', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(rec.reason, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                  const SizedBox(height: 6),
                  const Text('建议：耐心等待价格到达关键支撑/压力位，再考虑入场', style: TextStyle(fontSize: 11, color: Colors.amber)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.L0: return Colors.green;
      case RiskLevel.L1: return Colors.yellow;
      case RiskLevel.L2: return Colors.orange;
      case RiskLevel.L3: return Colors.red;
    }
  }
}
