import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'errors.dart';

bool get hasServer => AppConfig.serverUrl.isNotEmpty;

/// Sent with every call. The recipe app puts the chosen book here (X-Book).
final serverHeaders = <String, String>{};

/// Calls the home server with the signed-in user's Firebase ID token, which
/// the server checks on every route. Every call has a timeout. Returns the
/// decoded JSON (a map or a list), or null for an empty answer.
Future<dynamic> server(
  String method,
  String path, [
  Object? body,
]) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  final req = http.Request(method, Uri.parse('${AppConfig.serverUrl}$path'))
    ..headers.addAll(serverHeaders)
    ..headers['Content-Type'] = 'application/json';
  if (token != null) req.headers['Authorization'] = 'Bearer $token';
  if (body != null) req.body = jsonEncode(body);
  final http.Response res;
  try {
    res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 30)));
  } on http.ClientException {
    throw Errors.noConnection; // the web's (and a refused socket's) failure
  }
  if (res.statusCode >= 400) {
    // The recipe server answers {"error": code, "message": Hebrew}.
    var message = '';
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map && j['message'] is String) message = j['message'] as String;
    } catch (_) {}
    throw ServerException(res.statusCode, message);
  }
  return res.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
}
