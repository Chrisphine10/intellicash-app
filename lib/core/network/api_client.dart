import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../utils/app_logger.dart';
import 'api_credentials.dart';
import 'api_exception.dart';

/// Thin HTTP client for the IntelliCash Node/Express backend.
///
/// Sends the `Authorization: Bearer ic_sk_…` header the API's
/// `resolveUserFromRequest` middleware expects, unwraps the standard
/// `{ data, meta }` success envelope, and maps failures — which arrive as
/// `{ error: { code, message, details } }` — to [ApiException].
class ApiClient {
  ApiClient({
    required ApiCredentials Function() credentials,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 20),
  })  : _credentials = credentials,
        _http = httpClient ?? http.Client(),
        _timeout = timeout;

  final ApiCredentials Function() _credentials;
  final http.Client _http;
  final Duration _timeout;

  Map<String, String> _headers({bool auth = true, bool json = false}) {
    final creds = _credentials();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (auth && creds.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${creds.apiKey}',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = _credentials().baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final params = query
        ?.map((k, v) => MapEntry(k, v?.toString()))
      ?..removeWhere((_, v) => v == null);
    return Uri.parse('$base$normalizedPath').replace(
      queryParameters: (params == null || params.isEmpty)
          ? null
          : params.cast<String, String>(),
    );
  }

  /// Resolves a path against the server ORIGIN, dropping the `/api/v1`
  /// prefix — used for `/health`, which is mounted at the root.
  Uri _rootUri(String path) {
    final base = Uri.parse(_credentials().baseUrl);
    return base.replace(path: path.startsWith('/') ? path : '/$path', query: '');
  }

  /// GET returning the decoded `data` field.
  Future<dynamic> getData(String path, {Map<String, dynamic>? query}) async {
    final body = await _send('GET $path', () => _http
        .get(_uri(path, query), headers: _headers())
        .timeout(_timeout));
    return body['data'];
  }

  /// GET returning `data` as a list (empty when absent).
  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) async {
    final data = await getData(path, query: query);
    return (data as List?) ?? const [];
  }

  /// GET returning the full `{ data, meta }` envelope — for endpoints whose
  /// `meta` carries extra fields (e.g. notifications' `unreadCount`).
  Future<Map<String, dynamic>> getEnvelope(String path,
      {Map<String, dynamic>? query}) async {
    return _send('GET $path', () =>
        _http.get(_uri(path, query), headers: _headers()).timeout(_timeout));
  }

  /// POST a JSON body, returning the decoded `data` field.
  Future<dynamic> postData(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final decoded = await _send('POST $path', () => _http
        .post(
          _uri(path),
          headers: _headers(auth: auth, json: true),
          body: jsonEncode(body ?? const {}),
        )
        .timeout(_timeout));
    return decoded['data'];
  }

  Future<dynamic> putData(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final decoded = await _send('PUT $path', () => _http
        .put(
          _uri(path),
          headers: _headers(auth: auth, json: true),
          body: jsonEncode(body ?? const {}),
        )
        .timeout(_timeout));
    return decoded['data'];
  }

  /// POST a file as multipart/form-data, returning the decoded `data` field.
  ///
  /// Separate from [postData] because a photograph must not be base64'd into a
  /// JSON body: that inflates it by a third and forces the whole image into
  /// memory on a handset that may only have a few hundred megabytes to spare.
  ///
  /// The timeout is deliberately longer than the JSON one. A 400 KB image over
  /// a rural 2G link takes tens of seconds, and cutting it off at the usual
  /// limit would mean an upload that can never succeed where it is needed most.
  Future<dynamic> postMultipart(
    String path, {
    required String field,
    required String filePath,
    required String fileName,
    required String contentType,
    Map<String, String> fields = const {},
    bool auth = true,
    Duration? timeout,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers(auth: auth))
      ..fields.addAll(fields)
      ..files.add(
        await http.MultipartFile.fromPath(
          field,
          filePath,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );

    final decoded = await _send('POST $path', () async {
      final streamed = await request.send().timeout(timeout ?? const Duration(minutes: 2));
      return http.Response.fromStream(streamed);
    });
    return decoded['data'];
  }

  /// PATCH a JSON body, returning the decoded `data` field.
  ///
  /// Used for partial updates where PUT would mean "replace the whole record" —
  /// closing one action item should not have to resend everything else about it.
  Future<dynamic> patchData(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final decoded = await _send('PATCH $path', () => _http
        .patch(
          _uri(path),
          headers: _headers(auth: auth, json: true),
          body: jsonEncode(body ?? const {}),
        )
        .timeout(_timeout));
    return decoded['data'];
  }

  Future<dynamic> deleteData(String path, {bool auth = true}) async {
    final decoded = await _send('DELETE $path', () =>
        _http.delete(_uri(path), headers: _headers(auth: auth)).timeout(_timeout));
    return decoded['data'];
  }

  /// Unauthenticated liveness probe against the server root (`/health`).
  Future<Map<String, dynamic>> getRoot(String path) async {
    return _send('GET $path', () =>
        _http.get(_rootUri(path), headers: _headers(auth: false)).timeout(_timeout));
  }

  /// Signs in with phone/email + password against `/auth/login`. Returns the
  /// user payload and the session token parsed from the `Set-Cookie` header —
  /// that token is then used as the bearer credential for later calls (the
  /// backend accepts a session token as a Bearer, verified live).
  Future<({Map<String, dynamic> user, String sessionToken})> login({
    required String identifier,
    required String password,
  }) {
    final isEmail = identifier.contains('@');
    return _sessionAuthPost('/auth/login', {
      if (isEmail) 'email': identifier.trim() else 'phone': identifier.trim(),
      'password': password,
    }, invalidCredentialsMessage: 'Invalid phone/email or password.');
  }

  /// Creates a new account against `/auth/register` and signs straight in —
  /// the response carries the same session cookie as a login.
  Future<({Map<String, dynamic> user, String sessionToken})> register({
    required String accountType, // GROUP | MEMBER | AGENT
    required String name,
    required String phone,
    required String password,
    String? email,
    String? county,
  }) {
    return _sessionAuthPost('/auth/register', {
      'accountType': accountType,
      'name': name.trim(),
      'phone': phone.trim(),
      'password': password,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (county != null && county.trim().isNotEmpty) 'county': county.trim(),
    });
  }

  /// POST to an auth endpoint that responds with a `Set-Cookie` session.
  Future<({Map<String, dynamic> user, String sessionToken})> _sessionAuthPost(
    String path,
    Map<String, dynamic> body, {
    String? invalidCredentialsMessage,
  }) async {
    final http.Response response;
    try {
      response = await _http
          .post(_uri(path),
              headers: _headers(auth: false, json: true), body: jsonEncode(body))
          .timeout(_timeout);
    } on TimeoutException {
      log.warn('api', 'POST $path -> timeout');
      throw const ApiException(
          'The server took too long to respond. Check the connection and try again.');
    } catch (e) {
      log.warn('api', 'POST $path -> transport failure', e);
      throw const ApiException(
          'Could not reach the server. Confirm the base URL and that the backend is running.');
    }

    Map<String, dynamic> decoded;
    try {
      final parsed = response.body.isEmpty ? {} : jsonDecode(response.body);
      decoded = parsed is Map<String, dynamic> ? parsed : {};
    } on FormatException {
      throw ApiException('The server returned an unexpected response (${response.statusCode}).',
          statusCode: response.statusCode);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final token = _sessionTokenFrom(response.headers['set-cookie']);
      if (token == null) {
        throw const ApiException('Signed in, but the server returned no session.');
      }
      log.info('api', 'POST $path -> ${response.statusCode} (signed in)');
      return (user: (decoded['data'] as Map<String, dynamic>), sessionToken: token);
    }
    if (response.statusCode == 401 && invalidCredentialsMessage != null) {
      log.warn('api', 'POST $path -> 401 invalid credentials');
      throw ApiException(invalidCredentialsMessage, statusCode: 401);
    }
    throw _errorFrom(response.statusCode, decoded);
  }

  static String? _sessionTokenFrom(String? setCookie) {
    if (setCookie == null) return null;
    final match = RegExp(r'ic_session=([^;]+)').firstMatch(setCookie);
    return match?.group(1);
  }

  Future<Map<String, dynamic>> _send(
    String label,
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request();
    } on TimeoutException {
      log.warn('api', '$label -> timeout');
      throw const ApiException(
        'The server took too long to respond. Check the connection and try again.',
      );
    } catch (e) {
      log.warn('api', '$label -> transport failure', e);
      throw const ApiException(
        'Could not reach the server. Confirm the base URL and that the '
        'backend is running.',
      );
    }

    Map<String, dynamic> decoded;
    try {
      final parsed = response.body.isEmpty ? {} : jsonDecode(response.body);
      decoded = parsed is Map<String, dynamic> ? parsed : {'data': parsed};
    } on FormatException {
      throw ApiException(
        'The server returned an unexpected response (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      log.debug('api', '$label -> ${response.statusCode}');
      return decoded;
    }
    final failure = _errorFrom(response.statusCode, decoded);
    final error = decoded['error'];
    final code = error is Map ? error['code'] : null;
    final traceId = error is Map ? error['traceId'] : null;
    log.warn('api',
        '$label -> ${response.statusCode} $code${traceId != null ? ' (trace $traceId)' : ''}: ${failure.message}');
    throw failure;
  }

  /// Parses the backend error envelope `{ error: { code, message, details } }`.
  ApiException _errorFrom(int status, Map<String, dynamic> body) {
    final error = body['error'];
    final code = error is Map ? error['code']?.toString() : null;
    final rawMessage = error is Map ? error['message']?.toString() : null;

    // Zod validation failures arrive as details.fieldErrors / formErrors.
    Map<String, List<String>>? details;
    final rawDetails = error is Map ? error['details'] : null;
    final fieldErrors = rawDetails is Map ? rawDetails['fieldErrors'] : null;
    if (fieldErrors is Map) {
      details = fieldErrors.map(
        (k, v) => MapEntry(
          k.toString(),
          (v is List ? v : [v]).map((e) => e.toString()).toList(),
        ),
      );
    }

    final message = switch (status) {
      401 => 'Invalid or expired API key. Re-check the token in Server settings.',
      403 => rawMessage ??
          'This API key lacks permission for that action (code: $code).',
      404 => rawMessage ?? 'Not found on the server.',
      400 => details?.values.firstOrNull?.firstOrNull ??
          rawMessage ??
          'The server rejected the request.',
      429 => 'Rate limit reached. Wait a moment and try again.',
      _ => rawMessage ?? 'Server error ($status).',
    };
    return ApiException(message, statusCode: status, details: details, code: code);
  }

  void close() => _http.close();
}
