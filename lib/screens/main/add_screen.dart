import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/providers/add_provider.dart';
import 'package:musly/screens/main/main_screen.dart' show MainScreen;
import 'package:musly/services/companion_service.dart';
import 'package:musly/services/integration_config_store.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/widgets/new_tab/new_tab.dart'
    show kNewTabGutter, newTabUsesGlass;
import 'package:musly/widgets/widgets.dart';

/// The Add tab: paste a YouTube link, check it, and have the companion
/// service on the user's server turn it into an MP3 in the library.
///
/// Owns its [AddProvider] (nothing is registered app-wide). [apiFactory],
/// [store] and [pollInterval] exist for tests; by default the screen talks to
/// the real [CompanionService].
class AddScreen extends StatefulWidget {
  const AddScreen({super.key, this.apiFactory, this.store, this.pollInterval});

  final CompanionApiFactory? apiFactory;
  final IntegrationConfigStore? store;
  final Duration? pollInterval;

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  late final AddProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = AddProvider(
      store: widget.store ?? IntegrationConfigStore(),
      apiFactory: widget.apiFactory ??
          (url, token) => CompanionService(baseUrl: url, token: token),
      pollInterval: widget.pollInterval ?? const Duration(seconds: 1),
    )..load();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider<AddProvider>.value(
      value: _provider,
      child: Scaffold(
        backgroundColor:
            isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        body: const _AddBody(),
      ),
    );
  }
}

class _AddBody extends StatelessWidget {
  const _AddBody();

  @override
  Widget build(BuildContext context) {
    final add = context.watch<AddProvider>();
    final Widget content;
    switch (add.configState) {
      case AddConfigState.loading:
        content = const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        );
      case AddConfigState.notConfigured:
        content = const _SetupCard();
      case AddConfigState.ready:
        content = add.editingConfig ? const _SetupCard() : const _AddFlow();
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        const SliverToBoxAdapter(child: _Header()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kNewTabGutter),
            child: content,
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: MainScreen.scrollEndPadding(context, 40)),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final add = context.watch<AddProvider>();
    final showGear =
        add.configState == AddConfigState.ready && !add.editingConfig;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kNewTabGutter, 12, 4, 16),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  AppLocalizations.of(context)!.addTab,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ),
            if (showGear)
              IconButton(
                tooltip: 'Connection settings',
                icon: const Icon(CupertinoIcons.gear),
                onPressed: () => add.setEditingConfig(true),
              ),
          ],
        ),
      ),
    );
  }
}

Color _secondary(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSecondaryText
        : AppTheme.lightSecondaryText;

Color _cardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkCard
        : AppTheme.lightCard;

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}

// ---------------------------------------------------------------- setup ----

class _SetupCard extends StatefulWidget {
  const _SetupCard();

  @override
  State<_SetupCard> createState() => _SetupCardState();
}

class _SetupCardState extends State<_SetupCard> {
  late final TextEditingController _url;
  late final TextEditingController _token;
  bool _testing = false;
  String? _result;
  bool _resultOk = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<AddProvider>().config;
    _url = TextEditingController(text: config?.url ?? '');
    _token = TextEditingController(text: config?.secret ?? '');
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  bool get _filled =>
      _url.text.trim().isNotEmpty && _token.text.trim().isNotEmpty;

