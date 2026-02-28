import 'package:flutter/material.dart';
import 'package:my_records/models/record.dart';
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
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}
