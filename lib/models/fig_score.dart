class FigScore {
  final String routineId;
  final String judgeId;
  final String role;           // DB, DA, A, E
  final double score;          // итоговый балл судьи
  final Map<String, dynamic>? breakdown; // для будущего детального ввода

  FigScore({
    required this.routineId,
    required this.judgeId,
    required this.role,
    required this.score,
    this.breakdown,
  });

  Map<String, dynamic> toMap() {
    return {
      'judgeId': judgeId,
      'role': role,
      'score': score,
      'breakdown': breakdown,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
