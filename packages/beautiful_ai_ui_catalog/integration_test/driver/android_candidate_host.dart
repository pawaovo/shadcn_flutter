import 'dart:convert';
import 'dart:io';

/// Host-local HTTP transport shared by the driver and real wire regression.
final class AndroidCandidateHost {
  AndroidCandidateHost(this.base, this.token) {
    client.findProxy = (_) => 'DIRECT';
    client.connectionTimeout = const Duration(seconds: 2);
  }

  factory AndroidCandidateHost.fromEnvironment() {
    final base = Uri.parse(
      Platform.environment['ANDROID_CANDIDATE_HOST_URL'] ?? '',
    );
    final token = Platform.environment['ANDROID_CANDIDATE_HOST_TOKEN'] ?? '';
    if (base.scheme != 'http' ||
        base.host != '127.0.0.1' ||
        !base.hasPort ||
        base.userInfo.isNotEmpty ||
        (base.path.isNotEmpty && base.path != '/') ||
        base.hasQuery ||
        base.hasFragment ||
        token.isEmpty) {
      throw StateError(
        'The native supervisor must be an authenticated loopback HTTP endpoint.',
      );
    }
    return AndroidCandidateHost(base, token);
  }

  final Uri base;
  final String token;
  final HttpClient client = HttpClient();

  Future<Map<String, Object?>> request(
    String method,
    String path,
    Map<String, Object?>? body, {
    required Duration timeout,
  }) async {
    HttpClientRequest? outgoing;
    try {
      return await (() async {
        outgoing = await client.openUrl(method, base.resolve(path));
        outgoing!.followRedirects = false;
        outgoing!.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        if (body != null) {
          final payload = utf8.encode(jsonEncode(body));
          outgoing!.headers.contentType = ContentType.json;
          outgoing!.contentLength = payload.length;
          outgoing!.add(payload);
        }
        final response = await outgoing!.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 1024 * 1024) {
            throw StateError('Native response is too large.');
          }
        }
        final result = Map<String, Object?>.from(
          jsonDecode(utf8.decode(bytes)) as Map,
        );
        if (response.statusCode != 200) {
          throw StateError(
            'Native supervisor $path failed (${response.statusCode}): $result',
          );
        }
        return result;
      })().timeout(timeout);
    } catch (_) {
      outgoing?.abort();
      rethrow;
    }
  }

  void close() => client.close(force: true);
}
