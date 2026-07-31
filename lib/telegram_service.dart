import 'package:http/http.dart' as http;

class TelegramService {
  // Token ដែលបងទទួលបានពី BotFather
  static const String _token =
      "8010829886:AAE7pV3IsLm2_RN kFMeUS3EiyrChs0xITV4";

  // លេខ ID របស់បង (Chat ID)
  static const String _chatId = "740933875";

  static Future<void> sendMessage(String message) async {
    final url = Uri.parse("https://api.telegram.org/bot${_token}/sendMessage");

    try {
      final response = await http.post(
        url,
        body: {
          "chat_id": _chatId,
          "text": message,
          "parse_mode": "Markdown", // ប្រើ Markdown ដើម្បីឱ្យអក្សរដិតស្អាត
        },
      );

      if (response.statusCode == 200) {
        print("✅ Telegram notification sent!");
      } else {
        print("❌ Failed to send Telegram: ${response.body}");
      }
    } catch (e) {
      print("⚠️ Telegram Error: $e");
    }
  }
}
