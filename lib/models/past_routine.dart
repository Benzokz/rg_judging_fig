import 'package:cloud_firestore/cloud_firestore.dart';

class PastRoutine {
  final String id;
  final String gymnastName;
  final String yearGroup;     // например "2008-2010", "Junior" и т.д.
  final String apparatus;     // Обруч, Мяч, Булавы, Лента и т.д.
  final double finalD;
  final double finalA;
  final double finalE;
  final double total;
  final DateTime date;

  PastRoutine({
    required this.id,
    required this.gymnastName,
    required this.yearGroup,
    required this.apparatus,
    required this.finalD,
    required this.finalA,
    required this.finalE,
    required this.total,
    required this.date,
  });

  factory PastRoutine.fromMap(Map<String, dynamic> map, String id) {
    return PastRoutine(
      id: id,
      gymnastName: map['gymnastName'] ?? '',
      yearGroup: map['yearGroup'] ?? '',
      apparatus: map['apparatus'] ?? '',
      finalD: (map['finalD'] ?? 0.0).toDouble(),
      finalA: (map['finalA'] ?? 0.0).toDouble(),
      finalE: (map['finalE'] ?? 0.0).toDouble(),
      total: (map['total'] ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
    );
  }
}
