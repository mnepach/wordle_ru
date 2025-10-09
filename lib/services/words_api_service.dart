import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WordsApiService {
  static bool _initialized = false;
  static List<String> _answers = [
    'БАГЕТ',
    'КНИГА',
    'ГАМАК',
    'ОКЕАН',
    'ЗЕМЛЯ',
    'ЛИЛИЯ',
    'УСПЕХ',
    'ГОРОД',
    'РЕЧКА',
    'ТАЙНА',
    'ДОЖДЬ',
    'РАДИЙ',
    'ТРАВА',
    'ГРОЗА',
    'АТЛАС',
    'ПЕСНЯ',
    'СКВЕР',
    'ОСЕНЬ',
    'ОАЗИС',
    'ВЕНИК',
    'ХОЛСТ',
    'ФАКЕЛ'
  ];
  static Set<String> _allowed = {};

  static const _wordleRussianRaw =
      'https://raw.githubusercontent.com/mediahope/Wordle-Russian-Dictionary/main/Russian.txt';

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAllowed = prefs.getStringList('w_allowed_v3');

      if (cachedAllowed != null && cachedAllowed.isNotEmpty) {
        _allowed = cachedAllowed.map((w) => w.toUpperCase()).toSet();
        _initialized = true;
        return;
      }

      try {
        final allowedAsset = await rootBundle.loadString('assets/wordlists/allowed.txt');
        final allowed = LineSplitter.split(allowedAsset)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => s.toUpperCase())
            .where((w) => _isValidWordleWord(w))
            .toSet();

        if (allowed.isNotEmpty) {
          _allowed = allowed;
          _cacheWords();
          _initialized = true;
          return;
        }
      } catch (_) {}

      final loaded = await _tryLoadFromWordleApi();
      if (loaded && _allowed.isNotEmpty) {
        _cacheWords();
      }
    } catch (_) {} finally {
      _initialized = true;
    }
  }

  static bool _isValidWordleWord(String word) {
    if (!RegExp(r'^[А-Я]{5}$').hasMatch(word)) return false;
    if (word.contains('Ъ') || word.contains('Ь') || word.contains('Ё')) return false;
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