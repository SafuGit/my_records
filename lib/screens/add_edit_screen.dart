import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/record.dart';
import '../services/db_service.dart';

class AddEditRecordScreen extends StatefulWidget {
  final Record? record;

  const AddEditRecordScreen({super.key, this.record});

  @override
  State<AddEditRecordScreen> createState() => _AddEditRecordScreenState();
}

class _AddEditRecordScreenState extends State<AddEditRecordScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _subjectController;
  late TextEditingController _maxMarksController;
  late TextEditingController _obtainedMarksController;
  late TextEditingController _amountController;

  final ImagePicker _picker = ImagePicker();

  String _type = 'exam';
  DateTime _date = DateTime.now();
  bool _completed = false;
  List<String> _images = [];

  bool get isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _subjectController = TextEditingController();
    _maxMarksController = TextEditingController();
    _obtainedMarksController = TextEditingController();
    _amountController = TextEditingController();

    if (isEditing) _loadRecord(widget.record!);
  }

  void _loadRecord(Record r) {
    _type = r.type;
    _titleController.text = r.title;
    _descriptionController.text = r.description;
    _subjectController.text = r.subject;
    _date = r.date;
    _maxMarksController.text = r.maxMarks?.toString() ?? '';
    _obtainedMarksController.text = r.obtainedMarks?.toString() ?? '';
    _amountController.text = r.amount?.toString() ?? '';
    _completed = r.completed ?? false;
    _images = List<String>.from(r.images ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _maxMarksController.dispose();
    _obtainedMarksController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final base64Str = base64Encode(bytes);
    setState(() => _images.add(base64Str));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _removeImageAt(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();

    final id = isEditing ? widget.record!.id : UniqueKey().toString();
    final createdAt = isEditing ? widget.record!.createdAt : now;

    final int? maxMarks = _maxMarksController.text.trim().isEmpty
        ? null
        : int.tryParse(_maxMarksController.text.trim());
    final int? obtainedMarks = _obtainedMarksController.text.trim().isEmpty
        ? null
        : int.tryParse(_obtainedMarksController.text.trim());
    final double? amount = _amountController.text.trim().isEmpty
        ? null
        : double.tryParse(_amountController.text.trim());

    final record = Record(
      id: id,
      type: _type,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      subject: _subjectController.text.trim(),
      date: _date,
      maxMarks: maxMarks,
      obtainedMarks: obtainedMarks,
      completed: _type == 'homework' ? _completed : null,
      amount: _type == 'due' ? amount : null,
      images: List<String>.from(_images),
      createdAt: createdAt,
      updatedAt: now,
      syncPending: true,
    );

    try {
      if (isEditing) {
        await DBService.updateRecord(record);
      } else {
        await DBService.insertRecord(record, syncPending: true);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      // Show error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save record: $e')),
      );
    }
  }

  Widget _buildImageCarousel() {
    if (_images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        itemBuilder: (context, idx) {
          final imgBase64 = _images[idx];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                Card(
                  elevation: 2,
                  child: Image.memory(
                    base64Decode(imgBase64),
                    width: 160,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _removeImageAt(idx),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Record' : 'Add Record'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(value: 'exam', child: Text('Exam')),
                            DropdownMenuItem(value: 'homework', child: Text('Homework')),
                            DropdownMenuItem(value: 'due', child: Text('Due')),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? 'exam'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (s) => (s?.trim().isEmpty ?? true) ? 'Title is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(labelText: 'Description'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _subjectController,
                          decoration: const InputDecoration(labelText: 'Subject (optional)'),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _pickDate,
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: 'Date'),
                              controller: TextEditingController(text: _date.toLocal().toString().split(' ')[0]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Conditional fields
                if (_type == 'exam')
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(children: [
                        TextFormField(
                          controller: _maxMarksController,
                          decoration: const InputDecoration(labelText: 'Max Marks'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _obtainedMarksController,
                          decoration: const InputDecoration(labelText: 'Obtained Marks'),
                          keyboardType: TextInputType.number,
                        ),
                      ]),
                    ),
                  ),

                if (_type == 'due')
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(labelText: 'Amount'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),

                if (_type == 'homework')
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Completed'),
                          Switch(
                            value: _completed,
                            onChanged: (v) => setState(() => _completed = v),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Images
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Images', style: TextStyle(fontWeight: FontWeight.w600)),
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.add_a_photo),
                              label: const Text('Add Image'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildImageCarousel(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Text(isEditing ? 'Save Changes' : 'Save'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
