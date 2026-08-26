import 'dart:convert';

import 'package:http/http.dart' as http;

import '../generated/app_localizations.dart';

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

/// Maps [ApiException.code] to a localized generic message for the 5 known
/// `ErrorCode` values (`publicapi.yml` lines 670-677). Any `code` that is
/// `null` or outside that enum falls back to the raw server [ApiException.message]
/// unchanged (D-05 — future/unknown code drift never produces a blank or
/// substituted-generic state).
extension ApiExceptionLocalization on ApiException {
  String localizedMessage(
    AppLocalizations l10n, {
    Map<String, String>? overrides,
  }) {
    final errorCode = code;
    if (errorCode == null) return message;
    final override = overrides?[errorCode];
    if (override != null) return override;
    switch (errorCode) {
      case 'invalid_input':
        return l10n.commonErrorInvalidInput;
      case 'not_found':
        return l10n.commonErrorNotFound;
      case 'permission_denied':
        return l10n.commonErrorPermissionDenied;
      case 'operation_rejected':
        return l10n.commonErrorOperationRejected;
      case 'already_exists':
        return l10n.commonErrorAlreadyExists;
      default:
        return message;
    }
  }
}
