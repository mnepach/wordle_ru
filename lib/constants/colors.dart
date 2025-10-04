import 'package:flutter/material.dart';

// Kawaii цветовая палитра для игры Wordle
class AppColors {
  // Пастельные цвета плиток
  static const Color correct = Color(0xFFB4E4B4);      // Мятно-зелёный
  static const Color present = Color(0xFFFFF4A3);      // Нежно-жёлтый
  static const Color absent = Color(0xFFE5D4ED);       // Лавандовый
  static const Color empty = Color(0xFFFFFFFF);        // Белый

  // Градиенты фона
  static const Color gradientStart = Color(0xFFFFF0F5); // Светло-розовый
  static const Color gradientEnd = Color(0xFFE0F4FF);   // Светло-голубой

  // Цвета границ
  static const Color border = Color(0xFFFFB6D9);        // Розовая граница
  static const Color borderFilled = Color(0xFFB8A4E5);  // Фиолетовая граница

  // Цвета клавиатуры
  static const Color keyboardDefault = Color(0xFFFFE4F0); // Розоватая клавиша
  static const Color keyboardText = Color(0xFF8B6A9E);    // Фиолетовый текст

  // Основные цвета
  static const Color primary = Color(0xFFFFB6D9);       // Розовый
  static const Color secondary = Color(0xFFB8D4FF);     // Голубой
  static const Color accent = Color(0xFFFFF4A3);        // Жёлтый
  static const Color text = Color(0xFF6D5A7E);          // Тёмно-фиолетовый текст

  // Цвета для эффектов
  static const Color shadow = Color(0x26FF9ECE);        // Тень розовая
  static const Color star = Color(0xFFFFE082);          // Звёздочка
  static const Color heart = Color(0xFFFFB6D9);         // Сердечко
}