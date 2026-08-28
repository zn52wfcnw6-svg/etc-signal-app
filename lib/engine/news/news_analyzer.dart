import 'dart:async';
import '../models/market_data.dart';

/// 消息面类型
enum NewsType {
  macroEconomic, // 宏观经济数据
  exchangeAnnouncement, // 交易所公告
  regulatoryNews, // 监管新闻
  whaleMovement, // 大户异动
  technicalBreakout, // 技术突破
  fundingRateExtreme, // 资金费率极端
  sentimentExtreme, // 情绪极端
  generalNews, // 一般新闻
}

/// 消息面影响等级
enum NewsImpact {
  high, // 高影响
  medium, // 中影响
  low, // 低影响
}

/// 消息面情绪
enum NewsSentiment {
  bullish, // 利好
  bearish, // 利空
  neutral, // 中性
}

/// 新闻条目
class NewsItem {
  final String id;
  final String title;
  final String summary;
  final NewsType type;
  final NewsImpact impact;
  final NewsSentiment sentiment;
  final DateTime timestamp;
  final String source;
  final String? url;
  final double priceImpactEstimate; // 预估价格影响百分比（正=利好，负=利空）

  const NewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.type,
    required this.impact,
    required this.sentiment,
    required this.timestamp,
    required this.source,
    this.url,
    this.priceImpactEstimate = 0,
  });

  String get typeLabel {
    switch (type) {
      case NewsType.macroEconomic: return '宏观经济';
      case NewsType.exchangeAnnouncement: return '交易所公告';
      case NewsType.regulatoryNews: return '监管新闻';
      case NewsType.whaleMovement: return '大户异动';
      case NewsType.technicalBreakout: return '技术突破';
      case NewsType.fundingRateExtreme: return '资金费率';
      case NewsType.sentimentExtreme: return '情绪极端';
      case NewsType.generalNews: return '一般新闻';
    }
  }

  String get impactLabel {
    switch (impact) {
      case NewsImpact.high: return '高影响';
      case NewsImpact.medium: return '中影响';
      case NewsImpact.low: return '低影响';
    }
  }

  String get sentimentLabel {
    switch (sentiment) {
      case NewsSentiment.bullish: return '利好';
      case NewsSentiment.bearish: return '利空';
      case NewsSentiment.neutral: return '中性';
    }
  }
}

/// 消息面分析结果
class NewsAnalysisResult {
  final List<NewsItem> recentNews;
  final double overallSentimentScore; // -100到100，正=利好，负=利空
  final NewsSentiment overallSentiment;
  final int highImpactNewsCount;
  final int bullishNewsCount;
  final int bearishNewsCount;
  final double estimatedPriceImpact; // 预估综合价格影响
  final String recommendation; // 消息面建议

  const NewsAnalysisResult({
    required this.recentNews,
    required this.overallSentimentScore,
    required this.overallSentiment,
    required this.highImpactNewsCount,
    required this.bullishNewsCount,
    required this.bearishNewsCount,
    required this.estimatedPriceImpact,
    required this.recommendation,
  });
}

/// 消息面分析引擎
/// SSS级标准：多维度消息面聚合+情绪分析+价格影响评估
class NewsAnalyzer {
  static final NewsAnalyzer _instance = NewsAnalyzer._internal();
  factory NewsAnalyzer() => _instance;
  NewsAnalyzer._internal();

  final List<NewsItem> _newsCache = [];
  Timer? _refreshTimer;
  final StreamController<NewsAnalysisResult> _newsController = StreamController.broadcast();
  Stream<NewsAnalysisResult> get newsStream => _newsController.stream;

  /// 初始化消息面分析
  Future<void> init() async {
    await _refreshNews();
    _startAutoRefresh();
  }

