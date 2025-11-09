import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';
import '../models/leave.dart';

class LeaveService {
  final ApiClient apiClient;

  LeaveService(this.apiClient);

  Exception _buildHttpError(int statusCode, String body, String context) {
    debugPrint('[$context] HTTP $statusCode: $body');
    if (statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  /// GET /leaves/list -> returns all leave requests (for managers/admins)
  Future<List<Leave>> fetchAllLeaves(String token) async {
    try {
      final res = await apiClient.get(
        ApiConstants.leaveListEndpoint,
        token: token,
        retryOn401: true,
        retryOn5xx: true,
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['leavedata'] ?? data['leaveData'] ?? data['leaves'] ?? data['data'] ?? []) as List<dynamic>?;
        if (list == null || list.isEmpty) return [];
        return list.map((e) => Leave.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw _buildHttpError(res.statusCode, res.body, 'LeaveService.fetchAllLeaves');
    } catch (e) {
      // Return empty list if API doesn't exist yet
      return [];
    }
  }

  /// GET /leaves/myleave -> returns user's leave requests
  Future<List<Leave>> fetchMyLeaves(String token) async {
    try {
      final res = await apiClient.get(
        ApiConstants.myLeaveEndpoint,
        token: token,
        retryOn401: true,
        retryOn5xx: true,
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // My Leave API uses 'userleavedata' key
        final list = (data['userleavedata'] ?? data['userLeaveData'] ?? data['leavedata'] ?? data['leaveData'] ?? data['leaves'] ?? data['data'] ?? []) as List<dynamic>?;
        if (list == null || list.isEmpty) return [];
        return list.map((e) => Leave.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw _buildHttpError(res.statusCode, res.body, 'LeaveService.fetchMyLeaves');
    } catch (e) {
      // Return empty list if API doesn't exist yet
      return [];
    }
  }

  Future<bool> createLeave(
    String token, {
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      // Format date as YYYY/MM/DD using local date (avoid timezone issues)
      String formatDate(DateTime date) {
        // Use local date components to avoid timezone conversion issues
        final localDate = DateTime(date.year, date.month, date.day);
        return '${localDate.year}/${localDate.month.toString().padLeft(2, '0')}/${localDate.day.toString().padLeft(2, '0')}';
      }

      final requestBody = {
        'leave_type': leaveType,
        'start_date': formatDate(startDate),
        'end_date': formatDate(endDate),
        'reason': reason,
      };

      final res = await apiClient.post(
        ApiConstants.leaveStoreEndpoint,
        token: token,
        body: jsonEncode(requestBody),
        retryOn401: true,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['status'] == true || data['status'] == 'true' || data['success'] == true;
      }
      
      // Handle error responses (422, 400, etc.)
      try {
        final errorData = jsonDecode(res.body);
        final errorMessage = errorData['message'] ?? errorData['error'] ?? 'Failed to create leave request';
        throw Exception(errorMessage);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Failed to create leave request');
      }
    } catch (e) {
      print("Create leave - Exception: $e");
      rethrow; // Re-throw so provider can catch and display the error message
    }
  }

  Future<bool> reviewLeave(String token, int leaveId, String reviewRemarks) async {
    try {
      final res = await apiClient.post(
        ApiConstants.leaveReviewEndpoint(leaveId),
        token: token,
        body: jsonEncode({
          'review_remarks': reviewRemarks,
        }),
        retryOn401: true,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['status'] == true || data['status'] == 'true' || data['success'] == true;
      }
      throw _buildHttpError(res.statusCode, res.body, 'LeaveService.reviewLeave');
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveLeave(String token, int leaveId, String approvedRemarks) async {
    try {
      final res = await apiClient.post(
        ApiConstants.leaveApproveEndpoint(leaveId),
        token: token,
        body: jsonEncode({
          'approved_remarks': approvedRemarks,
        }),
        retryOn401: true,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['status'] == true || data['status'] == 'true' || data['success'] == true;
      }
      throw _buildHttpError(res.statusCode, res.body, 'LeaveService.approveLeave');
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateLeave(
    String token,
    int leaveId, {
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      // Format date as YYYY/MM/DD using local date (avoid timezone issues)
      String formatDate(DateTime date) {
        // Use local date components to avoid timezone conversion issues
        final localDate = DateTime(date.year, date.month, date.day);
        return '${localDate.year}/${localDate.month.toString().padLeft(2, '0')}/${localDate.day.toString().padLeft(2, '0')}';
      }

      final requestBody = {
        'leave_type': leaveType,
        'start_date': formatDate(startDate),
        'end_date': formatDate(endDate),
        'reason': reason,
      };

      final res = await apiClient.put(
        ApiConstants.leaveUpdateEndpoint(leaveId),
        token: token,
        body: jsonEncode(requestBody),
        retryOn401: true,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['status'] == true || data['status'] == 'true' || data['success'] == true;
      }
      throw _buildHttpError(res.statusCode, res.body, 'LeaveService.updateLeave');
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteLeave(String token, int leaveId) async {
    try {
      final res = await apiClient.delete(
        ApiConstants.leaveDeleteEndpoint(leaveId),
        token: token,
        retryOn401: true,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['status'] == true || data['status'] == 'true' || data['success'] == true;
      }
      throw _buildHttpError(res.statusCode, res.body, 'LeaveService.deleteLeave');
    } catch (e) {
      return false;
    }
  }
}

