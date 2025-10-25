import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Инициализация Firebase с правильными опциями
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase успешно инициализирован');

    // Даём Firebase время на инициализацию
    await Future.delayed(const Duration(milliseconds: 500));

    // Инициализация сервиса синхронизации
    try {
      await SyncService().initialize();
      print('Сервис синхронизации успешно инициализирован');
    } catch (e) {
      print('Не удалось инициализировать синхронизацию: $e');
      // Продолжаем работу без синхронизации
    }
  } catch (e) {
    print('Ошибка инициализации Firebase: $e');
    // Продолжаем работу без Firebase
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const WordleApp());
}

class WordleApp extends StatelessWidget {
  const WordleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordle РУ かわいい',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: const Color(0xFFFFF0F5),
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}