  /// 开始自动刷新（每5分钟）
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _refreshNews());
  }

  /// 刷新新闻（模拟数据，实际应接入新闻API）
  Future<void> _refreshNews() async {
    // 模拟生成新闻数据（实际应接入：CoinGecko/CoinTelegraph/交易所公告等API）
    final mockNews = _generateMockNews();
    _newsCache.clear();
    _newsCache.addAll(mockNews);
    final result = analyze();
    if (!_newsController.isClosed) {
      _newsController.add(result);
    }
  }

  /// 生成模拟新闻（用于演示，实际应接入真实API）
  List<NewsItem> _generateMockNews() {
    final now = DateTime.now();
    return [
      NewsItem(
        id: '1',
        title: '美联储会议纪要显示可能放缓加息步伐',
        summary: '美联储最新会议纪要显示，多位官员支持在下次会议上放缓加息步伐，市场风险偏好回升。',
        type: NewsType.macroEconomic,
        impact: NewsImpact.high,
        sentiment: NewsSentiment.bullish,
        timestamp: now.subtract(const Duration(hours: 2)),
        source: '路透社',
        priceImpactEstimate: 2.5,
      ),
      NewsItem(
        id: '2',
        title: '比特币ETF净流入创月度新高',
        summary: '美国比特币现货ETF昨日净流入超过2亿美元，连续第5日净流入，机构资金持续入场。',
        type: NewsType.whaleMovement,
        impact: NewsImpact.high,
        sentiment: NewsSentiment.bullish,
        timestamp: now.subtract(const Duration(hours: 4)),
        source: 'CoinShares',
        priceImpactEstimate: 1.8,
      ),
      NewsItem(
        id: '3',
        title: '某交易所宣布上线ETH永续合约新币种',
        summary: '主流交易所宣布将于下周上线新的ETH永续合约交易对，预计将增加市场流动性。',
        type: NewsType.exchangeAnnouncement,
        impact: NewsImpact.medium,
        sentiment: NewsSentiment.bullish,
        timestamp: now.subtract(const Duration(hours: 6)),
        source: '交易所公告',
        priceImpactEstimate: 0.8,
      ),
      NewsItem(
        id: '4',
        title: 'ETH资金费率转为正值，多头占优',
        summary: 'ETH永续合约资金费率从负转正，当前为0.01%，显示市场多头情绪占优，但需警惕过度拥挤。',
        type: NewsType.fundingRateExtreme,
        impact: NewsImpact.medium,
        sentiment: NewsSentiment.neutral,
        timestamp: now.subtract(const Duration(hours: 8)),
        source: 'Coinglass',
        priceImpactEstimate: 0.3,
      ),
      NewsItem(
        id: '5',
        title: '恐慌贪婪指数升至72，进入贪婪区域',
        summary: '加密货币恐慌贪婪指数今日升至72，进入"贪婪"区域，市场情绪偏乐观，但短期有回调风险。',
        type: NewsType.sentimentExtreme,
        impact: NewsImpact.medium,
        sentiment: NewsSentiment.bearish,
        timestamp: now.subtract(const Duration(hours: 10)),
        source: 'Alternative.me',
        priceImpactEstimate: -0.5,
      ),
      NewsItem(
        id: '6',
        title: 'ETH突破关键阻力位，技术面转强',
        summary: 'ETH价格突破2500美元关键阻力位，日线级别形成突破形态，技术面短期转强。',
        type: NewsType.technicalBreakout,
        impact: NewsImpact.medium,
        sentiment: NewsSentiment.bullish,
        timestamp: now.subtract(const Duration(hours: 12)),
        source: '技术分析',
        priceImpactEstimate: 1.2,
      ),
    ];
  }

  /// 分析消息面
  NewsAnalysisResult analyze() {
    if (_newsCache.isEmpty) {
      return const NewsAnalysisResult(
        recentNews: [],
        overallSentimentScore: 0,
        overallSentiment: NewsSentiment.neutral,
        highImpactNewsCount: 0,
        bullishNewsCount: 0,
        bearishNewsCount: 0,
        estimatedPriceImpact: 0,
        recommendation: '暂无消息面数据',
      );
    }

    double totalScore = 0;
    int highImpact = 0;
    int bullish = 0;
    int bearish = 0;
    double totalImpact = 0;

    for (final news in _newsCache) {
      // 情绪评分：利好+，利空-，中性0
      double sentimentScore = 0;
      if (news.sentiment == NewsSentiment.bullish) {
        sentimentScore = 50;
        bullish++;
      } else if (news.sentiment == NewsSentiment.bearish) {
        sentimentScore = -50;
        bearish++;
      }

      // 影响权重：高影响3x，中影响2x，低影响1x
      double weight = 1;
      if (news.impact == NewsImpact.high) {
        weight = 3;
        highImpact++;
      } else if (news.impact == NewsImpact.medium) {
        weight = 2;
      }

      totalScore += sentimentScore * weight;
      totalImpact += news.priceImpactEstimate;
    }

    // 归一化到-100到100
    final maxPossibleScore = _newsCache.fold<double>(0, (sum, n) {
      double w = n.impact == NewsImpact.high ? 3 : n.impact == NewsImpact.medium ? 2 : 1;
      return sum + 50 * w;
    });
    final normalizedScore = maxPossibleScore > 0 ? (totalScore / maxPossibleScore * 100).clamp(-100.0, 100.0) : 0.0;

    // 综合情绪
    NewsSentiment overall;
    if (normalizedScore > 20) overall = NewsSentiment.bullish;
    else if (normalizedScore < -20) overall = NewsSentiment.bearish;
    else overall = NewsSentiment.neutral;

    // 建议
    String recommendation;
    if (normalizedScore > 40 && totalImpact > 2) {
      recommendation = '消息面强烈利好，可考虑顺势做多';
    } else if (normalizedScore > 20) {
      recommendation = '消息面偏利好，做多胜率较高';
    } else if (normalizedScore < -40 && totalImpact < -2) {
      recommendation = '消息面强烈利空，可考虑顺势做空';
    } else if (normalizedScore < -20) {
      recommendation = '消息面偏利空，做空胜率较高';
    } else {
      recommendation = '消息面中性，以技术面和订单流为主';
    }

    return NewsAnalysisResult(
      recentNews: _newsCache,
      overallSentimentScore: normalizedScore,
      overallSentiment: overall,
      highImpactNewsCount: highImpact,
      bullishNewsCount: bullish,
      bearishNewsCount: bearish,
      estimatedPriceImpact: totalImpact,
      recommendation: recommendation,
    );
  }

  /// 获取最近新闻
  List<NewsItem> getRecentNews({int count = 10}) {
    return _newsCache.take(count).toList();
  }

  /// 手动刷新
  Future<void> refresh() async {
    await _refreshNews();
  }

  /// 销毁
  void dispose() {
    _refreshTimer?.cancel();
    _newsController.close();
  }
}
