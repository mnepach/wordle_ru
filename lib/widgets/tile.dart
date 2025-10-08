import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/word_data.dart';
import '../constants/colors.dart';

class LetterTile extends StatefulWidget {
  final Letter letter;
  final int animationDelay;
  final bool highlight;

  const LetterTile({
    Key? key,
    required this.letter,
    this.animationDelay = 0,
    this.highlight = false,
  }) : super(key: key);

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile>
    with SingleTickerProviderStateMixin {
  double _flip = 0.0;
  bool _pop = false;
  late LetterStatus _prevStatus;
  late String _prevCharacter;

  @override
  void initState() {
    super.initState();
    _prevStatus = widget.letter.status;
    _prevCharacter = widget.letter.character;
  }

  @override
  void didUpdateWidget(covariant LetterTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.letter.character != widget.letter.character) {
      // Сбрасываем анимации при изменении символа
      _flip = 0.0;
      _pop = false;
      if (widget.letter.character.isNotEmpty) {
        setState(() => _pop = true);
        Future.delayed(const Duration(milliseconds: 140), () {
          if (mounted) setState(() => _pop = false);
        });
      }
    }

    if (_prevStatus == LetterStatus.notChecked &&
        widget.letter.status != LetterStatus.notChecked &&
        widget.letter.status != LetterStatus.empty) {
      Future.delayed(Duration(milliseconds: widget.animationDelay), () {
        if (!mounted) return;
        setState(() => _flip = 1.0);
      });
    }

    _prevStatus = widget.letter.status;
    _prevCharacter = widget.letter.character;
  }

  Color _getColor(LetterStatus status) {
    switch (status) {
      case LetterStatus.correct:
        return AppColors.correct;
      case LetterStatus.present:
        return AppColors.present;
      case LetterStatus.absent:
        return AppColors.absent;
      default:
        return AppColors.empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final size = (screenWidth * 0.88 - 24) / 5;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _flip),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final angle = value * math.pi;
        final showFront = angle < math.pi / 2;
        final color = showFront ? AppColors.empty : _getColor(widget.letter.status);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(angle),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.letter.character.isEmpty
                    ? AppColors.border
                    : color.withOpacity(0.8),
                width: 2.5,
              ),
            ),
            child: Center(
              child: AnimatedScale(
                scale: _pop ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Transform(
                  transform: Matrix4.rotationX(showFront ? 0 : math.pi),
                  alignment: Alignment.center,
                  child: Text(
                    widget.letter.character,
                    style: TextStyle(
                      fontSize: size * 0.45,
                      fontWeight: FontWeight.bold,
                      color: showFront
                          ? AppColors.text
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}