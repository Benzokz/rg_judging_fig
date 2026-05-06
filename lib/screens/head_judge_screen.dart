import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HeadJudgeScreen extends StatelessWidget {
  const HeadJudgeScreen({super.key});

  double calculateFinalScore(List<QueryDocumentSnapshot> docs) {
    final scores = docs
        .map((d) => (d['score'] ?? 0).toDouble())
        .toList();

    if (scores.length < 3) return 0;

    scores.sort();
    scores.removeAt(0);
    scores.removeLast();

    final sum = scores.reduce((a, b) => a + b);
    return sum / scores.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главный судья'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('competitions')
            .doc('comp_1')
            .collection('routines')
            .doc('routine_1')
            .collection('scores')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final scores = snapshot.data!.docs;
          final finalScore = calculateFinalScore(scores);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Итоговый балл: ${finalScore.toStringAsFixed(3)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Получено баллов: ${scores.length}',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: scores.length,
                  itemBuilder: (context, index) {
                    final data =
                        scores[index].data() as Map<String, dynamic>;

                    final score =
                        (data['score'] ?? 0).toDouble();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(scores[index].id),
                        ),
                        title: Text(scores[index].id),
                        trailing: Text(
                          score.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
