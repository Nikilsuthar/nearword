class Guess {
  const Guess({
    required this.word,
    required this.rank,
    required this.timestamp,
  });

  final String word;
  final int rank;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'word': word,
    'rank': rank,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  factory Guess.fromJson(Map<dynamic, dynamic> json) => Guess(
    word: json['word'] as String,
    rank: json['rank'] as int,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
  );
}
