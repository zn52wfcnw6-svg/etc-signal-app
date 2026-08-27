import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Telegram推送服务
/// S级标准：信号触发时自动推送Telegram消息
class TelegramPushService {
  static const String _storageKey = 'telegram_config';

  String? _botToken;
  String? _chatId;
  bool _enabled = false;

  String? get botToken => _botToken;
  String? get chatId => _chatId;
  bool get enabled => _enabled;

  /// 加载配置
  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configStr = prefs.getString(_storageKey);
      if (configStr != null) {
        final config = json.decode(configStr);
        _botToken = config['botToken'];
        _chatId = config['chatId'];
        _enabled = config['enabled'] ?? false;
      }
    } catch (_) {}
  }

  /// 保存配置
  Future<void> saveConfig({
    required String botToken,
    required String chatId,
    required bool enabled,
  }) async {
    _botToken = botToken;
    _chatId = chatId;
    _enabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json.encode({
        'botToken': botToken,
        'chatId': chatId,
        'enabled': enabled,
      }));
    } catch (_) {}
  }

  /// 测试推送
  Future<bool> testPush() async {
    return sendMessage('✅ ETH信号监控 - 测试消息\n\n推送配置成功！');
  }

  /// 发送信号推送
  Future<bool> sendSignal({
    required String direction,
    required double entryPrice,
    required double stopLoss,
    required double tp1,
    required double tp2,
    required double riskReward,
    required String timeframe,
  }) async {
    final emoji = direction == 'long' ? '🟢' : '🔴';
    final dirText = direction == 'long' ? '做多' : '做空';
    final message = '''
$emoji ETH永续信号 - $dirText

📊 周期：$timeframe
💰 开仓：\$${entryPrice.toStringAsFixed(2)}
🛑 止损：\$${stopLoss.toStringAsFixed(2)}
🎯 TP1：\$${tp1.toStringAsFixed(2)}
🎯 TP2：\$${tp2.toStringAsFixed(2)}
📈 盈亏比：${riskReward.toStringAsFixed(1)}:1

⚠️ 信号仅供参考，严格执行止损！
''';
    return sendMessage(message);
  }

  /// 发送通用消息
  Future<bool> sendMessage(String text) async {
    if (!_enabled || _botToken == null || _chatId == null) return false;
    try {
      final url = 'https://api.telegram.org/bot$_botToken/sendMessage';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'chat_id': _chatId,
          'text': text,
          'parse_mode': 'HTML',
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
