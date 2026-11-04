import 'dart:async';

import 'package:dio/dio.dart';

/// Why a call to the companion service failed. The UI picks its message and
/// whether to offer Retry from this, so keep the kinds coarse and stable.
enum CompanionErrorKind {
  /// No URL or token saved yet.
  notConfigured,

  /// The server answered 401/403: wrong token.
  unauthorized,

  /// No answer at all: wrong address, server down, no network.
  unreachable,

  /// The server took too long.
  timeout,

  /// The link was rejected: not YouTube, a playlist, private, region-blocked,
  /// unavailable. [CompanionException.message] says which, in words.
  invalidLink,

  /// The link was fine but the file is already in the library and the call
  /// didn't pass `force`.
  alreadyExists,

  /// Anything else the server reported (a 5xx, a failed job, a bad reply).
  server,
}

class CompanionException implements Exception {
  const CompanionException(this.kind, this.message);

  final CompanionErrorKind kind;
  final String message;

  /// Worth offering "Retry" for: the same call could succeed later.
  bool get retryable =>
      kind == CompanionErrorKind.unreachable ||
      kind == CompanionErrorKind.timeout ||
      kind == CompanionErrorKind.server;

  @override
  String toString() => 'CompanionException(${kind.name}): $message';
}

/// `GET /health`.
class CompanionHealth {
  const CompanionHealth({required this.version, required this.ytDlpVersion});

  final String version;
  final String ytDlpVersion;
}

/// How the server split a video title into tags.
class ParsedTitle {
  const ParsedTitle({
    required this.artist,
    required this.albumArtist,
    required this.title,
  });

  final String artist;
  final String albumArtist;
  final String title;

  /// Album = song title (the user's "one single per song" scheme).
  String get album => title;
}

/// `POST /validate`: what the link points at, before anything is downloaded.
class VideoPreview {
  const VideoPreview({
    required this.url,
    required this.videoId,
    required this.title,
    required this.channel,
    required this.durationSeconds,
    required this.parsed,
    this.thumbnailUrl,
    this.alreadyExists = false,
  });

  final String url;
  final String videoId;
  final String title;
  final String channel;
  final int durationSeconds;
  final String? thumbnailUrl;
  final ParsedTitle parsed;
  final bool alreadyExists;
}

enum JobStatus { queued, downloading, converting, tagging, done, failed }

/// `GET /jobs/{id}`.
class DownloadJob {
  const DownloadJob({
    required this.id,
    required this.status,
    this.progress = 0,
    this.error,
    this.file,
    this.warning,
  });

  final String id;
  final JobStatus status;

  /// 0..1.
  final double progress;
  final String? error;
  final String? file;

  /// Non-fatal: the file is saved but the Navidrome rescan failed.
  final String? warning;

  bool get finished => status == JobStatus.done || status == JobStatus.failed;
}

/// The companion service's HTTP API. [CompanionService] is the real client;
/// [MockCompanionService] is a test double.
abstract class CompanionApi {
  Future<CompanionHealth> health();
  Future<VideoPreview> validate(String url);

  /// Starts a download and returns the job id.
  Future<String> startDownload(String url, {bool force = false});
  Future<DownloadJob> job(String id);
}

/// Builds an API client for a URL and token, so "Test connection" can try
/// values that aren't saved yet.
typedef CompanionApiFactory = CompanionApi Function(String baseUrl, String token);

/// The real client for the companion service in `companion/`.
class CompanionService implements CompanionApi {
  CompanionService({required String baseUrl, required String token, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 8)
      ..sendTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      // Handle every status ourselves, so each maps to a clear error kind.
      ..validateStatus = (_) => true;
  }

  final Dio _dio;

