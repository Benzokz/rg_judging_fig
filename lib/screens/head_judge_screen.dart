import 'package:flutter/material.dart' hide Border; // Скрываем Border из Flutter
import 'package:flutter/material.dart' as fm;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'dart:js_interop'; // Добавляем для работы с JS
import 'package:web/web.dart' as web;

class HeadJudgeScreen extends fm.StatefulWidget {
  const HeadJudgeScreen({super.key});

  @override
  fm.State<HeadJudgeScreen> createState() => _HeadJudgeScreenState();
}

class _HeadJudgeScreenState extends fm.State<HeadJudgeScreen> {
  int _currentTab = 0;

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

  Future<void> _finishPerformance(String name, String app, double d, double a, double e, double total) async {
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

    final scoresRef = FirebaseFirestore.instance.collection('routines').doc('current').collection('scores');
    final snapshots = await scoresRef.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance.collection('routines').doc('current').update({
      'gymnastName': 'Ожидание...',
      'apparatus': '-',
    });

    fm.ScaffoldMessenger.of(context).showSnackBar(
      const fm.SnackBar(content: fm.Text('✅ Сохранено. ТВ очищено.'), backgroundColor: fm.Colors.green),
    );
  }

  @override
  fm.Widget build(fm.BuildContext context) {
    return fm.Scaffold(
      appBar: fm.AppBar(title: const fm.Text('Панель Главного Судьи'), backgroundColor: fm.Colors.deepPurple),
      body: fm.Column(
        children: [
          fm.Row(
            children: [
              _buildTabBtn("СУДЕЙСТВО", 0),
              _buildTabBtn("АРХИВ", 1),
            ],
          ),
          fm.Expanded(child: _currentTab == 0 ? _buildMainTab() : _buildHistoryTab()),
        ],
      ),
    );
  }

  fm.Widget _buildTabBtn(String title, int idx) {
    bool active = _currentTab == idx;
    return fm.Expanded(
      child: fm.InkWell(
        onTap: () => setState(() => _currentTab = idx),
        child: fm.Container(
          padding: const fm.EdgeInsets.all(16),
          color: active ? fm.Colors.deepPurple : fm.Colors.grey[200],
          child: fm.Text(title, textAlign: fm.TextAlign.center, 
            style: fm.TextStyle(color: active ? fm.Colors.white : fm.Colors.black, fontWeight: fm.FontWeight.bold)),
        ),
      ),
    );
  }

  fm.Widget _buildMainTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('routines').doc('current').snapshots(),
      builder: (context, routineSnap) {
        final rData = routineSnap.data?.data() as Map<String, dynamic>? ?? {};
        String gName = rData['gymnastName'] ?? "Ожидание...";
        String gApp = rData['apparatus'] ?? "-";

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('routines').doc('current').collection('scores').snapshots(),
          builder: (context, scoreSnap) {
            final docs = scoreSnap.data?.docs ?? [];
            Map<String, List<double>> grouped = {};
            for (var d in docs) {
              final data = d.data() as Map<String, dynamic>;
              grouped.putIfAbsent(data['role'], () => []).add((data['score'] as num).toDouble());
            }

            double avg(List<double>? list) {
              if (list == null || list.isEmpty) return 0.0;
              if (list.length <= 2) return list.reduce((a, b) => a + b) / list.length;
              list.sort();
              return (list.reduce((a, b) => a + b) - list.first - list.last) / (list.length - 2);
            }

            double fD = avg(grouped['DB']) + avg(grouped['DA']);
            double fA = avg(grouped['A']);
            double fE = avg(grouped['E']);
            double total = fD + fA + fE;

            return fm.Column(
              children: [
                const fm.SizedBox(height: 20),
                fm.Text(gName, style: const fm.TextStyle(fontSize: 28, fontWeight: fm.FontWeight.bold)),
                fm.Text("Предмет: $gApp"),
                const fm.Divider(height: 40),
                fm.Row(
                  mainAxisAlignment: fm.MainAxisAlignment.spaceEvenly,
                  children: [
                    _resBox("D", fD, fm.Colors.blue),
                    _resBox("A", fA, fm.Colors.orange),
                    _resBox("E", fE, fm.Colors.green),
                  ],
                ),
                const fm.SizedBox(height: 30),
                fm.Text(total.toStringAsFixed(3), style: const fm.TextStyle(fontSize: 70, fontWeight: fm.FontWeight.bold)),
                const fm.Spacer(),
                fm.Padding(
                  padding: const fm.EdgeInsets.all(20),
                  child: fm.ElevatedButton(
                    style: fm.ElevatedButton.styleFrom(backgroundColor: fm.Colors.green, minimumSize: const fm.Size(double.infinity, 70)),
                    onPressed: () => _finishPerformance(gName, gApp, fD, fA, fE, total),
                    child: const fm.Text("ЗАВЕРШИТЬ ВЫСТУПЛЕНИЕ", style: fm.TextStyle(fontSize: 22, color: fm.Colors.white)),
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }

  fm.Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('history').orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const fm.Center(child: fm.CircularProgressIndicator());
        final docs = snap.data!.docs;
        return fm.ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return fm.Card(
              margin: const fm.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: fm.ListTile(
                title: fm.Text(data['gymnastName']),
                subtitle: fm.Text("Итого: ${data['total']}"),
                trailing: fm.IconButton(
                  icon: const fm.Icon(fm.Icons.download, color: fm.Colors.blue),
                  onPressed: () => _downloadExcel(data),
                ),
              ),
            );
          },
        );
      },
    );
  }

  fm.Widget _resBox(String l, double v, fm.Color c) {
    return fm.Column(children: [
      fm.Text(l, style: const fm.TextStyle(fontSize: 18, fontWeight: fm.FontWeight.bold)),
      fm.Text(v.toStringAsFixed(3), style: fm.TextStyle(fontSize: 28, fontWeight: fm.FontWeight.bold, color: c))
    ]);
  }
}
