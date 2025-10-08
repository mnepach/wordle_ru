import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WordsApiService {
  static bool _initialized = false;
  static List<String> _answers = []; // Список слов для загадывания (5 букв, именительный падеж ед.ч.)
  static Set<String> _allowed = {}; // Разрешённые слова для ввода (то же, что и answers для строгой фильтрации)

  static const _wordleRussianRaw =
      'https://raw.githubusercontent.com/mediahope/Wordle-Russian-Dictionary/main/Russian.txt';

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAnswers = prefs.getStringList('w_answers_v3');
      final cachedAllowed = prefs.getStringList('w_allowed_v3');

      if (cachedAnswers != null && cachedAllowed != null && cachedAllowed.isNotEmpty) {
        _allowed = cachedAllowed.map((w) => w.toUpperCase()).toSet();
        _answers = cachedAnswers.map((w) => w.toUpperCase()).toList();
        _initialized = true;
        return;
      }

      // Fallback на assets, если нет
      try {
        final answersAsset = await rootBundle.loadString('assets/wordlists/answers.txt');
        final allowedAsset = await rootBundle.loadString('assets/wordlists/allowed.txt');

        final answers = LineSplitter.split(answersAsset)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => s.toUpperCase())
            .where((w) => _isValidWordleWord(w))
            .toList();

        final allowed = LineSplitter.split(allowedAsset)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => s.toUpperCase())
            .where((w) => _isValidWordleWord(w))
            .toSet();

        if (allowed.isNotEmpty) {
          _allowed = allowed;
          _answers = answers.isNotEmpty ? answers : allowed.toList();
          _cacheWords();
          _initialized = true;
          return;
        }
      } catch (_) {}

      // Загрузка из API
      final loaded = await _tryLoadFromWordleApi();
      if (loaded && _allowed.isNotEmpty) {
        _answers = _allowed.toList()..sort();
        _cacheWords();
      }
    } catch (_) {} finally {
      _initialized = true;
    }
  }

  // Фильтр для строгих 5-буквенных слов: именительный ед.ч., без мягких/твёрдых знаков, Ё
  static bool _isValidWordleWord(String word) {
    if (!RegExp(r'^[А-Я]{5}$').hasMatch(word)) return false;
    if (word.contains('Ъ') || word.contains('Ь') || word.contains('Ё')) return false;
    // Дополнительная фильтрация: исключаем известные множественные/склонённые формы (примерно)
    final excludedPatterns = [
      RegExp(r'^(ЩУК|ДОМЫ|РЫС|БЫТ|ИДУТ|СТОЯ|ЛЕЖИ|БЕЖИ|ПЛАЧ|КРИЧ|ШЕПТ|ЗОВУ|ДЫШИ|СПЯТ|ВОЮ|МИРУ|ЛЮБВ|СМЕХ|ГРУС|РАДО|БОЛЬ|СТРА|НАДЕ|МЕЧТ|ДРУГ|ВРАГ|ДОМЫ|ЩУК|РЫСЬ|ЛЕТА|ЗИМЫ|ВЕСН|ОСЕН|НОЧИ|ДНЯМ|ЧАСЫ|МИНУ|СЕКУ|МЕСЯ|ГОДА|РУКА|НОГА|ГОЛВ|ГЛАЗ|УШИ|НОСА|РОТА|ЗУБЫ|ЯЗЫ|МОЗГ|СЕРД|ЛЕГК|КРОВ|КОСТ|КожА|ВОЛО|ПЛОТЬ|ЖИЗН|СМЕР|СОНЫ|СНАМ|МЕЧТ|СОНЫ)$', caseSensitive: false)
    ];
    for (final pattern in excludedPatterns) {
      if (pattern.hasMatch(word)) return false;
    }
    return true;
  }

  static Future<bool> _tryLoadFromWordleApi() async {
    try {
      final resp = await http.get(Uri.parse(_wordleRussianRaw)).timeout(const Duration(seconds: 8));
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
        if (words.isNotEmpty) {
          _allowed = words;
          return true;
        }
      }
    } on TimeoutException catch (_) {
    } on SocketException catch (_) {
    } catch (_) {}
    return false;
  }

  static void _cacheWords() {
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      prefs.setStringList('w_allowed_v3', _allowed.toList());
      prefs.setStringList('w_answers_v3', _answers);
    });
  }

  static bool isValidWord(String word) {
    if (word.length != 5) return false; // Строго 5 букв
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
    _answers = [];
    _allowed = {};
    await initialize();
  }
}