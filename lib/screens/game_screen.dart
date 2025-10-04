import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/game_service.dart';
import '../constants/words.dart';
import '../widgets/game_board.dart';
import '../widgets/keyboard.dart';

// Главный экран игры
class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameService _gameService;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startNewGame();

    // Автоматически фокусируем для приема клавиатуры
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Начать новую игру
  void _startNewGame() {
    setState(() {
      // Используем слово дня (одно и то же для всех)
      _gameService = GameService(targetWord: WordsList.getWordOfTheDay());
      // Или используй случайное слово:
      // _gameService = GameService(targetWord: WordsList.getRandomWord());
    });
  }

  // Обработка ввода с физической клавиатуры
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
        // Проверяем, что это русская буква
        if (RegExp(r'[А-ЯЁ]').hasMatch(char)) {
          _onLetterPressed(char);
        }
      }
    }
  }

  // Добавить букву
  void _onLetterPressed(String letter) {
    if (_gameService.isGameOver) return;

    setState(() {
      _gameService.addLetter(letter);
    });
  }

  // Удалить букву
  void _onDeletePressed() {
    if (_gameService.isGameOver) return;

    setState(() {
      _gameService.removeLetter();
    });
  }

  // Отправить слово на проверку
  void _onEnterPressed() {
    if (_gameService.isGameOver) return;

    final success = _gameService.submitWord();

    if (!success) {
      // Слово недопустимо - показываем сообщение
      final currentRow = _gameService.getCurrentRow();
      if (currentRow.isFilled()) {
        _showMessage('Слова нет в словаре');
      } else {
        _showMessage('Недостаточно букв');
      }
      return;
    }

    setState(() {
      // Если игра закончилась - показываем результат
      if (_gameService.isGameOver) {
        Future.delayed(const Duration(milliseconds: 2000), () {
          _showGameOverDialog();
        });
      }
    });
  }

  // Показать временное сообщение
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 100,
          left: 50,
          right: 50,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Показать диалог окончания игры
  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          _gameService.isWinner ? 'Победа! 🎉' : 'Игра окончена',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_gameService.isWinner) ...[
              const Text(
                'Загаданное слово:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _gameService.targetWord,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ] else ...[
              Text(
                'Отгадано за ${_gameService.currentRowIndex + 1} ${_getPluralAttempts(_gameService.currentRowIndex + 1)}!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            child: const Text(
              'Новая игра',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Получить правильное склонение слова "попытка"
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: const Text(
            'WORDLE',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.black),
              onPressed: () => _showHelpDialog(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: () => _showNewGameConfirmation(),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
          },
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Диалог помощи
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Как играть',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Угадайте слово за 6 попыток.\n',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'Каждая попытка должна быть существующим словом из 5 букв.\n',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'Цвет плиток меняется, показывая насколько близко ваше слово:',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              _HelpExample(
                letter: 'П',
                color: Color(0xFF6AAA64),
                description: 'Буква есть в слове на этом месте',
              ),
              SizedBox(height: 8),
              _HelpExample(
                letter: 'О',
                color: Color(0xFFC9B458),
                description: 'Буква есть в слове, но в другом месте',
              ),
              SizedBox(height: 8),
              _HelpExample(
                letter: 'Т',
                color: Color(0xFF787C7E),
                description: 'Буквы нет в слове',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  // Подтверждение новой игры
  void _showNewGameConfirmation() {
    if (_gameService.isGameOver) {
      _startNewGame();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая игра?'),
        content: const Text('Текущий прогресс будет потерян.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            child: const Text('Начать'),
          ),
        ],
      ),
    );
  }
}

// Виджет для примера в помощи
class _HelpExample extends StatelessWidget {
  final String letter;
  final Color color;
  final String description;

  const _HelpExample({
    Key? key,
    required this.letter,
    required this.color,
    required this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}