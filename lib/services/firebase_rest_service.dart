import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game_stats.dart';

class FirebaseRestService {
  static const String _databaseUrl = 'https://wordle-ru-f1f08-default-rtdb.firebaseio.com';

  // Получить данные
  static Future<Map<String, dynamic>?> getData(String userId) async {
    try {
      final url = Uri.parse('$_databaseUrl/users/$userId/stats.json');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }
      return null;
    } catch (e) {
      print('Ошибка получения данных: $e');
      return null;
    }
  }

  // Сохранить данные
  static Future<bool> setData(String userId, GameStats stats) async {
    try {
      final url = Uri.parse('$_databaseUrl/users/$userId/stats.json');
      final response = await http.put(
        url,
        body: json.encode(stats.toJson()),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Ошибка сохранения данных: $e');
      return false;
    }
  }

  // Проверить подключение
  static Future<bool> checkConnection() async {
    try {
      final url = Uri.parse('$_databaseUrl/.json');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}