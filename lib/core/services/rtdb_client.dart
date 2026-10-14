import 'dart:convert';

import 'package:http/http.dart' as http;

/// Tiny Firebase Realtime Database REST client.
///
/// [tokenProvider] returns an ID token (when anonymous auth is on) that is
/// sent as `?auth=`; null means open mode.
class RtdbClient {
  RtdbClient(
    String databaseUrl, {
    http.Client? client,
    this.tokenProvider,
    this.timeout = const Duration(seconds: 8),
  })  : base = databaseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String base;
  final http.Client _client;
  final Future<String?> Function()? tokenProvider;
  final Duration timeout;

  Future<Uri> _uri(String path, [Map<String, String>? query]) async {
    final params = <String, String>{...?query};
    final token = await tokenProvider?.call();
    if (token != null) params['auth'] = token;
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$base/$clean.json').replace(
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Never _fail(String what, http.Response res) =>
      throw http.ClientException('$what -> ${res.statusCode}');

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final res = await _client.get(await _uri(path, query)).timeout(timeout);
    if (res.statusCode != 200) _fail('GET $path', res);
    return jsonDecode(res.body);
  }

  Future<void> put(String path, Object? body) => _send('PUT', path, body);

  Future<void> patch(String path, Object? body) => _send('PATCH', path, body);

  Future<void> _send(String method, String path, Object? body) async {
    final req = http.Request(method, await _uri(path))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);
    final res = await http.Response.fromStream(
      await _client.send(req).timeout(timeout),
    );
    if (res.statusCode != 200) _fail('$method $path', res);
  }

  Future<void> delete(String path) async {
    final res = await _client.delete(await _uri(path)).timeout(timeout);
    if (res.statusCode != 200) _fail('DELETE $path', res);
  }

  void close() => _client.close();
}
