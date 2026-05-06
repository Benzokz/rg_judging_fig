import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TvScreen extends StatelessWidget {
  const TvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('routines')
            .doc('current')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Ожидание выступления...',
                style: TextStyle(fontSize: 48, color: Colors.white),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final gymnastName = data['gymnastName'] ?? 'Гимнастка';
          final apparatus = data['apparatus'] ?? '';
          final finalD = (data['finalD'] ?? 0.0).toDouble();
          final finalA = (data['finalA'] ?? 0.0).toDouble();
          final finalE = (data['finalE'] ?? 0.0).toDouble();
          final total = (data['total'] ?? 0.0).toDouble();

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  gymnastName,
                  style: const TextStyle(fontSize: 72, color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (apparatus.isNotEmpty)
                  Text(
                    apparatus,
                    style: const TextStyle(fontSize: 48, color: Colors.grey),
                  ),
                const SizedBox(height: 80),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildScoreCard('D', finalD, Colors.blue),
                    const SizedBox(width: 40),
                    _buildScoreCard('A', finalA, Colors.orange),
                    const SizedBox(width: 40),
                    _buildScoreCard('E', finalE, Colors.green),
                  ],
                ),

                const SizedBox(height: 60),
                Text(
                  total.toStringAsFixed(3),
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'TOTAL',
                  style: TextStyle(fontSize: 36, color: Colors.pink, letterSpacing: 8),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreCard(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 42, color: color, fontWeight: FontWeight.bold)),
        Text(
          value.toStringAsFixed(3),
          style: TextStyle(fontSize: 52, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
