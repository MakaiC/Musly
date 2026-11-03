import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/providers/auth_provider.dart';
import 'package:musly/screens/main/main_screen.dart' show MainScreen;
import 'package:musly/theme/app_theme.dart';
import 'package:musly/widgets/new_tab/new_tab.dart';

/// The New tab, loosely modelled on Apple Music's: a vertically scrolling
/// page of discovery sections built only from what the Subsonic/Navidrome
/// API already offers.
///
/// Every section is a self-contained widget in `lib/widgets/new_tab/` that
/// fetches its own data and handles its own loading, empty and error states.
/// To drop one, delete its line from [_sections].
class NewScreen extends StatefulWidget {
  const NewScreen({super.key});

  @override
  State<NewScreen> createState() => _NewScreenState();
}

class _NewScreenState extends State<NewScreen> {
  final _refresh = NewTabRefreshRegistry();

  static const List<Widget> _sections = [
    FeaturedHeroCarousel(),
    FreshFromArtistsSection(),
    RediscoverSection(),
    // Skips the albums the carousel already features; use 0 without it.
    RecentlyAddedSection(skip: FeaturedHeroCarousel.albumCount),
    MixForYouSection(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final needsServer =
        auth.isLocalOnlyMode || auth.state == AuthState.offlineMode;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: NewTabRefreshScope(
        registry: _refresh,
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: _refresh.refreshAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(child: _LargeTitle()),
              if (needsServer)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NeedsServer(),
                )
              else
                SliverList.separated(
                  itemCount: _sections.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: kNewSectionGap),
                  itemBuilder: (_, i) => _sections[i],
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MainScreen.scrollEndPadding(context, 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS-style large page title.
class _LargeTitle extends StatelessWidget {
  const _LargeTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kNewTabGutter, 12, kNewTabGutter, 16),
        child: Semantics(
          header: true,
          child: Text(
            AppLocalizations.of(context)!.newTab,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the sections in offline and local-files mode: every
/// section needs the server.
class _NeedsServer extends StatelessWidget {
  const _NeedsServer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.wifi_slash, size: 44, color: secondary),
          const SizedBox(height: 14),
          Text(
            'New needs your server',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect to your music server to see what\'s new, '
            'rediscover old favourites and get a fresh mix.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}
