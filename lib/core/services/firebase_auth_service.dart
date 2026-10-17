import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../constants/backend_config.dart';
import 'storage_service.dart';

/// Anonymous Firebase Authentication over the REST API (no SDK needed).
///
/// Gives every install a stable `uid` and short-lived ID tokens that the
/// database can check in its rules. If Authentication is not enabled on the
/// Firebase project (or no API key is configured) the service stays
/// signed-out and the app keeps working in "open mode" with a local id.
class FirebaseAuthService extends GetxService {
  FirebaseAuthService(this._storage, {http.Client? client})
      : _client = client ?? http.Client();

  final StorageService _storage;
  final http.Client _client;

  /// Stable user id once signed in (null in open mode).
  final RxnString uid = RxnString();

  String? _idToken;
  DateTime _expiry = DateTime.fromMillisecondsSinceEpoch(0);
  String? _refreshToken;
  Future<bool>? _inFlight;

  static const _timeout = Duration(seconds: 10);

  bool get signedIn => uid.value != null;

  FirebaseAuthService init() {
    uid.value = _storage.getSetting<String>('fb_uid');
    _refreshToken = _storage.getSetting<String>('fb_refresh');
    return this;
  }

  /// A valid ID token, signing in / refreshing when needed. Null in open mode.
  Future<String?> idToken() async {
    if (!BackendConfig.authConfigured) return null;
    if (_idToken != null &&
        DateTime.now().isBefore(_expiry.subtract(const Duration(minutes: 5)))) {
      return _idToken;
    }
    await (_inFlight ??= _authenticate().whenComplete(() => _inFlight = null));
    return _idToken;
  }

  /// Signs in anonymously (or refreshes). Returns whether a token is held.
  Future<bool> signIn() async {
    await idToken();
    return signedIn && _idToken != null;
  }

  Future<bool> _authenticate() async {
    final key = BackendConfig.apiKey;
    try {
      if (_refreshToken != null) {
        final res = await _client
            .post(
              Uri.parse('https://securetoken.googleapis.com/v1/token?key=$key'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'grant_type=refresh_token&refresh_token=$_refreshToken',
            )
            .timeout(_timeout);
        if (res.statusCode == 200) {
          final j = jsonDecode(res.body) as Map<String, dynamic>;
          _apply(
            idToken: j['id_token'] as String,
            refresh: j['refresh_token'] as String,
            expiresIn: j['expires_in'] as String,
            localId: j['user_id'] as String,
          );
          return true;
        }
        // Refresh token revoked / project changed: start over.
        _refreshToken = null;
      }
      final res = await _client
          .post(
            Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$key',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'returnSecureToken': true}),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        _apply(
          idToken: j['idToken'] as String,
          refresh: j['refreshToken'] as String,
          expiresIn: j['expiresIn'] as String,
          localId: j['localId'] as String,
        );
        return true;
      }
      debugPrint(
          'Anonymous sign-in unavailable: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('Auth failed: $e');
    }
    return false;
  }

  void _apply({
    required String idToken,
    required String refresh,
    required String expiresIn,
    required String localId,
  }) {
    _idToken = idToken;
    _refreshToken = refresh;
    _expiry =
        DateTime.now().add(Duration(seconds: int.tryParse(expiresIn) ?? 3600));
    uid.value = localId;
    _storage.setSetting('fb_uid', localId);
    _storage.setSetting('fb_refresh', refresh);
  }

  @override
  void onClose() {
    _client.close();
    super.onClose();
  }
}
