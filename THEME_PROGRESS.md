# Liquid Glass theme: progress & handoff

Last updated 2026-11-02 (now-playing open/close transition + Navinix rename and icons, branch `player-anim`, merged into `master`); before that 2026-11-02 (collapsing bottom chrome, branch `collapsed-nav`, merged with the New tab); 2026-11-02 (New tab, branch `new-tab`); 2026-11-02 (sliders, branch `slider-work`); 2026-11-03 · branch `claude/sleepy-gates-rm92oh` (continues `claude/brave-bohr-80alrl`) · Flutter **3.47.7** (pinned in CI)

## Status at a glance

| Item | State |
|---|---|
| 1. Mini-player | ✅ Built, plus a polish pass after the user's first look: proportions, clearer centre, frosted rim, stronger refraction. The user approved it from renders and asked to move on. |
| Floating-chrome layout + page scroll padding | ✅ Built (groundwork for steps 1 and 2) |
| iOS UIScene lifecycle migration | ✅ Done. **Not yet compiled in Xcode**; the first build is the check |
| 2. Bottom navigation bar | 🔶 **In progress (the user's call, 2026-11-03).** `GlassTabBar` is built and committed (`c48b696`); the open work isn't written down yet. Ask the user. The iPhone Duo side placement below is likely part of it. |
| 3. Now-playing full-screen view | ⬜ **Not started (the user's call, 2026-11-03).** A first glass pass *is* committed (`5000ad8`) and was shown as renders, but the user hasn't accepted it. **Ask whether to iterate on it or redo it** before touching that code. |
| 4. Library grid (album/artist cards) | ⬜ Not started |
| 5. New tab | 🔶 **First version built (branch `new-tab`, 2026-11-02), awaiting the user's review.** Five removable sections; **the user is choosing which to keep** (see "New tab" under "What's built"). Not committed yet. |

**Statuses are the user's.** Where the branch has more code than the status suggests, the status wins: treat that code as an unaccepted draft.

The user has been building to their iPhone; see the iPhone Duo box below.

## Liquid Glass checklist: every screen and menu

Audited from `lib/screens/**` and the sheets, dialogs and menus they open (2026-11-03).
- `[x]` done, `[~]` in progress or a draft exists, `[ ]` not started, 🚫 out of scope under the current ground rules (needs the user's OK).
- "Glass" means the glass-mode branch only; classic must stay unchanged.

**Core chrome and player (the user's priority order)**
- [x] Mini-player: `lib/widgets/navigation/mini_player.dart`
- [~] Bottom nav / tab bar: `lib/widgets/navigation/glass_tab_bar.dart`, wired in `main_screen.dart`'s `_buildGlassBottomNav`. Built; the user marks it in progress.
- [~] Collapsing chrome on scroll: `main_screen.dart` (`_buildCollapsibleChrome`) + `GlassTabBar.collapse` + `MiniPlayer.collapse` + `lib/widgets/navigation/glass_collapsed_bar.dart`. Second version (one continuous morph) built 2026-11-02 after the user's feedback; waiting on their look. See "Collapsing chrome" below.
- [ ] Now-playing: `lib/screens/player/now_playing_screen.dart` + `lib/widgets/now_playing/*`. The user marks it not started; an unaccepted draft is in `5000ad8`. The open/close animation (branch `player-anim`, see "Now-playing open/close transition") was added on top at the user's request, without changing the layout or controls.
- [ ] Library grid: the cards in `lib/widgets/cards/` (`album_card`, `artist_card`, `media_card`) and the grid in `lib/screens/main/library_screen.dart`
- [~] New tab: `lib/screens/main/new_screen.dart` + `lib/widgets/new_tab/*`. Built, awaiting the user's pick of sections (see "New tab" below).
  - `MainScreen` now has 4 tabs: Home, **New**, Library, Search (Apple Music's order). Indices live in `MainTabs` (`lib/screens/main/main_tabs.dart`); **don't use bare numbers**. The Search easter egg now checks `MainTabs.search` (3).

**Main tabs (pages under the chrome)**
- [ ] Home: `lib/screens/main/home_screen.dart`, with `quick_access_tile`, `media_card` and the favourite-playlists row (`widgets/navigation/favorite_playlists_section.dart`)
- [ ] Library page chrome: header, filters, `lib/screens/main/library_screen.dart` (separate from the grid cards above)
- [ ] Search: `lib/screens/main/search_screen.dart`, with `top_result_card` and `browse_category_card`
- [ ] Library search (`showSearch`): `lib/screens/main/library_search_delegate.dart`

**Detail pages**
- [ ] Album: `lib/screens/detail/album_screen.dart` (+ its ⋯ popup menu and a confirm dialog)
- [ ] Artist: `lib/screens/detail/artist_screen.dart`
- [ ] Genre: `lib/screens/detail/genre_screen.dart`
- [ ] Playlist: `lib/screens/detail/playlist_screen.dart` (+ its ⋯ popup menu and 2 dialogs)

**Media pages (from Library/Home)**
- [ ] Album collection: `lib/screens/media/album_collection_screen.dart` (incl. its A–Z index bar)
- [ ] Song collection: `lib/screens/media/song_collection_screen.dart` (+ sort popup menu)
- [ ] Playlists: `lib/screens/media/playlists_screen.dart` (+ dialog)
- [ ] Favorites: `lib/screens/media/favorites_screen.dart` (uses `PillTabBar`; + dialog)
- [ ] Downloads: `lib/screens/media/downloads_screen.dart` (uses `PillTabBar`)
- [ ] Download playlist status: `lib/screens/media/download_playlist_status_screen.dart`
- [ ] Genres: `lib/screens/media/genres_screen.dart`
- [ ] Radio: `lib/screens/media/radio_screen.dart` (+ station options sheet)
- [ ] Jukebox: `lib/screens/media/jukebox_screen.dart`
- [ ] `PillTabBar` (`lib/widgets/common/pill_tab_bar.dart`): a natural candidate for the `GlassTabBar` bubble treatment
- [ ] Wrapped: `lib/screens/wrapped/wrapped_screen.dart`
- [ ] Fantasy (Search easter egg): `lib/screens/media/fantasy_screen.dart`

**Now-playing sub-pages and its menus** (they ride on the now-playing work)
- [ ] Lyrics page: `lib/screens/player/lyrics_screen.dart` + `lib/widgets/lyrics/*`
- [ ] Queue page: `lib/widgets/now_playing/queue_view.dart`
- [ ] ⋯ more menu sheet: `lib/widgets/now_playing/now_playing_more_menu.dart`
- [ ] Add-to menu and the playlist picker sheet: `lib/widgets/now_playing/add_to_menu.dart`
- [x] Progress and volume sliders: `lib/widgets/now_playing/playback_progress_slider.dart`, `volume_slider.dart`. Both now use the shared thumb-less `ThickBarSlider` (see "Sliders" below). **Applies in classic and glass mode** (and the TV scrubber), per the user's request.

**Sheets and menus (app-wide)**
- [ ] Song options (long-press a song): `lib/widgets/modals/song_options_modal.dart`
- [ ] Playlist options: `lib/widgets/modals/playlist_options_modal.dart`
- [ ] Server switcher: `lib/widgets/modals/server_switcher_sheet.dart`
- [ ] Connect devices / cast picker: `lib/screens/connect/connect_devices_modal.dart` (+ its dialog) and `lib/widgets/navigation/cast_button.dart` (2 dialogs)
- [ ] Multi-artist picker: `ArtistsBottomSheet` in `lib/widgets/common/multi_artist_widget.dart`
- [ ] Library add menu and sort menu sheets (`_showAddMenu`, `_showSortMenu` in `library_screen.dart`, + a dialog)
- [ ] Switch-profile sheet in `lib/main.dart` (`_showSwitchProfileDialog`)
- Note: sheets on the inner navigator already make the floating chrome slide away (`_SheetOnTopObserver`).
- A glass sheet would want `GlassStyle.frosted` (text-dense).
- Don't fade glass with `Opacity` (see the gotchas).

**Dialogs**
- [ ] Import playlist: `lib/widgets/dialogs/import_playlist_dialog.dart`
- [ ] Milestone celebration: `lib/widgets/dialogs/milestone_celebration_dialog.dart`
- [ ] Privacy policy: `lib/widgets/dialogs/privacy_policy_dialog.dart` (shown from `main.dart`)
- [ ] Support: `lib/widgets/dialogs/support_dialog.dart` (also from `usage_time_service.dart`)
- [ ] Update: `lib/widgets/dialogs/update_dialog.dart`
- [ ] Inline `AlertDialog`s in the album, playlist, playlists, favorites and library screens (confirmations, create playlist)

**Settings**: 🚫 the ground rules say don't touch settings screens; only the scroll-padding fix was approved
- 🚫 Settings shell: `lib/screens/settings/settings_screen.dart`
- 🚫 Tabs: `settings_display_tab`, `settings_playback_tab`, `settings_server_tab`, `settings_storage_tab`, `settings_android_auto_tab`, `settings_about_tab`, `settings_support_tab` (all in `lib/screens/settings/`)
- 🚫 Their sheets and dialogs: display (language picker sheet + dialog), server (2 dialogs), storage (4 dialogs), about (2 dialogs)
- 🚫 Shared settings widgets: `lib/widgets/settings/*`

**Auth and onboarding**: 🚫 the ground rules say don't touch auth/login
- 🚫 Login: `lib/screens/auth/login_screen.dart`
- 🚫 Add server: `lib/screens/auth/add_server_screen.dart`
- 🚫 Onboarding: `lib/screens/onboarding/onboarding_screen.dart` (not auth strictly, but part of first run; confirm with the user)

**Other layouts**: not in scope so far (glass is phone-layout only)
- Tablet/desktop (`_isLargeScreen`): `desktop_navigation_sidebar`, `desktop_player_bar`, `right_sidebar` and `desktop_lyrics_panel` in `lib/widgets/navigation/`. **Possibly relevant to iPhone Duo**; see below.
- TV: `lib/screens/main/tv_main_screen.dart`, `lib/screens/player/tv_now_playing_screen.dart`, `lib/widgets/navigation/tv_navigation_sidebar.dart`.

## iPhone Duo support

> **Status: 🔴 Not supported yet. Open design question.**
>
> **What the user sees (2026-11-03):** the layout looks off-centre on iPhone Duo.
>
> **Decided (minimum):** the nav bar has to move **to the side** on iPhone Duo.
>
> **Undecided:** where the mini-player goes, and how the other planned glass work (now-playing, library grid, New tab) should adapt.
>
> **Unknown:** the device's logical screen size in each posture. Get `MediaQuery.sizeOf(context)` (and the safe-area padding) on device first; it decides which layout branch the app takes.
>
> **Relevant code facts (no changes made):**
> - `MainScreen._isLargeScreen` (`lib/screens/main/main_screen.dart`) is `width >= 650 || shortestSide >= 600`.
>   - **Below that:** the phone layout, with the floating glass chrome (mini-player + `GlassTabBar`, full width minus 12pt margins).
>   - **At or above it:** the large-screen layout, with `DesktopNavigationSidebar` + `DesktopPlayerBar`, no glass and no mini-player.
>   - So a size just under the breakpoint stretches the phone chrome across a wide screen. That's a plausible cause of the off-centre look; unverified.
> - `ScreenHelper.isDesktop` is `width >= 800`; the mini-player hides only on desktop OSes at that width.
> - Glass currently applies **only** to the phone layout.
>
> **Options to discuss with the user** (none chosen):
> - **(a)** A dedicated "wide phone" layout for iPhone Duo: a glass side rail (`GlassTabBar` would need a vertical orientation) plus the mini-player docked bottom-leading or at the foot of the rail.
> - **(b)** Route iPhone Duo to the large-screen layout and bring glass to the desktop sidebar/player bar.
> - **(c)** Keep the bottom chrome but cap its width and pin it to one side.
>
> Whatever's chosen, `MainScreen.floatingChromeOverlap`/`scrollEndPadding` assume the chrome sits at the **bottom**. A side rail needs a leading/trailing inset for pages instead.

## New tab: Add Music (planned feature, not started)

The user wants **a new tab in the bottom row for adding new music**. This is a functional feature (new services, new credentials, a server-side helper), not a restyle. Notes below are the user's requirements, kept in full, plus what the audit found. Marked *(user)* = requested, *(suggested)* = mine, to confirm.

### Requirements *(user)*

The tab has three parts:

1. **Lidarr request UI.** Lidarr has its own REST API, separate from Navidrome's Subsonic API.
   - A new screen and service in Musly calls Lidarr directly: **search for an artist or album, show results, and let the user trigger a "monitor and grab" request.**
   - Musly would then hold **two sets of credentials/endpoints**: Navidrome's Subsonic API (library and playback, already working) and Lidarr's API (new, for search and request).
   - It's the same idea as Overseerr/Ombi for Sonarr/Radarr: a friendly request UI in front of the arr app. The user's research found **no prebuilt equivalent for Lidarr** (the user's note; I haven't verified it), so this is custom work.
2. **YouTube link to MP3 via yt-dlp.** (The user wrote "yt-dip"; I'm reading it as yt-dlp. **Confirm.**)
   - The user pastes a YouTube link into a text box.
   - **The server** receives the request, **determines whether the link is valid**, then **downloads it as an `.mp3`**.
3. **Further features on the YouTube component, "like" custom albums.** The user's example: **creating custom albums that are generated automatically and sorted automatically** for the different songs they get through the YouTube feature. "Other features like" this are expected, but only this one was described, so **ask what else**.

The user's notes also ended with an empty bullet, so more may be coming.

### Findings from the codebase audit

- **Musly's existing yt-dlp code can't do part 2.** `lib/services/ytdlp_service.dart` is for streaming, search and metadata of the YouTube Music source:
  - It runs a local `yt-dlp` binary on desktop and a `MethodChannel` (`com.devid.musly/ytdlp`) on Android.
  - **On iOS, `resolveStreamInfo` throws `UnsupportedError('YT Stream is disabled on iOS')`.** The user is on an iPhone, and iOS can't run yt-dlp or ffmpeg anyway.
  - So **downloading and converting to MP3 has to happen on the server**, as the user described. That means a **companion service on the user's server** (it runs yt-dlp + ffmpeg, validates the URL, writes the MP3 into the Navidrome music folder, and triggers a rescan). **Musly has no such service today, and it isn't in this repo.**
- **Credentials.** `StorageService` keeps server profiles in `shared_preferences` and passwords in `flutter_secure_storage` (via `_safeSecureRead`/`_safeSecureWrite`, with a fallback).
  - `ServerConfig` (with `serverFamily`: subsonic, jellyfin, youtube, local) drives library and playback.
  - Lidarr and the downloader should be a **separate "integration config"**, not new `ServerConfig` families, and the API keys belong in secure storage.
  - `ServerConfig` already models a LAN URL, self-signed certificates and client certificates. The same options are worth offering for these endpoints.
- **iOS networking is already fine.** `Info.plist` sets `NSAllowsArbitraryLoads` and has a local-network usage description, so plain-HTTP LAN endpoints (Lidarr is often `http://host:8686`) work without platform config changes.
- **No rescan call exists.** `SubsonicService` has no `startScan`/`getScanStatus`. After Lidarr imports a download or the companion writes an MP3, the new music needs a Navidrome rescan to show up. Either the companion does it (preferred, since it doesn't touch the Subsonic client), or the client gets a small addition.
- **Playlists exist, albums don't (yet).** Musly can already create and update playlists through the Subsonic API (`createPlaylist`/`updatePlaylist`). Navidrome builds **albums from file tags**, so a custom *album* means the companion writes the album/albumartist tags (and probably the folder layout); a custom *playlist* is only a list.
- **Tab bar.** `GlassTabBar` takes a list of items, so a 4th tab is easy. At 393pt each tab would be ~90pt wide.
  - **The Search easter egg is hard-coded to index 2** (`_onGlassTabSelected` and the classic `_buildBottomNav`). Putting the tab before Search breaks it.
  - Other places that list the tabs: `_screens`, `_buildBottomNav`, `DesktopNavigationSidebar`, and an l10n label (`l10n.yaml`/arb, Crowdin).

### Suggested shape *(suggested)*

- **Request flow (Lidarr):**
  - Search artist/album, with results showing cover, name and whether it's already in the library.
  - A "Request" action adds it as monitored and triggers a search.
  - A status list: queued, downloading, imported, failed.
  - Lidarr's own indexers and download client must already be set up; the app only requests.
- **Lidarr API outline.** This is from my memory of Lidarr's v1 API, **so check it against the user's instance (its Swagger/API docs) before building**:
  - Auth by `X-Api-Key` header, base `/api/v1/`.
  - Lookups: `artist/lookup?term=` and `album/lookup?term=`.
  - Adding an artist needs a root folder, a quality profile and a metadata profile (from `rootfolder`, `qualityprofile`, `metadataprofile`), plus `monitored` and `addOptions`.
  - Searching/grabbing: `POST command` with `ArtistSearch`/`AlbumSearch`.
  - Status: `queue`, `wanted/missing`, history.
- **Link flow (yt-dlp):**
  - A paste box, with a clipboard-paste shortcut.
  - The server validates the URL (YouTube/YouTube Music/youtu.be, single video vs playlist) and checks availability without downloading.
  - The app shows a preview (title, channel, cover, length) before the user confirms.
  - Then a progress/queue state, and a clear error for private, region-blocked or invalid links.
  - Duplicate detection against the library.
  - Metadata cleanup and embedded cover art, so the result sorts properly in Navidrome.
- **Custom albums:** the user decides how songs are grouped. Candidates: by source/collection name, by date added (e.g. "Added 2026-11"), by artist, or by a user-defined rule, with the tags written automatically at download time.

### Open questions (need the user)

1. **One backend or two?** Either the app talks to Lidarr directly and to a companion service for yt-dlp (three endpoints), or **one companion backend fronts both** (one credential in the app, and Lidarr's powerful API key stays on the server). The user said "two sets" of credentials, which assumes the direct route.
2. **Where does the companion live and who builds it?** It's outside this Flutter repo. A new repo, a container next to Navidrome/Lidarr, or a script in `tools/`? Its API also needs auth.
3. **How should custom albums be defined and sorted?** See the candidates above. Albums (tags) or playlists?
4. **Tab name, icon, position.** For example `CupertinoIcons.plus_circle`/`cloud_download`, and before or after Search. It also needs an l10n label.
5. **Classic mode too?** The tab is a feature, so classic probably needs it as well; otherwise it only exists when the glass toggle is on.
6. **Ground rules.** The current rules say don't touch settings screens, the Subsonic client or state management. This feature needs credential entry (a new settings section or in-tab setup), new state and possibly a `startScan` call. **Get explicit approval for each**, as the settings padding fix was.
7. **Distribution risk.** A feature that downloads YouTube audio may conflict with YouTube's terms and could be a problem in App Store review if the app is distributed publicly. Consider keeping it opt-in, off by default, or only active when a companion endpoint is configured.
8. **What else is planned?** The notes said "other features like" custom albums and ended with an empty bullet.

## Scope and ground rules (from the user)

Restyle these components with an iOS 26/27 Liquid Glass look, in this order: mini-player, bottom nav, now-playing, library grid.

- Work one component at a time. After each one, stop and report what changed and where. **Show the diff before the user builds.**
- Build reusable widgets (`GlassContainer`), not one-off styling.
- Get **as close to Apple's Liquid Glass as possible.** The user is exacting about this: center almost perfectly clear, edges warping the content behind.
- Keep theming intact (dark/light, accent, dynamic color). Glass sits on top of the theme.
- **Do not touch:** auth/login, settings screens, the API/Subsonic client, state management, or platform build config. The only exception is a minimal unavoidable wiring change, and it must be **flagged first**. (The settings scroll-padding fix was explicitly approved.)
- Don't touch playback logic, the app icon, the name or branding. **Exception (the user's request, 2026-11-02):** the app is now named **Navinix** and has a new icon; see "App name and icon". Further branding changes still need the user's go-ahead.
- User preference: when offered a multiple choice, they answer with just the choice.

## How to see it

**Settings → Display → "Circular Design"** toggles `ThemeService.liquidGlass` (pref key `app_liquid_glass`, default **off**). With it off, the classic layout must behave exactly as before; every helper below returns the original values. Glass applies only to the phone layout (width < 650 and shortestSide < 600). Tablet, desktop and TV use other layouts that haven't been touched.

## Commits on the branch

| Commit | What |
|---|---|
| `8ce0d8d` | `GlassContainer` / `GlassStyle` + mini-player glass branch |
| `d871894` | Floating chrome layout (`main_screen.dart`) + scroll padding in 18 pages |
| `d80305c` | Same padding fix for the 7 settings tabs (approved) |
| `9c5e92f` | Edge-refraction shader; `GlassContainer` rewrite; `shaders:` entry in pubspec |
| `083ded4` | Restored CRLF in `pubspec.yaml` (the previous commit accidentally converted it to LF) |
| `9007f21` | iOS UIScene lifecycle migration |
| `74759d1` | Mini-player polish: 60pt capsule and art geometry; edge-weighted frost/veil, clearer centre and stronger refraction in the shader and `GlassStyle` |
| `c48b696` | `GlassTabBar` (`lib/widgets/navigation/glass_tab_bar.dart`) + its widget tests; `_buildGlassBottomNav` uses it |
| `5000ad8` | Now-playing glass: `GlassIconButton`, `ArtworkBackdrop`, `GlassStyle.control`, `GlassContainer.visibility`, glass branches in the now-playing screen and widgets, + tests |
| *(branch `slider-work`)* | `ThickBarSlider`: thumb-less thick-bar scrubber and volume slider (both modes), + tests |
| *(branch `new-tab`, uncommitted)* | New tab: `NewScreen`, the five section widgets, `MainTabs`, the 4th tab in both tab bars and the desktop sidebar, the `newTab` l10n key, + tests |
| *(branch `collapsed-nav`, merged into `master`)* | Collapsing chrome: `GlassChromeScrollTracker` + `GlassTabButton`, `collapse` on `GlassTabBar`/`MiniPlayer`, the morph in `main_screen.dart`, + tests |
| *(branch `player-anim`)* | App renamed **Navinix** (launcher name + app title) and new light/dark/tinted icons for iOS and Android, with the renderer in `tools/app_icon/` |
| *(branch `player-anim`)* | Now-playing open/close transition: `NowPlayingRoute` / `NowPlayingTransition` / `NowPlayingFrame` / `NowPlayingArtAnchor` / `NowPlayingCapsuleAnchor`, `GlassPresence`, + tests. v3: close slides to the bottom, then merges up into the capsule as it reaches out |

## What's built

### `GlassContainer`: the reference implementation (`lib/widgets/common/glass_container.dart`)

Every future glass component should use this. Don't restyle surfaces one by one.

- `GlassContainer(...)` / `GlassContainer.capsule(...)`. The capsule radius is always half the shortest side.
- Params: `child`, `borderRadius`, `style`, `padding`, `width`, `height`, `onTap`, `onLongPress`, `pressScale`, `visibility`.
- **`visibility` (0..1) is how you fade glass.** It scales every optical effect (tint, lensing, frost, rim light, shadow, outline) toward nothing, so at 0 the glass has dissolved into its backdrop. **Never fade glass with a fractional `Opacity`/`FadeTransition`**: see the gotcha under "Shader and compositing".
- With `onTap`/`onLongPress` set, it acts like interactive iOS glass: it swells to `pressScale` (1.015) and its highlights brighten.
- Exported from `lib/widgets/widgets.dart`.
- `GlassContainer.debugForceBlurFallback` forces the fallback path (for comparisons and tests).

**Two rendering paths**

- **Refraction shader**, used whenever `ui.ImageFilter.isShaderFilterSupported` is true (Impeller: iOS always, most current Android):
  - The center is nearly fully see-through (2% base tint, light adaptive tint, a touch of vibrancy).
  - A curved bevel along the edge samples content from *outside* the glass and squeezes it into the rim (lensing), with chromatic dispersion and specular light on the bevel.
  - **Frost is concentrated at the edges:** across `edgeFrostWidth` from the rim, a grainy blur (12-tap Vogel disc, rotated per pixel so it reads as frosted grain rather than ghosting) and a milky veil ease in. On dark glass the veil is lifted 30% toward white, so the rim reads as scattered light, not a darker ring.
  - An adaptive tint ramps up only for strongly conflicting content: bright content under dark glass, dark content under light glass. It's now small (0.15), per the user's request for a clear centre; legibility of white text over near-white art is the trade-off.
- **Blur fallback** (web, Skia): `BackdropFilter.grouped` blur plus saturation, a thicker tint, and a sheen painter.

**Layers, bottom to top:** `ClipRSuperellipse` (continuous corners) → shader or blur → child → rim painter (crisp 1px specular line) → shadow painter. The shadow is a *foreground* painter clipped to outside the shape, so the glass never refracts its own shadow.

**`GlassStyle` defaults and presets** (lengths are logical px)

| Field | `regular` (default) | `clear` | `frosted` |
|---|---|---|---|
| `refraction` (max pull-in at the rim) | 22 | 14 | 22 |
| `bevel` (width of the bending band) | 22 | 22 | 22 |
| `dispersion` | 0.1 | 0.1 | 0.1 |
| `frost` (center blur radius) | 0 | 0 | 4 |
| `edgeFrost` (blur radius at the rim) | 3 | 2 | 5 |
| `edgeFrostWidth` (frosted band width) | 14 | 14 | 14 |
| `edgeTint` (milky veil opacity at the rim) | 0.14 | 0.08 | 0.14 |
| `saturation` | 1.15 | 1.15 | 1.15 |
| `lightTintOpacity` / `darkTintOpacity` | 0.02 / 0.02 | 0 / 0 | 0.40 / 0.32 |
| `adaptiveTint` | 0.15 | 0.12 | 0.3 |
| `highlight`, `elevation`, `rimWidth` | 1, 1, 1 | 1, 0.6, 1 | 1, 1, 1 |
| `fallbackBlurSigma` | 20 | 20 | 20 |

`GlassStyle.control` is for small round controls (`GlassIconButton`): refraction 10, bevel 12, edge frost 2 over 9pt, edge veil 0.16, tint 0.10 light / 0.08 dark, elevation 0.6. The lensing and frosted band are scaled down for a small radius, with a bit more tint so the disc reads over smooth backgrounds like blurred artwork.

History: bevel/refraction started at 20/18, picked over 16/14 (too subtle) and 24/22 (fisheye at the capsule ends on the old 56pt capsule). The user then asked for noticeably stronger warping (~10–15%+), so it's now 22/22 (+22% pull-in, +10% band). The frost band is kept narrower than the bevel (14 vs 22) so the inner part of the bend stays crisp and the warp stays visible. Previous centre values were tint 0.06/0.05, adaptive 0.45, saturation 1.2; the user found that too opaque.

### Shader: `shaders/liquid_glass.frag` (registered under `flutter: shaders:` in pubspec)

Uniform float indices, set in `_LiquidGlassLayer._resolveFilter`. **If you add a uniform, update both files.**

| Index | Uniform | Meaning (screen px unless noted) |
|---|---|---|
| 0–1 | `u_size` | Set by the engine: backdrop texture size |
| 2–5 | `u_rect` | Glass bounds: x, y, w, h |
| 6–9 | `u_shape` | Corner radius, bevel, max refraction, normal-field radius |
| 10–13 | `u_optics` | Dispersion (0..1), frost radius, saturation, specular strength |
| 14–17 | `u_tint` | Tint RGB + base opacity |
| 18 | `u_adaptive` | Adaptive tint amount |
| 19–22 | `u_edge` | Rim frost radius, rim veil opacity, frosted band width, veil lift toward white (0..1) |
| 23–24 | `u_drag` | Rim drag (screen px): how far the bevel's content lags behind the glass's motion. 0 at rest |

**Rim drag ("stickiness", added 2026-11-02 at the user's request):** the user wanted the refraction to "reach out to the edges" or "get stuck to the edges as it passes by". The shader had no notion of motion, so it was new for all glass, mini-player included.
- `_LiquidGlassLayer._updateDrag` measures the glass's on-screen centre every frame (the same compositing-time rect the shader uses). It drives an underdamped 2D spring (`_kDragStiffness` 320, `_kDragDamping` 0.5) toward `velocity × 0.035s × GlassStyle.stickiness`, capped at 0.9× the bevel.
- The shader offsets the bevel's sampling by `−u_drag`, eased in across the bevel and weighted by how much each edge faces the motion. At the trailing edge what the glass just passed stays stuck to the rim; at the leading edge the content inside reaches out to the edge. When it stops, the rim snaps back past rest a touch.
- **Still glass is unchanged** (0 at rest), so the approved resting look of every surface is untouched. It only shows on glass that moves on screen: the dragged/sliding pill, the collapsing chrome, the travelling Search button, sheet slides and route transitions. It doesn't respond to content scrolling under still glass (the shader can't see content motion).
- Off under reduce motion and below `stickiness` 0, faded with `visibility`. It only advances during real frames (not `toImage`), and keeps scheduling frames until settled. Gaps over 100ms and teleports don't count as motion.
- Knobs: `_kDragLag`/`_kDragStiffness`/`_kDragDamping`/`_kDragCap` in `glass_container.dart`, or `GlassStyle.stickiness` per surface.

The shader compiles for Vulkan, Metal, GLES2/3 and SkSL (checked with `impellerc`).

### Mini-player (`lib/widgets/navigation/mini_player.dart`)

Only the glass branch changed; the classic branch is untouched.
- A 60px `GlassContainer.capsule` with 12px side margins and 4px top/bottom padding. It was 56px; the user found the art cramped.
- 40px artwork with a 10px corner radius, inset 12px from the leading end and 10px top/bottom (`_kGlassArt*`). The bigger leading inset and rounder corners keep the art's corners about as far from the capsule's curve (~7px) as its edges are from the straight sides, instead of almost touching it.
- Cupertino filled glyphs: `play_fill`/`pause_fill`/`forward_fill`/`heart(_fill)`. The heart/shuffle/repeat visibility settings are honored.
- The progress bar is an inset rounded 2px hairline (in its own `RepaintBoundary`).

### Tab bar: `GlassTabBar` (`lib/widgets/navigation/glass_tab_bar.dart`)

The user's spec was Apple Music's interaction model, not a static bar: a selection bubble behind the selected tab, whose icon and label take the **theme accent** (the user chose the accent over hard-coded blue). Unselected tabs are neutral gray (`#A1A1A6` dark / `#6E6E73` light).

- A `GlassContainer.capsule` (62pt, same 12pt side margins as the mini-player) inside the chrome's shared `BackdropGroup`. Exported from `widgets.dart`. Takes `items` (`GlassTabItem`: icon, activeIcon, label), `currentIndex`, `onTabSelected`.
- **The bubble's position is one `AnimationController.unbounded` (`_pos`) in tab units** (0 = first tab's centre). Everything is derived from it each frame:
  - **The bubble is a colour window (the user's call, 2026-11-02, matching Apple Music):** two identical rows of tabs are stacked, one gray (outline icons) and one accent (filled icons). The accent row is clipped to the bubble's rounded rect and the gray row to everything outside it (`_BubbleClipper`, keys `accentLayerKey`/`neutralLayerKey`). As an edge crosses an icon, the part under the bubble is blue and the rest gray, pixel for pixel. Colours never fade or interpolate; only the bubble moves. Both rows share metrics (labels w600 in both) so they line up at the edge. Semantics live in a separate invisible row. The lens magnification during a drag eases with distance (`_proximity`) and is applied equally to both rows. *(An earlier attempt the same day snapped the whole tab's colour when the bubble's centre crossed a slot boundary; the user rejected it.)*
  - **Jelly (the user asked for a more liquid feel when moving it, 2026-11-02):** the old velocity stretch only worked during animations (the drag sets `_pos` directly, so `_pos.velocity` was 0). Now a `Ticker` (`_jelly`, `_tickJelly`) measures the bubble's real speed every frame from any motion (drag, tap slide, snap). An **underdamped spring** (`_kJellyStiffness` 260, `_kJellyDamping` 0.32) pulls the stretch toward `speed × 0.045` (cap 0.32): wider by the stretch, flatter by 0.4×. When it stops, it wobbles past round (narrower) and settles. The ticker stops once settled. The stretch is symmetric, so the centre still tracks the finger 1:1 (an off-centre droplet tail was tried and dropped for that reason). Off under reduce motion.
  - **Hold to grow (same request):** a pointer down on the bubble (`_handlePointerDown`, via a `Listener`) lifts it at once, without waiting for a drag. Up/cancel lowers it unless a drag is going. Holding elsewhere on the bar doesn't. Lift is now **+16%** (`_kLiftScale`, was 8%), and the lens refraction rises 8→13 while lifted.
- **Two separate animation paths, as the user suggested:**
  - **Tap:** `onTabSelected` fires, the parent changes `currentIndex`, and `didUpdateWidget` runs `_slideTo`. That's an `animateTo` with `Cubic(0.3, 0, 0.1, 1)` over 260ms + 60ms per tab travelled (~320ms to a neighbour), so it gets going immediately and eases into place. External index changes (back button, `NavigationHelper`) take the same path.
  - **Drag** (`onHorizontalDrag*`): the bubble *lifts* (`_lift`: +8% size, clearer fill, brighter rim, soft shadow; the icon under it grows up to 12%, like a lens) and tracks the finger 1:1. Right after the drag is recognised, `_catchUp` blends it from where it was to the finger over 160ms, so it never jumps. It rubber-bands up to 0.18 tabs past the end tabs. Each tab crossed gives a `HapticFeedback.selectionClick()`. **Nothing is selected mid-drag.**
  - **Release:** a `SpringSimulation` (stiffness **300**, damping ratio **0.7**; softened from 520/0.78 when the user found letting go "too snappy", and the lift now settles over 420ms instead of 260ms) to the nearest tab of `pos + velocity × 0.12s`, so a flick carries on to the tab it's heading for. It selects that tab if it differs from the current one; releasing over the current tab does nothing.
- **`currentIndex` is the source of truth.** If the parent doesn't adopt a selection (the Search easter egg opens a page instead), a post-frame check slides the bubble back.
- **Reduce motion:** taps and snaps jump; the drag still tracks.
- **Semantics:** each tab is a button with `selected` and a tap action.
- **`main_screen.dart`:** `_buildGlassBottomNav` now just builds a `GlassTabBar`. The old inline tap closure became `_onGlassTabSelected`, with an identical body: `popUntil` the first route, the 11-taps-on-Search easter egg, `setState(_currentIndex)`. A drag released onto Search counts as one easter-egg tap. The classic `_buildBottomNav` is untouched.
- **The bubble is a completely see-through glass lens over the icons** (the user asked for glass over the icons, then for the pill to be "completely see through" with "the same warping effect" as the mini-player and nav bar).
  - **Style `_kBubbleGlass`** = `GlassStyle.regular`'s rim optics (refraction 22, bevel 22, rim frost and veil) with no tint, no adaptive tint, no frost and no saturation boost. Refraction rises +4 while held. The painted body under it has no fill either, so the pill is clear except where its rim warps what it hovers over.
  - Its **lift shadow is clipped to outside the pill.** Inside, it showed through the see-through glass as a dark background while held or dragged (part of the user's "dark background" report).
  - **Drawn over the bar, not inside it** (`_buildLens`, a sibling of the bar's `GlassContainer` in its own `BackdropGroup`). Geometry comes from the shared `_bubbleRectIn`. While collapsing, it's mapped into the shrinking capsule (`tabsOrigin`) and clipped to it.
  - *Bug fixed (the user saw a dark pill in dark mode):* the first version sat **inside** the bar's glass. Impeller renders a glass surface's children into an offscreen subpass sized to that surface, so the lens shader's screen coordinates were wrong and it sampled empty texture. See the new gotcha. A probe render (Impeller, stripes behind the bar) showed the fixed lens with the stripes untouched inside it and bent at its rim like the bar's.
  - **Only with the refraction shader** (`GlassContainer.refractionAvailable`). The blur fallback's fixed +0.25 tint and σ20 blur would hide the icon, so on web/Skia the painted bubble keeps its fill and lit rim (`_BubblePainter(rim:, fill:)`).
  - Not built below 2% visibility, and never wrapped in `Opacity`. While the bar collapses it fades via `visibility` (`contentOpacity`).
  - Still not a *magnifying* lens (that needs a magnification mode in the shader); the held bubble's icon grows via the proximity scale.
- **Tests:** `test/widgets/glass_tab_bar_test.dart` (15 tests). The new ones: hold grows (and not when holding another tab), jelly stretch, rebound and settle (centre still on the finger), no jelly under reduce motion, lens only with the shader. The originals cover the initial state, the tap slide (not a teleport, settled in <½s), slow-drag 1:1 tracking with highlight and haptics, the bubble-as-window masking (an edge splits an icon into gray outside and accent inside, following the edge exactly), release over the current tab, the flick projection, the bubble returning when a selection isn't adopted, external index changes, reduce motion and semantics.

### Collapsing chrome (`main_screen.dart` `_buildCollapsibleChrome`, `lib/widgets/navigation/glass_collapsed_bar.dart`)

The user's spec (2026-11-02, revised the same day after the first version): when you scroll down a page, the full tab bar + mini-player **morph as one continuous move** into a compact row so more content shows. Glass phone layout only; classic is untouched.

- **Collapsed layout** (52pt row, `kGlassCollapsedBarHeight`, same 12pt side margins and bottom inset as the tab bar):
  - **Leading corner:** the tab bar itself, shrunk to a circle. It shows the **current tab** (filled accent icon), or **Home** (plain neutral icon) while on Search (`_collapsedLeadingTab`, `GlassTabBar.collapsedIndex`).
  - **Middle:** the mini-player itself, 52pt tall and narrowed into the gap. It **keeps artwork (36pt), title and artist**; every control except play/pause folds away, and **play/pause sits at the capsule's trailing edge** (centred in its rounded end). Tapping it opens now-playing as usual.
  - **Trailing corner:** always **Search** (accented while it's the current tab). So Home → [Home] [mini] [Search]; New → [New] [mini] [Search]; Library → [Library] [mini] [Search]; Search → [Home] [mini] [Search]. Indices come from `MainTabs`. This is the user's rule (2026-11-02, third round). It replaced a first guess of Home in the trailing corner, with Library getting [Search][Home].
- **When it changes** (`GlassChromeScrollTracker`, fed by a `NotificationListener<ScrollNotification>` around the inner navigator, so it works on **every page** under the chrome with no per-page code):
  - **Collapses** after scrolling **down 24pt** (`kGlassChromeScrollThreshold`) without reversing, once more than 24pt from the top.
  - **Stays collapsed** while scrolling either way, across page pushes and pops (the user's rule: scrolling up does *not* expand it).
  - **Expands only on:** a tab press (any tab: the collapsed circle, a trailing button, or the full bar, via `_onGlassTabSelected`; also `NavigationHelper` tab changes and Android back to Home), or reaching the **top** of a page (≤0.5pt of `minScrollExtent`, an iOS pull-down bounce past the top, or a pull-down `OverscrollNotification` at the top on Android).
  - Ignored: horizontal scrollables (Home's carousels), reversed lists, overscroll at the end of a list, and scrolling while a sheet is on top.
- **The morph.** One **unbounded** `AnimationController` `_chromeCollapse` (0 full, 1 collapsed), driven by a soft, **underdamped** spring (`_kChromeCollapseSpring`: stiffness 170, damping ratio 0.68, `snapToEnd`). The user asked for "flowy/bouncy" and slightly slower; it was critically damped at stiffness 320 (~0.3s) before. It takes ~0.5s and overshoots ~5% before settling, and a reversal mid-way keeps its speed. Reduce motion jumps.
  - The overshoot (`over` = value minus its clamp to 0..1) is **added to each piece's geometry**, so everything bounces. Collapsing, the mini-player dips ~4pt below its row and back, the circle dips ~8% (to ~48pt; in `GlassTabBar` the dip past 1 is relative to the circle, not the bar's long travel), and the trailing button pops past full size. Expanding, the mini-player rises ~4pt above its spot and the bar swells ~2%. Opacities and fades use the clamped value.
  - Every piece is placed by **lerping its rect** between the two layouts, with staggered `Interval`s:
  - **Tab bar** (`GlassTabBar.collapse`, 0–0.85): the glass capsule narrows toward its leading end and drops to 52pt tall, bottom-aligned, and becomes the leading circle. The tabs keep their full-width layout (`OverflowBox`, width remembered in `_expandedWidth`) and **glide so the current tab's centre lands on the circle's**, fading out as the circle's accent icon fades in. While collapsed the tabs ignore touches; tapping the circle calls `onTabSelected(currentIndex)` (pop to root + expand). It has one semantics button for the current tab.
  - **Mini-player** (`MiniPlayer.collapse`, 0.1–1, a beat after the tab bar so it has room): its rect drops into the gap between the corner buttons and narrows; capsule height 60→52, art 40→36 (radius 10→9, leading inset 12→9), trailing padding 8→2. The other controls fold away via `_fold` (width factor and opacity down to 0). Painted above the tab bar.
  - **Trailing Search button** (`GlassTabButton`): **travels from its slot in the bar to its corner** (the user's request, fourth round). Its rect lerps from a 52pt circle centred on the bar's own Search icon (`GlassTabBar.slotCentre` + `GlassTabBar.iconCentreOffset`) to the corner, with the bar's progress (`tabT`, overshoot included, so it bounces in). The glass forms around it over 0.05–0.6. **Hand-off: a crossfade**, not a switch. Over the first 15% of the collapse (`handoff`), the tab fades out of the bar (`GlassTabBar.detachedTabs` + `detachProgress`) as the button's glyph fades in (`glyphVisibility`). **Two more fixes (2026-11-02, the user saw "a black circle on top of the search glass for a second when going un-collapsed"):**
    - The button has **its own `BackdropGroup`**. In the chrome's shared group it read a snapshot taken before the tab bar was drawn, so over the bar it painted the raw page: a dark disc in dark mode.
    - It's **only built past `_kTrailStart` (2%)**, with the crossfade starting there. A glass surface left built at ~0 visibility still hid the bar's Search icon under it (~8% darker on a grey test page, worse on black). The spring's small rebound at the end of expanding re-created the invisible button there for ~0.2s, which was the "for a second". Measured on the real `MainScreen` under Impeller, dark theme: the Search spot read 106 (no own group) and 119 (own group, rebound present), against 129 for the bar alone. With both fixes the tail reads 129.
    - *Earlier bug fixed (the user's report: "Search" flashed under the spyglass as the chrome expanded):* it used to be a hard switch at collapse 0. The underdamped spring dips just past 0 and back when expanding, and each crossing flipped the bar's icon + label against the button's lone icon. The crossfade turns that dip into a ~2% flicker. Expanding runs the same trip in reverse, back onto the bar's icon. It used to swell in place at the corner.
  - **No glass is ever faded with a fractional `Opacity`;** plain `Opacity` is only on non-glass contents (tabs, icons, folded controls).
  - The chrome's box keeps the **full height** throughout (`SizedBox` around a `Stack`), so the overlap reported to pages (`floatingChromeOverlap`, 168pt with a song on a 34pt-inset iPhone) never changes and nothing reflows mid-scroll. Empty parts of the box don't hit-test.
- **Adding or reordering tabs** (the user has another tab coming on another branch): add it to `MainTabs` and `_glassTabItems` (plus the classic bar/sidebar, as before). The collapsed row needs nothing else: start points come from `GlassTabBar.slotCentre` for any tab count, and **which tabs go where is the one function `_collapsedLayout()`** (`leading`, `trailing`). Every tab listed in `trailing` travels from its slot automatically, and `leading` glides into the circle. If `_TabSlot`'s icon/label layout changes, re-measure `_kIconCentreOffset` (7pt; a test checks it).
- **Tuning knobs:** threshold (`kGlassChromeScrollThreshold`), row size (`kGlassCollapsedBarHeight`), spring (`_kChromeCollapseSpring`: lower stiffness = slower, lower ratio = bouncier), the `Interval`s (including `trailGlass`), the trailing start scale (0.85) in `_buildCollapsibleChrome`, the dip/swell gains (1.5 and 0.35) in `GlassTabBar.build`, the collapsed art constants (`_kGlassCollapsed*` in `mini_player.dart`), and the tab fade points (0.6 / 0.35) in `GlassTabBar.build`.
- **Tests:** `test/widgets/glass_collapsed_bar_test.dart` (15).
  - The tracker: threshold; stays collapsed scrolling up until the top; no collapse from jiggles near the top; pull-down at the top expands; horizontal scrolling ignored; end bounce ignored.
  - `GlassTabBar.collapse`: the capsule lerps into a 52pt circle anchored bottom-left; the current tab glides in and ends centred; tapping the circle selects the current tab; `collapsedIndex` (Home on Search: neutral icon, selects Home); overshoot dip and swell; collapsed semantics.
  - `slotCentre`/`iconCentreOffset` match where the bar draws each icon (and 4-tab spacing); `detachedTabs` leave the bar once collapsing starts.
  - `GlassTabButton`: size, colour, tap, semantics.

### Now-playing (`lib/screens/player/now_playing_screen.dart` + `lib/widgets/now_playing/*`)

Glass mode only (`ThemeService.liquidGlass`, read in `build` into `_glass`). Classic is **pixel-identical** to before (playing, paused and pressed renders diffed at 0). Applies to the portrait and landscape layouts; TV keeps `TvNowPlayingScreen`.

- **Backdrop: `ArtworkBackdrop`** (`lib/widgets/now_playing/artwork_backdrop.dart`) replaces `BlurredGradientBackground`. It shows the current cover decoded at 64px, blurred (σ36), saturated ×1.35, scaled ×1.5 and drifting slowly (40s loop: translate, rotate and scale; stops under reduce motion). It cross-fades on track change.
  - **Scrim:** a top-to-bottom black gradient whose strength follows `brightness`. The screen passes `0.6 × dominant + 0.4 × brightest` palette luminance (`_artworkBrightness`), so a bright highlight (a sun) still darkens it.
  - **Contrast checks:** a near-white cover went from ~2.6:1 to ~9:1 behind the controls; the dark sunset cover keeps its colour.
- **`GlassIconButton`** (`lib/widgets/common/glass_icon_button.dart`, exported) is a round glass button.
  - `persistent: true`: always on a glass disc; the disc swells while pressed.
  - `persistent: false`: glyph only, and a glass disc swells in behind it while pressed (iOS transport style).
  - Flipping `persistent` fades the disc in or out via `visibility`, which is how toggles show "on". Changing `icon` cross-fades the glyphs (play/pause).
  - **The press look starts on the raw `Listener.onPointerDown`.** The tap's own `onTapDown` is held back 100ms here by competing gestures (the page swipe and drag-to-dismiss).
  - `onTapCancel` releases it when a swipe takes over. A quick tap still shows the full swell before fading (`_releasePending`).
  - It has button semantics with a label.
- **What's glass on the screen:**
  - Top bar: chevron (✕ on the lyrics/queue pages) and ••• in 38pt discs, inset 18pt.
  - Title row: heart (accent when starred) and + in 36pt discs.
  - Lyric pill: `GlassContainer.capsule(style: control)`.
  - Transport: `PlaybackControls(glass: true)`. Cupertino `backward_fill`/`play_fill`·`pause_fill`/`forward_fill` with press-reveal discs (62/76/62pt). Shuffle and repeat get a persistent disc with an accent glyph while on.
  - Bottom row: `NowPlayingBottomActions(glass: true)`. The lyrics and queue buttons get a persistent disc while their page is showing. The cast button is unchanged.
  - Volume: `VolumeSlider(glass: true)` swaps in Cupertino speaker glyphs. The bar itself is the shared `ThickBarSlider` in both modes (see "Sliders").
- **Artwork shrinks to 0.86 while paused** (`_buildArtwork`, `AnimatedScale`, slight-overshoot curve, 480ms), like Apple Music.
- **Accent:** this screen forces `ThemeData.dark()`, so `Theme.of(context).colorScheme.primary` inside it is stock purple. Glass mode captures the **app accent** before that override (`_appAccent`) and uses it for active states. Classic still uses the palette colour.
- **One `BackdropGroup` wraps the whole screen**, so all its glass shares one backdrop read.
- **Not restyled for glass specifically:** the lyrics and queue pages themselves, and the sheets this screen opens (••• menu, add-to-playlist).
- **Tests:** `test/widgets/glass_icon_button_test.dart` (9) and `test/widgets/now_playing_glass_test.dart` (2). The second mounts the real screen in both modes: glass widget counts, the app accent on the heart, play/pause plus the artwork shrink, shuffle's on state, and classic unchanged.

### Now-playing open/close transition (`lib/widgets/now_playing/now_playing_transition.dart`)

**Version 3 (2026-11-02), merge loosened the same day.** After v3 the user asked for the merge to be "a little less stiff" ("I think we're golden"), then for "a little more loose". So the merge starts earlier (0.4), the springs are looser with more give on landing (close 110 / 0.72, swipe release 125 / 0.62), and the swallow swell is 5.5%. The user's feedback so far:
- **v1:** they loved the art flight ("exactly what I was looking for"). It's kept for **opening**.
- **v2:** the player compacted into the mini-player; "still pretty good".
- **For v3 they asked for:**
  - **more animation at the bottom, with the mini-player "reaching out" to the merge;**
  - **the player to slide all the way to the bottom of the screen, then merge back up;**
  - reference videos.
- Still standing from v2: the **whole mini-player** is the target, **no fade while it slides**, and it must work with the **collapsed** mini-player.

**References.** I couldn't find a video of the iOS 26/27 Music dismiss, and I can't watch video anyway. The closest documented behaviour is what v3 is modelled on:
- iOS 26's mini-player is the tab bar's bottom accessory, and the full player is a zoom/morph from it, not a plain slide. Sources: WWDC25 session 323; developer.apple.com/forums/thread/809806; github.com/speech115/Petrichor/pull/11.
- Liquid Glass's own merge: `GlassEffectContainer` shapes within its spacing "blend and morph together like water droplets" (Apple's `GlassEffectContainer` docs; dev.to/arshtechpro "Understanding GlassEffectContainer in iOS 26").
- **Not verified against an iOS 26/27 device.**

**The user's original spec (v1, still applies):** swipe-to-dismiss follows the finger, then settles with a weighted spring (a slight drop and a soft overshoot). One controller, so gestures can interrupt or reverse it. Smooth at 60/120Hz, reduce motion respected, layout and controls unchanged.

**Applies in classic and glass mode** (no mode qualifier, as with the sliders). Only the mini-player path uses it. The desktop player bar and TV keep their routes. `NowPlayingScreen` mounted without a transition builds exactly the tree it did before. Also, v2's 80pt backdrop bleed is gone, so the open screen's backdrop is laid out exactly as before.

- **Route:** the mini-player pushes `NowPlayingRoute`, a transparent `PageRoute` with zero-length transitions, on the root navigator. `NowPlayingTransition` does all the animating.
- **One controller:** an `AnimationController.unbounded` holds the progress `p` (0 = merged into the mini-player, 1 = open).
  - Every visual comes from a pure static function of `p` that returns a `NowPlayingFrame`. The frame holds the sheet or blob rect, the player's origin and scale, corner radius, sheet opacity, content opacity, glass presence, capsule reach and swell, the neck path, and the capsule cut-out.
  - A drag writes `p` (the sheet's top edge follows the finger 1:1). A release seeds a `SpringSimulation` on `p` with the finger's velocity. It dismisses on more than 700 px/s down, or past 150pt unless the finger was moving back up. A drag can grab it mid-flight.
- **Two paths on the one controller:**
  - **Open (`openFrame`, the v2 geometry):** the art flies from the mini-player's art to its place (`artRect`, v1's flight). Meanwhile the sheet grows up out of the capsule: its top travels linearly, and its sides and bottom spread with `compaction` (1−(1−p)⁴). The capsule bulges as the player pushes out (`capsuleGulp`). The sheet fades in only over `p` < 0.12.
  - **Close (`closeFrame`, new in v3):**
    1. **Slide (`p` 1 → `kNowPlayingMergeStart` = 0.4):** the whole player, art included (no flying copy), stays opaque. Its top edge travels linearly to the **screen's bottom edge** (1:1 with the finger), revealing the app and the mini-player. Only the last ~50pt above the bottom edge fades its controls, with glass off from there. A finger can take it down to the edge; the merge is the release's job.
    2. **Merge (`p` 0.4 → 0):**
       - A blob of the player's material (its backdrop) rises from the bottom edge. It starts screen-wide and 1.5× capsule height, then narrows to the capsule.
       - **The capsule reaches out:** it stretches down from its top edge by up to 18pt (`_kReach`), narrowing ~2% like a drop (`reachAmount`: ramps up as the blob appears, holds, lets go as they fuse).
       - **A liquid neck** (`_neck`) joins the capsule's stretched bottom to the blob's top: two quadratic curves pinched at a waist. It forms within 110pt (`_kNeckSpacing`, like a `GlassEffectContainer` spacing), thin at first and thickening to a full join as the gap closes.
       - **The capsule's shape is cut out of the blob** (`swallow`), so the blob disappears up into the capsule's bottom edge and never covers it.
       - The capsule swells (`_kGulpSwell` 5.5%) as it swallows, and again on the soft overshoot past 0 (the landing wobble). It's settled at `p` = 0, where the route pops.
       - The blob's own opacity eases out over the last 20% of the merge.
  - The open path runs until the player first settles open; from then on it's the close path. Both paths are the full screen at `p` = 1, so the switch is invisible. A gesture keeps the current path's geometry.
  - **Overshoot past open** (the release spring) swells the player very slightly instead of moving it, so no gap can open at the bottom.
- **Drawing:** the screen hands its backdrop and content over together (`wrapSheet`). They're transformed (origin and scale), clipped by a `ClipPath` (sheet or blob ∪ neck − capsule), and faded together, with the controls faded separately by `_ContentFade`.
  - While merging, the player's texture is anchored at the neck's top, so the neck has material to show.
  - The widget structure never changes mid-animation, so the backdrop's state survives. The clip is `Clip.none` when settled.
- **`NowPlayingCapsuleAnchor`** wraps the whole mini-player surface in `mini_player.dart`, at the outermost level of each branch.
  - **Glass:** `inset` (12, 4, 12, 4), `capsule: true`. **Classic:** `capsule: false`, radius 0.
  - It's measured live (box deflated by `inset`), so any mini-player layout is the target.
  - Its static `gulp` (0..1) and `reach` (stretch as a fraction of its height) notifiers drive a `Transform` hung from its top centre.
- **`NowPlayingArtAnchor`** wraps the mini-player's art: the source of the opening flight, hidden during it.
- **Glass under a fade: `GlassPresence`** (in `glass_container.dart`). It's an inherited 0..1 factor multiplying every `GlassContainer`'s `visibility`. At 0 the container skips its backdrop filter entirely and paints only its child, so it's safe inside a fractional `Opacity`. Each frame's `glassPresence` is above 0 only when both the sheet and content opacities are 1 (tested over both paths).
- **Closing paths:**
  - Chevron (`_closeOrBack` on page 0) → `close()`.
  - System back → `PopScope` → `close()`.
  - The close spring is softer than the open (stiffness 110, ratio 0.72), so both halves read and the merge lands with some give (it wobbles on a button close too). The swipe-release spring is 125 / 0.62 for a loose overshoot.
  - Direct `Navigator.pop`s (e.g. artist navigation) still pop at once.
  - The screen hit-tests opaque, so a mid-flight tap can't push a second player.
- **Reduce motion:** open and close jump. The drag still tracks the finger; the release jumps.
- **60/120Hz:** springs are time-based. Per frame: the sheet's transform, path clip and opacities, the capsule's transform, and the small flying-art widget (on open). The content and backdrop are `RepaintBoundary`s, so they're composited, not repainted.
- **Landscape:** open and close work; drag-to-dismiss stays off, as before.
- **Tests:** `test/widgets/now_playing_transition_test.dart` (16).
  - **Geometry:**
    - Both paths are full-screen at 1.
    - Open grows out of the capsule, with no fade above 0.12.
    - Close slides opaque, top 1:1, down to the bottom edge at 0.4, with no reach or neck.
    - The merge rises monotonically into the capsule.
    - The capsule reaches more than 11pt, and the neck spans the stretched capsule to the blob.
    - Glass only when fully opaque, on both paths.
    - The swell is settled at the ends.
    - The opening art is continuous.
  - **Widgets:**
    - The open flight starts on the hidden mini art and lands exactly on the real art.
    - No `BackdropFilter` inside a fractional `Opacity`.
    - Drag 1:1 with no fade, springing back with an overshoot.
    - Swipe dismissal: opaque all the way down; slides past the mini-player before the neck forms; the capsule reaches and swallows; dips below 0; lands on the capsule; the notifiers reset; the mini art is never hidden and no flying copy appears.
    - Catch-and-reverse, system back, reduce motion, and the glass chevron close.
- **Visual check:** a temporary harness (deleted) filmed the glass close with the real `MiniPlayer` on Skia: 12 frames from open to closed.
  - That showed v3's first cut painting the blob *over* the mini-player at the end. That's what the `swallow` cut-out fixes.
  - The final film shows the slide to the bottom, the blob rising, the stretched capsule, the pinched neck, and the blob vanishing under the capsule's edge.

#### Integration with collapsing chrome (`collapsed-nav` worktree, reviewed 2026-11-02)

- **What it does:** a scroll-driven `_chromeCollapse` spring in `main_screen.dart` lerps the mini-player's rect from full (12,688–381,748) to a 52pt capsule between the corner buttons (72,766–321,818). It passes `MiniPlayer(collapse: miniT)`, which shrinks the capsule height and art (40→36, radius 10→9) and folds the other controls away.
- **Why no glue is needed:** the transition **measures** the capsule and art anchors every tick, so it doesn't need to know about the collapse. The close merges into whichever capsule is on screen, and the open flies from whichever art size and radius is there.
  - With the collapsed capsule (bottom at 818pt), the rising blob is within the neck spacing almost at once, so the neck forms earlier and stays shorter.
  - (Checked against v2 in the trial merge below. v3 didn't change `mini_player.dart`, so the merge result is the same.)
- **Trial merge (2026-11-02, scratch worktree, since deleted):** `collapsed-nav`'s uncommitted diff, then this branch's.
  - **Code merges cleanly.** `mini_player.dart` auto-merges, because the anchors wrap the outermost widgets and the art call.
  - **Only `THEME_PROGRESS.md` conflicts.** Both branches edit the "Last updated" line, the commits table, the verification list and the open-feedback list, and both resolved the same stale `<<<<<<< HEAD` block. Keep both sides' content.
  - On the merge, all 112 widget tests pass and the analyzer is at the 16-info baseline.
  - A temporary harness mounted the real glass `MiniPlayer(collapse: 1)` at the collapsed rect. Tapping it opened the player (art flew from the 36pt art); the chevron closed it, and the sheet landed on (71.8, 766)–(321.2, …), matching the collapsed capsule.
- **Changes needed on the `collapsed-nav` side:** none required. Things to keep true when finishing it:
  1. **Keep one `MiniPlayer` on screen at a time.** The last-built `NowPlayingCapsuleAnchor`/`NowPlayingArtAnchor` is the target. A cross-fade that builds two mini-players at once would need the anchors to pick the visible one.
  2. **If the mini-player's outer `Padding` (12, 4, 12, 4) changes,** update the glass anchor's `inset` in `mini_player.dart` to match, or the sheet will compact into a slightly wrong rect.
  3. **Don't collapse or expand the chrome while the player is open.** The scroll tracker can't see under the root route anyway; it's fine as is. If a later change does (e.g. on a tab change triggered from inside the player), the close still targets the live rect; it just lands on a moving target.
  4. **The trailing tab buttons and the collapsed tab circle sit outside the capsule.** The rising blob starts screen-wide and passes over them before narrowing into the capsule. That's intended.
  5. *(Done: merged into `master` 2026-11-02, both sections kept.)*
  6. **Don't put another transform on the mini-player's surface inside `NowPlayingCapsuleAnchor`'s child expecting it to be at rest during the close.** The anchor scales it from its top centre (reach and swell), and the blob's cut-out assumes exactly that transform.

### Sliders: `ThickBarSlider` (`lib/widgets/common/thick_bar_slider.dart`)

The user asked (2026-11-02) for both the scrubber and the volume slider to drop the track-plus-thumb look for a thick bar, with **one shared widget so they can't drift apart**.

- **No thumb/dot at all.** The fill (clipped to the bar's pill shape, straight trailing edge) and the bar's thickness are the only position indicator.
- **Thickness:** `kThickBarIdleThickness` 6pt at rest (the old track was 4pt). `kThickBarActiveThickness` 12pt while touched or dragged. One `AnimationController`, 200ms, `easeOutCubic` growing / `easeInOutCubic` shrinking; the painter repaints off the animation, no rebuilds. Reduce motion jumps.
- **"Touched" starts on `Listener.onPointerDown`**, so the bar grows on contact, before the arena decides tap vs drag. It shrinks on pointer up/cancel once no drag is active.
- **Touch target:** `kThickBarHitHeight` 30pt for both (volume was 24pt, so the volume row is 6pt taller).
- **API:** `value` (0..1), `activeColor`, `inactiveColor` (default white 30%), `onChangeStart` / `onChanged` / `onChangeEnd`, `semanticLabel`. Has slider semantics with a percentage value. Exported from `widgets.dart`.
  - Tap: start → changed → end, all with the tapped value.
  - Drag: start (with the old value) → changed with the finger position as soon as the drag is recognised, then on every update → end with the last value. The bar shows its own drag value while dragging.
- **`PlaybackProgressSlider`:** time labels follow the drag (`onChanged`), **seeks only on release** (`onChangeEnd`) and on tap, as before. Colour is still the caller's `accentColor`.
- **`VolumeSlider`:** sets volume live on every change and on tap, as before; ignores system-volume callbacks while dragging, as before. Fill is white.
- **Behaviour fixes that fell out of the shared widget:**
  - The old volume slider mapped the finger against the **whole row's** width (icons included), so the fill lagged the finger. It now maps against the bar.
  - The old scrubber didn't set its drag value on drag start, so a drag released without an update seeked to 0. It now starts from the finger.
- **Tuning knobs:** the four `kThickBar*` constants at the top of the file.
- **Tests:** `test/widgets/thick_bar_slider_test.dart` (6): idle thickness and no thumb, smooth grow/shrink on touch, reduce motion, tap callbacks, drag tracking and clamping, and the scrubber seeking on release/tap but not mid-drag.

### New tab (`lib/screens/main/new_screen.dart` + `lib/widgets/new_tab/`)

The user asked (2026-11-02) for a New tab loosely modelled on Apple Music's, using **only data the Subsonic/Navidrome API already provides** (no external services), with each section a separate widget so any can be removed.

**Sections, top to bottom. The user is deciding which to keep:**

| # | Section | Widget (file in `lib/widgets/new_tab/`) | What it shows | API calls |
|---|---|---|---|---|
| 1 | Featured hero carousel | `FeaturedHeroCarousel` (`featured_hero_carousel.dart`) | The 6 most recently added albums as large swipeable cards: "RECENTLY ADDED" eyebrow, title and artist · year above a 16pt-radius square artwork with a Play pill; page dots below | `getAlbumList2?type=newest&size=6` |
| 2 | Fresh From Artists You Play | `FreshFromArtistsSection` (`fresh_from_artists_section.dart`) | Newest albums by your most-played artists that you *haven't* been playing (up to 2 per artist, 14 total), "Artist · year"; subtitle "New from A, B and more" | `type=frequent&size=60` to rank artists (rank-weighted, "Various Artists" skipped), then `getArtist` for the top 8. Albums already in the frequent list are dropped; sorted by year, then date added |
| 3 | Rediscover | `RediscoverSection` (`rediscover_section.dart`) | Starred albums not among your 60 most recently played, shuffled per load (14 max). With fewer than 6, it tops up with most-played albums that also aren't recent | `type=starred&size=200`, `type=recent&size=60`, and `type=frequent&size=40` only when topping up |
| 4 | Recently Added | `RecentlyAddedSection` (`recently_added_section.dart`) | A horizontal row of newest albums; the header chevron (See All) opens the existing New Releases list | `type=newest&size=20&offset=skip`. `NewScreen` passes `skip: FeaturedHeroCarousel.albumCount` so the row doesn't repeat the carousel |
| 5 | Mix For You | `MixForYouSection` (`mix_for_you_section.dart`) | A card over a blurred cover: 2×2 cover mosaic, "25 songs", three artists "and more", **Play** (queues the whole mix) and a **new-mix** button that rolls another | `getRandomSongs?size=25` |

**To remove a section:** delete its line from `_NewScreenState._sections` in `new_screen.dart`, then delete its file and its `export` in `new_tab.dart`. If you remove the hero, change `RecentlyAddedSection(skip: …)` to `skip: 0` (the only coupling, and it's commented there).

**Shared plumbing (`new_section.dart`)**
- `NewSectionState<W, T>`: the base state every section extends. It fetches `T` (30s timeout) and renders a header plus one of four states:
  - **Loading:** a shimmer row, a shimmer square for the hero, a grey card for the mix.
  - **Content.**
  - **Empty:** a per-section hint in an inline card, e.g. "Star albums you love…".
  - **Error:** "Error loading albums" + **Retry**.
  - A reload keeps the old content up until new data arrives; only the error state goes back to the placeholder.
- `NewTabRefreshScope` / `NewTabRefreshRegistry`: sections register themselves, so the page's pull-to-refresh reloads whatever sections are mounted without knowing which exist.
- Shared helpers: `NewSectionHeader` (Apple-style bold title, chevron when tappable), `NewSectionMessage`, `NewAlbumTile`/`NewAlbumRow` (150pt art, opens `AlbumScreen`), `playNewTabAlbum` (snackbar on failure), `compareAlbumsNewestFirst`.
- **Page-level state:** in offline or local-files mode the sections are replaced by "New needs your server" (every section needs the server).
- Page: a 34pt large title "New", sections 32pt apart, ends with `MainScreen.scrollEndPadding(context, 40)`. All text uses theme styles; titles are hard-coded English like the Home tab's. Only the tab label is localised (`newTab`, English in every locale for now).

**Liquid Glass**
- `newTabUsesGlass(context)` = glass mode **and** the phone layout (mirrors `MainScreen._isLargeScreen`).
- **Glass where there's content behind it to refract:**
  - the hero's Play pill (`GlassContainer.capsule`, regular style) over the artwork;
  - the mix card's Play (`GlassStyle.control` capsule) and new-mix (`GlassIconButton`) over the blurred cover.
- **Classic mode:** a white pill, an accent pill and a translucent round button instead.
- **Deliberately not glass:** the empty/error cards. They sit on the flat page background, where clear glass reads as an empty outline.
- **No `BackdropGroup` around the carousel:** grouped glass shares one snapshot taken at the first glass, so later pages' pills would refract stale content.
- **No fades over glass** (no `AnimatedSwitcher`/`Opacity`), per the gotcha.

**Tab wiring (`main_screen.dart`, `desktop_navigation_sidebar.dart`)**
- `MainTabs` constants (home 0, newTab 1, library 2, search 3) replace every bare index: `_screens`, back button, both easter-egg checks, and the sidebar items, which gained a New item.
- Icons: `CupertinoIcons.square_grid_2x2(_fill)` in both tab bars (as Apple Music), `Icons.grid_view_*` in the sidebar.
- **TV is untouched** (`tv_main_screen.dart` keeps its own 3-screen list).
- **There is no collapsed-bar logic on master** (`collapsed-nav` points at the same commit as master), so nothing to update there. If that work lands, it must account for 4 tabs.
- l10n: `newTab` was added to `app_en.arb`, and its getter was hand-added to the tracked generated files. Running `flutter gen-l10n` with the local 3.47.9 reformats all 30 files, so avoid committing that churn.

**Tests:** `test/widgets/new_tab_sections_test.dart` (9):
- the hero (features newest, swipes);
- Recently Added's skip;
- Fresh From Artists (ranking, played albums excluded, 2 per artist, compilations skipped, subtitle);
- Rediscover (recent excluded; frequent top-up);
- the empty state; the error state + Retry;
- the mix (count, artist line, new-mix refetch);
- the refresh registry reloading all mounted sections.

**Open questions for the user**
- Which sections to keep (table above).
- Hero size (square art plus caption ≈ 470pt tall on a 393pt phone) and whether it should auto-advance (it doesn't now).
- Whether Rediscover should also count albums you rated highly; it can't use "last played" dates because `Album` doesn't parse `played`. Parsing it would let it say "not played in N months", but that touches the model.
- Localising section titles (they're English, like Home's).
- The tab icon.
### App name and icon (branch `player-anim`, 2026-11-02)

The user asked to rename the app **Navinix** and to give it a new icon, with separate light- and dark-mode versions. Their references were two JPGs from their Downloads (`app logo.jpg` light, `app image 2.jpg` dark). Both are Apple's iOS 26 Apple Music icon art: a glass tile with a beamed note and chromatic rim streaks.
- **Copyright:** the user was told, and said they aren't worried because this is mostly for themselves.
- **Their choice:** an icon drawn from scratch, "as close as you can get" to the references, at full resolution. The JPGs are ~300px tiles, too small to use directly.

**The icon** is painted with `dart:ui` by `tools/app_icon/render_app_icon_test.dart`. Run it with `flutter test tools/app_icon/render_app_icon_test.dart`; it writes to `assets/app_icon/render/`. The installed sources are in `assets/app_icon/`. They're not listed in pubspec assets, so they aren't bundled into the app.
- **What it draws:**
  - A continuous-corner glass tile, 72% of the icon, with a soft bevel, a top-left sheen and a hairline edge.
  - Two chromatic streaks hugging the rim: the top edge round the top-right corner, and the bottom-left corner. Each is layered blurred colour bands plus a bright core, fading at the ends.
  - A beamed eighth-note pair with a red/blue chromatic fringe, and a blue glow where the left note head meets the bottom-left streak.
- **Light:** light-grey ground, frosted white tile, black note. **Dark:** black ground, near-black blue glass, white note, warmer streaks. **Tinted:** the dark icon in greyscale (iOS tints it).
- **iOS** (`ios/Runner/Assets.xcassets/AppIcon.appiconset`): the catalog already had universal light, dark and tinted 1024 slots. `Icon-Light-1024`, `Icon-Dark-1024` and `Icon-Tinted-1024` were replaced, and every legacy `Icon-App-*` size was regenerated from the light icon with `sips`. All are **opaque** (no alpha channel; converted via a max-quality JPEG round trip), as the App Store requires. `Contents.json` is unchanged.
- **Android:**
  - `drawable-*dpi/ic_launcher_foreground.png` is the tile and note on transparent, light version. The adaptive XML still insets it 16%, which keeps the tile's rounded corners inside a circular mask.
  - `drawable-night-*dpi/` holds the dark foreground.
  - `ic_launcher_background` is `#ECECEE` (`values/colors.xml`) and `#000000` in the new `values-night/colors.xml`.
  - Legacy `mipmap-*dpi/ic_launcher.png` comes from the light icon.
  - **Themed icon (Android 13+):** a new `drawable-*dpi/ic_launcher_monochrome.png` (the note alone). Both `mipmap-anydpi-v26` XMLs now use it for `<monochrome>`; it used to be the full foreground, which would have themed as a blob.
  - **Dark mode on Android:** launchers don't officially switch app icons with the system theme. The night resources apply only where a launcher re-reads them; elsewhere you get the light icon. The user was told.
- **Not changed:** the macOS, Windows, Linux and web icons (the user builds for iPhone). `flutter_launcher_icons.yaml` still points at the old `Musly Icon.png`. **Don't run `flutter_launcher_icons`**: it would overwrite these icons on iOS and Android. Update its `image_path`s first if it's ever needed for the desktop or web icons.

**The name (launcher and system only):**
- iOS `CFBundleDisplayName` and `CFBundleName` → `Navinix` (`Info.plist` is CRLF; it was edited byte for byte).
- Android `android:label` → `Navinix`.
- `MaterialApp.title` → `Navinix` (the task switcher).
- **Unchanged:**
  - The bundle and package IDs (`com.musly.musly`). Changing them makes it a different app for installs, updates and store listings.
  - The Dart package name, class names (`MuslyApp`, `MuslyAudioHandler`) and the Subsonic client name sent to servers.
  - The desktop and web titles.
  - About 50 in-app "Musly" strings in the l10n `.arb` files (20+ languages): feature names like "Musly Connect" and "Musly Playback", the developer's support text, the onboarding wordmark, and settings screens (off-limits under the ground rules). Ask before renaming those.
- **Checked:** analyzer at the 16-info baseline, all 101 widget tests pass, and the iOS PNGs have no alpha. **Not checked:** an Android build (no Android SDK on the user's Mac, so `flutter build apk` stops before compiling resources), an Xcode build, or the icons on a device.

### Floating chrome layout (`lib/screens/main/main_screen.dart`)

Glass mode only:
- The mini-player and tab bar become the outer Scaffold's `bottomNavigationBar` with `extendBody: true`, so pages run edge-to-edge underneath. This is built in `_buildFloatingGlassChrome`, with the page column in `_buildPhoneBody`.
- Both bars sit in **one `BackdropGroup`** (a shared backdrop read).
- **Inner navigator MediaQuery:** keeps the **real system bottom inset**, not the chrome height. This is deliberate: see the gotchas.
- **How pages learn the chrome height:** a private `_FloatingChromeScope` publishes it, read through three static helpers:
  - `MainScreen.floatingChromeOverlap(context)`: the overlap height; 0 in classic mode and for root-navigator routes.
  - `MainScreen.scrollEndPadding(context, base)`: returns `base` in classic mode. In glass mode it returns `max(base, overlap + 16)`.
  - `MainScreen.clearFloatingChrome(context, child)`: for `ListView`s without explicit padding and for `SafeArea`s.
- **Sheets:** `_SheetOnTopObserver` slides the chrome away (and ignores taps) while a `ModalBottomSheetRoute` or `CupertinoModalPopupRoute` is on top of the inner navigator. It keeps its layout size so pages don't reflow under the sheet.
- **Classic mode:** the chrome stays inline in the body Column, unchanged.

### Scroll padding (pages)

Each page's final spacer now goes through `scrollEndPadding`:
- **Main:** home, library, search, library search delegate.
- **Detail:** album, artist, genre, playlist.
- **Media:** album collection (including its A–Z index bar), downloads, favorites, genres, playlists, radio, song collection, jukebox, download playlist status.
- **Other:** Wrapped (`SafeArea.minimum`) and the 7 settings tabs.

### iOS UIScene lifecycle (needed before any device testing)

Builds with the iOS 27 SDK crash on launch without it (`UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`). This follows https://flutter.dev/to/uiscene-migration:
- **`Info.plist`:** gained a `UIApplicationSceneManifest` with one window scene pointing at `$(PRODUCT_MODULE_NAME).SceneDelegate` and the `Main` storyboard. The disabled CarPlay scene is kept as a commented role *inside* that manifest.
- **`project.pbxproj`:** `SceneDelegate.swift` (a `FlutterSceneDelegate` subclass) is now part of the Runner target. It existed before but was never compiled.
- **`AppDelegate`:** adopts `FlutterImplicitEngineDelegate`. **All plugin registration**, including the app's own `iOSSystemPlugin`, `iOSBluetoothPlugin` and AirPlay platform view, now happens in `didInitializeImplicitFlutterEngine`. The empty `applicationWillResignActive`/`applicationDidEnterBackground` overrides were removed.

## How it was verified

- **Real Impeller, run headless:** Mesa's software Vulkan driver (lavapipe) plus `flutter test --enable-impeller`.
  - **Alignment:** a glass moved by scrolling *without repainting* is byte-identical to one freshly built at the same spot (max channel diff 0).
  - **Grouped vs ungrouped:** identical except a 2pt sliver at the top rim of the lower glass. That's the expected cost of a shared backdrop.
- **Real `MainScreen`, iPhone size (393×852, 34pt inset), glass mode:**
  - Chrome spans 688→852 (164pt), and the overlap reported to pages is 164. Since the mini-player went to 60pt it's 684→852 (168pt); the tab bar is at 756→818.
  - The last list item ends exactly 16pt above the chrome.
  - With a sheet open, the chrome moves to y≈917 (off-screen) and the sheet still sees the 34pt inset.
- **Real `MainScreen`, classic mode:** pages stop at 695.5, overlap is 0, and every spacer returns its original value.
- **Real `MainScreen` with `GlassTabBar` (2026-11-03):** a tap on Library shows `LibraryScreen`; a drag from Library to Search shows `SearchScreen`; 10 more taps on Search open `FantasyScreen`.
- **Tests:** all widget tests pass. Seven live-network/platform tests (`lrclib_service`, `playlist_import_service`, `update_service` "targetAsset") fail in the container on the untouched base too. The analyzer shows the **16 pre-existing infos (the baseline), no new ones.**
- **Now-playing (2026-11-03):** rendered glass and classic, portrait and landscape, with a dark sunset cover and a near-white one. Classic is byte-identical to the old code. All 38 chrome renders (mini-player plus tab bar at rest, mid-tap and mid-drag, dark and light) are byte-identical to before the `GlassContainer.visibility` change.
- **Sliders (2026-11-02, macOS, `flutter test`):** the 6 new `ThickBarSlider` tests and all 84 widget tests pass, including `now_playing_glass_test` (which mounts the real screen in both modes). Analyzer at the 16-info baseline. No renders or device check yet.
- **New tab (2026-11-02, macOS, `flutter test`, Skia so glass shows the blur fallback):**
  - All 94 widget tests pass, including the 9 new ones. Analyzer at the 16-info baseline.
  - A temporary `MainScreen` harness (deleted) checked, in glass and classic modes: 4 tabs showing; New → `NewScreen` (errors per section with no server, as expected); Library → `LibraryScreen` at index 2; 11 Search taps → `FantasyScreen`. Run glass and classic in separate processes; mounting twice throws, and teardown needs `pump(3 min)` for the usage-time timer.
  - Full-page renders with fake data and real fonts, dark and light at 393pt wide: no overflows. The hero caption needed 80pt; 66 overflowed.
  - Not yet seen on device or with the refraction shader.
- **Collapsing chrome (2026-11-02, macOS, `flutter test`):** the 13 tests and all 98 widget tests pass; the analyzer is at the 16-info baseline. A temporary harness (deleted) mounted the real glass `MainScreen` at iPhone size (393×852, 34pt inset), with a song and a tall page pushed, and checked:
  - Geometry: the overlap stays 168pt collapsed. The mini-player goes from 12,688–381,748 to 72,766–321,818, showing title and artist, with play/pause centred 26pt from its end. The tab bar becomes a 52pt circle at 12,766.
  - Behaviour: it stays collapsed scrolling up mid-page and after play/pause, and expands at the top. Tapping the circle pops to root and expands. Row per tab: Home → [Home][Search]; Library → [Library][Search]; (New → [New][Search], by the same rule; not run in the harness, which predates the merge); Search → [Home, neutral][Search, accent]. Search from Library navigates and expands; the Home circle on Search goes Home.
  - Bounce (third round): collapsing, the mini-player's bottom peaks at 821.8 (rest 818) and the circle dips to 47.8pt; expanding, the mini-player's top peaks at 683.8 (rest 688). Both settle exactly.
  - Skia (fallback) frames of the morph looked continuous. No Impeller renders or device check yet.
  - **Fifth round (hand-off fix, glass bubble, hold, jelly):** 114 widget tests pass; the tab-bar and collapse tests also pass under `--enable-impeller`. On the real `MainScreen`, expanding: the bar's Search and the travelling glyph crossfade over ~5 frames (max 0.31 per frame), and the spring's dip shows only as 0.98/0.02, not a flip. Hold: the bubble goes 86→100pt wide. Drag at 9pt/frame: 100→142pt, then after stopping 142→93 (rebound)→102 (lifted rest).
  - **Travelling Search (fourth round, 4 tabs):** the button starts at (331.9, 780), which is exactly the bar's Search icon. It overshoots to 356.2 before settling at its corner (329,766–381,818), and on expanding returns to exactly (331.9, 780). All 109 widget tests pass.
  - **After merging `master` (the New tab):** Search moved from index 2 to `MainTabs.search` (3). The collapsed row's rules now use `MainTabs` instead of bare numbers, and `_glassTabItems` includes New. All widget tests re-run after the merge.
- **Now-playing transition v3 (2026-11-02, macOS, `flutter test`, Skia):** the 16 transition tests and all 101 widget tests pass; the analyzer is at the 16-info baseline. The glass close was filmed frame by frame (see the section). The trial merge with `collapsed-nav` passes 112 widget tests, plus the collapsed-capsule harness (see "Integration with collapsing chrome"). No renders, films or device check yet. The glass-under-fade guarantee was checked on the blur fallback's `BackdropFilter`; the shader path uses the same switch (`presence <= 0` skips both).
- **Not verified:** a real device, Metal (iOS), the GLES fallback on older Android, on-device performance, and an Xcode compile of the UIScene changes.

## Open feedback and issues

- **Waiting on the user's first device test.** Ask about:
  - **Edge strength:** `refraction`/`bevel`.
  - **Center clarity vs. legibility over bright art:** `adaptiveTint`, the tint opacities, `frost`.
  - **Scroll smoothness.** Each is a single `GlassStyle` field.
- **Now-playing:** waiting on the user's review (they got before/after renders). Likely knobs: the backdrop blur/saturation/drift (`_BlurredArtwork`), the scrim curve (`ArtworkBackdrop`), the pause shrink (`_buildArtwork`), button sizes, and `GlassStyle.control`.
- **Sliders:** waiting on the user's look on device. Knobs: idle/active thickness, hit height, resize duration (`kThickBar*`). **Classic mode changed too**: the user's request covered both sliders without a mode qualifier, unlike the "classic stays unchanged" rule for glass work. If they want classic back, gate on `VolumeSlider.glass` and add a `glass` flag to `PlaybackProgressSlider`.
- **Tab bar:** tuning knobs if the user asks (they got GIFs of the tap slide and drag). Likely tuning knobs: tap slide duration/curve (`_slideTo`, `_kSlideCurve`), snap spring (`_kSnapSpring`), lift size (`_kLiftScale`), bubble fill (`_BubblePainter`), and the lens falloff (`_proximity`). Colour comes only from the bubble mask; don't reintroduce per-tab colour fades or snaps. With 4 tabs each slot is narrower; check the bubble width and labels on device.
- **New tab:** waiting on the user's section picks and a device look. See "New tab" under "What's built" for the open questions.
- **Collapsing chrome:** waiting on the user's look on device. History: the first version (2026-11-02) cross-dissolved the full chrome into a separate row with a play/pause-only capsule, and expanded on any scroll up. The user rejected it: they wanted one fluid move, the mini-player keeping its art, title and artist, play/pause at its far right, and expanding only on a tab press or at the top. Third round (same day): the user asked for bounce and a slightly slower pace (now the underdamped spring), and set the tab rule (Search always trailing; Home leading on Search). Fourth round: tabs that move travel to their new spot (Search from its slot), and the row's tab rule is kept in one function for the user's upcoming extra tab. Possible knobs if it feels off: the spring's stiffness/ratio and the stagger `Interval`s.
- **Blur fallback mid-dissolve:** on the fallback path (Skia, web, tests) a glass surface at low `visibility` shows a saturated smear of what's behind it, visible mid-collapse in renders. The shader path (iOS) isn't affected. Pre-existing in `GlassContainer`'s fallback; scale its saturation by `visibility` if it matters.
- **Now-playing open/close transition (v3):** the user called it "golden" after the merge was loosened. Still waiting on their look on device. The art flight on open was approved in v1. v3's close (slide to the bottom, then the liquid merge with the capsule reaching out) answers their v2 feedback. Knobs, at the top of `now_playing_transition.dart` or in its geometry functions:
  - Springs: `_kOpenSpring` (230 / 0.88), `_kCloseSpring` (110 / 0.72), `_kSettleSpring` (125 / 0.62; lower the ratio for more wobble on landing). History: 150 / 0.9 and 170 / 0.74 at first, then 130 / 0.8 and 150 / 0.68 after "less stiff", then these after "a little more loose".
  - Dismissal: `_kDismissVelocity` (700 px/s), `_kDismissDistance` (150pt).
  - The merge: where it starts (`kNowPlayingMergeStart`, 0.4; was 0.3), how far the capsule reaches (`_kReach`, 18pt) and when (`reachAmount`), when the neck forms (`_kNeckSpacing`, 110pt) and its shape (`_neck`), the swell (`_kGulpSwell`, 5.5%; was 4%), and the blob's size and path in `closeFrame`.
  - Open: `compaction`, `sheetOpacity`, `artRect`.
  - Not done: the neck and blob use the player's backdrop material, not real glass. A glass neck would need a shape-aware shader mode, the same follow-up as the tab bar's lens bubble.
- **Legibility over near-white art in dark mode:** with the centre this clear (adaptive tint 0.15), white text over a near-white cover is hard to read. The user was told. Options: raise `adaptiveTint`, or adaptive foreground (glyphs flip dark over bright content, as iOS does), which is a bigger feature.
- **Dialogs on the inner navigator:** the chrome stays above the dim barrier, as in classic mode. iOS also dims the tab bar. Possible follow-up.
- **Light mode:** the adaptive tint lifts near-black content behind the glass toward gray. This is by design for legibility, and tunable.
- **Press glow on inner buttons:** holding an inner icon button for more than 100ms also triggers the capsule's glow (the outer `onTapDown` deadline).
- **Edge sampling:** refraction near the very screen edge clamps to the edge pixels.
- **Deployment target:** the user said their deployment target is iOS 27, but `IPHONEOS_DEPLOYMENT_TARGET`/Podfile are **15.0**. Left unchanged; the crash comes from building with the iOS 27 SDK.
- **After the UIScene migration, check on device:**
  - The app launches, and the Xcode console prints `iOSSystemPlugin registered`.
  - Lock-screen/Now Playing controls, Bluetooth metadata and the AirPlay button work.
  - Background audio continues with the screen locked.
  - Local file import works. `file_picker` uses the deprecated `UIApplication.windows`, which still works under scenes.
- **CarPlay** is still disabled (`#if false`, pending Apple's entitlement).

## Next in scope

**Before anything else:** reconcile the statuses above with the user (tab bar "in progress", now-playing "not started" despite the draft), and settle the iPhone Duo direction.

**Step 4: library grid**
- Lives in `lib/widgets/cards/` (`album_card.dart`, `artist_card.dart`, `media_card.dart`) and the grid in `library_screen.dart`.
- Scrolling alignment is already handled by the compositing-time layer.
- **Watch performance:** many backdrop filters in one grid. Consider a `BackdropGroup` per grid, or glass only on part of each card. `GlassStyle.frosted` exists for text-dense surfaces.

## Gotchas (read before changing anything)

### Environment and tooling
- **Flutter isn't installed in the container.** Download `flutter_linux_3.47.7-stable.tar.xz` from `storage.googleapis.com/flutter_infra_release` into the scratchpad. Warnings about running as root are harmless.
- **Any `pub get`** (including one triggered by a pubspec change) **regenerates the tracked `lib/l10n/app_localizations*.dart`**. Revert with `git checkout -- lib/l10n/`.
- **CRLF files:** `pubspec.yaml`, `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`. Python text-mode rewrites silently convert them to LF (this already happened once; see `083ded4`). Edit in binary mode or with the Edit tool, and check `git diff --stat` for whole-file churn.
- **Don't run `dart format` on whole files.** Several files (for example `main_screen.dart`) aren't format-clean, and the diff explodes.
- **Analyzer baseline is 16 infos.** "No new issues" means it still reports 16.
- **`flutter.dev`/`docs.flutter.dev` are blocked** by the session network policy. Use the docs source at `raw.githubusercontent.com/flutter/website/main/sites/docs/src/content/...`. iOS engine headers aren't in the Linux SDK; get them from `raw.githubusercontent.com/flutter/flutter/3.47.7/engine/src/flutter/shell/platform/darwin/ios/framework/Headers/`.
- **The GitHub API only reaches `makaic/musly`**; raw.githubusercontent.com works for public repos.
- **A stop hook requires all changes committed and pushed** before a turn ends.

### Testing
- **On macOS, `flutter test --enable-impeller` works without extra setup** (the shader loads; `GlassContainer.refractionAvailable` is true). But its offscreen renders show artifacts in glass that isn't being changed (white bands across the mini-player), so don't judge looks from them. Use them for behaviour, and the Linux/lavapipe setup below or a device for looks.
- **Testing the shader path:**
  - Install the driver with `apt-get install -y mesa-vulkan-drivers`, then run `flutter test --enable-impeller` (a hidden flag).
  - Plain `flutter test` uses Skia, so you only ever see the fallback.
- **`debugDisableShadows`** is true in tests, so shadows render hard-edged. Set it false in the test body and reset it **before the body ends**; the invariant check runs before `tearDown`.
- **Screen captures:** use `RepaintBoundary.toImage(pixelRatio: dpr)` on a boundary at the **root** (origin 0,0). The shader's coordinates assume that.
- **Filming interactions:** drive gestures with `startGesture`/`moveTo`, pump in fixed steps, and capture each step. Assemble GIFs **one at a time and crop each frame as soon as it's loaded**; holding full 3x screenshots for two films at once got the worker OOM-killed.
- **`tester.flingFrom` with a short offset reports zero velocity.** It sends 50 moves, and the velocity tracker keeps only the last 20 samples. If those cover less than the 18px touch slop, it's not a fling. Use offsets of ~50px or more.
- **Mounting `NowPlayingScreen` in tests:** mock the volume_controller method channel (`com.kurenai7968.volume_controller.method`) *and* its event channel (`...volume_listener_event`, `setMockStreamHandler`). Palette extraction never finishes under the fake clock; pre-warm it with `tester.runAsync(() => PaletteService.extractColors(image, songId))` when the colours matter. Unmount and `pump(3s)` at the end to drain timers. LRCLIB lookups log 400s; that's harmless.
- **Mounting the real `MainScreen` logs a RenderFlex overflow from the Home page** under the test font. It happens on the untouched base too; `tester.takeException()` it.
- **Fonts for realistic renders:** Roboto and MaterialIcons from the SDK's `bin/cache/artifacts/material_fonts`, CupertinoIcons from the pub cache.
- **Switching light/dark between captures:** set `themeAnimationDuration: Duration.zero` on the harness `MaterialApp`. Otherwise a re-pumped app is caught mid-way through its 200ms theme lerp, and you get gray icons and a half-lerped glass tint that look like app bugs but aren't.
- **Image loads in captures:** a local-file `coverArt` path works for `AlbumArtwork`. Pump inside `tester.runAsync` a few times before capturing, and throw away the first capture, which often misses the image.
- **`MainScreen` in tests:**
  - It needs `RecommendationService` and `LocalMusicService` on top of `createTestApp`'s providers, plus a fake `PlayerProvider` that overrides `currentSong` and friends.
  - Mounting it twice in one process throws at teardown (`UsageTimeService` singleton disposed twice). That's a harness artifact, not an app bug.
- **The temporary harnesses (`test/zz_*.dart`) were deleted.** Recreate them as needed; don't commit them.

### Shader and compositing (don't "simplify" these)
- **Platform support:** `ImageFilter.shader` is **Impeller-only**. Web returns `isShaderFilterSupported == false`.
- **Coordinates:**
  - A backdrop shader's `FlutterFragCoord()` is **render-target physical px, top-left origin on every backend**, and `u_size` is the render target. The input texture is the **whole backdrop**, so sampling outside the glass works; that's what makes lensing possible.
  - Only the texture lookup needs the Y flip on GLES. These facts were measured with a probe shader on Impeller.
- **Why the position is computed at compositing time:**
  - `paint()` does **not** re-run when an ancestor moves the glass (scrolling, slide animations, route transitions).
  - So `_LiquidGlassLayer` (a `BackdropFilterLayer` subclass) overrides `alwaysNeedsAddToScene => true` and computes the screen rect in `addToScene` by walking the ancestors' `applyTransform`.
  - It supplies the filter by overriding the **`filter` getter**. Don't move this back to `localToGlobal` in paint.
- **The `configure()` workaround:**
  - The inherited `BackdropFilterLayer` setters call `markNeedsAddToScene`, which **asserts** on an always-re-added layer. That's why `configure()` flips the flag while setting `backdropKey`.
  - The key's id is private, so the setter is the only way to set it.
- **Uniform copies:** uniforms are **copied when the filter is created**, so one `FragmentShader` per surface can be mutated every frame.
- **BackdropGroup trade-off:** grouped surfaces share one snapshot, so they can't see or refract each other (the 2pt sliver).
- **Fractional `Opacity` breaks glass.** An `Opacity`/`FadeTransition` below 1 renders its subtree into an offscreen layer whose render target isn't the screen. The shader's `FlutterFragCoord`/`u_size` are then relative to that layer, so the glass samples the wrong part of the backdrop (seen as an opaque salmon disc in the first now-playing render). Fade glass with `GlassContainer.visibility`. To fade a whole subtree that contains glass, wrap it in `GlassPresence` and keep the presence at 0 while the fade is fractional (as `NowPlayingTransition` does). Route transitions that fade (e.g. Android's zoom transition) will show this briefly on glass inside them.

### Glass inside glass, and invisible glass (learned 2026-11-02)
- **Never nest a `GlassContainer` inside another one's child.** Impeller renders a backdrop filter's children into a subpass sized to that surface, so a nested shader's screen coordinates are wrong (same failure as fractional `Opacity`): it came out as a dark pill. Draw the inner glass as a sibling **over** the outer one, in its own `BackdropGroup` (see `GlassTabBar._buildLens`).
- **Glass that should see other glass needs its own `BackdropGroup`.** The chrome's shared group snapshots the page before any chrome is drawn, so a grouped surface passing over the tab bar shows the page there, not the bar. (The travelling Search button has its own group; the mini-player still shares, which is fine because it never rests over the bar.)
- **Don't leave glass built at ~0 visibility.** It isn't invisible on Impeller (it hid the icon under it). Remove it below a small threshold instead (2% for the travelling button and the lens).

### Layout
- **Inner navigator inset:**
  - In glass mode it deliberately keeps the **real** system bottom inset. Most `showModalBottomSheet` calls in the app land on the inner navigator, and many sheets use `SafeArea`. Giving them the chrome height would add a ~150pt empty band.
  - Pages get the chrome height only through the `MainScreen.*` helpers.
- **Any new scrollable page** must end with `MainScreen.scrollEndPadding(context, base)` (or wrap auto-padded lists in `clearFloatingChrome`). Otherwise its last item hides behind the chrome.
- **Where things land:**
  - Pages pushed via `NavigationHelper.push` go to the **inner** navigator, under the chrome.
  - Sheets there make the chrome slide away; dialogs don't.
  - Snackbars land on `MainScreen`'s Scaffold, above the chrome.

### iOS
- **Native registration:** any new native channel or platform view must be registered in `AppDelegate.didInitializeImplicitFlutterEngine`, **not** `didFinishLaunchingWithOptions`. The window and engine don't exist yet at launch under UIScene.
- **CarPlay:** re-enable by uncommenting its role inside the *existing* scene manifest (not a second manifest), and remove `#if false` in `CarPlaySceneDelegate.swift`.
