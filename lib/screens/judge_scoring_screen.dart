import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JudgeScoringScreen extends StatefulWidget {
  final String role;
  const JudgeScoringScreen({super.key, required this.role});

  @override
  State<JudgeScoringScreen> createState() => _JudgeScoringScreenState();
}

class _JudgeScoringScreenState extends State<JudgeScoringScreen> {
  final _scoreController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendScore() async {
    final scoreText = _scoreController.text.trim();
    if (scoreText.isEmpty) return;

    final score = double.tryParse(scoreText);
    if (score == null || score < 0 || score > 10) return;

    setState(() => _isSending = true);

    try {
      await FirebaseFirestore.instance
await FirebaseFirestore.instance
    .collection('competitions')
    .doc('comp_1')
    .collection('routines')
    .doc('routine_1')
    .collection('judges')
    .doc(widget.role)
    .set({
  'score': score,
  'updatedAt': FieldValue.serverTimestamp(),
});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Балл отправлен!'), backgroundColor: Colors.green),
      );
      _scoreController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Судья — ${widget.role}'), backgroundColor: Colors.pink),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Панель: ${widget.role}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            TextField(
              controller: _scoreController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: '8.75', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: _isSending ? null : _sendScore,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                minimumSize: const Size(double.infinity, 70),
              ),
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Отправить балл', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
