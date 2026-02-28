import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/record.dart';
import '../services/db_service.dart';
import 'add_edit_screen.dart';

class RecordDetailsScreen extends StatelessWidget {
  final Record record;

  const RecordDetailsScreen({super.key, required this.record});

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

  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  // ── delete flow ───────────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
          '"${record.title}" will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await DBService.deleteRecord(record.id);

    if (!context.mounted) return;
    // Pop with `true` so DashboardScreen knows to refresh.
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor(record.type);
    final hasImages = record.images != null && record.images!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          record.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditRecordScreen(record: record),
              ),
            ).then((changed) {
              if (changed == true && context.mounted) {
                Navigator.pop(context, true);
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          record.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (record.syncPending == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, left: 8),
                          child: Tooltip(
                            message: 'Sync pending',
                            child: Icon(
                              Icons.cloud_upload_outlined,
                              size: 18,
                              color: Colors.blueGrey.shade400,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _TypeBadge(
                        label: _badgeLabel(record.type),
                        color: color,
                      ),
                      if (record.subject.isNotEmpty)
                        Text(
                          record.subject,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: _formatDate(record.date),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _TypeDetails(record: record),

            const SizedBox(height: 12),

            if (record.description.isNotEmpty)
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'Description'),
                    const SizedBox(height: 6),
                    Text(
                      record.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

            if (record.description.isNotEmpty) const SizedBox(height: 12),

            if (hasImages)
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'Images'),
                    const SizedBox(height: 10),
                    _ImageGallery(images: record.images!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeDetails extends StatelessWidget {
  const _TypeDetails({required this.record});

  final Record record;

  @override
  Widget build(BuildContext context) {
    return switch (record.type) {
      'exam' => _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(text: 'Exam Details'),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.grade_outlined,
                label: 'Marks',
                value: (record.obtainedMarks != null &&
                        record.maxMarks != null)
                    ? '${record.obtainedMarks} / ${record.maxMarks}'
                    : '—',
                valueColor: Colors.blue,
              ),
              if (record.obtainedMarks != null && record.maxMarks != null) ...[
                const SizedBox(height: 8),
                _MarksProgressBar(
                  obtained: record.obtainedMarks!,
                  max: record.maxMarks!,
                ),
              ],
            ],
          ),
        ),
      'homework' => _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(text: 'Homework Details'),
              const SizedBox(height: 10),
              _DetailRow(
                icon: record.completed == true
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                label: 'Status',
                value: record.completed == true ? 'Completed' : 'Pending',
                iconColor:
                    record.completed == true ? Colors.green : Colors.grey,
                valueColor:
                    record.completed == true ? Colors.green : Colors.grey,
              ),
            ],
          ),
        ),
      'due' => _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(text: 'Due Details'),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.currency_rupee_outlined,
                label: 'Amount',
                value: record.amount != null
                    ? '₹${record.amount!.toStringAsFixed(2)}'
                    : '—',
                valueColor: Colors.orange,
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => _showFullImage(context, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(images[index]),
              width: 150,
              height: 160,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(
                width: 150,
                height: 160,
                color: Colors.grey.shade200,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullImageViewer extends StatefulWidget {
  const _FullImageViewer({
    required this.images,
    required this.initialIndex,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<_FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<_FullImageViewer> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, index) => InteractiveViewer(
          child: Center(
            child: Image.memory(
              base64Decode(widget.images[index]),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarksProgressBar extends StatelessWidget {
  const _MarksProgressBar({required this.obtained, required this.max});

  final int obtained;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = (max > 0 ? obtained / max : 0.0).clamp(0.0, 1.0);
    final percent = (ratio * 100).toStringAsFixed(1);
    final color = ratio >= 0.75
        ? Colors.green
        : ratio >= 0.5
            ? Colors.orange
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.grey.shade600,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor ?? Colors.black45),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

