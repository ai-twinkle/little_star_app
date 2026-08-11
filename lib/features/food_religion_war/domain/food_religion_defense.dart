import 'package:characters/characters.dart';

enum FoodReligionDefenseError {
  empty('請輸入 1～50 字的辯護'),
  tooLong('最多只能輸入 50 字');

  const FoodReligionDefenseError(this.message);

  final String message;
}

class FoodReligionDefenseValidation {
  const FoodReligionDefenseValidation._({this.defense, this.error});

  const FoodReligionDefenseValidation.valid(FoodReligionDefense defense)
    : this._(defense: defense);

  const FoodReligionDefenseValidation.invalid(FoodReligionDefenseError error)
    : this._(error: error);

  final FoodReligionDefense? defense;
  final FoodReligionDefenseError? error;
}

class FoodReligionDefense {
  const FoodReligionDefense._({required this.text});

  static const maxCharacters = 50;

  /// The player's own wording, with only the surrounding whitespace removed:
  /// what the counter counts is what the model is asked to judge.
  final String text;

  int get characterCount => countCharacters(text);

  static int countCharacters(String value) => value.trim().characters.length;

  static FoodReligionDefenseValidation validate(String value) {
    final normalizedText = value.trim();
    final trimmedLength = normalizedText.characters.length;
    if (trimmedLength == 0) {
      return const FoodReligionDefenseValidation.invalid(
        FoodReligionDefenseError.empty,
      );
    }
    if (trimmedLength > maxCharacters) {
      return const FoodReligionDefenseValidation.invalid(
        FoodReligionDefenseError.tooLong,
      );
    }
    return FoodReligionDefenseValidation.valid(
      FoodReligionDefense._(text: normalizedText),
    );
  }
}
