import 'package:flutter/material.dart';

// Цвета для игры Wordle
class AppColors {
  // Цвета плиток
  static const Color correct = Color(0xFF6AAA64);      // Зеленый - правильная буква на правильном месте
  static const Color present = Color(0xFFC9B458);      // Желтый - буква есть, но не на своем месте
  static const Color absent = Color(0xFF787C7E);       // Серый - буквы нет в слове
  static const Color empty = Color(0xFFFFFFFF);        // Белый - пустая клетка

  // Цвета границ
  static const Color border = Color(0xFFD3D6DA);       // Граница пустой клетки
  static const Color borderFilled = Color(0xFF878A8C);  // Граница заполненной клетки

  // Цвета клавиатуры
  static const Color keyboardDefault = Color(0xFFD3D6DA); // Серая клавиша
  static const Color keyboardText = Color(0xFF000000);    // Черный текст

  // Цвета фона
  static const Color background = Color(0xFFFFFFFF);   // Белый фон
  static const Color text = Color(0xFF000000);         // Черный текст
}