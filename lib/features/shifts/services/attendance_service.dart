import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../constants/api_constants.dart';
import '../../../core/api_client.dart';

class AttendanceService {
  final ApiClient api;
  AttendanceService(this.api);

  // --- helpers ---
  String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return ''; // will trigger 422 clearly
    return v.toStringAsFixed(6);
  }

  MediaType _guessMediaType(File f) {
    final name = f.path.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    } else if (name.endsWith('.png')) {
      return MediaType('image', 'png');
    } else if (name.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    // fallback – Laravel may reject without a proper image mime
    return MediaType('application', 'octet-stream');
  }

  Exception _buildHttpError(http.Response res, String context) {
    debugPrint('[$context] HTTP ${res.statusCode}: ${res.body}');
    if (res.statusCode == 401) {
      return Exception('Your session expired. Please login again.');
    }
    if (res.statusCode >= 500) {
      return Exception('We\'re having trouble reaching the server. Please try again later.');
    }
    return Exception('We couldn\'t complete that request. Please try again.');
  }

  Future<http.Response> _sendAttendanceRequest({
    required String endpoint,
    required String token,
    required Map<String, String> fields,
    required String imageField,
    required File imageFile,
  }) async {
    Future<http.Response> run(String authToken) async {
      final req = http.MultipartRequest('POST', api.uri(endpoint))
        ..headers['Authorization'] = 'Bearer $authToken'
        ..headers['Accept'] = 'application/json'
        ..fields.addAll(fields);

      req.files.add(
        await http.MultipartFile.fromPath(
          imageField,
          imageFile.path,
          contentType: _guessMediaType(imageFile),
        ),
      );

      final streamRes = await req.send();
      return http.Response.fromStream(streamRes);
    }

    var response = await run(token);
    if (response.statusCode != 401) {
      return response;
    }

    final newToken = await api.refreshAccessToken();
    if (newToken == null || newToken.isEmpty) {
      return response;
    }

    response = await run(newToken);
    return response;
  }

  Future<bool> checkIn({
    required String token,
    required int assignmentId,
    required double lat,
    required double lon,
    required bool force,
    required File imageFile,
  }) async {
    if (!await imageFile.exists()) {
      // Surface a clear reason instead of silent 422
      throw Exception('check_in_image file not found at ${imageFile.path}');
    }

    final resp = await _sendAttendanceRequest(
      endpoint: ApiConstants.checkInEndpoint,
      token: token,
      fields: {
        'user_shift_assignment_id': assignmentId.toString(),
        'check_in_latitude': _fmt(lat),
        'check_in_longitude': _fmt(lon),
        'check_in_force_mark': force ? '1' : '0',
      },
      imageField: 'check_in_image',
      imageFile: imageFile,
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) return true;
    if (resp.statusCode == 404) {
      debugPrint('[AttendanceService] Check-in: assignment not found (404).');
      return false;
    }
    if (resp.statusCode == 422) {
      _logValidation(resp);
      return false;
    }
    throw _buildHttpError(resp, 'AttendanceService(checkIn)');
  }

  Future<bool> checkOut({
    required String token,
    required int attendanceId,
    required int assignmentId,
    required double lat,
    required double lon,
    required bool force,
    required File imageFile,
  }) async {
    if (!await imageFile.exists()) {
      throw Exception('check_out_image file not found at ${imageFile.path}');
    }

    final resp = await _sendAttendanceRequest(
      endpoint: ApiConstants.checkOutEndpoint,
      token: token,
      fields: {
        'attendance_id': attendanceId.toString(),
        'user_shift_assignment_id': assignmentId.toString(),
        'check_out_latitude': _fmt(lat),
        'check_out_longitude': _fmt(lon),
        'check_out_force_mark': force ? '1' : '0',
      },
      imageField: 'check_out_image',
      imageFile: imageFile,
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) return true;
    if (resp.statusCode == 404) {
      debugPrint('[AttendanceService] Check-out: attendance not found (404).');
      return false;
    }
    if (resp.statusCode == 422) {
      _logValidation(resp);
      return false;
    }
    throw _buildHttpError(resp, 'AttendanceService(checkOut)');
  }

  void _logValidation(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      final msg = body['message'];
      final errs = body['errors'];
      if (errs is Map) {
        // Print field-wise errors in console; you can surface this to UI if you want
        errs.forEach((k, v) => print('422 [$k]: $v'));
      } else {
        print('422: $msg | ${resp.body}');
      }
    } catch (_) {
      print('422 (non-JSON): ${resp.body}');
    }
  }
}
