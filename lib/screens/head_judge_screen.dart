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
  String? currentGymnastId;
  String? currentGymnastName;
  String? currentApparatus = "Обруч";

  // Выбор гимнастки
  void _selectGymnast() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите следующую гимнастку'),
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
                    subtitle: Text('${data['school']} • ${data['region']}'),
                    onTap: () {
                      setState(() {
                        currentGymnastId = gymnasts[index].id;
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

  // Очистить текущее выступление
  Future<void> _clearCurrentRoutine() async {
    await FirebaseFirestore.instance
        .collection('routines')
        .doc('current')
        .collection('scores')
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.delete();
      }
    });

    setState(() {
      currentGymnastName = null;
      currentGymnastId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Текущее выступление очищено'), backgroundColor: Colors.blue),
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
  ) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Протокол FIG'];

    sheet.appendRow([TextCellValue('ПРОТОКОЛ СУДЕЙСТВА')]);
    sheet.appendRow([TextCellValue('Гимнастка: ${currentGymnastName ?? "Не выбрана"}')]);
    sheet.appendRow([TextCellValue('Аппарат: $currentApparatus')]);
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
      ..setAttribute("download", "Протокол_${currentGymnastName ?? 'Гимнастка'}.xlsx")
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
          // Выбор гимнастки
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.person, size: 40, color: Colors.pink),
                title: Text(currentGymnastName ?? 'Гимнастка не выбрана'),
                subtitle: Text(currentApparatus ?? 'Выберите гимнастку'),
                trailing: IconButton(
                  icon: const Icon(Icons.change_circle, color: Colors.deepPurple),
                  onPressed: _selectGymnast,
                ),
              ),
            ),
          ),

          // Финальный расчёт
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreBox('D', '0.000', Colors.blue),
                _buildScoreBox('A', '0.000', Colors.orange),
                _buildScoreBox('E', '0.000', Colors.green),
                _buildScoreBox('TOTAL', '0.000', Colors.purple, isBig: true),
              ],
            ),
          ),

          // Список оценок
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('routines')
                  .doc('current')
                  .collection('scores')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final allScores = snapshot.data!.docs;
                final Map<String, List<double>> byRole = {};

                for (var doc in allScores) {
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
                    Expanded(
                      child: ListView.builder(
                        itemCount: allScores.length,
                        itemBuilder: (context, i) {
                          final data = allScores[i].data() as Map<String, dynamic>;
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

                    // Нижние кнопки
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _exportToExcel(context, allScores, d, a, e, total),
                                  icon: const Icon(Icons.table_chart),
                                  label: const Text('Excel'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Опубликовано на TV'), backgroundColor: Colors.green),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('НА TV'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _clearCurrentRoutine,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Завершить выступление и очистить'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
