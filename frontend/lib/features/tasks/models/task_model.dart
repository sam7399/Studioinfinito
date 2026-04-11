class TaskModel {
  final int id;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final int assignedTo;
  final String? assignedToName;
  final int createdBy;
  final String? createdByName;
  final int departmentId;
  final String? departmentName;
  final int locationId;
  final String? locationName;
  final int? companyId;
  final DateTime? dueDate;
  final double? estimatedHours;
  final int progressPercent;
  final List<String> tags;
  final List<String> collaboratorNames;
  final int escalationLevel;
  final bool isRestricted;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    required this.assignedTo,
    this.assignedToName,
    required this.createdBy,
    this.createdByName,
    required this.departmentId,
    this.departmentName,
    required this.locationId,
    this.locationName,
    this.companyId,
    this.dueDate,
    this.estimatedHours,
    this.progressPercent = 0,
    required this.tags,
    this.collaboratorNames = const [],
    this.escalationLevel = 0,
    this.isRestricted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != 'finalized';

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try { return DateTime.parse(v.toString()); } catch (_) { return null; }
  }

  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static String? _str(dynamic v) => v?.toString();

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    List<String> collabs = [];
    try {
      collabs = (json['collaborators'] as List<dynamic>? ?? [])
          .map((c) => (c is Map ? c['name']?.toString() : null) ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {}

    List<String> tags = [];
    try {
      final rawTags = json['tags'];
      if (rawTags is List) {
        tags = rawTags.map((t) => t?.toString() ?? '').where((t) => t.isNotEmpty).toList();
      }
    } catch (_) {}

    String? _nestedName(dynamic v) {
      try { return (v as Map?)?['name']?.toString(); } catch (_) { return null; }
    }

    return TaskModel(
      id: _parseInt(json['id']),
      title: _str(json['title']) ?? '',
      description: _str(json['description']),
      priority: _str(json['priority']) ?? 'normal',
      status: _str(json['status']) ?? 'open',
      assignedTo: _parseInt(json['assigned_to_user_id'] ?? json['assigned_to']),
      assignedToName: _nestedName(json['assignee']),
      createdBy: _parseInt(json['created_by_user_id'] ?? json['created_by']),
      createdByName: _nestedName(json['creator']),
      departmentId: _parseInt(json['department_id']),
      departmentName: _nestedName(json['department']),
      locationId: _parseInt(json['location_id']),
      locationName: _nestedName(json['location']),
      companyId: json['company_id'] != null ? _parseInt(json['company_id']) : null,
      dueDate: _parseDate(json['due_date']),
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble(),
      progressPercent: _parseInt(json['progress_percent']),
      tags: tags,
      collaboratorNames: collabs,
      escalationLevel: _parseInt(json['escalation_level']),
      isRestricted: json['_restricted'] == true,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }
}

class TaskActivity {
  final int id;
  final String action;
  final String? note;
  final String? actorName;
  final DateTime createdAt;

  TaskActivity({
    required this.id,
    required this.action,
    this.note,
    this.actorName,
    required this.createdAt,
  });

  factory TaskActivity.fromJson(Map<String, dynamic> json) {
    return TaskActivity(
      id: json['id'],
      action: json['action'] ?? '',
      note: json['note'],
      actorName:
          (json['actor'] as Map<String, dynamic>?)?['name'] as String?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
