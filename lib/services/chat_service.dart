import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // ضع رابط الـ Worker الخاص بك هنا
  static const String workerUrl = 'https://alili-omni.medalili2045.workers.dev';

  static Future<String> sendMessage({
    required String message,
    required String model,
    required List<Map<String, String>> history,
    required bool search,
    required bool thinking,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'model': model,
          'history': history,
          'search': search,
          'thinking': thinking,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['reply'] ?? 'لم أفهم الرد.';
      } else {
        return 'مشكلة في الخادم (كود ${response.statusCode})';
      }
    } catch (e) {
      return 'خطأ في الاتصال: $e';
    }
  }
}
