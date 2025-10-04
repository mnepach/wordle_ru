import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/colors.dart';

// Милый прыгающий персонаж на фоне
class FloatingCharacter extends StatefulWidget {
  final Alignment startPosition;
  final double delay;

  const FloatingCharacter({
    Key? key,
    this.startPosition = Alignment.bottomLeft,
    this.delay = 0,
  }) : super(key: key);

  @override
  State<FloatingCharacter> createState() => _FloatingCharacterState();
}

class _FloatingCharacterState extends State<FloatingCharacter>
    with TickerProviderStateMixin {
  late AnimationController _jumpController;
  late AnimationController _moveController;
  late Animation<double> _jumpAnimation;
  late Animation<double> _moveAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация прыжка
    _jumpController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _jumpAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -60)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -60, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_jumpController);

    // Анимация перемещения
    _moveController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _moveAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.linear),
    );

    // Запуск с задержкой
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) {
        _startAnimation();
      }
    });
  }

  void _startAnimation() {
    _moveController.repeat();
    _jumpController.repeat();
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: Listenable.merge([_jumpController, _moveController]),
      builder: (context, child) {
        // Вычисляем позицию на основе стартовой позиции
        double x;
        double y;

        if (widget.startPosition == Alignment.bottomLeft) {
          x = _moveAnimation.value * screenWidth - 40;
          y = screenHeight - 120;
        } else if (widget.startPosition == Alignment.bottomRight) {
          x = screenWidth - (_moveAnimation.value * screenWidth) - 40;
          y = screenHeight - 120;
        } else {
          x = _moveAnimation.value * screenWidth - 40;
          y = screenHeight / 2 - 40;
        }

        return Positioned(
          left: x.clamp(0, screenWidth - 80),
          bottom: (y - _jumpAnimation.value).clamp(80, screenHeight - 80),
          child: Opacity(
            opacity: 0.4,
            child: child!,
          ),
        );
      },
      child: _KawaiiCharacter(),
    );
  }
}

// Милый персонаж (котик)
class _KawaiiCharacter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          // Тело
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              width: 60,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          // Голова
          Positioned(
            left: 20,
            bottom: 40,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  // Глазки
                  Positioned(
                    left: 10,
                    top: 12,
                    child: _Eye(),
                  ),
                  Positioned(
                    right: 10,
                    top: 12,
                    child: _Eye(),
                  ),
                  // Носик
                  Positioned(
                    left: 17,
                    top: 22,
                    child: Container(
                      width: 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.text.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Улыбка
                  Positioned(
                    left: 12,
                    top: 24,
                    child: CustomPaint(
                      size: const Size(16, 8),
                      painter: _SmilePainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Левое ушко
          Positioned(
            left: 15,
            bottom: 70,
            child: CustomPaint(
              size: const Size(15, 20),
              painter: _EarPainter(),
            ),
          ),
          // Правое ушко
          Positioned(
            right: 15,
            bottom: 70,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: CustomPaint(
                size: const Size(15, 20),
                painter: _EarPainter(),
              ),
            ),
          ),
          // Хвостик
          Positioned(
            right: 5,
            bottom: 20,
            child: Container(
              width: 25,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Лапки
          Positioned(
            left: 20,
            bottom: 5,
            child: _Paw(),
          ),
          Positioned(
            right: 20,
            bottom: 5,
            child: _Paw(),
          ),
        ],
      ),
    );
  }
}

// Глазик
class _Eye extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 7,
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// Лапка
class _Paw extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// Рисовальщик улыбки
class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.text.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width / 2, size.height, size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Рисовальщик ушка
class _EarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}