import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/approval_model.dart';
import '../../../core/constants/api_constants.dart';

class ApprovalService {
  final Dio _dio;
  final _logger = Logger();

  ApprovalService(this._dio);

  /// Get pending approvals for the current manager
  /// [page] - pagination page number (default: 1)
  /// [limit] - items per page (default: 20)
  /// [priority] - optional filter by priority
  /// [departmentId] - optional filter by department
  Future<({List<PendingApprovalModel> approvals, int total, int page, int pages})>
      getPendingApprovals({
    int page = 1,
    int limit = 20,
    String? priority,
    int? departmentId,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'limit': limit,
        if (priority != null) 'priority': priority,
        if (departmentId != null) 'department_id': departmentId,
      };

      final response = await _dio.get(
        ApiConstants.approvalPending,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data['data'] ?? [];
      final approvals = data
          .map((item) => PendingApprovalModel.fromJson(item as Map<String, dynamic>))
          .toList();

      final pagination = response.data['pagination'] ?? {};
      final total = (pagination['total'] as num?)?.toInt() ?? 0;
      final pageNum = (pagination['page'] as num?)?.toInt() ?? page;
      final pages = (pagination['pages'] as num?)?.toInt() ?? 1;

      return (
        approvals: approvals,
        total: total,
        page: pageNum,
        pages: pages,
      );
    } on DioException catch (e) {
      _logger.e('Error fetching pending approvals', error: e);
      rethrow;
    }
  }

  /// Get count of pending approvals for current manager
  Future<int> getPendingApprovalsCount() async {
    try {
      final response = await _dio.get(ApiConstants.approvalPendingCount);
      return (response.data['data']['count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      _logger.e('Error fetching pending approvals count', error: e);
      return 0; // Return 0 instead of throwing for count endpoint
    }
  }

  /// Submit a task for approval
  /// Only task creator or assignee can submit
  Future<ApprovalActionResponse> submitForApproval(int taskId) async {
    try {
      final response = await _dio.post(
        ApiConstants.approvalSubmit(taskId),
      );
      return ApprovalActionResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error submitting task for approval', error: e);
      rethrow;
    }
  }

  /// Approve a pending task
  /// [taskId] - ID of task to approve
  /// [comments] - optional approval comments
  Future<ApprovalActionResponse> approveTask(
    int taskId, {
    String? comments,
  }) async {
    try {
      final requestBody = {
        if (comments != null && comments.isNotEmpty) 'comments': comments,
      };

      final response = await _dio.put(
        ApiConstants.approvalApprove(taskId),
        data: requestBody.isEmpty ? null : requestBody,
      );
      return ApprovalActionResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error approving task', error: e);
      rethrow;
    }
  }

  /// Reject a pending task
  /// [taskId] - ID of task to reject
  /// [reason] - reason for rejection (required)
  Future<ApprovalActionResponse> rejectTask(
    int taskId,
    String reason,
  ) async {
    try {
      if (reason.trim().isEmpty) {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          error: 'Rejection reason is required',
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 400,
            data: {'message': 'Rejection reason is required'},
          ),
        );
      }

      final response = await _dio.put(
        ApiConstants.approvalReject(taskId),
        data: {'reason': reason.trim()},
      );
      return ApprovalActionResponse.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error rejecting task', error: e);
      rethrow;
    }
  }

  /// Get approval history for a task
  /// Returns the complete audit trail of approval actions
  Future<List<TaskApprovalModel>> getApprovalHistory(int taskId) async {
    try {
      final response = await _dio.get(
        ApiConstants.approvalHistory(taskId),
      );

      final List<dynamic> data = response.data['data'] ?? [];
      return data
          .map((item) => TaskApprovalModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _logger.e('Error fetching approval history', error: e);
      rethrow;
    }
  }

  /// Add a comment to an approval during the approval process
  /// This is typically used before approving/rejecting to add discussion
  /// Note: After approval/rejection, comments are part of the approval record
  Future<void> addApprovalComment(int taskId, String comment) async {
    try {
      if (comment.trim().isEmpty) {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          error: 'Comment cannot be empty',
          type: DioExceptionType.badResponse,
        );
      }

      // Note: This endpoint might not exist in the current backend
      // You may need to add this or use comments during approve/reject instead
      _logger.w('addApprovalComment: This endpoint may not be implemented yet');
      // await _dio.post(
      //   ApiConstants.approvalComment(taskId),
      //   data: {'comment': comment.trim()},
      // );
    } on DioException catch (e) {
      _logger.e('Error adding approval comment', error: e);
      rethrow;
    }
  }
}
