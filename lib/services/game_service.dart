import '../models/word_data.dart';
import './words_api_service.dart';

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
      final newLetters = List<Letter>.from(currentRow.letters);
      newLetters[emptyIndex] = Letter(
        character: letter.toUpperCase(),
        status: LetterStatus.notChecked,
      );
      rows[currentRowIndex] = WordRow(letters: newLetters);
    }
  }

  // Удалить последнюю букву из текущей строки
  void removeLetter() {
    if (isGameOver) return;

    final currentRow = rows[currentRowIndex];
    for (int i = currentRow.letters.length - 1; i >= 0; i--) {
      if (currentRow.letters[i].character.isNotEmpty) {
        final newLetters = List<Letter>.from(currentRow.letters);
        newLetters[i] = Letter(character: '');
        rows[currentRowIndex] = WordRow(letters: newLetters);
        break;
      }
    }
  }

  // Проверить введенное слово
  bool submitWord() {
    if (isGameOver) return false;

    final currentRow = rows[currentRowIndex];
    if (!currentRow.isFilled()) return false;

    final guessWord = currentRow.getWord();
    if (!WordsApiService.isValidWord(guessWord)) return false;

    // Проверка слова и обновление статусов
    final newRow = _checkWord(currentRow, guessWord);
    rows[currentRowIndex] = newRow;

    if (guessWord == targetWord) {
      isGameOver = true;
      isWinner = true;
      return true;
    }

    currentRowIndex++;
    if (currentRowIndex >= 6) {
      isGameOver = true;
      isWinner = false;
    }

    return true;
  }

  // Проверка слова с пересозданием объектов (фикс подсветки)
  WordRow _checkWord(WordRow row, String guessWord) {
    final targetLetters = targetWord.split('');
    final guessLetters = guessWord.split('');
    final targetLetterCounts = <String, int>{};

    for (var letter in targetLetters) {
      targetLetterCounts[letter] = (targetLetterCounts[letter] ?? 0) + 1;
    }

    final newLetters = List<Letter>.generate(5, (i) {
      final ch = guessLetters[i];
      LetterStatus status = LetterStatus.notChecked;

      if (ch == targetLetters[i]) {
        status = LetterStatus.correct;
        targetLetterCounts[ch] = targetLetterCounts[ch]! - 1;
        _updateKeyboardStatus(ch, LetterStatus.correct);
      }

      return Letter(character: ch, status: status);
    });

    for (int i = 0; i < 5; i++) {
      if (newLetters[i].status == LetterStatus.correct) continue;
      final ch = guessLetters[i];

      if (targetLetters.contains(ch) && (targetLetterCounts[ch] ?? 0) > 0) {
        newLetters[i] = Letter(character: ch, status: LetterStatus.present);
        targetLetterCounts[ch] = targetLetterCounts[ch]! - 1;

        if (keyboardStatus[ch] != LetterStatus.correct) {
          _updateKeyboardStatus(ch, LetterStatus.present);
        }
      } else {
        newLetters[i] = Letter(character: ch, status: LetterStatus.absent);

        if (keyboardStatus[ch] != LetterStatus.correct &&
            keyboardStatus[ch] != LetterStatus.present) {
          _updateKeyboardStatus(ch, LetterStatus.absent);
        }
      }
    }

    return WordRow(letters: newLetters);
  }

  void _updateKeyboardStatus(String letter, LetterStatus status) {
    keyboardStatus[letter] = status;
  }

  WordRow getCurrentRow() {
    return rows[currentRowIndex];
  }
}
