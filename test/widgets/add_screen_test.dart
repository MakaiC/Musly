import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/providers/add_provider.dart';
import 'package:musly/screens/main/add_screen.dart';
import 'package:musly/services/companion_service.dart';
import 'package:musly/services/integration_config_store.dart';
import 'package:musly/services/services.dart';
import 'package:musly/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bootstrap.dart';

const _link = 'https://www.youtube.com/watch?v=abc123';

Future<void> _pump(
  WidgetTester tester, {
  required IntegrationConfigStore store,
  CompanionApiFactory? factory,
  bool glass = false,
}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final theme = ThemeService();
  if (glass) await theme.setLiquidGlass(true);
  await tester.pumpWidget(ChangeNotifierProvider<ThemeService>.value(
    value: theme,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AddScreen(
        store: store,
        apiFactory: factory ??
            (url, token) => MockCompanionService(step: Duration.zero, clientToken: token),
        pollInterval: const Duration(milliseconds: 100),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<IntegrationConfigStore> _configured() async {
  final store = IntegrationConfigStore();
  await store.save(Integration.companion,
      const IntegrationConfig(url: 'http://192.168.1.10:8787', secret: 'demo'));
  return store;
}

Future<void> _check(WidgetTester tester, String link) async {
  await tester.enterText(find.byKey(const Key('add-link-field')), link);
  await tester.pump();
  await tester.tap(find.byKey(const Key('add-check-button')));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  initializeTestEnvironment();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('IntegrationConfigStore', () {
    test('round-trips per integration and clears', () async {
      final store = IntegrationConfigStore();
      expect(await store.load(Integration.companion), isNull);
      await store.save(Integration.companion,
          const IntegrationConfig(url: 'http://a', secret: 's1'));
      await store.save(Integration.lidarr,
          const IntegrationConfig(url: 'http://b', secret: 's2'));
      expect((await store.load(Integration.companion))!.secret, 's1');
      expect((await store.load(Integration.lidarr))!.url, 'http://b');
      await store.clear(Integration.companion);
      expect(await store.load(Integration.companion), isNull);
      expect(await store.load(Integration.lidarr), isNotNull);
    });

    test('falls back to obfuscated preferences when secure storage throws',
        () async {
      final store = IntegrationConfigStore(secureStorage: const _BrokenSecureStorage());
      await store.save(Integration.companion,
          const IntegrationConfig(url: 'http://a', secret: 'topsecret'));
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('fallback_integration_companion_secret')!;
      expect(stored, isNot(contains('topsecret')));
      final loaded = await store.load(Integration.companion);
      expect(loaded!.secret, 'topsecret');
    });
  });

  test('normalizeUrl adds http and trims slashes', () {
    expect(AddProvider.normalizeUrl(' 192.168.1.10:8787/ '),
        'http://192.168.1.10:8787');
    expect(AddProvider.normalizeUrl('https://x.example//'), 'https://x.example');
  });

  group('Add screen', () {
    testWidgets('loading, then the setup card when not configured',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddScreen(
          store: IntegrationConfigStore(),
          apiFactory: (_, __) => MockCompanionService(step: Duration.zero),
        ),
      ));
      // Before the saved config has loaded.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('add-url-field')), findsOneWidget);
      expect(find.byKey(const Key('add-link-field')), findsNothing);
      // Save stays disabled until both fields are filled.
      FilledButton save() =>
          tester.widget(find.byKey(const Key('add-save-button')));
      expect(save().onPressed, isNull);
    });

    testWidgets('test connection reports success and failure', (tester) async {
      await _pump(tester, store: IntegrationConfigStore());
      await tester.enterText(
          find.byKey(const Key('add-url-field')), '192.168.1.10:8787');
      await tester.enterText(find.byKey(const Key('add-token-field')), 'wrong');
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-test-button')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Connected'), findsNothing);

      await tester.enterText(find.byKey(const Key('add-token-field')), 'demo');
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-test-button')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Connected. Service 0.1.0-mock'),
          findsOneWidget);
    });

    testWidgets('a failed test shows the error kind', (tester) async {
      await _pump(
        tester,
        store: IntegrationConfigStore(),
        factory: (_, __) => _Failing(const CompanionException(
            CompanionErrorKind.unauthorized, 'The token was rejected.')),
      );
      await tester.enterText(find.byKey(const Key('add-url-field')), 'x');
      await tester.enterText(find.byKey(const Key('add-token-field')), 'y');
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-test-button')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('The token was rejected.'), findsOneWidget);
    });

    testWidgets('saving stores the config and shows the paste box',
        (tester) async {
      final store = IntegrationConfigStore();
      await _pump(tester, store: store);
      await tester.enterText(
          find.byKey(const Key('add-url-field')), '192.168.1.10:8787/');
      await tester.enterText(find.byKey(const Key('add-token-field')), ' demo ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-save-button')));
      await tester.pump(const Duration(milliseconds: 50));
      final saved = await store.load(Integration.companion);
      expect(saved!.url, 'http://192.168.1.10:8787');
      expect(saved.secret, 'demo');
      expect(find.byKey(const Key('add-link-field')), findsOneWidget);
    });

    testWidgets('empty state, and the gear reopens the setup card prefilled',
        (tester) async {
      await _pump(tester, store: await _configured());
      expect(find.textContaining('Paste a link to a single YouTube video'),
          findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.gear));
      await tester.pump();
      final field = tester.widget<TextField>(find.byKey(const Key('add-url-field')));
      expect(field.controller!.text, 'http://192.168.1.10:8787');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.byKey(const Key('add-link-field')), findsOneWidget);
    });

    testWidgets('paste from clipboard fills the box', (tester) async {
      await _pump(tester, store: await _configured());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': _link};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.tap(find.byKey(const Key('add-paste-button')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
          tester
              .widget<TextField>(find.byKey(const Key('add-link-field')))
              .controller!
              .text,
          _link);
    });

    testWidgets('a rejected link shows a clear error with no Retry',
        (tester) async {
      await _pump(tester, store: await _configured());
      await _check(tester, 'https://example.com/video');
      expect(find.byKey(const Key('add-error-message')), findsOneWidget);
      expect(find.text('That isn\'t a YouTube link.'), findsOneWidget);
      expect(find.byKey(const Key('add-retry')), findsNothing);
      await tester.tap(find.text('Start over'));
      await tester.pump();
      expect(find.byKey(const Key('add-error-message')), findsNothing);
    });

    testWidgets('a playlist is refused', (tester) async {
      await _pump(tester, store: await _configured());
      await _check(tester, 'https://www.youtube.com/playlist?list=PL1');
      expect(
          tester.widget<Text>(find.byKey(const Key('add-error-message'))).data,
          contains('playlist'));
    });

    testWidgets('preview shows the parsed tags, then progress, then done, and '
        'logs the session', (tester) async {
      await _pump(tester, store: await _configured());
      await _check(tester, _link);

      expect(find.text('IMGEEKED, IM HIGH, IM FCKED UP'), findsNWidgets(2),
          reason: 'song and album');
      expect(find.text('Cochise & Pradabagshawty'), findsOneWidget);
      expect(find.text('3:07'), findsNothing);
      expect(find.textContaining('3:07'), findsOneWidget);
      expect(find.byKey(const Key('add-exists-warning')), findsNothing);

      await tester.tap(find.byKey(const Key('add-confirm')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('add-progress')), findsOneWidget);

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Added to your library'), findsOneWidget);
      expect(find.text('This session'), findsOneWidget);
      expect(find.textContaining('IMGEEKED'), findsWidgets);

      await tester.tap(find.byKey(const Key('add-another')));
      await tester.pump();
      expect(find.byKey(const Key('add-link-field')), findsOneWidget);
      // The session list survives.
      expect(find.text('This session'), findsOneWidget);
    });

    testWidgets('an existing file warns and offers Add anyway', (tester) async {
      await _pump(tester, store: await _configured());
      await _check(tester, '$_link&exists=1');
      expect(find.byKey(const Key('add-exists-warning')), findsOneWidget);
      expect(find.text('Add anyway'), findsOneWidget);

      // "Add anyway" must send force, or the server answers 409.
      await tester.ensureVisible(find.byKey(const Key('add-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-confirm')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('add-progress')), findsOneWidget);
      expect(find.byKey(const Key('add-error-message')), findsNothing);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Added to your library'), findsOneWidget);
    });

    testWidgets('a failed job shows its error and Retry', (tester) async {
      await _pump(tester, store: await _configured());
      await _check(tester, '$_link&fail=1');
      await tester.tap(find.byKey(const Key('add-confirm')));
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('yt-dlp could not download this video.'), findsWidgets);
      expect(find.byKey(const Key('add-retry')), findsOneWidget);
    });

    testWidgets('an unreachable server while checking offers Retry',
        (tester) async {
      var fail = true;
      await _pump(
        tester,
        store: await _configured(),
        factory: (_, __) => _Failing(
          const CompanionException(
              CompanionErrorKind.unreachable, 'Can\'t reach the server.'),
          failWhile: () => fail,
        ),
      );
      await _check(tester, _link);
      expect(find.text('Can\'t reach the server.'), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const Key('add-retry')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('add-confirm')), findsOneWidget);
    });

    testWidgets('glass mode puts the confirm pill over the thumbnail only',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _pump(tester, store: await _configured(), glass: true);
      await _check(tester, _link);
      final pill = find.byKey(const Key('add-confirm'));
      expect(tester.widget(pill), isA<GlassContainer>());
      // Inside the 16:9 thumbnail, and no glass anywhere else on the page.
      final thumb = tester.getRect(find.byType(AspectRatio).first);
      expect(thumb.contains(tester.getCenter(pill)), isTrue);
      expect(find.byType(GlassContainer), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);

      // The label is centred in the pill, both ways.
      // A label stretched to the pill's full 44pt height draws its glyphs at
      // the top of that box, so its box must be text-sized, not pill-sized.
      final label = tester.getRect(find.text('Add to library'));
      final pillCentre = tester.getCenter(pill);
      expect(label.height, lessThan(30));
      expect(label.center.dx, closeTo(pillCentre.dx, 0.5));
      expect(label.center.dy, closeTo(pillCentre.dy, 0.5));
    });

    testWidgets('the glass pill\'s spinner is a circle, centred',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final hold = Completer<void>();
      await _pump(
        tester,
        store: await _configured(),
        glass: true,
        factory: (_, __) => _Slow(hold.future),
      );
      await _check(tester, _link);
      await tester.tap(find.byKey(const Key('add-confirm')));
      await tester.pump(const Duration(milliseconds: 50));

      final spinner = find.descendant(
          of: find.byKey(const Key('add-confirm')),
          matching: find.byType(CircularProgressIndicator));
      final size = tester.getSize(spinner);
      expect(size.width, size.height, reason: 'a circle, not an oval');
      final c = tester.getCenter(spinner);
      final pill = tester.getCenter(find.byKey(const Key('add-confirm')));
      expect(c.dx, closeTo(pill.dx, 0.5));
      expect(c.dy, closeTo(pill.dy, 0.5));
      hold.complete();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('classic mode uses a themed filled button', (tester) async {
      await _pump(tester, store: await _configured());
      await _check(tester, _link);
      expect(tester.widget(find.byKey(const Key('add-confirm'))), isA<FilledButton>());
      expect(find.byType(GlassContainer), findsNothing);
    });
  });
}

