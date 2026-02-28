import 'package:flutter/material.dart';
import '../models/record.dart';

class AddEditRecordScreen extends StatefulWidget {
  final Record? record;

  const AddEditRecordScreen({super.key, this.record});

  @override
  State<AddEditRecordScreen> createState() => _AddEditRecordScreenState();
}

class _AddEditRecordScreenState extends State<AddEditRecordScreen> {
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Record' : 'Add Record'),
      ),
      body: const Center(
        child: Text(
          'Add / Edit screen\n(to be implemented)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
