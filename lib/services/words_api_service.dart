import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WordsApiService {
  static bool _initialized = false;
  static List<String> _answers = [
    'БАГЕТ', 'КНИГА', 'ГАМАК', 'ОКЕАН', 'ЗЕМЛЯ',
    'ЛИЛИЯ', 'УСПЕХ', 'ГОРОД', 'РЕЧКА', 'ТАЙНА',
    'ДОЖДЬ', 'РАДИЙ', 'ТРАВА', 'ГРОЗА', 'АТЛАС',
    'ПЕСНЯ', 'СКВЕР', 'ОСЕНЬ', 'ОАЗИС', 'ВЕНИК',
    'ХОЛСТ', 'ФАКЕЛ', 'КОШКА', 'ЛАМПА', 'ГРУША',
    'СОКОЛ', 'ПЕЧКА', 'НОСОК', 'ЛОДКА', 'СТОЛБ',
    'ДОСКА', 'КАРТА', 'ТУМАН', 'ПАЛЕЦ', 'СВЕЧА',
    'РЫБКА', 'ЗАМОК', 'ОЗЕРО', 'БАНКА', 'МЫШКА'
  ];
  static Set<String> _allowed = {};
  static const _wordleRussianRaw = 'https://raw.githubusercontent.com/mediahope/Wordle-Russian-Dictionary/main/Russian.txt';

  static Future<void> initialize() async {
    if (_initialized) return;
    print('Инициализация словаря...');
    try {
      print('Пытаемся загрузить из API...');
      final loaded = await _tryLoadFromWordleApi();
      if (loaded && _allowed.isNotEmpty) {
        print('Загружено ${_allowed.length} слов из API');
        _cacheWords();
        _initialized = true;
        return;
      }
      try {
        print('Пытаемся загрузить из assets...');
        final allowedAsset = await rootBundle.loadString('assets/words/answers.txt');
        final allowed = LineSplitter.split(allowedAsset)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => s.toUpperCase())
            .where((w) => _isValidWordleWord(w))
            .toSet();
        if (allowed.isNotEmpty) {
          _allowed = allowed;
          print('Загружено ${_allowed.length} слов из assets');
          _cacheWords();
          _initialized = true;
          return;
        }
      } catch (e) {
        print('Не удалось загрузить из assets: $e');
      }
      print('Используем встроенный список слов (${_answers.length} слов)');
      _allowed = Set<String>.from(_answers);
      _cacheWords();
      _initialized = true;
    } catch (e) {
      print('Ошибка инициализации словаря: $e');
      _allowed = Set<String>.from(_answers);
      _cacheWords();
      _initialized = true;
    }
    print('Словарь инициализирован. Доступно слов: ${_allowed.length}');
  }

  static bool _isValidWordleWord(String word) {
    if (!RegExp(r'^[А-Я]{5}$').hasMatch(word)) return false;
    if (word.contains('Ъ') || word.contains('Ь') || word.contains('Ё')) return false;
    return true;
  }

  static Future<bool> _tryLoadFromWordleApi() async {
    try {
      print('Отправляем запрос к $_wordleRussianRaw');
      final resp = await http.get(Uri.parse(_wordleRussianRaw)).timeout(const Duration(seconds: 15));
      print('Статус ответа: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final lines = LineSplitter.split(resp.body);
        final Set<String> words = {};
        for (var raw in lines) {
          final w = raw.trim();
          if (w.isEmpty) continue;
          final up = w.toUpperCase();
          if (_isValidWordleWord(up)) {
            words.add(up);
          }
        }
        print('Получено ${words.length} слов из API');
        if (words.isNotEmpty) {
          _allowed = words;
          _answers = words.toList();
          return true;
        }
        print('API вернул пустой список слов');
      } else {
        print('Ошибка API: статус ${resp.statusCode}');
      }
    } on TimeoutException catch (_) {
      print('Timeout при загрузке словаря из API');
    } on SocketException catch (_) {
      print('Нет подключения к интернету');
    } catch (e) {
      print('Ошибка загрузки из API: $e');
    }
    return false;
  }

  static void _cacheWords() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('w_allowed_v3', _allowed.toList());
      prefs.setStringList('w_answers_v3', _answers);
      print('Словарь закэширован');
    }).catchError((e) {
      print('Ошибка кэширования: $e');
    });
  }

  static bool isValidWord(String word) {
    if (word.length != 5) return false;
    final up = word.toUpperCase();
    return _allowed.contains(up);
  }

  static String getRandomWord() {
    if (_answers.isEmpty) return 'СЛОВО';
    final r = Random().nextInt(_answers.length);
    return _answers[r];
  }

  static String getWordOfTheDay({DateTime? forDate}) {
    if (_answers.isEmpty) return 'ИГРА';
    final epoch = DateTime(2024, 1, 1);
    final date = forDate ?? DateTime.now();
    final days = date.difference(epoch).inDays;
    final idx = days % _answers.length;
    return _answers[idx];
  }

  static Future<void> forceRefresh() async {
    _initialized = false;
    _allowed = {};
    _answers = [];
    await initialize();
  }
}