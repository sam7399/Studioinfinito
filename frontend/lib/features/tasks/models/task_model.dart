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
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != 'finalized';

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final collabs = (json['collaborators'] as List<dynamic>? ?? [])
        .map((c) => (c as Map<String, dynamic>?)?['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    return TaskModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 'normal',
      status: json['status'] ?? 'open',
      assignedTo: json['assigned_to_user_id'] ?? json['assigned_to'] ?? 0,
      assignedToName:
          (json['assignee'] as Map<String, dynamic>?)?['name'] as String?,
      createdBy: json['created_by_user_id'] ?? json['created_by'] ?? 0,
      createdByName:
          (json['creator'] as Map<String, dynamic>?)?['name'] as String?,
      departmentId: json['department_id'] ?? 0,
      departmentName:
          (json['department'] as Map<String, dynamic>?)?['name'] as String?,
      locationId: json['location_id'] ?? 0,
      locationName:
          (json['location'] as Map<String, dynamic>?)?['name'] as String?,
      companyId: json['company_id'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble(),
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      collaboratorNames: collabs,
      escalationLevel: (json['escalation_level'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
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
