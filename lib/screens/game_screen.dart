import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/game_service.dart';
import '../constants/words.dart';
import '../constants/colors.dart';
import '../widgets/game_board.dart';
import '../widgets/keyboard.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameService _gameService;
  final FocusNode _focusNode = FocusNode();
  late AnimationController _headerAnimationController;

  @override
  void initState() {
    super.initState();
    _startNewGame();

    _headerAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _startNewGame() {
    setState(() {
      _gameService = GameService(targetWord: WordsList.getWordOfTheDay());
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
        _showMessage('Слова нет в словаре 😢');
      } else {
        _showMessage('Недостаточно букв ✨');
      }
      return;
    }

    setState(() {
      if (_gameService.isGameOver) {
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
      builder: (context) => Dialog(
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
              // Эмодзи
              Text(
                _gameService.isWinner ? '🎉✨🌟' : '😢💔',
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 16),
              // Заголовок
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
              // Содержимое
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              ] else ...[
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
                    'Отгадано за ${_gameService.currentRowIndex + 1} ${_getPluralAttempts(_gameService.currentRowIndex + 1)}!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              // Кнопка
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startNewGame();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'Новая игра ✨',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'попытки';
    } else {
      return 'попыток';
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: SafeArea(
            child: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: Column(
                children: [
                  // Kawaii хедер
                  _buildKawaiiHeader(),
                  const SizedBox(height: 10),
                  // Игровое поле
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: GameBoard(rows: _gameService.rows),
                      ),
                    ),
                  ),
                  // Клавиатура
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
          // Кнопка помощи
          _KawaiiIconButton(
            icon: Icons.help_outline_rounded,
            onPressed: _showHelpDialog,
          ),
          // Логотип с анимацией
          AnimatedBuilder(
            animation: _headerAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _headerAnimationController.value * 4 - 2),
                child: child,
              );
            },
            child: Row(
              children: [
                const Text(
                  '✨ ',
                  style: TextStyle(fontSize: 24),
                ),
                const Text(
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
                const Text(
                  ' ✨',
                  style: TextStyle(fontSize: 24),
                ),
              ],
            ),
          ),
          // Кнопка новой игры
          _KawaiiIconButton(
            icon: Icons.refresh_rounded,
            onPressed: _showNewGameConfirmation,
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
                '💡 Как играть',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Угадайте слово за 6 попыток!\n\nКаждая попытка должна быть существующим словом из 5 букв.\n\nЦвет плиток показывает насколько вы близки:',
                style: TextStyle(fontSize: 15, color: AppColors.text, height: 1.5),
              ),
              const SizedBox(height: 20),
              _HelpExample(
                letter: 'П',
                color: AppColors.correct,
                description: 'Буква на своём месте ✨',
              ),
              const SizedBox(height: 12),
              _HelpExample(
                letter: 'О',
                color: AppColors.present,
                description: 'Буква есть, но не здесь 🔄',
              ),
              const SizedBox(height: 12),
              _HelpExample(
                letter: 'Т',
                color: AppColors.absent,
                description: 'Буквы нет в слове 💔',
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Понятно! 💖',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text(
          '🎮 Новая игра?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: const Text(
          'Текущий прогресс будет потерян.',
          style: TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена', style: TextStyle(color: AppColors.text)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text('Начать', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Kawaii кнопка с иконкой
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

// Пример для помощи
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
    style: const TextStyle(fontSize: 22,
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