  Future<void> _test() async {
    final add = context.read<AddProvider>();
    setState(() {
      _testing = true;
      _result = null;
    });
    try {
      final health = await add.testConnection(_url.text, _token.text);
      if (!mounted) return;
      setState(() {
        _resultOk = true;
        _result = 'Connected. Service ${health.version}, '
            'yt-dlp ${health.ytDlpVersion}.';
      });
    } on CompanionException catch (e) {
      if (!mounted) return;
      setState(() {
        _resultOk = false;
        _result = e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final add = context.watch<AddProvider>();
    final configured = add.config != null;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            configured ? 'Connection' : 'Set up the Add tab',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the address and token of the companion service running '
            'next to your music server. They are stored securely on this '
            'device.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: _secondary(context)),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('add-url-field'),
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _result = null),
            decoration: const InputDecoration(
              labelText: 'Companion address',
              hintText: 'http://192.168.1.10:8787',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('add-token-field'),
            controller: _token,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _result = null),
            decoration: const InputDecoration(
              labelText: 'Token',
              border: OutlineInputBorder(),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _resultOk
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.exclamationmark_circle_fill,
                  size: 18,
                  color: _resultOk ? AppTheme.brandGreen : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_result!, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                key: const Key('add-test-button'),
                onPressed: _filled && !_testing ? _test : null,
                child: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Test connection'),
              ),
              FilledButton(
                key: const Key('add-save-button'),
                onPressed: _filled
                    ? () => add.saveConfig(_url.text, _token.text)
                    : null,
                child: const Text('Save'),
              ),
              if (configured)
                TextButton(
                  onPressed: () => add.setEditingConfig(false),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- flow ----

class _AddFlow extends StatelessWidget {
  const _AddFlow();

  @override
  Widget build(BuildContext context) {
    final add = context.watch<AddProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PasteCard(busy: add.phase == AddPhase.validating),
        const SizedBox(height: 16),
        switch (add.phase) {
          AddPhase.idle => const _EmptyHint(),
          AddPhase.validating => const _Checking(),
          AddPhase.preview ||
          AddPhase.starting =>
            _PreviewCard(preview: add.preview!, starting: add.phase == AddPhase.starting),
          AddPhase.downloading => _ProgressCard(job: add.job),
          AddPhase.done => const _DoneCard(),
          AddPhase.failed => const _ErrorCard(),
        },
        if (add.history.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SessionList(),
        ],
      ],
    );
  }
}

class _PasteCard extends StatefulWidget {
  const _PasteCard({required this.busy});

  final bool busy;

  @override
  State<_PasteCard> createState() => _PasteCardState();
}

class _PasteCardState extends State<_PasteCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() => _controller.text = text);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.busy) return;
    FocusScope.of(context).unfocus();
    context.read<AddProvider>().validate(text);
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('add-link-field'),
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.go,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Paste a YouTube link',
              border: const OutlineInputBorder(),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(CupertinoIcons.clear_circled_solid),
                      onPressed: () => setState(_controller.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: const Key('add-paste-button'),
                onPressed: _paste,
                icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 18),
                label: const Text('Paste from clipboard'),
              ),
              FilledButton(
                key: const Key('add-check-button'),
                onPressed:
                    _controller.text.trim().isEmpty || widget.busy ? null : _submit,
                child: const Text('Check'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final secondary = _secondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Icon(CupertinoIcons.dot_radiowaves_left_right,
              size: 40, color: secondary),
          const SizedBox(height: 12),
          Text(
            'Paste a link to a single YouTube video. You\'ll see how it will '
            'be filed before anything is downloaded.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
}

String _formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview, required this.starting});

  final VideoPreview preview;
  final bool starting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = newTabUsesGlass(context);
    final exists = preview.alreadyExists;
    final label = exists ? 'Add anyway' : 'Add to library';
    final add = context.read<AddProvider>();

    final confirm = starting
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null;

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Thumbnail(url: preview.thumbnailUrl),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    // Glass only here: the thumbnail is what it refracts.
                    child: glass
                        ? GlassContainer.capsule(
                            key: const Key('add-confirm'),
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            onTap: starting ? null : () => add.confirm(force: exists),
                            child: confirm ??
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${preview.channel} · ${_formatDuration(preview.durationSeconds)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: _secondary(context)),
                ),
                const SizedBox(height: 14),
                _TagRow(label: 'Artist', value: preview.parsed.artist),
                _TagRow(label: 'Song', value: preview.parsed.title),
                _TagRow(label: 'Album', value: preview.parsed.album),
                if (exists) ...[
                  const SizedBox(height: 12),
                  Row(
                    key: const Key('add-exists-warning'),
                    children: [
                      Icon(CupertinoIcons.exclamationmark_triangle_fill,
                          size: 18, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Already in your library. Adding again '
                            'replaces that file.'),
                      ),
                    ],
                  ),
                ],
                if (!glass) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('add-confirm'),
                    onPressed: starting ? null : () => add.confirm(force: exists),
                    child: confirm ?? Text(label),
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: starting ? null : add.reset,
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.45)],
        ),
      ),
      child: const Center(
        child: Icon(CupertinoIcons.music_note_2, size: 48, color: Colors.white70),
      ),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: _secondary(context)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(JobStatus s) => switch (s) {
      JobStatus.queued => 'Waiting in line',
      JobStatus.downloading => 'Downloading',
      JobStatus.converting => 'Converting to MP3',
      JobStatus.tagging => 'Adding tags and cover',
      JobStatus.done => 'Added',
      JobStatus.failed => 'Failed',
    };

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.job});

  final DownloadJob? job;

  @override
  Widget build(BuildContext context) {
    final status = job?.status ?? JobStatus.queued;
    final progress = job?.progress ?? 0;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLabel(status),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const Key('add-progress'),
              minHeight: 6,
              value: status == JobStatus.queued ? null : progress,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard();

  @override
  Widget build(BuildContext context) {
    final add = context.read<AddProvider>();
    final job = add.job;
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_circle_fill,
                  color: AppTheme.brandGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added to your library',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (job?.file != null) ...[
            const SizedBox(height: 8),
            Text(job!.file!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: _secondary(context))),
          ],
          if (job?.warning != null) ...[
            const SizedBox(height: 8),
            Text(job!.warning!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.orange.shade700)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('add-another'),
            onPressed: add.reset,
            child: const Text('Add another'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();

  @override
  Widget build(BuildContext context) {
    final add = context.read<AddProvider>();
    final theme = Theme.of(context);
    final error = add.error;
    final canRetry = error == null || error.retryable;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.exclamationmark_triangle_fill,
                  color: theme.colorScheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error?.message ?? 'Something went wrong.',
                  key: const Key('add-error-message'),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (canRetry)
                FilledButton(
                  key: const Key('add-retry'),
                  onPressed: add.retry,
                  child: const Text('Retry'),
                ),
              if (canRetry) const SizedBox(width: 10),
              TextButton(
                onPressed: add.reset,
                child: const Text('Start over'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList();

  @override
  Widget build(BuildContext context) {
    final add = context.watch<AddProvider>();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This session',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final entry in add.history.take(10))
                _HistoryRow(entry: entry),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final AddHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = entry.status == JobStatus.failed;
    final done = entry.status == JobStatus.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (done)
            const Icon(CupertinoIcons.checkmark_circle_fill,
                size: 20, color: AppTheme.brandGreen)
          else if (failed)
            Icon(CupertinoIcons.xmark_circle_fill,
                size: 20, color: theme.colorScheme.error)
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  failed && entry.error != null
                      ? entry.error!
                      : _statusLabel(entry.status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: _secondary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
