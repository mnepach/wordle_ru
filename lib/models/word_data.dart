// Статусы
enum LetterStatus {
  empty,    // Пустая клетка
  notChecked, // Введена, но еще не проверена
  correct,  // Правильная буква на правильном месте
  present,  // Буква есть в слове, но не на этом месте
  absent,   // Буквы нет в слове
}

class Letter {
  final String character;
  final LetterStatus status;

  Letter({
    required this.character,
    this.status = LetterStatus.empty,
  });

  Letter copyWith({
    String? character,
    LetterStatus? status,
  }) {
    return Letter(
      character: character ?? this.character,
      status: status ?? this.status,
    );
  }
}

class WordRow {
  final List<Letter> letters;

  WordRow({required this.letters});

  factory WordRow.empty() {
    return WordRow(
      letters: List.generate(
        5,
            (index) => Letter(character: ''),
      ),
    );
  }

  String getWord() {
    return letters.map((l) => l.character).join();
  }

  // заполнена ли строка проверка
  bool isFilled() {
    return letters.every((letter) => letter.character.isNotEmpty);
  }
}