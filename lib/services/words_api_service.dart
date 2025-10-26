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

  // Список слов для ОТГАДЫВАНИЯ (не меняется!)
  static final List<String> _answers = [
    'КОШКА', 'ЛАМПА', 'КНИГА', 'ГРУША', 'СОКОЛ',
    'ТРАВА', 'ПЕЧКА', 'НОСОК', 'ЛОДКА', 'СТОЛБ',
    'ДОСКА', 'КАРТА', 'ПЕСНЯ', 'ТУМАН', 'ПАЛЕЦ',
    'СВЕЧА', 'РЫБКА', 'ЗАМОК', 'ОЗЕРО', 'БАНКА',
  ];

  // Список слов для ВВОДА (можно загрузить из API)
  static Set<String> _allowed = {};

  static const _wordleRussianRaw = 'https://raw.githubusercontent.com/mediahope/Wordle-Russian-Dictionary/main/Russian.txt';

  static Future<void> initialize() async {
    if (_initialized) return;
    print('Инициализация словаря...');

    try {
      // 1. Добавляем все слова-ответы в список допустимых слов
      _allowed = Set<String>.from(_answers);
      print('Добавлено ${_answers.length} слов-ответов в список допустимых');

      // 2. Пытаемся загрузить дополнительные слова из кэша
      final cached = await _loadFromCache();
      if (cached) {
        print('Загружено из кэша: ${_allowed.length} слов');
        _initialized = true;
        return;
      }

      // 3. Пытаемся загрузить из API
      print('Пытаемся загрузить дополнительные слова из API...');
      final loaded = await _tryLoadFromWordleApi();
      if (loaded && _allowed.length > _answers.length) {
        print('Загружено ${_allowed.length} слов из API (включая ${_answers.length} ответов)');
        _cacheWords();
        _initialized = true;
        return;
      }

      // 4. Пытаемся загрузить из assets
      try {
        print('Пытаемся загрузить из assets...');
        final allowedAsset = await rootBundle.loadString('assets/words/answers.txt');
        final additionalWords = LineSplitter.split(allowedAsset)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => s.toUpperCase())
            .where((w) => _isValidWordleWord(w))
            .toSet();

        if (additionalWords.isNotEmpty) {
          _allowed.addAll(additionalWords);
          print('Добавлено ${additionalWords.length} слов из assets');
          _cacheWords();
          _initialized = true;
          return;
        }
      } catch (e) {
        print('Не удалось загрузить из assets: $e');
      }

      // 5. Используем только слова-ответы
      print('Используем только встроенный список из ${_answers.length} слов для ввода');
      _cacheWords();
      _initialized = true;

    } catch (e) {
      print('Ошибка инициализации словаря: $e');
      _allowed = Set<String>.from(_answers);
      _cacheWords();
      _initialized = true;
    }

    print('Словарь инициализирован. Доступно слов для ввода: ${_allowed.length}, для ответов: ${_answers.length}');
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
        int addedCount = 0;

        for (var raw in lines) {
          final w = raw.trim();
          if (w.isEmpty) continue;
          final up = w.toUpperCase();
          if (_isValidWordleWord(up)) {
            _allowed.add(up);
            addedCount++;
          }
        }

        print('Добавлено $addedCount новых слов из API');

        if (addedCount > 0) {
          return true;
        }
        print('API не вернул новых слов');
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

  static Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAllowed = prefs.getStringList('w_allowed_v3');

      if (cachedAllowed != null && cachedAllowed.isNotEmpty) {
        _allowed = cachedAllowed.toSet();
        // Убеждаемся что все слова-ответы включены
        _allowed.addAll(_answers);
        return true;
      }
    } catch (e) {
      print('Ошибка загрузки из кэша: $e');
    }
    return false;
  }

  static void _cacheWords() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('w_allowed_v3', _allowed.toList());
      print('Словарь закэширован: ${_allowed.length} слов');
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
    await initialize();
  }
}