  /// `/validate` and `/download` run yt-dlp on the server, which can take a
  /// while on a slow YouTube day.
  static const _slow = Duration(seconds: 90);

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method, receiveTimeout: timeout),
      );
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw const CompanionException(
            CompanionErrorKind.timeout,
            'The server took too long to answer.',
          );
        default:
          throw const CompanionException(
            CompanionErrorKind.unreachable,
            'Can\'t reach the server. Check the address and that the '
            'service is running.',
          );
      }
    }
    final status = response.statusCode ?? 0;
    final data = response.data;
    final json = data is Map ? Map<String, dynamic>.from(data) : null;
    final message = json?['error'] is String ? json!['error'] as String : null;
    if (status >= 200 && status < 300) {
      if (json == null) {
        throw const CompanionException(
          CompanionErrorKind.server,
          'That address answered, but it isn\'t the companion service.',
        );
      }
      return json;
    }
    switch (status) {
      case 401:
      case 403:
        throw CompanionException(
          CompanionErrorKind.unauthorized,
          message ?? 'The token was rejected.',
        );
      case 409:
        throw CompanionException(
          CompanionErrorKind.alreadyExists,
          message ?? 'That song is already in your library.',
        );
      case 422:
        throw CompanionException(
          CompanionErrorKind.invalidLink,
          message ?? 'That link can\'t be added.',
        );
      default:
        throw CompanionException(
          CompanionErrorKind.server,
          message ?? 'The server answered with an error ($status).',
        );
    }
  }

  static String _str(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is String) return v;
    throw CompanionException(
      CompanionErrorKind.server,
      'The server\'s reply is missing "$key".',
    );
  }

  @override
  Future<CompanionHealth> health() async {
    final j = await _call('GET', '/health');
    return CompanionHealth(
      version: _str(j, 'version'),
      ytDlpVersion: _str(j, 'ytDlpVersion'),
    );
  }

  @override
  Future<VideoPreview> validate(String url) async {
    final j = await _call('POST', '/validate', body: {'url': url}, timeout: _slow);
    final parsed = j['parsed'];
    if (parsed is! Map) {
      throw const CompanionException(
        CompanionErrorKind.server,
        'The server\'s reply is missing "parsed".',
      );
    }
    final p = Map<String, dynamic>.from(parsed);
    return VideoPreview(
      url: url,
      videoId: _str(j, 'videoId'),
      title: _str(j, 'title'),
      channel: j['channel'] is String ? j['channel'] as String : '',
      durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
      thumbnailUrl: j['thumbnailUrl'] as String?,
      parsed: ParsedTitle(
        artist: _str(p, 'artist'),
        albumArtist: _str(p, 'albumArtist'),
        title: _str(p, 'title'),
      ),
      alreadyExists: j['alreadyExists'] == true,
    );
  }

  @override
  Future<String> startDownload(String url, {bool force = false}) async {
    final j = await _call(
      'POST',
      '/download',
      body: {'url': url, 'force': force},
      timeout: _slow,
    );
    return _str(j, 'jobId');
  }

  @override
  Future<DownloadJob> job(String id) async {
    final j = await _call('GET', '/jobs/${Uri.encodeComponent(id)}');
    final status = JobStatus.values.where((s) => s.name == j['status']);
    if (status.isEmpty) {
      throw const CompanionException(
        CompanionErrorKind.server,
        'The server sent an unknown job status.',
      );
    }
    return DownloadJob(
      id: id,
      status: status.first,
      progress: (j['progress'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0,
      error: j['error'] as String?,
      file: j['file'] as String?,
      warning: j['warning'] as String?,
    );
  }
}

/// A stand-in for the companion service, for tests.
///
/// Accepts YouTube links only, rejects playlists, treats any link containing
/// `exists` as already in the library, and walks a job through its states one
/// step per [step] (and per poll).
class MockCompanionService implements CompanionApi {
  MockCompanionService({
    this.step = const Duration(milliseconds: 600),
    this.clientToken = '',
  });

  final Duration step;

  /// The token the app presents. Calls fail with `unauthorized` unless it is
  /// [validToken].
  final String clientToken;

  /// The one token the mock accepts, so the setup card can be tried out.
  static const validToken = 'demo';

  static const _hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
  };

  final Map<String, int> _polls = {};

  Future<void> _wait() async {
    if (step > Duration.zero) await Future<void>.delayed(step);
    if (clientToken != validToken) {
      throw const CompanionException(
        CompanionErrorKind.unauthorized,
        'The token was rejected. (The demo service accepts "demo".)',
      );
    }
  }

  @override
  Future<CompanionHealth> health() async {
    await _wait();
    return const CompanionHealth(version: '0.1.0-mock', ytDlpVersion: '2026.10.01');
  }

  @override
  Future<VideoPreview> validate(String url) async {
    await _wait();
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_hosts.contains(uri.host.toLowerCase())) {
      throw const CompanionException(
        CompanionErrorKind.invalidLink,
        'That isn\'t a YouTube link.',
      );
    }
    if (uri.queryParameters.containsKey('list') && !uri.queryParameters.containsKey('v') ||
        uri.path == '/playlist') {
      throw const CompanionException(
        CompanionErrorKind.invalidLink,
        'That\'s a playlist. Paste a link to a single video.',
      );
    }
    if (url.contains('private')) {
      throw const CompanionException(
        CompanionErrorKind.invalidLink,
        'That video is private.',
      );
    }
    return VideoPreview(
      url: url.trim(),
      videoId: uri.queryParameters['v'] ?? 'dQw4w9WgXcQ',
      title: 'Cochise & Pradabagshawty - IMGEEKED, IM HIGH, IM FCKED UP '
          '＊snippet＊ (EXTENDED EDIT) (HQ)',
      channel: 'Cochise',
      durationSeconds: 187,
      parsed: const ParsedTitle(
        artist: 'Cochise & Pradabagshawty',
        albumArtist: 'Cochise',
        title: 'IMGEEKED, IM HIGH, IM FCKED UP',
      ),
      alreadyExists: url.contains('exists'),
    );
  }

  @override
  Future<String> startDownload(String url, {bool force = false}) async {
    await _wait();
    if (url.contains('exists') && !force) {
      throw const CompanionException(
        CompanionErrorKind.alreadyExists,
        'That song is already in your library.',
      );
    }
    final id = 'mock-${DateTime.now().microsecondsSinceEpoch}';
    _polls[id] = url.contains('fail') ? -1 : 0;
    return id;
  }

  @override
  Future<DownloadJob> job(String id) async {
    await _wait();
    final n = _polls[id];
    if (n == null) {
      throw const CompanionException(CompanionErrorKind.server, 'Unknown job.');
    }
    if (n < 0) {
      return DownloadJob(
        id: id,
        status: JobStatus.failed,
        error: 'yt-dlp could not download this video.',
      );
    }
    _polls[id] = n + 1;
    switch (n) {
      case 0:
        return DownloadJob(id: id, status: JobStatus.queued);
      case 1:
        return DownloadJob(id: id, status: JobStatus.downloading, progress: 0.35);
      case 2:
        return DownloadJob(id: id, status: JobStatus.downloading, progress: 0.8);
      case 3:
        return DownloadJob(id: id, status: JobStatus.converting, progress: 0.9);
      case 4:
        return DownloadJob(id: id, status: JobStatus.tagging, progress: 0.97);
      default:
        return DownloadJob(
          id: id,
          status: JobStatus.done,
          progress: 1,
          file: 'Cochise & Pradabagshawty - IMGEEKED, IM HIGH, IM FCKED UP.mp3',
        );
    }
  }
}
