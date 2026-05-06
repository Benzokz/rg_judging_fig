import 'package:flutter/material.dart' hide Border;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

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
    sheet.appendRow([TextCellValue('Гимнастка: ${data['gymnastName']}')]);
    sheet.appendRow([TextCellValue('Предмет: ${data['apparatus']}')]);
    sheet.appendRow([TextCellValue('Итого: ${data['total']}')]);
    
    final bytes = excel.encode()!;
    final content = Uint8List.fromList(bytes).toJS;
    final blob = web.Blob([content].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = "Result_${data['gymnastName']}.xlsx";
    anchor.click();
  }

  Future<void> _finish(String name, String app, double d, double a, double e, double total) async {
    if (name == "Ожидание..." || name == "") return;

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
      appBar: AppBar(title: const Text('ГЛАВНЫЙ СУДЬЯ'), backgroundColor: Colors.indigo),
      body: Column(
        children: [
          Row(children: [
            _tabBtn("СУДЕЙСТВО", 0),
            _tabBtn("ИСТОРИЯ", 1),
          ]),
          Expanded(child: _currentTab == 0 ? _buildMain() : _buildHistory()),
        ],
      ),
    );
  }

  Widget _tabBtn(String txt, int i) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _currentTab = i),
      child: Container(
        padding: const EdgeInsets.all(15),
        color: _currentTab == i ? Colors.indigo : Colors.grey[300],
        child: Text(txt, textAlign: TextAlign.center, style: TextStyle(color: _currentTab == i ? Colors.white : Colors.black)),
      ),
    ),
  );

  Widget _buildMain() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('routines').doc('current').snapshots(),
      builder: (context, rSnap) {
        final rData = rSnap.data?.data() as Map<String, dynamic>? ?? {};
        String name = rData['gymnastName'] ?? "Ожидание...";
        String app = rData['apparatus'] ?? "-";

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('routines').doc('current').collection('scores').snapshots(),
          builder: (context, sSnap) {
            final docs = sSnap.data?.docs ?? [];
            Map<String, List<double>> sc = {};
            for (var d in docs) {
              final data = d.data() as Map<String, dynamic>;
              sc.putIfAbsent(data['role'], () => []).add((data['score'] as num).toDouble());
            }

            double calc(List<double>? l) {
              if (l == null || l.isEmpty) return 0.0;
              if (l.length <= 2) return l.reduce((a, b) => a + b) / l.length;
              l.sort();
              return (l.reduce((a, b) => a + b) - l.first - l.last) / (l.length - 2);
            }

            double dS = calc(sc['DB']) + calc(sc['DA']);
            double aS = calc(sc['A']);
            double eS = calc(sc['E']);
            double total = dS + aS + eS;

            return Column(
              children: [
                const SizedBox(height: 20),
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: fm.FontWeight.bold)),
                Text("Вид: $app"),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _stat("D", dS), _stat("A", aS), _stat("E", eS),
                ]),
                const SizedBox(height: 30),
                Text(total.toStringAsFixed(3), style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60)),
                    onPressed: () => _finish(name, app, dS, aS, eS, total),
                    child: const Text("ЗАВЕРШИТЬ (ОЧИСТИТ ТВ)", style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }

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
              subtitle: Text("Итого: ${d['total']}"),
              trailing: IconButton(icon: const Icon(Icons.download), onPressed: () => _downloadExcel(d)),
            );
          },
        );
      },
    );
  }

  Widget _stat(String l, double v) => Column(children: [
    Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
    Text(v.toStringAsFixed(3), style: const TextStyle(fontSize: 20)),
  ]);
}
