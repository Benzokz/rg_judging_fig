import 'package:flutter/material.dart';
import 'judge_scoring_screen.dart';
import 'head_judge_screen.dart';
import 'admin_panel.dart';

class JudgeRoleScreen extends StatelessWidget {
  const JudgeRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roles = [
      {'title': 'DB — Body Difficulties', 'value': 'DB', 'color': Colors.blue},
      {'title': 'DA — Apparatus Difficulties', 'value': 'DA', 'color': Colors.purple},
      {'title': 'A — Artistry', 'value': 'A', 'color': Colors.orange},
      {'title': 'E — Execution', 'value': 'E', 'color': Colors.green},
      {'title': 'Главный судья', 'value': 'HEAD', 'color': Colors.deepPurple},
      {'title': 'Администратор', 'value': 'ADMIN', 'color': Colors.teal},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Выбор роли'), backgroundColor: Colors.pink),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: roles.length,
          itemBuilder: (context, index) {
            final role = roles[index];
            return Card(
              elevation: 6,
              child: InkWell(
                onTap: () {
                  if (role['value'] == 'HEAD') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HeadJudgeScreen()));
                  } else if (role['value'] == 'ADMIN') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JudgeScoringScreen(role: role['value'] as String),
                      ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: (role['color'] as Color).withOpacity(0.1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, size: 50, color: role['color'] as Color),
                      const SizedBox(height: 12),
                      Text(
                        role['title'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
