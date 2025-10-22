import 'package:flutter/material.dart';
import '../models/word_data.dart';
import 'tile.dart';

class GameBoard extends StatefulWidget {
  final List<WordRow> rows;
  final int? winningRowIndex;

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
    final screenHeight = MediaQuery.of(context).size.height;
    final maxBoardWidth = 400.0;
    final boardWidth = screenWidth > 600
        ? maxBoardWidth
        : screenWidth * 0.88;

    final tileSize = (boardWidth - 24) / 5;
    final totalBoardHeight = (tileSize + 12) * widget.rows.length;

    final double adjustedTileSize;
    if (totalBoardHeight > screenHeight * 0.6) {
      adjustedTileSize = (screenHeight * 0.6 - 12 * widget.rows.length) / widget.rows.length;
    } else {
      adjustedTileSize = tileSize;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                    maxBoardWidth: boardWidth,
                    fixedSize: adjustedTileSize,
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
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: rowWidget,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: rowWidget,
            );
          }),
        ),
      ),
    );
  }
}