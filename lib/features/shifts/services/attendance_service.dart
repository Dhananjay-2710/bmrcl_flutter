import 'dart:io';
import 'dart:convert';
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

  Future<bool> checkIn({
    required String token,
    required int assignmentId,
    required double lat,
    required double lon,
    required bool force,
    required File imageFile,
  }) async {
    final url = api.uri(ApiConstants.checkInEndpoint);

    final req = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['user_shift_assignment_id'] = assignmentId.toString()
      ..fields['check_in_latitude'] = _fmt(lat)
      ..fields['check_in_longitude'] = _fmt(lon)
      ..fields['check_in_force_mark'] = force ? '1' : '0';

    // DO NOT set Content-Type header yourself; MultipartRequest will add the boundary.
    if (!await imageFile.exists()) {
      // Surface a clear reason instead of silent 422
      throw Exception('check_in_image file not found at ${imageFile.path}');
    }

    req.files.add(
      await http.MultipartFile.fromPath(
        'check_in_image',
        imageFile.path,
        contentType: _guessMediaType(imageFile),
      ),
    );

    final streamRes = await req.send();
    final resp = await http.Response.fromStream(streamRes);

    if (resp.statusCode == 200 || resp.statusCode == 201) return true;
    if (resp.statusCode == 404) return false;
    if (resp.statusCode == 422) {
      _logValidation(resp);
      return false;
    }
    if (resp.statusCode >= 500) {
      throw Exception('Server error ${resp.statusCode}: ${resp.body}');
    }
    return false;
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
    final url = api.uri(ApiConstants.checkOutEndpoint);

    final req = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['attendance_id'] = attendanceId.toString()
      ..fields['user_shift_assignment_id'] = assignmentId.toString()
      ..fields['check_out_latitude'] = _fmt(lat)
      ..fields['check_out_longitude'] = _fmt(lon)
      ..fields['check_out_force_mark'] = force ? '1' : '0';

    if (!await imageFile.exists()) {
      throw Exception('check_out_image file not found at ${imageFile.path}');
    }

    req.files.add(
      await http.MultipartFile.fromPath(
        'check_out_image',
        imageFile.path,
        contentType: _guessMediaType(imageFile),
      ),
    );

    final streamRes = await req.send();
    final resp = await http.Response.fromStream(streamRes);

    // print('CHECKOUT -> ${resp.statusCode}\n${resp.body}');

    if (resp.statusCode == 200 || resp.statusCode == 201) return true;
    if (resp.statusCode == 404) return false;
    if (resp.statusCode == 422) {
      _logValidation(resp);
      return false;
    }
    if (resp.statusCode >= 500) {
      throw Exception('Server error ${resp.statusCode}: ${resp.body}');
    }
    return false;
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
