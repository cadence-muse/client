import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'auth_session.dart';
import 'http_client_factory.dart';

/// Thin HTTP wrapper around `lib/api/publicapi.yml`.
///
/// Attaches the session cookie the API expects (`cadencesession`, see
/// `components.securitySchemes.cookieAuth` in the spec) to authenticated
/// requests, and signs the user out whenever a request comes back with a
/// 403, since that means the session is no longer valid.
///
/// On web, scripts can't read or set the `Cookie` header themselves (it's a
/// forbidden header per the Fetch spec) — the browser attaches it
/// automatically as long as the client is created with credentials enabled
/// (see `http_client_factory_web.dart`), so there we just skip setting it
/// ourselves. Native platforms don't have that restriction, and their
/// `HttpClient` cookie jar is in-memory only (lost on process restart), so
/// there we still forward the persisted token as the cookie explicitly.
class ApiClient {
  ApiClient({required this.baseUrl, required this.authSession, http.Client? httpClient})
    : _httpClient = httpClient ?? createHttpClient();

  final String baseUrl;
  final AuthSession authSession;
  final http.Client _httpClient;

  Future<Map<String, dynamic>?> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {'Content-Type': 'application/json'};

    final token = authSession.token;
    if (requireAuth && token != null && !kIsWeb) {
      headers['Cookie'] = 'cadencesession=$token';
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 403) {
      await authSession.signOut();
      throw ApiException.fromResponse(response);
    }
    if (response.statusCode >= 400) {
      throw ApiException.fromResponse(response);
    }

    if (response.body.isEmpty) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
