import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'http_client_factory.dart';

/// Thin HTTP wrapper around `lib/api/publicapi.yml`.
///
/// Attaches the session token the API expects via the `Authorization` header
/// (see `components.securitySchemes.sessionAuth` in the spec) to authenticated
/// requests, and signs the user out whenever a request comes back with a
/// 403, since that means the session is no longer valid.
///
/// [getToken] and [onUnauthorized] decouple this class from the concrete
/// auth-state implementation (a Riverpod-generated `AuthSession` class, not
/// a plain object with a synchronous `.token` getter) — see
/// `lib/providers/auth_provider.dart`.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.getToken,
    required this.onUnauthorized,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? createHttpClient();

  final String baseUrl;
  final String? Function() getToken;
  final Future<void> Function() onUnauthorized;
  final http.Client _httpClient;

  Future<Map<String, dynamic>?> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParameters);
    final headers = <String, String>{};
    if (body != null) headers['Content-Type'] = 'application/json';

    final token = getToken();
    if (requireAuth && token != null) {
      headers['Authorization'] = token;
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 403) {
      await onUnauthorized();
      throw ApiException.fromResponse(response);
    }
    if (response.statusCode >= 400) {
      throw ApiException.fromResponse(response);
    }

    if (response.body.isEmpty) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
