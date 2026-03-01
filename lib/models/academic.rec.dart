import 'package:my_records/models/record.dart';

class AcademicRec {
  int version = 1;
  DateTime exportedAt;
  String deviceId;
  String authId;
  Map<String, Record> records;

  AcademicRec({
    required this.exportedAt,
    required this.deviceId,
    required this.authId,
    required this.records,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'deviceId': deviceId,
        'authId': authId,
        'records': records.values.map((r) => r.toJson()).toList(),
      };

  static AcademicRec fromJson(Map<String, dynamic> json) {
    final recs = (json['records'] as List)
        .map((r) => Record.fromJson(r))
        .toList();
    return AcademicRec(
      exportedAt: DateTime.parse(json['exportedAt']),
      deviceId: json['deviceId'],
      authId: json['authId'],
      records: {for (var r in recs) r.id: r},
    );
  }
}