import 'package:flutter/material.dart';
import '../models/record.dart';

class RecordDetailsScreen extends StatelessWidget {
  final Record record;

  const RecordDetailsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(record.title),
      ),
      body: const Center(
        child: Text(
          'Record Details screen\n(to be implemented)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
