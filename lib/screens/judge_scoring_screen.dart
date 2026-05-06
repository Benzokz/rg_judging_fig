import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JudgeScoringScreen extends StatefulWidget {
  final String role;
  final String gymnastId;
  final String gymnastName;

  const JudgeScoringScreen({
    super.key,
    required this.role,
    required this.gymnastId,
    required this.gymnastName,
  });

  @override
  State<JudgeScoringScreen> createState() => _JudgeScoringScreenState();
}

class _JudgeScoringScreenState extends State<JudgeScoringScreen> {
  final _scoreController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendScore() async {
    final score = double.tryParse(_scoreController.text.trim());
    if (score == null || score < 0 || score > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Балл от 0.00 до 10.00'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await FirebaseFirestore.instance
          .collection('routines')
          .doc('current')                    // <-- важно!
          .collection('scores')
          .add({
        'role': widget.role,
        'score': score,
        'gymnastId': widget.gymnastId,
        'gymnastName': widget.gymnastName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.role} — ${score.toStringAsFixed(2)} отправлено ✓'), backgroundColor: Colors.green),
      );
      _scoreController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color roleColor = widget.role.startsWith('D') ? Colors.blue : widget.role == 'A' ? Colors.orange : Colors.green;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.role} — ${widget.gymnastName}'), backgroundColor: roleColor),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Панель: ${widget.role}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: roleColor)),
            const SizedBox(height: 40),
            TextField(
              controller: _scoreController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: '8.75', border: OutlineInputBorder(), filled: true),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: _isSending ? null : _sendScore,
              style: ElevatedButton.styleFrom(backgroundColor: roleColor, minimumSize: const Size(double.infinity, 75)),
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Отправить ${widget.role}', style: const TextStyle(fontSize: 22)),
            ),
          ],
        ),
      ),
    );
  }
}
