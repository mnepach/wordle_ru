import 'package:flutter/material.dart';
import '../models/word_data.dart';
import '../constants/colors.dart';

// Виджет экранной клавиатуры
class GameKeyboard extends StatelessWidget {
  final Function(String) onLetterTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onEnterTap;
  final Map<String, LetterStatus> keyboardStatus;

  const GameKeyboard({
    Key? key,
    required this.onLetterTap,
    required this.onDeleteTap,
    required this.onEnterTap,
    required this.keyboardStatus,
  }) : super(key: key);

  // Раскладка клавиатуры (русская)
  static const List<List<String>> _keyboardLayout = [
    ['Й', 'Ц', 'У', 'К', 'Е', 'Н', 'Г', 'Ш', 'Щ', 'З', 'Х', 'Ъ'],
    ['Ф', 'Ы', 'В', 'А', 'П', 'Р', 'О', 'Л', 'Д', 'Ж', 'Э'],
    ['ENTER', 'Я', 'Ч', 'С', 'М', 'И', 'Т', 'Ь', 'Б', 'Ю', 'DELETE'],
  ];

  // Получить цвет клавиши в зависимости от статуса
  Color _getKeyColor(String key) {
    if (key == 'ENTER' || key == 'DELETE') {
      return AppColors.keyboardDefault;
    }

    final status = keyboardStatus[key] ?? LetterStatus.empty;
    switch (status) {
      case LetterStatus.correct:
        return AppColors.correct;
      case LetterStatus.present:
        return AppColors.present;
      case LetterStatus.absent:
        return AppColors.absent;
      default:
        return AppColors.keyboardDefault;
    }
  }

  // Получить цвет текста клавиши
  Color _getKeyTextColor(String key) {
    final status = keyboardStatus[key] ?? LetterStatus.empty;
    if (status == LetterStatus.correct ||
        status == LetterStatus.present ||
        status == LetterStatus.absent) {
      return Colors.white;
    }
    return AppColors.keyboardText;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: _keyboardLayout.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                // Определяем ширину клавиши
                final isSpecialKey = key == 'ENTER' || key == 'DELETE';
                final keyWidth = isSpecialKey ? 65.0 : 32.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: _KeyButton(
                    label: key,
                    width: keyWidth,
                    backgroundColor: _getKeyColor(key),
                    textColor: _getKeyTextColor(key),
                    onTap: () {
                      if (key == 'ENTER') {
                        onEnterTap();
                      } else if (key == 'DELETE') {
                        onDeleteTap();
                      } else {
                        onLetterTap(key);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Виджет одной кнопки клавиатуры
class _KeyButton extends StatelessWidget {
  final String label;
  final double width;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _KeyButton({
    Key? key,
    required this.label,
    required this.width,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width,
          height: 58,
          alignment: Alignment.center,
          child: Text(
            label == 'DELETE' ? '⌫' : label,
            style: TextStyle(
              fontSize: label == 'ENTER' || label == 'DELETE' ? 14 : 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}