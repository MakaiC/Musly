# Liquid Glass theme: progress & handoff

Last updated 2026-11-02 (collapsing bottom chrome, branch `collapsed-nav`, merged with the New tab); before that 2026-11-02 (New tab, branch `new-tab`); 2026-11-02 (sliders, branch `slider-work`); 2026-11-03 · branch `claude/sleepy-gates-rm92oh` (continues `claude/brave-bohr-80alrl`) · Flutter **3.47.7** (pinned in CI)

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
- [ ] Now-playing: `lib/screens/player/now_playing_screen.dart` + `lib/widgets/now_playing/*`. The user marks it not started; an unaccepted draft is in `5000ad8`.
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

## Scope and ground rules (from the user)

Restyle these components with an iOS 26/27 Liquid Glass look, in this order: mini-player, bottom nav, now-playing, library grid.

- Work one component at a time. After each one, stop and report what changed and where. **Show the diff before the user builds.**
- Build reusable widgets (`GlassContainer`), not one-off styling.
- Get **as close to Apple's Liquid Glass as possible.** The user is exacting about this: center almost perfectly clear, edges warping the content behind.
- Keep theming intact (dark/light, accent, dynamic color). Glass sits on top of the theme.
- **Do not touch:** auth/login, settings screens, the API/Subsonic client, state management, or platform build config. The only exception is a minimal unavoidable wiring change, and it must be **flagged first**. (The settings scroll-padding fix was explicitly approved.)
- Don't touch playback logic, the app icon, the name or branding.
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
  - **Liquid stretch:** while `_pos` animates, the bubble lengthens up to 18% (and flattens a little) with its velocity.
- **Two separate animation paths, as the user suggested:**
  - **Tap:** `onTabSelected` fires, the parent changes `currentIndex`, and `didUpdateWidget` runs `_slideTo`. That's an `animateTo` with `Cubic(0.3, 0, 0.1, 1)` over 260ms + 60ms per tab travelled (~320ms to a neighbour), so it gets going immediately and eases into place. External index changes (back button, `NavigationHelper`) take the same path.
  - **Drag** (`onHorizontalDrag*`): the bubble *lifts* (`_lift`: +8% size, clearer fill, brighter rim, soft shadow; the icon under it grows up to 12%, like a lens) and tracks the finger 1:1. Right after the drag is recognised, `_catchUp` blends it from where it was to the finger over 160ms, so it never jumps. It rubber-bands up to 0.18 tabs past the end tabs. Each tab crossed gives a `HapticFeedback.selectionClick()`. **Nothing is selected mid-drag.**
  - **Release:** a `SpringSimulation` (stiffness 520, damping ratio 0.78, so a hint of overshoot) to the nearest tab of `pos + velocity × 0.12s`, so a flick carries on to the tab it's heading for. It selects that tab if it differs from the current one; releasing over the current tab does nothing.
- **`currentIndex` is the source of truth.** If the parent doesn't adopt a selection (the Search easter egg opens a page instead), a post-frame check slides the bubble back.
- **Reduce motion:** taps and snaps jump; the drag still tracks.
- **Semantics:** each tab is a button with `selected` and a tap action.
- **`main_screen.dart`:** `_buildGlassBottomNav` now just builds a `GlassTabBar`. The old inline tap closure became `_onGlassTabSelected`, with an identical body: `popUntil` the first route, the 11-taps-on-Search easter egg, `setState(_currentIndex)`. A drag released onto Search counts as one easter-egg tap. The classic `_buildBottomNav` is untouched.
- The bubble is **painted** (`_BubblePainter`), not a nested backdrop filter. A true magnifying-lens bubble that refracts the icons under it would need a nested, ungrouped backdrop and a magnification mode in the shader; that's a possible follow-up.
- **Tests:** `test/widgets/glass_tab_bar_test.dart` (10 tests) covers the initial state, the tap slide (not a teleport, settled in <½s), slow-drag 1:1 tracking with highlight and haptics, the bubble-as-window masking (an edge splits an icon into gray outside and accent inside, following the edge exactly), release over the current tab, the flick projection, the bubble returning when a selection isn't adopted, external index changes, reduce motion and semantics.

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
  - **Trailing Search button** (`GlassTabButton`): **travels from its slot in the bar to its corner** (the user's request, fourth round). Its rect lerps from a 52pt circle centred on the bar's own Search icon (`GlassTabBar.slotCentre` + `GlassTabBar.iconCentreOffset`) to the corner, with the bar's progress (`tabT`, overshoot included, so it bounces in). The glyph stays solid (`glyphVisibility: 1`) while the glass forms around it (0.05–0.6). The bar stops drawing that tab as soon as it starts collapsing (`GlassTabBar.detachedTabs`), so it never shows twice. Expanding runs the same trip in reverse, back onto the bar's icon. It used to swell in place at the corner.
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
  - **Travelling Search (fourth round, 4 tabs):** the button starts at (331.9, 780), which is exactly the bar's Search icon. It overshoots to 356.2 before settling at its corner (329,766–381,818), and on expanding returns to exactly (331.9, 780). All 109 widget tests pass.
  - **After merging `master` (the New tab):** Search moved from index 2 to `MainTabs.search` (3). The collapsed row's rules now use `MainTabs` instead of bare numbers, and `_glassTabItems` includes New. All widget tests re-run after the merge.
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
- **Fractional `Opacity` breaks glass.** An `Opacity`/`FadeTransition` below 1 renders its subtree into an offscreen layer whose render target isn't the screen. The shader's `FlutterFragCoord`/`u_size` are then relative to that layer, so the glass samples the wrong part of the backdrop (seen as an opaque salmon disc in the first now-playing render). Fade glass with `GlassContainer.visibility`. Route transitions that fade (e.g. Android's zoom transition) will show this briefly on glass inside them.

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
