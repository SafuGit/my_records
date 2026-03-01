// ignore_for_file: unnecessary_underscores

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/record.dart';
import '../services/db_service.dart';
import 'add_edit_screen.dart';
import 'record_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Record> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    setState(() => _isLoading = true);
    final records = await DBService.getAllRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  static Color _badgeColor(String type) => switch (type) {
    'exam' => Colors.blue,
    'homework' => Colors.green,
    'due' => Colors.orange,
    _ => Colors.grey,
  };

  static String _badgeLabel(String type) => switch (type) {
    'exam' => 'Exam',
    'homework' => 'Homework',
    'due' => 'Due',
    _ => type,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyRecords'),
        centerTitle: false,
        elevation: 2,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add record',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditRecordScreen()),
        ).then((_) => loadRecords()),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadRecords,
              child: _records.isEmpty ? _emptyState() : _recordList(),
            ),
    );
  }

  Widget _emptyState() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Icon(Icons.inbox_outlined, size: 64, color: Colors.black26),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No records yet.\nTap + to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black45),
            ),
          ),
        ],
      );

  Widget _recordList() => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        // Smooth scrolling for 1000+ items
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          return _RecordCard(
            record: record,
            badgeColor: _badgeColor(record.type),
            badgeLabel: _badgeLabel(record.type),
            formattedDate: _formatDate(record.date),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordDetailsScreen(record: record),
              ),
            ).then((_) => loadRecords()),
          );
        },
      );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.badgeColor,
    required this.badgeLabel,
    required this.formattedDate,
    required this.onTap,
  });

  final Record record;
  final Color badgeColor;
  final String badgeLabel;
  final String formattedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = record.images != null && record.images!.isNotEmpty;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Thumbnail(
                hasImage: hasImage,
                images: record.images,
                fallbackColor: badgeColor,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row + sync icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (record.syncPending == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Tooltip(
                              message: 'Sync pending',
                              child: Icon(
                                Icons.cloud_upload_outlined,
                                size: 16,
                                color: Colors.blueGrey.shade400,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Type badge + subject
                    Row(
                      children: [
                        _TypeBadge(label: badgeLabel, color: badgeColor),
                        if (record.subject.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              record.subject,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Date + type-specific detail
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                        _TypeDetail(record: record),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.hasImage,
    required this.images,
    required this.fallbackColor,
  });

  final bool hasImage;
  final List<String>? images;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    if (hasImage) {
      return ClipOval(
        child: Image.memory(
          base64Decode(images![0]),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          // If the base64 data is corrupt, fall back gracefully.
          errorBuilder: (_, __, ___) =>
              _FallbackAvatar(color: fallbackColor),
          // Caching hint — avoid decoding every frame during fast scrolls.
          gaplessPlayback: true,
        ),
      );
    }
    return _FallbackAvatar(color: fallbackColor);
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(38), // ≈ 15 % opacity
      ),
      child: Icon(Icons.description_outlined, color: color, size: 28),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(38), // ≈ 15 % opacity
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(102)), // ≈ 40 % opacity
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TypeDetail extends StatelessWidget {
  const _TypeDetail({required this.record});

  final Record record;

  @override
  Widget build(BuildContext context) {
    // Exam: obtained / max marks
    if (record.type == 'exam' &&
        record.obtainedMarks != null &&
        record.maxMarks != null) {
      return Text(
        '${record.obtainedMarks} / ${record.maxMarks}',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.blue,
        ),
      );
    }

    // Due: amount
    if (record.type == 'due' && record.amount != null) {
      return Text(
        '₹${record.amount!.toStringAsFixed(2)}',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.orange,
        ),
      );
    }

    // Homework: completion status
    if (record.type == 'homework') {
      final done = record.completed == true;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: done ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            done ? 'Done' : 'Pending',
            style: TextStyle(
              fontSize: 12,
              color: done ? Colors.green : Colors.grey,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}