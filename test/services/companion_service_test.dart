import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/services/companion_service.dart';

/// Answers requests from a handler, and records them.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

(CompanionService, _Adapter) _client(
    FutureOr<ResponseBody> Function(RequestOptions) handler) {
  final adapter = _Adapter(handler);
  final dio = Dio()..httpClientAdapter = adapter;
  return (
    CompanionService(baseUrl: 'http://10.0.0.2:8787', token: 'tok', dio: dio),
    adapter
  );
}

Future<CompanionException> _fails(Future<Object?> call) async {
  try {
    await call;
  } on CompanionException catch (e) {
    return e;
  }
  fail('expected a CompanionException');
}

const _preview = {
  'valid': true,
  'videoId': 'dQw4w9WgXcQ',
  'title': 'Cochise - JACKSON (pt. 2) *snippet*',
  'channel': 'Cochise',
  'durationSeconds': 187,
  'thumbnailUrl': 'https://img/x.jpg',
  'parsed': {
    'artist': 'Cochise',
    'albumArtist': 'Cochise',
    'title': 'JACKSON (pt. 2)',
  },
  'alreadyExists': true,
};

void main() {
  test('health sends the bearer token and parses the versions', () async {
    final (c, a) = _client((_) =>
        _json(200, {'version': '0.1.0', 'ytDlpVersion': '2026.10.01'}));
    final h = await c.health();
    expect((h.version, h.ytDlpVersion), ('0.1.0', '2026.10.01'));
    expect(a.requests.single.uri.toString(), 'http://10.0.0.2:8787/health');
    expect(a.requests.single.headers['Authorization'], 'Bearer tok');
  });

  test('validate posts the url and parses the preview', () async {
    final (c, a) = _client((_) => _json(200, _preview));
    final p = await c.validate('https://youtu.be/dQw4w9WgXcQ');
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.path, '/validate');
    expect(a.requests.single.data, {'url': 'https://youtu.be/dQw4w9WgXcQ'});
    expect(p.videoId, 'dQw4w9WgXcQ');
    expect(p.durationSeconds, 187);
    expect(p.parsed.title, 'JACKSON (pt. 2)');
    expect(p.parsed.album, 'JACKSON (pt. 2)');
    expect(p.alreadyExists, isTrue);
    expect(p.url, 'https://youtu.be/dQw4w9WgXcQ');
  });

  test('download sends force and returns the job id', () async {
    final (c, a) = _client((_) => _json(200, {'jobId': 'j1'}));
    expect(await c.startDownload('u', force: true), 'j1');
    expect(a.requests.single.data, {'url': 'u', 'force': true});
  });

  test('job maps every status and the optional fields', () async {
    for (final s in JobStatus.values) {
      final (c, _) = _client((_) => _json(200, {
            'status': s.name,
            'progress': 0.5,
            'error': s == JobStatus.failed ? 'nope' : null,
            'file': 'A - B.mp3',
            'warning': 'rescan failed',
          }));
      final j = await c.job('j1');
      expect(j.status, s);
      expect(j.progress, 0.5);
      expect(j.file, 'A - B.mp3');
      expect(j.warning, 'rescan failed');
      expect(j.error, s == JobStatus.failed ? 'nope' : isNull);
    }
  });

  test('HTTP statuses map to error kinds with the server\'s message',
      () async {
    final cases = <int, CompanionErrorKind>{
      401: CompanionErrorKind.unauthorized,
      403: CompanionErrorKind.unauthorized,
      409: CompanionErrorKind.alreadyExists,
      422: CompanionErrorKind.invalidLink,
      500: CompanionErrorKind.server,
      404: CompanionErrorKind.server,
    };
    for (final e in cases.entries) {
      final (c, _) = _client((_) => _json(e.key, {'error': 'because'}));
      final err = await _fails(c.validate('u'));
      expect(err.kind, e.value, reason: '${e.key}');
      expect(err.message, 'because');
    }
    final (c, _) = _client((_) => _json(422, {'x': 1}));
    expect((await _fails(c.validate('u'))).message, isNotEmpty);
  });

  test('retryable only for unreachable, timeout and server', () {
    for (final k in CompanionErrorKind.values) {
      expect(CompanionException(k, 'm').retryable, {
        CompanionErrorKind.unreachable,
        CompanionErrorKind.timeout,
        CompanionErrorKind.server,
      }.contains(k));
    }
  });

  test('a connection failure is unreachable; timeouts are timeouts', () async {
    var (c, _) = _client((o) => throw DioException.connectionError(
        requestOptions: o, reason: 'refused'));
    expect((await _fails(c.health())).kind, CompanionErrorKind.unreachable);

    (c, _) = _client((o) => throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 8), requestOptions: o));
    expect((await _fails(c.health())).kind, CompanionErrorKind.timeout);

    (c, _) = _client((o) => throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 8), requestOptions: o));
    expect((await _fails(c.validate('u'))).kind, CompanionErrorKind.timeout);
  });

  test('a reply that is not the companion service is a server error',
      () async {
    var (c, _) = _client((_) => ResponseBody.fromString('<html></html>', 200));
    expect((await _fails(c.health())).kind, CompanionErrorKind.server);

    (c, _) = _client((_) => _json(200, {'hello': 'world'}));
    expect((await _fails(c.health())).kind, CompanionErrorKind.server);

    (c, _) = _client((_) => _json(200, {'status': 'weird'}));
    expect((await _fails(c.job('j'))).kind, CompanionErrorKind.server);
  });

  test('validate and download get a longer receive timeout than health',
      () async {
    final (c, a) = _client((o) => o.path == '/health'
        ? _json(200, {'version': '1', 'ytDlpVersion': '2'})
        : o.path == '/validate'
            ? _json(200, _preview)
            : _json(200, {'jobId': 'j'}));
    await c.health();
    await c.validate('u');
    await c.startDownload('u');
    expect(a.requests[0].receiveTimeout, isNot(const Duration(seconds: 90)));
    expect(a.requests[1].receiveTimeout, const Duration(seconds: 90));
    expect(a.requests[2].receiveTimeout, const Duration(seconds: 90));
  });
}
