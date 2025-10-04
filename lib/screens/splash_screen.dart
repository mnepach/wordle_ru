import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/colors.dart';
import 'game_screen.dart';

// Приветственный экран с kawaii анимацией
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _floatController;
  late AnimationController _sparkleController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация прыжка логотипа
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -30).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    // Анимация плавания
    _floatController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Анимация блёсток
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Запускаем анимацию прыжка
    _bounceController.forward();

    // Автоматический переход через 3 секунды
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const GameScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _floatController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gradientStart,
              AppColors.gradientEnd,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Плавающие звёздочки на фоне
            ...List.generate(20, (index) => _FloatingShape(
              key: ValueKey('star_$index'),
              controller: _sparkleController,
              delay: index * 0.1,
              isStar: true,
            )),
            // Плавающие сердечки на фоне
            ...List.generate(15, (index) => _FloatingShape(
              key: ValueKey('heart_$index'),
              controller: _sparkleController,
              delay: index * 0.15 + 0.5,
              isStar: false,
            )),
            // Основной контент
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Анимированный логотип
                  AnimatedBuilder(
                    animation: Listenable.merge([_bounceController, _floatController]),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _bounceAnimation.value + _floatAnimation.value),
                        child: child,
                      );
                    },
                    child: _KawaiiLogo(),
                  ),
                  const SizedBox(height: 40),
                  // Название игры
                  AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnimation.value * 0.5),
                        child: child,
                      );
                    },
                    child: const Text(
                      'WORDLE',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        letterSpacing: 8,
                        shadows: [
                          Shadow(
                            color: AppColors.shadow,
                            offset: Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Подзаголовок
                  Text(
                    'Русская версия',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text.withOpacity(0.7),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Индикатор загрузки
                  _LoadingIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Kawaii логотип с котиком или облаком
class _KawaiiLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFFFFE4F0),
            Color(0xFFFFB6D9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Милое личико
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Глазки
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Eye(),
                  const SizedBox(width: 20),
                  _Eye(),
                ],
              ),
              const SizedBox(height: 8),
              // Улыбка
              Container(
                width: 40,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.text,
                      width: 3,
                    ),
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Румянец
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Blush(),
                  const SizedBox(width: 60),
                  _Blush(),
                ],
              ),
            ],
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
      width: 12,
      height: 16,
      decoration: const BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
    );
  }
}

// Румянец
class _Blush extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

// Плавающие формы (звёздочки и сердечки)
class _FloatingShape extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final bool isStar;

  const _FloatingShape({
    Key? key,
    required this.controller,
    required this.delay,
    required this.isStar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final random = math.Random(key.hashCode);
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final top = random.nextDouble() * MediaQuery.of(context).size.height;
    final size = 15 + random.nextDouble() * 25;

    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final value = (controller.value + delay) % 1.0;
          final opacity = (math.sin(value * math.pi * 2) + 1) / 2;
          final scale = 0.5 + opacity * 0.5;

          return Opacity(
            opacity: opacity * 0.6,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },
        child: isStar ? _Star(size: size) : _Heart(size: size),
      ),
    );
  }
}

// Звёздочка
class _Star extends StatelessWidget {
  final double size;

  const _Star({required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.star,
      size: size,
      color: AppColors.star,
    );
  }
}

// Сердечко
class _Heart extends StatelessWidget {
  final double size;

  const _Heart({required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.favorite,
      size: size,
      color: AppColors.heart,
    );
  }
}

// Индикатор загрузки
class _LoadingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(
          AppColors.primary,
        ),
      ),
    );
  }
}