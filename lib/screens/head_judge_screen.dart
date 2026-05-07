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
              final list = snapshot.data!.docs;
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final data = list[i].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['fullName'] ?? ''),
                    subtitle: Text('${data['school'] ?? ''} • ${data['region'] ?? ''}'),
                    onTap: () async {
                      await FirebaseFirestore.instance.collection('routines').doc('current').set({
                        'gymnastName': data['fullName'],
                        'gymnastId': list[i].id,
                        'apparatus': 'Обруч',
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

  // Экспорт одного выступления в Excel
  Future<void> _exportSinglePerformance(BuildContext context, Map<String, dynamic> data) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Протокол'];

    sheet.appendRow([TextCellValue('ПРОТОКОЛ СУДЕЙСТВА')]);
    sheet.appendRow([TextCellValue('Художественная гимнастика — FIG 2025-2028')]);
    sheet.appendRow([TextCellValue('Гимнастка: ${data['gymnastName']}')]);
    sheet.appendRow([TextCellValue('Предмет: ${data['apparatus'] ?? '-'}')]);
    sheet.appendRow([TextCellValue('Дата: ${data['date'].toDate().toString().substring(0, 16)}')]);
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('D'), TextCellValue((data['finalD'] ?? 0.0).toStringAsFixed(3))]);
    sheet.appendRow([TextCellValue('A'), TextCellValue((data['finalA'] ?? 0.0).toStringAsFixed(3))]);
    sheet.appendRow([TextCellValue('E'), TextCellValue((data['finalE'] ?? 0.0).toStringAsFixed(3))]);
    sheet.appendRow([TextCellValue('TOTAL'), TextCellValue((data['total'] ?? 0.0).toStringAsFixed(3))]);

    final bytes = excel.encode()!;
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Протокол_${data['gymnastName'] ?? 'Выступление'}.xlsx")
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Протокол скачан'), backgroundColor: Colors.green),
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
          Row(
            children: [
              Expanded(child: _tabButton('Текущее выступление', 0)),
              Expanded(child: _tabButton('История выступлений', 1)),
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

  // ==================== ТЕКУЩЕЕ ВЫСТУПЛЕНИЕ ====================
  Widget _buildCurrentTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('routines').doc('current').snapshots(),
      builder: (context, rSnap) {
        final rData = rSnap.data?.data() as Map<String, dynamic>? ?? {};
        final String gymnastName = rData['gymnastName'] ?? 'Гимнастка не выбрана';

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('routines').doc('current').collection('scores').orderBy('timestamp', descending: true).snapshots(),
          builder: (context, sSnap) {
            final scores = sSnap.data?.docs ?? [];

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
                Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.person, size: 48, color: Colors.pink),
                    title: Text(gymnastName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    subtitle: Text(rData['apparatus'] ?? '—'),
                    trailing: ElevatedButton(onPressed: _selectGymnast, child: const Text('Сменить')),
                  ),
                ),

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
                          trailing: Text((data['score'] as num).toStringAsFixed(2), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
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
                        child: ElevatedButton(
                          onPressed: () => _finishAndSaveToHistory(gymnastName, rData['apparatus'] ?? '-', d, a, e, total),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Завершить выступление'),
                        ),
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

  // ==================== ИСТОРИЯ ====================
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
            final date = (data['date'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.all(8),
              child: ExpansionTile(
                leading: const Icon(Icons.history, color: Colors.deepPurple),
                title: Text(data['gymnastName'] ?? 'Без имени'),
                subtitle: Text('${data['apparatus'] ?? '-'} • ${date.toString().substring(0, 16)}'),
                trailing: Text(
                  (data['total'] ?? 0.0).toStringAsFixed(3),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildScoreBox('D', (data['finalD'] ?? 0.0).toStringAsFixed(3), Colors.blue),
                            _buildScoreBox('A', (data['finalA'] ?? 0.0).toStringAsFixed(3), Colors.orange),
                            _buildScoreBox('E', (data['finalE'] ?? 0.0).toStringAsFixed(3), Colors.green),
                            _buildScoreBox('TOTAL', (data['total'] ?? 0.0).toStringAsFixed(3), Colors.purple, isBig: true),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _exportToExcel(context, [], data['finalD'] ?? 0.0, data['finalA'] ?? 0.0, data['finalE'] ?? 0.0, data['total'] ?? 0.0, data['gymnastName'] ?? ''),
                          icon: const Icon(Icons.download),
                          label: const Text('Скачать протокол Excel'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
    for (var doc in scores.docs) await doc.reference.delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Выступление сохранено в историю'), backgroundColor: Colors.green),
    );
  }

  Future<void> _exportToExcel(
    BuildContext context,
    List<QueryDocumentSnapshot> scores,
    double finalD,
    double finalA,
    double finalE,
    double total,
    String gymnastName,
  ) async {
    // (тот же код экспорта, что был раньше)
    var excel = Excel.createExcel();
    Sheet sheet = excel['Протокол'];

    sheet.appendRow([TextCellValue('ПРОТОКОЛ СУДЕЙСТВА')]);
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
}
