import 'package:flutter/material.dart';
import '../models/word_data.dart';
import '../constants/colors.dart';

class LetterTile extends StatefulWidget {
  final Letter letter;
  final int animationDelay;

  const LetterTile({
    Key? key,
    required this.letter,
    this.animationDelay = 0,
  }) : super(key: key);

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  LetterStatus _previousStatus = LetterStatus.empty;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _previousStatus = widget.letter.status;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Анимация переворота
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Анимация масштаба при вводе
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Анимация подпрыгивания
    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void didUpdateWidget(LetterTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Запуск анимации только при смене статуса с notChecked на другой
    if (_previousStatus == LetterStatus.notChecked &&
        widget.letter.status != LetterStatus.notChecked &&
        widget.letter.status != LetterStatus.empty &&
        !_isAnimating) {
      _isAnimating = true;
      _previousStatus = widget.letter.status;

      Future.delayed(Duration(milliseconds: widget.animationDelay), () {
        if (mounted && _isAnimating) {
          _controller.forward(from: 0).then((_) {
            if (mounted) {
              setState(() {
                _isAnimating = false;
              });
            }
          });
        }
      });
    }
    // Анимация при добавлении буквы
    else if (oldWidget.letter.character.isEmpty &&
        widget.letter.character.isNotEmpty &&
        !_isAnimating) {
      _previousStatus = widget.letter.status;
      _controller.forward(from: 0).then((_) {
        if (mounted) {
          _controller.reverse();
        }
      });
    }
    // Просто обновляем статус без анимации
    else if (oldWidget.letter.status != widget.letter.status) {
      _previousStatus = widget.letter.status;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.letter.status) {
      case LetterStatus.correct:
        return AppColors.correct;
      case LetterStatus.present:
        return AppColors.present;
      case LetterStatus.absent:
        return AppColors.absent;
      case LetterStatus.empty:
        return AppColors.empty;
      case LetterStatus.notChecked:
        return AppColors.empty;
    }
  }

  Color _getBorderColor() {
    if (widget.letter.character.isNotEmpty &&
        widget.letter.status == LetterStatus.notChecked) {
      return AppColors.borderFilled;
    }
    if (widget.letter.status == LetterStatus.empty) {
      return AppColors.border;
    }
    return _getBackgroundColor();
  }

  Color _getTextColor() {
    if (widget.letter.status == LetterStatus.empty ||
        widget.letter.status == LetterStatus.notChecked) {
      return AppColors.text;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _flipAnimation.value * 3.14159;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(angle);

        final showFront = angle < 3.14159 / 2;

        // Определяем, показывать ли старый или новый цвет
        final displayStatus = showFront ? LetterStatus.notChecked : widget.letter.status;
        final backgroundColor = showFront
            ? AppColors.empty
            : _getBackgroundColor();
        final borderColor = showFront
            ? _getBorderColor()
            : _getBackgroundColor();
        final textColor = showFront || widget.letter.status == LetterStatus.notChecked
            ? AppColors.text
            : Colors.white;

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(
                color: borderColor,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Основная буква
                Center(
                  child: Transform.scale(
                    scale: widget.letter.status == LetterStatus.notChecked
                        ? _scaleAnimation.value
                        : 1.0,
                    child: Transform(
                      transform: Matrix4.rotationX(showFront ? 0 : 3.14159),
                      alignment: Alignment.center,
                      child: Text(
                        widget.letter.character,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
                // Блестки при правильной букве (каомодзи)
                if (widget.letter.status == LetterStatus.correct && !showFront)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Opacity(
                      opacity: _bounceAnimation.value,
                      child: const Text(
                        '✧',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}