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
    // Используем LayoutBuilder, чтобы подстраиваться под доступную ширину.
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Отступы слева/справа и промежутки между клавишами
        const horizontalPadding = 8.0;
        const keyGap = 6.0;
        final usableWidth = totalWidth - horizontalPadding * 2;

        Widget buildRow(List<String> row, {bool isThird = false}) {
          // Для третьего ряда делаем ENTER и DELETE шире (flex = 2).
          return Row(
            children: row.map((key) {
              final bool isSpecial = key == 'ENTER' || key == 'DELETE';
              final int flex = isThird && isSpecial ? 2 : 1;

              return Expanded(
                flex: flex,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: keyGap / 2, vertical: 4),
                  child: _KeyButton(
                    label: key,
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
                ),
              );
            }).toList(),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildRow(_keyboardLayout[0]),
              buildRow(_keyboardLayout[1]),
              // третий ряд — ENTER и DELETE шире
              buildRow(_keyboardLayout[2], isThird: true),
            ],
          ),
        );
      },
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _KeyButton({
    Key? key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _onTapUp(TapUpDetails _) {
    setState(() => _pressed = false);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final isIcon = widget.label == 'DELETE';
    final display = widget.label == 'ENTER' ? '✓' : widget.label;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
        height: 46,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: _pressed
              ? null
              : [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isIcon
              ? Icon(Icons.backspace_outlined, color: widget.textColor, size: 20)
              : Text(
            display,
            style: TextStyle(
              fontSize: widget.label == 'ENTER' ? 16 : 14,
              fontWeight: FontWeight.w800,
              color: widget.textColor,
            ),
          ),
        ),
      ),
    );
  }
}
