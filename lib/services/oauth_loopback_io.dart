import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<HttpServer> _bindLoopbackServer() async {
  // Prefer port 3000 (matches Supabase default Site URL `http://localhost:3000`)
  // so even if Supabase falls back to Site URL, our local server catches it.
  for (final port in [3000, 0]) {
    try {
      return await HttpServer.bind(
        InternetAddress.anyIPv6,
        port,
        v6Only: false,
      );
    } catch (_) {
      try {
        return await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      } catch (_) {
        if (port == 0) rethrow;
      }
    }
  }
  return HttpServer.bind(InternetAddress.loopbackIPv4, 0);
}

Future<bool> signInWithDesktopLoopback(
  SupabaseClient client, {
  bool selectAccount = false,
}) async {
  if (!isDesktopPlatform) return false;
  HttpServer? server;
  try {
    server = await _bindLoopbackServer();
    final redirectUrl = 'http://localhost:${server.port}';
    final completer = Completer<Uri?>();

    late final StreamSubscription<HttpRequest> sub;
    sub = server.listen((HttpRequest request) async {
      if (request.uri.path == '/favicon.ico') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final hasAuthParams = request.uri.queryParameters.containsKey('code') ||
          request.uri.queryParameters.containsKey('error');

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Dogtopia Sign-In</title></head>
<body style="font-family:sans-serif;background:#1F0B03;color:#FEF3C7;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
  <div style="text-align:center;padding:24px 32px;border:2px solid #F59E0B;border-radius:16px;background:#2A1205;">
    <h2 style="color:#FEF08A;margin-top:0;">Sign-in complete!</h2>
    <p>You can close this browser tab and return to Dogtopia.</p>
  </div>
</body>
</html>
''');
      await request.response.close();

      if (hasAuthParams && !completer.isCompleted) {
        completer.complete(
          Uri.parse('$redirectUrl${request.uri.toString()}'),
        );
        await sub.cancel();
      }
    });

    final launched = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
      queryParams: selectAccount ? const {'prompt': 'select_account'} : null,
    );
    if (!launched) {
      await sub.cancel();
      return false;
    }

    final callbackUri = await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => null,
    );
    if (callbackUri == null ||
        callbackUri.queryParameters.containsKey('error')) {
      return false;
    }

    await client.auth.getSessionFromUrl(callbackUri);
    return client.auth.currentUser != null;
  } finally {
    await server?.close(force: true);
  }
}
