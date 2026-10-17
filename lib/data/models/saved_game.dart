import 'guess.dart';

enum GameStatus { playing, won, gaveUp }

/// Persisted state of one puzzle so the player can resume after closing the app.
class SavedGame {
  SavedGame({
    required this.puzzleId,
    this.guesses = const [],
    this.hintsUsed = 0,
    this.elapsedSeconds = 0,
    this.status = GameStatus.playing,
    this.firstLetterHint = false,
    this.lengthHint = false,
  });

  final String puzzleId;
  final List<Guess> guesses;
  final int hintsUsed;
  final int elapsedSeconds;
  final GameStatus status;
  final bool firstLetterHint;
  final bool lengthHint;

  Map<String, dynamic> toJson() => {
        'puzzleId': puzzleId,
        'guesses': guesses.map((g) => g.toJson()).toList(),
        'hintsUsed': hintsUsed,
        'elapsed': elapsedSeconds,
        'status': status.name,
        'firstLetterHint': firstLetterHint,
        'lengthHint': lengthHint,
      };

  factory SavedGame.fromJson(Map<dynamic, dynamic> json) => SavedGame(
        puzzleId: json['puzzleId'] as String,
        guesses: (json['guesses'] as List)
            .map((e) => Guess.fromJson(e as Map))
            .toList(),
        hintsUsed: json['hintsUsed'] as int? ?? 0,
        elapsedSeconds: json['elapsed'] as int? ?? 0,
        status: GameStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => GameStatus.playing,
        ),
        firstLetterHint: json['firstLetterHint'] as bool? ?? false,
        lengthHint: json['lengthHint'] as bool? ?? false,
      );
}
