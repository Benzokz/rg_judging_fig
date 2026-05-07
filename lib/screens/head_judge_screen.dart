import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:html' as html;
import 'tv_screen.dart';

class HeadJudgeScreen extends StatefulWidget {
  const HeadJudgeScreen({super.key});

  @override
  State<HeadJudgeScreen> createState() => _HeadJudgeScreenState();
}

class _HeadJudgeScreenState extends State<HeadJudgeScreen> {
  int _currentTab = 0; // 0 = Текущее, 1 = История

  // Выбор гимнастки
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

              final gymnasts = snapshot.data!.docs;
              return ListView.builder(
                itemCount: gymnasts.length,
                itemBuilder: (context, index) {
                  final data = gymnasts[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['fullName'] ?? ''),
                    subtitle: Text('${data['school'] ?? ''} • ${data['region'] ?? ''}'),
                    onTap: () async {
                      await FirebaseFirestore.instance.collection('routines').doc('current').set({
                        'gymnastName': data['fullName'],
                        'gymnastId': gymnasts[index].id,
                        'apparatus': 'Обруч', // можно потом сделать выбор
                      }, SetOptions(merge: true));
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

  // Экспорт в Excel
  Future<void> _exportToExcel(
    BuildContext context,
    List<QueryDocumentSnapshot> scores,
    double finalD,
    double finalA,
    double finalE,
    double total,
    String gymnastName,
  ) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Протокол FIG'];

    sheet.appendRow([TextCellValue('ПРОТОКОЛ СУДЕЙСТВА')]);
    sheet.appendRow([TextCellValue('Художественная гимнастика — FIG 2025-2028')]);
    sheet.appendRow([TextCellValue('Гимнастка: $gymnastName')]);
    sheet.appendRow([TextCellValue('Дата: ${DateTime.now().toString().substring(0, 16)}')]);
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('№'), TextCellValue('Роль'), TextCellValue('Балл')]);

    for (int i = 0; i < scores.length; i++) {
      final data = scores[i].data() as Map<String, dynamic>;
      sheet.appendRow([
        TextCellValue((i + 1).toString()),
        TextCellValue(data['role']?.toString() ?? ''),
        TextCellValue((data['score'] as num).toStringAsFixed(2)),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('D'), TextCellValue(finalD.toStringAsFixed(3))]);
    sheet.appendRow([TextCellValue('A'), TextCellValue(finalA.toStringAsFixed(3))]);
    sheet.appendRow([TextCellValue('E'), TextCellValue(finalE.toStringAsFixed(3))]);
    sheet.appendRow([TextCellValue('TOTAL'), TextCellValue(total.toStringAsFixed(3))]);

    final bytes = excel.encode()!;
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Протокол_${gymnastName.replaceAll(' ', '_')}.xlsx")
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Протокол Excel скачан'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главный судья — FIG 2025-2028'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.tv, size: 34),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TvScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Вкладки
          Row(
            children: [
              Expanded(child: _tabButton('Текущее выступление', 0)),
              Expanded(child: _tabButton('История', 1)),
            ],
          ),

          Expanded(
            child: _currentTab == 0 ? _buildCurrentTab() : _buildHistoryTab(),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String text, int tab) {
    return InkWell(
      onTap: () => setState(() => _currentTab = tab),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: _currentTab == tab ? Colors.deepPurple : Colors.grey[200],
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _currentTab == tab ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('routines').doc('current').snapshots(),
      builder: (context, routineSnap) {
        final rData = routineSnap.data?.data() as Map<String, dynamic>? ?? {};
        final String gymnastName = rData['gymnastName'] ?? 'Гимнастка не выбрана';
        final String apparatus = rData['apparatus'] ?? '—';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('routines')
              .doc('current')
              .collection('scores')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, scoreSnap) {
            final scores = scoreSnap.data?.docs ?? [];

            final Map<String, List<double>> byRole = {};
            for (var doc in scores) {
              final data = doc.data() as Map<String, dynamic>;
              final role = data['role'] as String;
              final score = (data['score'] as num).toDouble();
              byRole.putIfAbsent(role, () => []).add(score);
            }

            double avg(List<double> list) {
              if (list.isEmpty) return 0.0;
              if (list.length <= 2) return list.fold(0.0, (a, b) => a + b) / list.length;
              list.sort();
              list.removeAt(0);
              list.removeAt(list.length - 1);
              return list.fold(0.0, (a, b) => a + b) / list.length;
            }

            final d = avg(byRole['DB'] ?? []) + avg(byRole['DA'] ?? []);
            final a = avg(byRole['A'] ?? []);
            final e = avg(byRole['E'] ?? []);
            final total = d + a + e;

            return Column(
              children: [
                // Информация о гимнастке
                Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.person, size: 48, color: Colors.pink),
                    title: Text(gymnastName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    subtitle: Text("Предмет: $apparatus"),
                    trailing: ElevatedButton(
                      onPressed: _selectGymnast,
                      child: const Text('Сменить'),
                    ),
                  ),
                ),

                // Финальный расчёт
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScoreBox('D', d.toStringAsFixed(3), Colors.blue),
                      _buildScoreBox('A', a.toStringAsFixed(3), Colors.orange),
                      _buildScoreBox('E', e.toStringAsFixed(3), Colors.green),
                      _buildScoreBox('TOTAL', total.toStringAsFixed(3), Colors.purple, isBig: true),
                    ],
                  ),
                ),

                // Оценки судей
                Expanded(
                  child: ListView.builder(
                    itemCount: scores.length,
                    itemBuilder: (context, i) {
                      final data = scores[i].data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(data['role'].toString())),
                          title: Text('${data['role']}'),
                          trailing: Text(
                            (data['score'] as num).toStringAsFixed(2),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Кнопки действий
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _exportToExcel(context, scores, d, a, e, total, gymnastName),
                              icon: const Icon(Icons.table_chart),
                              label: const Text('Excel'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _finishAndSaveToHistory(gymnastName, apparatus, d, a, e, total),
                              icon: const Icon(Icons.save),
                              label: const Text('Завершить'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('history').orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final history = snapshot.data!.docs;

        return ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final data = history[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(data['gymnastName'] ?? ''),
                subtitle: Text('${data['apparatus']} • ${data['date'].toDate().toString().substring(0, 16)}'),
                trailing: Text(
                  (data['total'] ?? 0.0).toStringAsFixed(3),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _finishAndSaveToHistory(String name, String app, double d, double a, double e, double total) async {
    await FirebaseFirestore.instance.collection('history').add({
      'gymnastName': name,
      'apparatus': app,
      'finalD': d,
      'finalA': a,
      'finalE': e,
      'total': total,
      'date': FieldValue.serverTimestamp(),
    });

    // Очистка текущих оценок
    final scores = await FirebaseFirestore.instance.collection('routines').doc('current').collection('scores').get();
    for (var doc in scores.docs) {
      await doc.reference.delete();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Выступление сохранено в историю'), backgroundColor: Colors.green),
    );
  }

  Widget _buildScoreBox(String label, String value, Color color, {bool isBig = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: isBig ? 22 : 18, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: isBig ? 36 : 28, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
