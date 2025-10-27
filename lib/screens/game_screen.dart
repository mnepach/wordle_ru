import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/game_service.dart';
import '../services/words_api_service.dart';
import '../services/stats_service.dart';
import '../constants/colors.dart';
import '../widgets/game_board.dart';
import '../widgets/keyboard.dart';
import '../widgets/floating_character.dart';
import 'stats_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameService _gameService;
  final FocusNode _focusNode = FocusNode();
  late AnimationController _headerAnimationController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeGame();

    _headerAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )
      ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _initializeGame() async {
    await WordsApiService.initialize();
    await StatsService.loadStats(); // Загружаем статистику при старте
    setState(() {
      _gameService = GameService(targetWord: WordsApiService.getRandomWord());
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _startNewGame() async {
    // Синхронизируем статистику перед началом новой игры
    print('🎮 Начинаем новую игру - синхронизируем статистику...');

    try {
      await StatsService.syncNow();
      print('✅ Синхронизация завершена, начинаем новую игру');
    } catch (e) {
      print('⚠️ Ошибка синхронизации: $e');
    }

    setState(() {
      _gameService = GameService(targetWord: WordsApiService.getRandomWord());
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter) {
      _onEnterPressed();
    } else if (key == LogicalKeyboardKey.backspace) {
      _onDeletePressed();
    } else {
      final char = event.character?.toUpperCase();
      if (char != null && char.length == 1) {
        if (RegExp(r'[А-ЯЁ]').hasMatch(char)) {
          _onLetterPressed(char);
        }
      }
    }
  }

  void _onLetterPressed(String letter) {
    if (_gameService.isGameOver) return;
    setState(() {
      _gameService.addLetter(letter);
    });
  }

  void _onDeletePressed() {
    if (_gameService.isGameOver) return;
    setState(() {
      _gameService.removeLetter();
    });
  }

  void _onEnterPressed() {
    if (_gameService.isGameOver) return;

    final success = _gameService.submitWord();

    if (!success) {
      final currentRow = _gameService.getCurrentRow();
      if (currentRow.isFilled()) {
        _showMessage('Слова нет в словаре (╥﹏╥)');
      } else {
        _showMessage('Недостаточно букв (・_・;)');
      }
      return;
    }

    setState(() {
      if (_gameService.isGameOver) {
        // Записываем результат игры в статистику
        final attempts = _gameService.currentRowIndex + 1;
        StatsService.recordGame(
          won: _gameService.isWinner,
          attempts: attempts,
        );

        Future.delayed(const Duration(milliseconds: 2000), () {
          _showGameOverDialog();
        });
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.text,
          ),
        ),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 50, right: 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _gameService.isWinner ? '(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧' : '(╥﹏╥)',
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _gameService.isWinner ? 'Победа!' : 'Игра окончена',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!_gameService.isWinner) ...[
                    const Text(
                      'Загаданное слово:',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _gameService.targetWord,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ] else
                    ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Отгадано за ${_gameService.currentRowIndex +
                              1} ${_getPluralAttempts(
                              _gameService.currentRowIndex + 1)}! ٩(◕‿◕｡)۶',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  const SizedBox(height: 24),
                  // Кнопки
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const StatsScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
                        ),
                        icon: const Icon(Icons.bar_chart, size: 20),
                        label: const Text(
                          'Статистика',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _startNewGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
                        ),
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text(
                          'Новая игра',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  String _getPluralAttempts(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'попытку';
    } else
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'попытки';
    } else {
      return 'попыток';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
          ),
          child: Stack(
            children: [
              const FloatingCharacter(startPosition: Alignment.bottomLeft),
              const FloatingCharacter(
                  startPosition: Alignment.bottomRight, delay: 1.5),
              const FloatingCharacter(
                  startPosition: Alignment.centerLeft, delay: 3.0),

              SafeArea(
                child: GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: Column(
                    children: [
                      _buildKawaiiHeader(),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: GameBoard(
                              rows: _gameService.rows,
                              key: ValueKey(_gameService),
                            ),
                          ),
                        ),
                      ),
                      GameKeyboard(
                        onLetterTap: _onLetterPressed,
                        onDeleteTap: _onDeletePressed,
                        onEnterTap: _onEnterPressed,
                        keyboardStatus: _gameService.keyboardStatus,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKawaiiHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _KawaiiIconButton(
            icon: Icons.help_outline_rounded,
            onPressed: _showHelpDialog,
          ),
          AnimatedBuilder(
            animation: _headerAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _headerAnimationController.value * 4 - 2),
                child: child,
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Row(
                  children: [
                    Text(
                      'WORDLE',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: AppColors.text,
                        shadows: [
                          Shadow(
                            color: AppColors.shadow,
                            offset: Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: -8,
                  right: -30,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'かわいい',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _KawaiiIconButton(
                icon: Icons.bar_chart,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const StatsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _KawaiiIconButton(
                icon: Icons.refresh_rounded,
                onPressed: _showNewGameConfirmation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Как играть (◕‿◕)',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Угадайте слово за 6 попыток!\n\nКаждая попытка должна быть существующим словом из 5 букв.\n\nЦвет плиток показывает насколько вы близки:',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.text, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _HelpExample(
                    letter: 'П',
                    color: AppColors.correct,
                    description: 'Буква на своём месте ♪(´▽｀)',
                  ),
                  const SizedBox(height: 12),
                  _HelpExample(
                    letter: 'О',
                    color: AppColors.present,
                    description: 'Буква есть, но не здесь',
                  ),
                  const SizedBox(height: 12),
                  _HelpExample(
                    letter: 'Т',
                    color: AppColors.absent,
                    description: 'Буквы нет в слове (｡•́︿•̀｡)',
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Понятно! (｡♥‿♥｡)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showNewGameConfirmation() {
    if (_gameService.isGameOver) {
      _startNewGame();
      return;
    }

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25)),
            title: const Text(
              'Новая игра? (・・？)',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.text),
            ),
            content: const Text(
              'Текущий прогресс будет потерян.',
              style: TextStyle(color: AppColors.text),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                    'Отмена', style: TextStyle(color: AppColors.text)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startNewGame(); // Здесь будет синхронизация
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                    'Начать', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }
}

class _KawaiiIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _KawaiiIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.text),
        onPressed: onPressed,
        iconSize: 28,
      ),
    );
  }
}

class _HelpExample extends StatelessWidget {
  final String letter;
  final Color color;
  final String description;

  const _HelpExample({
    required this.letter,
    required this.color,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}