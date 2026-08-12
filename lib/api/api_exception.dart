import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException({required this.statusCode, this.code, required this.message});

  factory ApiException.fromResponse(http.Response response) {
    if (response.body.isNotEmpty) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return ApiException(
            statusCode: response.statusCode,
            code: body['code'] as String?,
            message: (body['message'] as String?) ?? 'Request failed',
          );
        }
      } catch (_) {
        // Response body isn't the expected JSON error shape; fall through.
      }
    }
    return ApiException(statusCode: response.statusCode, message: 'Request failed');
  }

  final int statusCode;
  final String? code;
  final String message;

  @override
  String toString() => message;
}
