import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiClient {
  String? token;
  static const _requestTimeout = Duration(seconds: 75);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConstants.apiBaseUrl}$path')
          .replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token'
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) async =>
      _decode(
          await _send(() => http.get(_uri(path, query), headers: _headers)));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _send(() => http.post(
            _uri(path),
            headers: _headers,
            body: jsonEncode(body ?? {}),
          )));

  Future<dynamic> patch(String path, Map<String, dynamic> body) async =>
      _decode(await _send(() => http.patch(
            _uri(path),
            headers: _headers,
            body: jsonEncode(body),
          )));

  Future<dynamic> delete(String path) async =>
      _decode(await _send(() => http.delete(_uri(path), headers: _headers)));

  Future<dynamic> postMultipart(
    String path,
    Map<String, String> fields, {
    File? file,
    String fileField = 'photo',
    void Function(int sent, int total)? onProgress,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields.addAll(fields);
      if (file != null) {
        request.files
            .add(await http.MultipartFile.fromPath(fileField, file.path));
      }
      final body = request.finalize();
      final total = request.contentLength;
      final upload = http.StreamedRequest(request.method, request.url)
        ..contentLength = total
        ..headers.addAll(request.headers);
      final responseFuture = client.send(upload).timeout(timeout);
      var sent = 0;
      onProgress?.call(sent, total);
      await for (final chunk in body) {
        upload.sink.add(chunk);
        sent += chunk.length;
        onProgress?.call(sent.clamp(0, total).toInt(), total);
      }
      await upload.sink.close();
      onProgress?.call(total, total);
      final streamed = await responseFuture;
      final response =
          await http.Response.fromStream(streamed).timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException(
        'Photo upload timed out. Check your connection and try again.',
      );
    } on SocketException {
      throw ApiException(
        'Cannot reach the server. Check your internet connection and try again.',
      );
    } on http.ClientException {
      throw ApiException(
          'Could not connect to the academy server. Please try again.');
    } finally {
      client.close();
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'Server did not respond in time. It may be waking up; please try again.',
      );
    } on SocketException {
      throw ApiException(
        'Cannot reach the server. Check your internet connection and try again.',
      );
    } on http.ClientException {
      throw ApiException(
        'Could not connect to the academy server. Please try again.',
      );
    }
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
          'Server response could not be read', response.statusCode);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map && data['error'] is Map
          ? data['error']['message']?.toString()
          : null;
      final details = data is Map && data['error'] is Map
          ? data['error']['details']
          : null;
      final reason = details is Map ? details['reason']?.toString() : null;
      final safeMessage = reason == null || reason.isEmpty
          ? message ?? 'Request failed'
          : '${message ?? 'Request failed'}: $reason';
      throw ApiException(safeMessage, response.statusCode);
    }
    return data is Map ? data['data'] : data;
  }
}
