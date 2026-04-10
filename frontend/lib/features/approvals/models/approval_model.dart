import '../../tasks/models/task_model.dart';

/// Model representing a task approval audit record
class TaskApprovalModel {
  final int id;
  final int taskId;
  final int approverId;
  final String status; // 'pending', 'approved', 'rejected'
  final String? comments;
  final String? reason;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Related objects
  final ApproverModel? approver;
  final TaskModel? task;

  TaskApprovalModel({
    required this.id,
    required this.taskId,
    required this.approverId,
    required this.status,
    this.comments,
    this.reason,
    required this.submittedAt,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.approver,
    this.task,
  });

  factory TaskApprovalModel.fromJson(Map<String, dynamic> json) {
    return TaskApprovalModel(
      id: json['id'] ?? 0,
      taskId: json['task_id'] ?? 0,
      approverId: json['approver_id'] ?? 0,
      status: json['status'] ?? 'pending',
      comments: json['comments'],
      reason: json['reason'],
      submittedAt: json['submitted_at'] != null 
          ? DateTime.parse(json['submitted_at'])
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null 
          ? DateTime.parse(json['reviewed_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      approver: json['approver'] != null 
          ? ApproverModel.fromJson(json['approver'])
          : null,
      task: json['task'] != null
          ? TaskModel.fromJson(json['task'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'task_id': taskId,
    'approver_id': approverId,
    'status': status,
    'comments': comments,
    'reason': reason,
    'submitted_at': submittedAt.toIso8601String(),
    'reviewed_at': reviewedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  
  /// Returns the duration since submission
  Duration get ageFromSubmission => DateTime.now().difference(submittedAt);
  
  /// Returns true if approval is pending and older than specified days
  bool isOlderThanDays(int days) {
    if (!isPending) return false;
    return ageFromSubmission.inDays >= days;
  }
}

/// Model representing the approver (User lite model)
class ApproverModel {
  final int id;
  final String name;
  final String email;
  final String? role;

  ApproverModel({
    required this.id,
    required this.name,
    required this.email,
    this.role,
  });

  factory ApproverModel.fromJson(Map<String, dynamic> json) {
    return ApproverModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
  };
}

/// Model for approval requests (pending approvals from a manager's perspective)
class PendingApprovalModel {
  final int id;
  final TaskApprovalModel approval;
  final TaskModel task;

  PendingApprovalModel({
    required this.id,
    required this.approval,
    required this.task,
  });

  factory PendingApprovalModel.fromJson(Map<String, dynamic> json) {
    return PendingApprovalModel(
      id: json['id'] ?? 0,
      approval: TaskApprovalModel.fromJson(json),
      task: json['task'] != null 
          ? TaskModel.fromJson(json['task'])
          : TaskModel.fromJson({'id': 0, 'title': '', 'status': '', 'assigned_to_user_id': 0, 'created_by_user_id': 0, 'department_id': 0, 'location_id': 0, 'tags': [], 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'approval': approval.toJson(),
    'task': task,
  };
}

/// Response model for approval actions
class ApprovalActionResponse {
  final bool success;
  final String message;
  final TaskModel? task;
  final TaskApprovalModel? approval;

  ApprovalActionResponse({
    required this.success,
    required this.message,
    this.task,
    this.approval,
  });

  factory ApprovalActionResponse.fromJson(Map<String, dynamic> json) {
    return ApprovalActionResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      task: json['data']?['task'] != null 
          ? TaskModel.fromJson(json['data']['task'])
          : null,
      approval: json['data']?['approval'] != null 
          ? TaskApprovalModel.fromJson(json['data']['approval'])
          : null,
    );
  }
}
