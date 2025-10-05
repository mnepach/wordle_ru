import 'package:flutter/material.dart';
import '../models/word_data.dart';
import '../constants/colors.dart';

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

  static const List<List<String>> _keyboardLayout = [
    ['Й', 'Ц', 'У', 'К', 'Е', 'Н', 'Г', 'Ш', 'Щ', 'З', 'Х', 'Ъ'],
    ['Ф', 'Ы', 'В', 'А', 'П', 'Р', 'О', 'Л', 'Д', 'Ж', 'Э'],
    ['ENTER', 'Я', 'Ч', 'С', 'М', 'И', 'Т', 'Ь', 'Б', 'Ю', 'DELETE'],
  ];

  Color _getKeyColor(String key) {
    if (key == 'ENTER' || key == 'DELETE') {
      return AppColors.primary;
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

  Color _getKeyTextColor(String key) {
    if (key == 'ENTER' || key == 'DELETE') {
      return Colors.white;
    }

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
    final screenWidth = MediaQuery.of(context).size.width;
    // Вычисляем размер клавиши на основе ширины экрана
    final horizontalPadding = 8.0;
    final keySpacing = 2.0;
    // Для первого ряда (12 клавиш)
    final availableWidth = screenWidth - (horizontalPadding * 2);
    final totalSpacing = keySpacing * 11; // 11 промежутков между 12 клавишами
    final keyWidth = (availableWidth - totalSpacing) / 12;
    final clampedKeyWidth = keyWidth.clamp(24.0, 32.0);

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: horizontalPadding),
      child: Column(
        children: _keyboardLayout.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final row = entry.value;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                final isSpecialKey = key == 'ENTER' || key == 'DELETE';
                final keyWidthValue = isSpecialKey ? clampedKeyWidth * 1.8 : clampedKeyWidth;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: keySpacing / 2),
                  child: _KawaiiKeyButton(
                    label: key,
                    width: keyWidthValue,
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

class _KawaiiKeyButton extends StatefulWidget {
  final String label;
  final double width;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _KawaiiKeyButton({
    Key? key,
    required this.label,
    required this.width,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_KawaiiKeyButton> createState() => _KawaiiKeyButtonState();
}

class _KawaiiKeyButtonState extends State<_KawaiiKeyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isSpecialKey = widget.label == 'ENTER' || widget.label == 'DELETE';
    final fontSize = isSpecialKey ? 18.0 : (widget.width > 28 ? 16.0 : 14.0);
    final iconSize = widget.width > 28 ? 20.0 : 18.0;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: 48,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isPressed
                    ? []
                    : [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: widget.label == 'DELETE'
                    ? Icon(
                  Icons.backspace_outlined,
                  color: widget.textColor,
                  size: iconSize,
                )
                    : Text(
                  widget.label == 'ENTER' ? '✓' : widget.label,
                  style: TextStyle(
                    fontSize: widget.label == 'ENTER' ? fontSize + 4 : fontSize,
                    fontWeight: FontWeight.w800,
                    color: widget.textColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}