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
  int _currentTab = 0;

  void _selectGymnast() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите гимнастку'),
        content: SizedBox(
          width: double.maxFinite,
          height: 550,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('gymnasts').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final list = snapshot.data!.docs;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Поиск по имени...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        // Поиск будет работать через Stream
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
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
                              'selectedByHeadJudge': true,
                            }, SetOptions(merge: true));
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _finishPerformance(double d, double a, double e, double total) async {
    final currentDoc = await FirebaseFirestore.instance.collection('routines').doc('current').get();
    final data = currentDoc.data() ?? {};

    await FirebaseFirestore.instance.collection('history').add({
      'gymnastName': data['gymnastName'] ?? 'Неизвестно',
      'apparatus': data['apparatus'] ?? '-',
      'finalD': d,
      'finalA': a,
      'finalE': e,
      'total': total,
      'date': FieldValue.serverTimestamp(),
    });

    // Очищаем текущие оценки
    final scores = await FirebaseFirestore.instance.collection('routines').doc('current').collection('scores').get();
    for (var doc in scores.docs) {
      await doc.reference.delete();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Выступление завершено и отправлено на TV'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главный судья — FIG 2025-2028'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: const Icon(Icons.tv, size: 34), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TvScreen()))),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: _tabButton('Текущее выступление', 0)),
              Expanded(child: _tabButton('История', 1)),
            ],
          ),
          Expanded(child: _currentTab == 0 ? _buildCurrentTab() : _buildHistoryTab()),
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
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: _currentTab == tab ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

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

            bool allPanelsHaveScores = byRole.containsKey('DB') && byRole.containsKey('DA') && byRole.containsKey('A') && byRole.containsKey('E');

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
                  child: ElevatedButton(
                    onPressed: allPanelsHaveScores ? () => _finishAndSaveToHistory(gymnastName, rData['apparatus'] ?? '-', d, a, e, total) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allPanelsHaveScores ? Colors.green : Colors.grey,
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    child: const Text('ЗАВЕРШИТЬ ВЫСТУПЛЕНИЕ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                subtitle: Text('${data['apparatus'] ?? '-'} • ${data['date'].toDate().toString().substring(0, 16)}'),
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

    // Очищаем текущие оценки
    final scores = await FirebaseFirestore.instance.collection('routines').doc('current').collection('scores').get();
    for (var doc in scores.docs) await doc.reference.delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Выступление завершено и отправлено на TV'), backgroundColor: Colors.green),
    );
  }
}