class _BrokenSecureStorage extends FlutterSecureStorage {
  const _BrokenSecureStorage();

  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) =>
      throw PlatformException(code: 'unavailable');
  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) =>
      throw PlatformException(code: 'unavailable');
  @override
  Future<void> delete({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) =>
      throw PlatformException(code: 'unavailable');
}

class _Failing implements CompanionApi {
  _Failing(this.error, {this.failWhile});

  final CompanionException error;
  final bool Function()? failWhile;
  final _ok = MockCompanionService(step: Duration.zero, clientToken: 'demo');

  bool get _fail => failWhile?.call() ?? true;

  @override
  Future<CompanionHealth> health() async => _fail ? throw error : _ok.health();
  @override
  Future<VideoPreview> validate(String url) async =>
      _fail ? throw error : _ok.validate(url);
  @override
  Future<String> startDownload(String url, {bool force = false}) =>
      _ok.startDownload(url, force: force);
  @override
  Future<DownloadJob> job(String id) => _ok.job(id);
}

/// Validates at once but holds the download start until [gate] completes.
class _Slow implements CompanionApi {
  _Slow(this.gate);

  final Future<void> gate;
  final _ok = MockCompanionService(step: Duration.zero, clientToken: 'demo');

  @override
  Future<CompanionHealth> health() => _ok.health();
  @override
  Future<VideoPreview> validate(String url) => _ok.validate(url);
  @override
  Future<String> startDownload(String url, {bool force = false}) async {
    await gate;
    return _ok.startDownload(url, force: force);
  }

  @override
  Future<DownloadJob> job(String id) => _ok.job(id);
}
