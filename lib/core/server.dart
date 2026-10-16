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
  Duration timeout = const Duration(seconds: 30),
]) async {
  final req = http.Request(method, Uri.parse('${AppConfig.serverUrl}$path'))
    ..headers['Content-Type'] = 'application/json';
  if (body != null) req.body = jsonEncode(body);
  return _send(req, timeout: timeout);
}

/// Reading a photo, a PDF or a cooking video takes the server up to two minutes.
const slowCall = Duration(seconds: 150);

/// A multipart upload (photos, PDFs): [files] by field name, as bytes with
/// their file name; [fields] as plain form values.
Future<dynamic> serverUpload(
  String method,
  String path, {
  required Map<String, (List<int>, String)> files,
  Map<String, String> fields = const {},
}) async {
  final req = http.MultipartRequest(method, Uri.parse('${AppConfig.serverUrl}$path'))
    ..fields.addAll(fields);
  for (final MapEntry(key: field, value: (bytes, name)) in files.entries) {
    req.files.add(http.MultipartFile.fromBytes(field, bytes, filename: name));
  }
  return _send(req, timeout: slowCall);
}

Future<dynamic> _send(http.BaseRequest req, {required Duration timeout}) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  req.headers.addAll(serverHeaders);
  if (token != null) req.headers['Authorization'] = 'Bearer $token';
  final http.Response res;
  try {
    res = await http.Response.fromStream(await req.send().timeout(timeout));
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
