import '../models/word_data.dart';
import '../constants/words.dart';

// Сервис с логикой игры
class GameService {
  final String targetWord;
  List<WordRow> rows = [];
  int currentRowIndex = 0;
  Map<String, LetterStatus> keyboardStatus = {};
  bool isGameOver = false;
  bool isWinner = false;

  GameService({required this.targetWord}) {
    // Инициализируем 6 пустых строк (6 попыток)
    rows = List.generate(6, (index) => WordRow.empty());
    _initKeyboardStatus();
  }

  // Инициализация статуса клавиатуры
  void _initKeyboardStatus() {
    const russianLetters = 'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ';
    for (var letter in russianLetters.split('')) {
      keyboardStatus[letter] = LetterStatus.empty;
    }
  }

  // Добавить букву в текущую строку
  void addLetter(String letter) {
    if (isGameOver) return;

    final currentRow = rows[currentRowIndex];
    final emptyIndex = currentRow.letters.indexWhere((l) => l.character.isEmpty);

    if (emptyIndex != -1) {
      currentRow.letters[emptyIndex] = Letter(
        character: letter.toUpperCase(),
        status: LetterStatus.notChecked,
      );
    }
  }

  // Удалить последнюю букву из текущей строки
  void removeLetter() {
    if (isGameOver) return;

    final currentRow = rows[currentRowIndex];
    for (int i = currentRow.letters.length - 1; i >= 0; i--) {
      if (currentRow.letters[i].character.isNotEmpty) {
        currentRow.letters[i] = Letter(character: '');
        break;
      }
    }
  }

  // Проверить введенное слово
  bool submitWord() {
    if (isGameOver) return false;

    final currentRow = rows[currentRowIndex];

    // Проверяем, заполнена ли строка
    if (!currentRow.isFilled()) {
      return false;
    }

    final guessWord = currentRow.getWord();

    // Проверяем, существует ли такое слово
    if (!WordsList.isValidWord(guessWord)) {
      return false;
    }

    // Проверяем буквы
    _checkWord(currentRow, guessWord);

    // Проверяем, выиграл ли игрок
    if (guessWord == targetWord) {
      isGameOver = true;
      isWinner = true;
      return true;
    }

    // Переходим к следующей строке
    currentRowIndex++;

    // Проверяем, закончились ли попытки
    if (currentRowIndex >= 6) {
      isGameOver = true;
      isWinner = false;
    }

    return true;
  }

  // Проверка слова и назначение статусов буквам
  void _checkWord(WordRow row, String guessWord) {
    final targetLetters = targetWord.split('');
    final guessLetters = guessWord.split('');
    final targetLetterCounts = <String, int>{};

    // Подсчитываем количество каждой буквы в целевом слове
    for (var letter in targetLetters) {
      targetLetterCounts[letter] = (targetLetterCounts[letter] ?? 0) + 1;
    }

    // Первый проход: отмечаем правильные буквы (зеленые)
    for (int i = 0; i < 5; i++) {
      if (guessLetters[i] == targetLetters[i]) {
        row.letters[i] = row.letters[i].copyWith(status: LetterStatus.correct);
        targetLetterCounts[guessLetters[i]] = targetLetterCounts[guessLetters[i]]! - 1;
        _updateKeyboardStatus(guessLetters[i], LetterStatus.correct);
      }
    }

    // Второй проход: отмечаем буквы, которые есть в слове (желтые)
    for (int i = 0; i < 5; i++) {
      if (row.letters[i].status == LetterStatus.correct) continue;

      if (targetLetters.contains(guessLetters[i]) &&
          (targetLetterCounts[guessLetters[i]] ?? 0) > 0) {
        row.letters[i] = row.letters[i].copyWith(status: LetterStatus.present);
        targetLetterCounts[guessLetters[i]] = targetLetterCounts[guessLetters[i]]! - 1;

        // Обновляем клавиатуру только если там еще не стоит correct
        if (keyboardStatus[guessLetters[i]] != LetterStatus.correct) {
          _updateKeyboardStatus(guessLetters[i], LetterStatus.present);
        }
      } else {
        row.letters[i] = row.letters[i].copyWith(status: LetterStatus.absent);

        // Обновляем клавиатуру только если там еще не стоит correct или present
        if (keyboardStatus[guessLetters[i]] != LetterStatus.correct &&
            keyboardStatus[guessLetters[i]] != LetterStatus.present) {
          _updateKeyboardStatus(guessLetters[i], LetterStatus.absent);
        }
      }
    }
  }

  // Обновление статуса клавиши на клавиатуре
  void _updateKeyboardStatus(String letter, LetterStatus status) {
    keyboardStatus[letter] = status;
  }

  // Получить текущую строку
  WordRow getCurrentRow() {
    return rows[currentRowIndex];
  }
}