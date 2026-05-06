import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'package:web/web.dart' as web; // Современный импорт для Web
import 'tv_screen.dart';

class HeadJudgeScreen extends StatefulWidget {
  const HeadJudgeScreen({super.key});

  @override
  State<HeadJudgeScreen> createState() => _HeadJudgeScreenState();
}

class _HeadJudgeScreenState extends State<HeadJudgeScreen> {
  int _currentTab = 0; // 0 = Текущее, 1 = История

  String? currentGymnastName;
  String? currentGymnastId;
  String currentApparatus = "Обруч";

  // Метод для скачивания файла в вебе (замена dart:html)
  void _downloadFile(Uint8List bytes, String fileName) {
    final blob = web.Blob([bytes.buffer.asUint8List()].toList().cast<web.JSObject>());
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  // Выбор гимнастки из базы
  void _selectGymnast() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите гимнастку'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('gymnasts').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final list = snapshot.data!.docs;
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final data = list[i].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['fullName'] ?? 'Без имени'),
                    subtitle: Text('${data['school'] ?? ''} • ${data['region'] ?? ''}'),
                    onTap: () {
                      setState(() {
                        currentGymnastId = list[i].id;
                        currentGymnastName = data['fullName'];
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Сохранение в историю и очистка текущего выступления
  Future<void> _finishAndSaveToHistory(double d, double a, double e, double total) async {
    if (currentGymnastName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Сначала выберите гимнастку!'), backgroundColor: Colors.red),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('history').add({
      'gymnastName': currentGymnastName,
      'gymnastId': currentGymnastId,
      'apparatus': currentApparatus,
      'finalD': d,
      'finalA': a,
      'finalE': e,
      'total': total,
      'date': FieldValue.serverTimestamp(),
    });

    // Очистка текущих оценок в Firebase
    final scoresRef = FirebaseFirestore.instance.collection('routines').doc('current').collection('scores');
    final snapshots = await scoresRef.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }

    setState(() {
      currentGymnastName = null;
      currentGymnastId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Результат сохранен в историю'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главный судья (Pavlodar 24/7)'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.tv, size: 30),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TvScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Вкладки
          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                _buildTabItem('ТЕКУЩЕЕ', 0),
                _buildTabItem('ИСТОРИЯ', 1),
              ],
            ),
          ),
          Expanded(
            child: _currentTab == 0 ? _buildCurrentRoutineTab() : _buildHistoryTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    bool isActive = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isActive ? Colors.deepPurple : Colors.transparent, width: 3)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.deepPurple : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildCurrentRoutineTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('routines').doc('current').collection('scores').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        Map<String, List<double>> groupedScores = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          String role = data['role'] ?? 'Unknown';
          double score = (data['score'] as num).toDouble();
          groupedScores.putIfAbsent(role, () => []).add(score);
        }

        // Логика расчета среднего (FIG: убираем мин/макс если судей много)
        double calcFinal(List<double>? list) {
          if (list == null || list.isEmpty) return 0.0;
          if (list.length <= 2) return list.reduce((a, b) => a + b) / list.length;
          list.sort();
          return (list.reduce((a, b) => a + b) - list.first - list.last) / (list.length - 2);
        }

        double finalD = (calcFinal(groupedScores['DB']) + calcFinal(groupedScores['DA']));
        double finalA = calcFinal(groupedScores['A']);
        double finalE = calcFinal(groupedScores['E']);
        double total = finalD + finalA + finalE;

        return Column(
          children: [
            ListTile(
              tileColor: Colors.amber[50],
              leading: const Icon(Icons.person_pin, color: Colors.deepPurple, size: 40),
              title: Text(currentGymnastName ?? "Выберите гимнастку", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Предмет: $currentApparatus"),
              trailing: ElevatedButton(onPressed: _selectGymnast, child: const Text("Выбрать")),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _scoreResult("D (Сложность)", finalD, Colors.blue),
                _scoreResult("A (Артизм)", finalA, Colors.orange),
                _scoreResult("E (Исполнение)", finalE, Colors.green),
              ],
            ),
            const SizedBox(height: 10),
            Text(total.toStringAsFixed(3), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const Text("ИТОГОВЫЙ БАЛЛ"),
            const Divider(),
            Expanded(
              child: ListView(
                children: groupedScores.entries.map((e) => ListTile(
                  title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(e.value.join(" | "), style: const TextStyle(fontSize: 18)),
                )).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _finishAndSaveToHistory(finalD, finalA, finalE, total),
                  child: const Text("ЗАВЕРШИТЬ И СОХРАНИТЬ", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('history').orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.deepPurple, child: Text("${i+1}", style: const TextStyle(color: Colors.white))),
                title: Text(data['gymnastName'] ?? 'Гимнастка', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${data['apparatus']} | D:${data['finalD']} A:${data['finalA']} E:${data['finalE']}"),
                trailing: Text("${data['total']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _scoreResult(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value.toStringAsFixed(3), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
