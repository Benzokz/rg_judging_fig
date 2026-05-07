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

  void _downloadExcel(Map<String, dynamic> data) {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Протокол'];
    sheet.appendRow([TextCellValue('ПРОТОКОЛ РЕЗУЛЬТАТОВ')]);
    sheet.appendRow([TextCellValue('Гимнастка: ${data['gymnastName']}')]);
    sheet.appendRow([TextCellValue('Предмет: ${data['apparatus']}')]);
    sheet.appendRow([TextCellValue('D: ${data['finalD'] ?? 0.0}')]);
    sheet.appendRow([TextCellValue('A: ${data['finalA'] ?? 0.0}')]);
    sheet.appendRow([TextCellValue('E: ${data['finalE'] ?? 0.0}')]);
    sheet.appendRow([TextCellValue('ИТОГО: ${data['total']}')]);

    final bytes = excel.encode()!;
    final content = Uint8List.fromList(bytes).toJS;
    final blob = web.Blob([content].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = "Result_${data['gymnastName']}.xlsx";
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  double _calculateFigScore(List<double> scores) {
    if (scores.isEmpty) return 0.0;
    if (scores.length <= 2) return scores.reduce((a, b) => a + b) / scores.length;
    List<double> sorted = List.from(scores)..sort();
    sorted.removeAt(0);
    sorted.removeLast();
    return sorted.reduce((a, b) => a + b) / sorted.length;
  }

  void _selectGymnast() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ВЫБОР ГИМНАСТКИ'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
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
        title: const Text('ГЛАВНЫЙ СУДЬЯ'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.tv),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TvScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Row(children: [
            _tabBtn("СУДЕЙСТВО", 0),
            _tabBtn("АРХИВ", 1),
          ]),
          Expanded(child: _currentTab == 0 ? _buildMainSystem() : _buildHistory()),
        ],
      ),
    );
  }

  Widget _tabBtn(String t, int i) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _currentTab = i),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _currentTab == i ? Colors.deepPurple : Colors.grey[200],
          border: Border(bottom: BorderSide(color: _currentTab == i ? Colors.white : Colors.transparent, width: 2)),
        ),
        child: Text(t, textAlign: TextAlign.center, style: TextStyle(color: _currentTab == i ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
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
                Card(margin: const EdgeInsets.all(16), child: ListTile(
                  title: Text(gymnastName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text("ПРЕДМЕТ: $apparatus"),
                  trailing: ElevatedButton(onPressed: _selectGymnast, child: const Text("ВЫБРАТЬ")),
                )),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _scoreBox("D", dFinal, Colors.blue),
                  _scoreBox("A", aFinal, Colors.orange),
                  _scoreBox("E", eFinal, Colors.green),
                ]),
                const SizedBox(height: 10),
                Text(total.toStringAsFixed(3), style: const TextStyle(fontSize: 60, fontWeight: FontWeight.black, color: Colors.deepPurple)),
                Expanded(child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return ListTile(title: Text("Судья ${data['role']}"), trailing: Text("${data['score']}"));
                  },
                )),
                Padding(padding: const EdgeInsets.all(16), child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], minimumSize: const Size(double.infinity, 50)),
                  onPressed: () => _finishPerformance(gymnastName, apparatus, dFinal, aFinal, eFinal, total),
                  child: const Text("ЗАВЕРШИТЬ И СОХРАНИТЬ", style: TextStyle(color: Colors.white)),
                ))
              ],
            );
          },
        );
      },
    );
  }

  Widget _scoreBox(String label, double val, Color c) => Column(children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    Text(val.toStringAsFixed(3), style: TextStyle(fontSize: 20, color: c, fontWeight: FontWeight.bold)),
  ]);

  Widget _buildHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('history').orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, i) {
            final d = snap.data!.docs[i].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(d['gymnastName']),
              subtitle: Text("${d['apparatus']} | ${d['total'].toStringAsFixed(3)}"),
              trailing: IconButton(icon: const Icon(Icons.download), onPressed: () => _downloadExcel(d)),
            );
          },
        );
      },
    );
  }
}
