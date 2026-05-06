import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'judge_scoring_screen.dart';
import 'head_judge_screen.dart';
import 'admin_panel.dart';

class JudgeRoleScreen extends StatefulWidget {
  const JudgeRoleScreen({super.key});

  @override
  State<JudgeRoleScreen> createState() => _JudgeRoleScreenState();
}

class _JudgeRoleScreenState extends State<JudgeRoleScreen> {
  String? selectedGymnastId;
  String? selectedGymnastName;

  @override
  Widget build(BuildContext context) {
    // ... (остальной код без изменений до GridView)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор роли — FIG 2025-2028'),
        backgroundColor: Colors.pink,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: ListTile(
                title: Text(selectedGymnastName ?? 'Выберите гимнастку'),
                subtitle: const Text('Текущее выступление'),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _showGymnastSelector(context),
              ),
            ),
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Выберите свою роль', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              childAspectRatio: 1.6,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildRoleCard('DB', 'Body Difficulties', Colors.blue),
                _buildRoleCard('DA', 'Apparatus Difficulties', Colors.indigo),
                _buildRoleCard('A', 'Artistry (Артистизм)', Colors.orange),
                _buildRoleCard('E', 'Execution (Исполнение)', Colors.green),
                _buildRoleCard('HEAD', 'Главный судья', Colors.deepPurple),
                _buildRoleCard('ADMIN', 'Администратор', Colors.teal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String value, String title, Color color) {
    return Card(
      elevation: 6,
      child: InkWell(
        onTap: () {
          if (value == 'HEAD') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HeadJudgeScreen()));
          } else if (value == 'ADMIN') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
          } else {
            if (selectedGymnastId == null || selectedGymnastName == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Сначала выберите гимнастку!')),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JudgeScoringScreen(
                  role: value,
                  gymnastId: selectedGymnastId!,
                  gymnastName: selectedGymnastName!,
                ),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.1),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person, size: 48, color: color),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGymnastSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите гимнастку'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
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
                        selectedGymnastId = gymnasts[index].id;
                        selectedGymnastName = data['fullName'];
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
}
