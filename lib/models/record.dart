class Record {
  String id;
  String type; // exam | homework | due
  String title;
  String description;
  String subject;
  DateTime date;
  String? category;

  // Exam Specific
  int? maxMarks;
  int? obtainedMarks;

  // Homework Specific
  bool? completed;

  // Dues specific
  double? amount;

  List<String>? images; // store base64
  DateTime createdAt;
  DateTime updatedAt;

  Record({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.subject,
    required this.date,
    this.maxMarks,
    this.obtainedMarks,
    this.completed,
    this.amount,
    this.category,
    this.images,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      description: json['description'],
      subject: json['subject'] ?? '',
      date: DateTime.parse(json['date']),
      maxMarks: json['maxMarks'],
      obtainedMarks: json['obtainedMarks'],
      completed: json['completed'],
      amount: json['amount']?.toDouble(),
      category: json['category'],
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'description': description,
    'subject': subject,
    'date': date.toIso8601String(),
    'maxMarks': maxMarks,
    'obtainedMarks': obtainedMarks,
    'completed': completed,
    'amount': amount,
    'category': category,
    'images': images,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
