import 'package:flutter/material.dart' hide Border;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'tv_screen.dart';

class HeadJudgeScreen extends StatefulWidget {
  const HeadJudgeScreen({super.key});

  @override
  State<HeadJudgeScreen> createState() => _HeadJudgeScreenState();
}

class _HeadJudgeScreenState extends State<HeadJudgeScreen> {
  int _currentTab = 0;

  // Метод для выгрузки Excel
  void _downloadExcel(Map<String, dynamic> data) {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Протокол'];
    sheet.appendRow([TextCellValue('ПРОТОКОЛ РЕЗУЛЬТАТОВ')]);
    sheet.appendRow([TextCellValue('Гимнастка: ${data['gymnastName']}')]);
    sheet.appendRow([TextCellValue('Предмет: ${data['apparatus']}')]);
    sheet.appendRow([TextCellValue('D: ${data['finalD']}')]);
    sheet.appendRow([TextCellValue('A: ${data['finalA']}')]);
    sheet.appendRow([TextCellValue('E: ${data['finalE']}')]);
    sheet.appendRow([TextCellValue('ИТОГО: ${data['total']}')]);

    final bytes = excel.encode()!;
    final content = Uint8List.fromList(bytes).toJS;
    final blob = web.Blob([content].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = "Protocol_${data['gymnastName']}.xlsx";
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  void _selectGymnast() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ВЫБОР ГИМНАСТКИ (FIG 2025-2028)'),
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
                    leading: const Icon(Icons.person_add),
                    title: Text(data['fullName'] ?? ''),
                    subtitle: Text(data['school'] ?? ''),
                    onTap: () async {
                      await FirebaseFirestore.instance.collection('routines').doc('current').set({
                        'gymnastName': data['fullName'],
                        'apparatus': 'Обруч',
                        'region': data['region'] ?? '',
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

  double _calculateFigScore(List<double> scores) {
    if (scores.isEmpty) return 0.0;
    if (scores.length <= 2) return scores.reduce((a, b) => a + b) / scores.length;
    List<double> sorted = List.from(scores)..sort();
    sorted.removeAt(0);
    sorted.removeLast();
    return sorted.reduce((a, b) => a + b) / sorted.length;
  }

  Future<void> _finishPerformance(String name, String app, double d, double a, double e, double total) async {
    if (name == "Ожидание..." || name.isEmpty) return;

    await FirebaseFirestore.instance.collection('history').add({
      'gymnastName': name,
      'apparatus': app,
      'finalD': d,
      'finalA': a,
      'finalE': e,
      'total': total,
      'date': FieldValue.serverTimestamp(),
    });

    final scores = await FirebaseFirestore.instance.collection('routines').doc('current').collection('scores').get();
    for (var doc in scores.docs) { await doc.reference.delete(); }

    await FirebaseFirestore.instance.collection('routines').doc('current').update({
      'gymnastName': 'Ожидание...',
      'apparatus': '-',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ГЛАВНЫЙ СУДЬЯ: ПАНЕЛЬ УПРАВЛЕНИЯ'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_overscan, size: 30),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TvScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[200],
            child: Row(children: [
              _tabBtn("СУДЕЙСТВО", 0),
              _tabBtn("АРХИВ", 1),
            ]),
          ),
          Expanded(child: _currentTab == 0 ? _buildMainSystem() : _buildHistory()),
        ],
      ),
    );
  }

  Widget _tabBtn(String t, int i) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _currentTab = i),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _currentTab == i ? Colors.deepPurple : Colors.transparent,
          border: Border(bottom: BorderSide(color: _currentTab == i ? Colors.white : Colors.transparent, width: 3)),
        ),
        child: Text(t, textAlign: TextAlign.center, style: TextStyle(
          color: _currentTab == i ? Colors.white : Colors.black54, 
          fontWeight: FontWeight.bold
        )),
      ),
    ),
  );

  Widget _buildMainSystem() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('routines').doc('current').snapshots(),
      builder: (context, rSnap) {
        final rData = rSnap.data?.data() as Map<String, dynamic>? ?? {};
        String gymnastName = rData['gymnastName'] ?? "Гимнастка не выбрана";
        String apparatus = rData['apparatus'] ?? "-";

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('routines').doc('current').collection('scores').snapshots(),
          builder: (context, sSnap) {
            final docs = sSnap.data?.docs ?? [];
            Map<String, List<double>> grouped = {};
            for (var d in docs) {
              final data = d.data() as Map<String, dynamic>;
              grouped.putIfAbsent(data['role'], () => []).add((data['score'] as num).toDouble());
            }

            double dFinal = _calculateFigScore(grouped['DB'] ?? []) + _calculateFigScore(grouped['DA'] ?? []);
            double aFinal = _calculateFigScore(grouped['A'] ?? []);
            double eFinal = _calculateFigScore(grouped['E'] ?? []);
            double total = dFinal + aFinal + eFinal;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: ListTile(
                      title: Text(gymnastName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      subtitle: Text("ПРЕДМЕТ: $apparatus"),
                      trailing: ElevatedButton(onPressed: _selectGymnast, child: const Text("ВЫБРАТЬ")),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _scoreBox("D", dFinal, Colors.blue),
                      _scoreBox("A", aFinal, Colors.orange),
                      _scoreBox("E", eFinal, Colors.green),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(total.toStringAsFixed(3), style: const TextStyle(fontSize: 80, fontWeight: FontWeight.black, color: Colors.deepPurple)),
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text("Судья ${data['role']}"),
                        trailing: Text("${data['score']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], minimumSize: const Size(double.infinity, 60)),
                    onPressed: () => _finishPerformance(gymnastName, apparatus, dFinal, aFinal, eFinal, total),
                    child: const Text("ЗАВЕРШИТЬ И СОХРАНИТЬ", style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _scoreBox(String label, double val, Color c) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      Text(val.toStringAsFixed(3), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c)),
    ],
  );

  Widget _buildHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('history').orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, i) {
            final doc = snap.data!.docs[i];
            final d = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(d['gymnastName']),
              subtitle: Text(d['apparatus']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d['total'].toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.download), onPressed: () => _downloadExcel(d)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
