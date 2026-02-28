import 'package:flutter/material.dart';
import 'package:my_records/models/record.dart';
import 'package:my_records/screens/dashboard_screen.dart';
import 'package:my_records/services/db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sample = Record(
    id: '1',
    type: 'exam',
    title: 'Math Test',
    description: 'Chapters 1-5',
    subject: 'Mathematics',
    date: DateTime.now(),
    maxMarks: 100,
    obtainedMarks: 95,
    images: [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await DBService.insertRecord(sample);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigate to DashboardScreen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white, // button background
            foregroundColor: Colors.black, // text & icon color
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: const Text(
            'Go to Dashboard Screen',
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
