import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/companion_service.dart';
import '../services/integration_config_store.dart';

/// Whether the companion's URL and token are saved.
enum AddConfigState { loading, notConfigured, ready }

/// Where the paste → preview → download flow is.
enum AddPhase {
  idle,
  validating,
  preview,
  starting,
  downloading,
  done,
  failed,
}

/// One row of the "this session" list.
class AddHistoryEntry {
  AddHistoryEntry({
    required this.id,
    required this.label,
    required this.status,
    this.error,
    this.warning,
  });

  final String id;
  final String label;
  JobStatus status;
  String? error;
  String? warning;
}

/// State of the Add tab. Owned by `AddScreen`, not registered app-wide.
class AddProvider extends ChangeNotifier {
  AddProvider({
    required IntegrationConfigStore store,
    required CompanionApiFactory apiFactory,
    this.pollInterval = const Duration(seconds: 1),
  })  : _store = store,
        _apiFactory = apiFactory;

  final IntegrationConfigStore _store;
  final CompanionApiFactory _apiFactory;
  final Duration pollInterval;

  AddConfigState configState = AddConfigState.loading;

  /// The gear button: show the setup card even though it's configured.
  bool editingConfig = false;
  IntegrationConfig? config;

  AddPhase phase = AddPhase.idle;
  VideoPreview? preview;
  DownloadJob? job;
  CompanionException? error;

  /// The URL the current flow started from, for Retry.
  String? _url;
  bool _force = false;

  final List<AddHistoryEntry> history = [];

  CompanionApi? _api;
  Timer? _poll;
  bool _disposed = false;

  Future<void> load() async {
    final saved = await _store.load(Integration.companion);
    if (_disposed) return;
    config = saved;
    _api = saved == null ? null : _apiFactory(saved.url, saved.secret);
    configState =
        saved == null ? AddConfigState.notConfigured : AddConfigState.ready;
    notifyListeners();
  }

  /// Adds `http://` when the user typed a bare host, and drops trailing
  /// slashes. Plain http LAN addresses are fine.
  static String normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.contains('://')) url = 'http://$url';
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Calls `/health` with values that may not be saved yet.
  Future<CompanionHealth> testConnection(String url, String token) {
    return _apiFactory(normalizeUrl(url), token.trim()).health();
  }

  Future<void> saveConfig(String url, String token) async {
    final next = IntegrationConfig(
      url: normalizeUrl(url),
      secret: token.trim(),
    );
    if (!next.isComplete) return;
    await _store.save(Integration.companion, next);
    if (_disposed) return;
    config = next;
    _api = _apiFactory(next.url, next.secret);
    configState = AddConfigState.ready;
    editingConfig = false;
    notifyListeners();
  }

  void setEditingConfig(bool value) {
    if (editingConfig == value) return;
    editingConfig = value;
    notifyListeners();
  }

  /// Asks the server what [url] is. Moves to [AddPhase.preview] or, on a
  /// rejected link, to [AddPhase.failed] with [error] set.
  Future<void> validate(String url) async {
    final api = _api;
    if (api == null) return;
    _url = url.trim();
    _force = false;
    _poll?.cancel();
    phase = AddPhase.validating;
    preview = null;
    job = null;
    error = null;
    notifyListeners();
    try {
      final result = await api.validate(_url!);
      if (_disposed) return;
      preview = result;
      phase = AddPhase.preview;
    } on CompanionException catch (e) {
      if (_disposed) return;
      error = e;
      phase = AddPhase.failed;
    }
    notifyListeners();
  }

  /// Starts the download for the previewed link. [force] goes ahead even if
  /// the file exists.
  Future<void> confirm({bool force = false}) async {
    final api = _api;
    final shown = preview;
    if (api == null || shown == null) return;
    _force = force || _force;
    phase = AddPhase.starting;
    error = null;
    notifyListeners();
    try {
      final id = await api.startDownload(shown.url, force: _force);
      if (_disposed) return;
      job = DownloadJob(id: id, status: JobStatus.queued);
      history.insert(
        0,
        AddHistoryEntry(
          id: id,
          label: '${shown.parsed.artist} - ${shown.parsed.title}',
          status: JobStatus.queued,
        ),
      );
      phase = AddPhase.downloading;
      notifyListeners();
      _startPolling(id);
    } on CompanionException catch (e) {
      if (_disposed) return;
      error = e;
      phase = AddPhase.failed;
      notifyListeners();
    }
  }

  void _startPolling(String id) {
    _poll?.cancel();
    _poll = Timer.periodic(pollInterval, (_) => _tick(id));
  }

  bool _ticking = false;

  Future<void> _tick(String id) async {
    final api = _api;
    if (api == null || _ticking) return;
    _ticking = true;
    try {
      final next = await api.job(id);
      if (_disposed) return;
      job = next;
      final entry = history.where((h) => h.id == id).firstOrNull;
      if (entry != null) {
        entry.status = next.status;
        entry.error = next.error;
        entry.warning = next.warning;
      }
      if (next.finished) {
        _poll?.cancel();
        phase = next.status == JobStatus.done ? AddPhase.done : AddPhase.failed;
        if (next.status == JobStatus.failed) {
          error = CompanionException(
            CompanionErrorKind.server,
            next.error ?? 'The download failed.',
          );
        }
      }
      notifyListeners();
    } on CompanionException catch (e) {
      // A dropped poll isn't a failed job: keep trying until it answers.
      debugPrint('Add: job poll failed: $e');
    } finally {
      _ticking = false;
    }
  }

  /// Tries the failed step again: the check if the link was rejected for a
  /// transient reason, otherwise the download.
  Future<void> retry() async {
    if (preview != null) {
      await confirm(force: _force);
    } else if (_url != null) {
      await validate(_url!);
    }
  }

  /// Back to an empty paste box.
  void reset() {
    _poll?.cancel();
    phase = AddPhase.idle;
    preview = null;
    job = null;
    error = null;
    _url = null;
    _force = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
