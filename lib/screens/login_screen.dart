import 'package:flutter/material.dart';
import 'judge_role_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_gymnastics, size: 110, color: Colors.pink),
              const SizedBox(height: 30),
              const Text(
                'Система судейства\nХудожественная гимнастика',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const Text('FIG 2025-2028', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 60),

              // Кнопка тестового входа
              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const JudgeRoleScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Войти как судья (ТЕСТ)'),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'Для тестирования\n(реальная авторизация будет позже)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
