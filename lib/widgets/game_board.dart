import 'package:flutter/material.dart';
import '../models/word_data.dart';
import 'tile.dart';

class GameBoard extends StatefulWidget {
  final List<WordRow> rows;
  final int? winningRowIndex; // индекс строки, которую нужно анимировать (при выигрыше)

  const GameBoard({
    Key? key,
    required this.rows,
    this.winningRowIndex,
  }) : super(key: key);

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  int? _prevWinningIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.08)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_controller);
  }

  @override
  void didUpdateWidget(covariant GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.winningRowIndex != null &&
        widget.winningRowIndex != _prevWinningIndex) {
      _prevWinningIndex = widget.winningRowIndex;
      _controller.forward(from: 0).then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardWidth = screenWidth * 0.88; // чтобы не прилипало к краям

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.rows.length, (rowIndex) {
            final row = widget.rows[rowIndex];
            final isWinningRow =
                widget.winningRowIndex != null && widget.winningRowIndex == rowIndex;

            Widget rowWidget = SizedBox(
              width: boardWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(row.letters.length, (letterIndex) {
                  return LetterTile(
                    letter: row.letters[letterIndex],
                    animationDelay: letterIndex * 100,
                    highlight: isWinningRow,
                  );
                }),
              ),
            );

            if (isWinningRow) {
              return AnimatedBuilder(
                animation: _scaleAnim,
                builder: (context, child) {
                  return Transform.scale(scale: _scaleAnim.value, child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: rowWidget,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: rowWidget,
            );
          }),
        ),
      ),
    );
  }
}
