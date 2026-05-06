import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _regionController = TextEditingController();

  Future<void> _addGymnast() async {
    if (_nameController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('gymnasts').add({
      'fullName': _nameController.text.trim(),
      'school': _schoolController.text.trim(),
      'region': _regionController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Гимнастка успешно добавлена!'), backgroundColor: Colors.green),
    );

    _nameController.clear();
    _schoolController.clear();
    _regionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Администратор — Список гимнасток'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Форма добавления
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'ФИО гимнастки'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _schoolController,
                      decoration: const InputDecoration(labelText: 'Школа / Клуб'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _regionController,
                      decoration: const InputDecoration(labelText: 'Регион / Область'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addGymnast,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        child: const Text('Добавить гимнастку'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text('Список гимнасток', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

            // Список гимнасток
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('gymnasts')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
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
                        trailing: const Icon(Icons.person),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
