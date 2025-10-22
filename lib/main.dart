import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      // Для Web и других платформ
        apiKey: "AIzaSyBytxs5pn_jQnqpTeUusQKus5YhtPWdC-c",
        authDomain: "wordle-ru-f1f08.firebaseapp.com",
        databaseURL: "https://wordle-ru-f1f08-default-rtdb.firebaseio.com",
        projectId: "wordle-ru-f1f08",
        storageBucket: "wordle-ru-f1f08.firebasestorage.app",
        messagingSenderId: "228393585619",
        appId: "1:228393585619:web:1c6e9f4fa7adbb1247bd26"
    ),
  );

  // Инициализация сервиса синхронизации
  try {
    await SyncService().initialize();
  } catch (e) {
    print('Не удалось инициализировать синхронизацию: $e');
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