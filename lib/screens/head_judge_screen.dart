import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HeadJudgeScreen extends StatelessWidget {
  const HeadJudgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Главный судья'), backgroundColor: Colors.deepPurple),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
    .collection('competitions')
    .doc('comp_1')
    .collection('routines')
    .doc('routine_1')
    .collection('scores')
    .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final score = (data['score'] ?? 0).toDouble();
score.toStringAsFixed(2)

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Получено баллов: ${scores.length}', style: const TextStyle(fontSize: 22)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: scores.length,
                  itemBuilder: (context, index) {
                    final data = scores[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(data['role'].toString())),
                        title: Text('${data['role']}'),
                        trailing: Text(
                          data['score'].toStringAsFixed(2),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.pink),
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
