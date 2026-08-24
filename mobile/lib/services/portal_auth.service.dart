import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/infrastructure/repositories/network.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:logging/logging.dart';

// Redirect URL = hearth://portal-callback (distinct from Immich's own
// app.immich:///oauth-callback OAuth scheme).

final portalAuthServiceProvider = Provider((ref) => PortalAuthService());

/// Thrown when the server is portal-gated and no token could be obtained.
class PortalAuthException implements Exception {
  final String message;
  const PortalAuthException(this.message);

  @override
  String toString() => message;
}

/// The Hearth server sits behind an invitation-only auth portal enforced at
/// the reverse proxy (nginx auth_request), which gates /api as well. This
/// service obtains the portal's opaque per-device token via the system
/// browser (ASWebAuthenticationSession / Custom Tab), keeps it in the
/// platform keystore, and hands it to [ApiService] so every request carries
/// an X-Portal-Token header alongside Immich's own credentials.
class PortalAuthService {
  static const String callbackUrlScheme = 'hearth';
  static const String _callbackUrl = '$callbackUrlScheme://portal-callback';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static bool _restored = false;

  final _log = Logger('PortalAuthService');

  /// Loads the stored token into [ApiService.portalToken] so header pushes
  /// include it. Called once during app startup, before any header push.
  static Future<void> restore() async {
    if (_restored) {
      return;
    }
    try {
      ApiService.portalToken = await _storage.read(key: kSecuredPortalToken);
      _restored = true;
    } catch (error) {
      // Keystore hiccups must never block startup; the native layer still has
      // the last pushed headers, so requests keep working.
      Logger('PortalAuthService').warning('Unable to restore portal token: $error');
    }
  }

  /// Ensures requests to [serverUrl] can pass the portal perimeter, running
  /// the interactive portal sign-in when the server challenges us. No-op for
  /// servers that are not portal-gated.
  Future<void> ensurePortalAccess(String serverUrl) async {
    await restore();
    var portalOrigin = await _probeChallenge(serverUrl);
    if (portalOrigin == null) {
      return;
    }

    _log.info('Server is portal-gated, starting portal sign-in at $portalOrigin');
    final token = await _interactiveSignIn(portalOrigin);
    await _setToken(token, portalOrigin);
    await _pushHeaders(serverUrl);

    portalOrigin = await _probeChallenge(serverUrl);
    if (portalOrigin != null) {
      throw const PortalAuthException(
        'Portal sign-in did not unlock the server. Ask the administrator whether your account has access.',
      );
    }
  }

  /// Revokes this device's token at the portal (best effort) and forgets it.
  Future<void> signOut() async {
    final token = ApiService.portalToken;
    if (token == null) {
      return;
    }
    try {
      final baseUrl = await _storage.read(key: kSecuredPortalBaseUrl);
      if (baseUrl != null && baseUrl.isNotEmpty) {
        final client = HttpClient();
        try {
          final request = await client.postUrl(Uri.parse('$baseUrl/api/app/logout'));
          request.headers.set(kPortalTokenHeader, token);
          final response = await request.close().timeout(const Duration(seconds: 5));
          await response.drain();
        } finally {
          client.close(force: true);
        }
      }
    } catch (error) {
      _log.warning('Portal token revocation failed (revoke it from the portal admin instead): $error');
    }
    await _setToken(null, null);
    await _pushHeaders(null);
  }

  Future<void> _pushHeaders(String? extraServerUrl) async {
    final urls = ApiService.getServerUrls();
    if (extraServerUrl != null && !urls.contains(extraServerUrl)) {
      urls.add(extraServerUrl);
    }
    if (urls.isEmpty) {
      return;
    }
    await NetworkRepository.setHeaders(ApiService.getRequestHeaders(), urls);
  }

  /// Probes the server without following redirects. A redirect to a different
  /// host is the portal challenge (nginx `error_page 401 =302 https://portal/…`);
  /// returns that portal's origin, or null when the request passes the gate.
  Future<String?> _probeChallenge(String serverUrl) async {
    final base = serverUrl.endsWith('/api') ? serverUrl : '$serverUrl/api';
    final uri = Uri.parse('$base/server/ping');

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      final token = ApiService.portalToken;
      if (token != null) {
        request.headers.set(kPortalTokenHeader, token);
      }
      final response = await request.close().timeout(const Duration(seconds: 10));
      await response.drain();

      if (response.statusCode < 300 || response.statusCode >= 400) {
        return null;
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null) {
        return null;
      }
      final target = Uri.tryParse(location);
      if (target == null || !(target.isScheme('https') || target.isScheme('http')) || target.host == uri.host) {
        return null;
      }
      return target.origin;
    } on SocketException {
      return null; // unreachable server: let the normal validation report it
    } on TimeoutException {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _interactiveSignIn(String portalOrigin) async {
    final startUrl = Uri.parse(
      portalOrigin,
    ).replace(path: '/auth/app/start', queryParameters: {'rd': _callbackUrl, 'device': await _deviceName()});

    final result = await FlutterWebAuth2.authenticate(url: startUrl.toString(), callbackUrlScheme: callbackUrlScheme);

    final callback = Uri.parse(result);
    final error = callback.queryParameters['error'];
    if (error != null) {
      throw PortalAuthException(switch (error) {
        'notinvited' => 'This portal is invitation-only. Ask the administrator to invite your Google account.',
        'blocked' => 'Your portal access has been disabled by the administrator.',
        _ => 'Portal sign-in failed ($error). Please try again.',
      });
    }
    final token = callback.queryParameters['token'];
    if (token == null || token.isEmpty) {
      throw const PortalAuthException('Portal sign-in failed: no token returned.');
    }
    return token;
  }

  Future<void> _setToken(String? token, String? portalOrigin) async {
    ApiService.portalToken = token;
    try {
      if (token == null) {
        await _storage.delete(key: kSecuredPortalToken);
        await _storage.delete(key: kSecuredPortalBaseUrl);
      } else {
        await _storage.write(key: kSecuredPortalToken, value: token);
        if (portalOrigin != null) {
          await _storage.write(key: kSecuredPortalBaseUrl, value: portalOrigin);
        }
      }
    } catch (error) {
      _log.warning('Unable to persist portal token: $error');
    }
  }

  Future<String> _deviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        return (await deviceInfo.iosInfo).utsname.machine;
      }
      if (Platform.isAndroid) {
        return (await deviceInfo.androidInfo).model;
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }
}
