import 'package:flutter/material.dart';
import '../models/word_data.dart';
import 'tile.dart';

// Виджет игрового поля (сетка из плиток)
class GameBoard extends StatelessWidget {
  final List<WordRow> rows;

  const GameBoard({
    Key? key,
    required this.rows,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        rows.length,
            (rowIndex) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              rows[rowIndex].letters.length,
                  (letterIndex) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: LetterTile(
                  letter: rows[rowIndex].letters[letterIndex],
                  // Добавляем задержку для каскадной анимации
                  animationDelay: letterIndex * 100,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}