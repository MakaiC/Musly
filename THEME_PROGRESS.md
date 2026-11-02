# Liquid Glass theme: progress & handoff

Last updated 2026-11-02 · branch `claude/sleepy-gates-rm92oh` (continues `claude/brave-bohr-80alrl`) · Flutter **3.47.7** (pinned in CI)

## Status at a glance

| Item | State |
|---|---|
| 1. Mini-player | ✅ Built, plus a polish pass after the user's first look: proportions, clearer centre, frosted rim, stronger refraction. **Waiting on the user's review.** |
| Floating-chrome layout + page scroll padding | ✅ Built (groundwork for steps 1 and 2) |
| iOS UIScene lifecycle migration | ✅ Done. **Not yet compiled in Xcode**; the first build is the check |
| 2. Bottom navigation bar | ⏭ **Next**, once the user signs off on the mini-player polish (see the spec under "Next in scope") |
| 3. Now-playing full-screen view | Not started |
| 4. Library grid (album/artist cards) | Not started |

Nothing has run on a real device yet. The user's next step is building to their iPhone.

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
| *(this session)* | Mini-player polish: 60pt capsule and art geometry; edge-weighted frost/veil, clearer centre and stronger refraction in the shader and `GlassStyle` |

## What's built

### `GlassContainer`: the reference implementation (`lib/widgets/common/glass_container.dart`)

Every future glass component should use this. Don't restyle surfaces one by one.

- `GlassContainer(...)` / `GlassContainer.capsule(...)`. The capsule radius is always half the shortest side.
- Params: `child`, `borderRadius`, `style`, `padding`, `width`, `height`, `onTap`, `onLongPress`, `pressScale`.
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
  - Chrome spans 688→852 (164pt), and the overlap reported to pages is 164.
  - The last list item ends exactly 16pt above the chrome.
  - With a sheet open, the chrome moves to y≈917 (off-screen) and the sheet still sees the 34pt inset.
- **Real `MainScreen`, classic mode:** pages stop at 695.5, overlap is 0, and every spacer returns its original value.
- **Tests:** 101/101 pass. The analyzer shows the **16 pre-existing infos (the baseline), no new ones.**
- **Not verified:** a real device, Metal (iOS), the GLES fallback on older Android, on-device performance, and an Xcode compile of the UIScene changes.

## Open feedback and issues

- **Waiting on the user's first device test.** Ask about:
  - **Edge strength:** `refraction`/`bevel`.
  - **Center clarity vs. legibility over bright art:** `adaptiveTint`, the tint opacities, `frost`.
  - **Scroll smoothness.** Each is a single `GlassStyle` field.
- **Tab bar is still the old near-opaque pill** (`_buildGlassBottomNav`). It's already inside the `BackdropGroup` but doesn't use `GlassContainer` yet. That's step 2.
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

**Step 2: bottom nav.** The user's reference is an iOS 27.2 Apple Music screenshot:
- A floating glass capsule tab bar with a separate glass mini-player capsule above it.
- The selected tab sits in a lighter glass "lens" pill with an accent-colored icon and label; the others are neutral.

Musly has **3 tabs** (Home, Library, Search).

Implementation notes:
- Build it in `_buildGlassBottomNav` with `GlassContainer.capsule`. It's already inside the `BackdropGroup`.
- Keep the tap logic exactly as it is: `popUntil` the first route; the **11-taps-on-Search easter egg** opening `FantasyScreen` (`_searchTapCount`/`_lastSearchTap`); `setState(_currentIndex)`.
- Changes to the chrome height flow to pages automatically through `extendBody`, so no padding work is needed.
- Consider an animated selected pill.

**Step 3: now-playing**
- Lives in `lib/screens/player/now_playing_screen.dart` and `lib/widgets/now_playing/*`.
- It's a modal bottom sheet on the **root** navigator, so it isn't affected by the chrome.
- Glass controls over artwork probably want `GlassStyle.clear`.

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
