// Renders the Navinix app icon sources into assets/app_icon/render/.
//
//   flutter test tools/app_icon/render_app_icon_test.dart
//
// Then install them as described in THEME_PROGRESS.md ("App name and icon").
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _out = 'assets/app_icon/render';

enum Look { light, dark }

/// The beamed eighth notes, in unit-tile coordinates (0..1).
Path notePath(Rect tile) {
  Offset p(double x, double y) =>
      Offset(tile.left + x * tile.width, tile.top + y * tile.height);
  final w = tile.width;
  final path = Path();
  // Beam: a slanted slab, rising to the right.
  path.moveTo(p(0.33, 0.29).dx, p(0.33, 0.29).dy);
  path.lineTo(p(0.71, 0.185).dx, p(0.71, 0.185).dy);
  path.lineTo(p(0.71, 0.325).dx, p(0.71, 0.325).dy);
  path.lineTo(p(0.33, 0.43).dx, p(0.33, 0.43).dy);
  path.close();
  // Stems.
  final stem = 0.074 * w;
  path.addRect(Rect.fromLTWH(p(0.33, 0).dx, p(0, 0.33).dy, stem, 0.43 * w));
  path.addRect(Rect.fromLTWH(
      p(0.71, 0).dx - stem, p(0, 0.24).dy, stem, 0.43 * w));
  // Heads: tilted ovals, stem on their right edge.
  void head(double cx, double cy) {
    final c = p(cx, cy);
    final oval = Path()
      ..addOval(Rect.fromCenter(
          center: Offset.zero, width: 0.285 * w, height: 0.20 * w));
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(-0.38);
    path.addPath(oval, Offset.zero, matrix4: m.storage);
  }

  head(0.272, 0.765);
  head(0.652, 0.672);
  return path;
}

ui.RSuperellipse tileShape(Rect r) =>
    ui.RSuperellipse.fromRectAndRadius(r, Radius.circular(r.width * 0.255));

Path tilePath(Rect r) => Path()..addRSuperellipse(tileShape(r));

/// Draws a glowing chromatic streak along part of the tile's edge.
void streak(Canvas c, Rect tile, double from, double to, List<Color> bands,
    {double inset = 0, double width = 26, double sigma = 7, double core = 0.0,
    Color coreColor = Colors.white}) {
  for (var b = 0; b < bands.length; b++) {
    final r = tile.deflate(inset + b * width * 0.45);
    final metric = tilePath(r).computeMetrics().first;
    final len = metric.length;
    const pieces = 40;
    for (var i = 0; i < pieces; i++) {
      final t0 = from + (to - from) * i / pieces;
      final t1 = from + (to - from) * (i + 1.0) / pieces;
      final mid = (i + 0.5) / pieces;
      final fade = math.pow(math.sin(math.pi * mid), 0.8).toDouble();
      final seg = metric.extractPath(
          (t0 % 1) * len, ((t1 % 1) * len).clamp(0, len).toDouble());
      c.drawPath(
        seg,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = width * (1 - b * 0.18)
          ..color = bands[b].withValues(alpha: bands[b].a * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }
  }
  if (core > 0) {
    final metric = tilePath(tile.deflate(inset + 2)).computeMetrics().first;
    final len = metric.length;
    const pieces = 40;
    for (var i = 0; i < pieces; i++) {
      final t0 = from + (to - from) * i / pieces;
      final t1 = from + (to - from) * (i + 1.0) / pieces;
      final mid = (i + 0.5) / pieces;
      final fade = math.pow(math.sin(math.pi * mid), 1.6).toDouble();
      c.drawPath(
        metric.extractPath((t0 % 1) * len, (t1 % 1) * len),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = core
          ..color = coreColor.withValues(alpha: fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }
}

/// Paints the icon on a [size]² canvas. [background] false leaves it
/// transparent around the tile (Android adaptive foreground).
void paintIcon(Canvas c, double size, Look look,
    {bool background = true, double tileFraction = 0.72}) {
  final full = Rect.fromLTWH(0, 0, size, size);
  final dark = look == Look.dark;
  if (background) {
    c.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.linear(
          full.topCenter,
          full.bottomCenter,
          dark
              ? const [Color(0xFF000000), Color(0xFF000000)]
              : const [Color(0xFFF5F5F7), Color(0xFFE3E3E7)],
        ),
    );
  }
  final ts = size * tileFraction;
  final tile = Rect.fromCenter(
      center: full.center.translate(0, -size * 0.004), width: ts, height: ts);
  final shape = tilePath(tile);
  final k = ts / 737; // stroke scale relative to the 1024 design

  // Soft drop shadow (light only).
  if (!dark) {
    c.drawPath(
      shape.shift(Offset(0, 22 * k)),
      Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 34 * k),
    );
  }

  // Glass body.
  c.save();
  c.clipPath(shape);
  c.drawRect(
    tile,
    Paint()
      ..shader = ui.Gradient.linear(
        tile.topLeft,
        tile.bottomRight,
        dark
            ? const [Color(0xFF0E1A26), Color(0xFF05090F), Color(0xFF0A121B)]
            : const [Color(0xFFFBFBFD), Color(0xFFEDEDF1), Color(0xFFF6F6F8)],
        const [0, 0.6, 1],
      ),
  );
  // Inner bevel: a soft band just inside the edge.
  c.drawPath(
    tilePath(tile.deflate(10 * k)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26 * k
      ..color = dark ? const Color(0x5536506A) : const Color(0x1A000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * k),
  );
  // Top-left specular sheen.
  c.drawPath(
    tilePath(tile.deflate(5 * k)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * k
      ..shader = ui.Gradient.linear(
        tile.topLeft,
        tile.bottomRight,
        dark
            ? const [Color(0x99B8C8D8), Color(0x00FFFFFF), Color(0x55B8C8D8)]
            : const [Color(0xFFFFFFFF), Color(0x00FFFFFF), Color(0xCCFFFFFF)],
        const [0, 0.5, 1],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * k),
  );

  // Chromatic streaks hugging the rim. Fractions run clockwise from the
  // top-left corner along the superellipse's perimeter.
  final top = dark
      ? const [Color(0xFF2A6CFF), Color(0xFFFF2D8A), Color(0xFFFF8A3D)]
      : const [Color(0xFF1F6BFF), Color(0xFFFF2D6E), Color(0xFF7A1FFF)];
  final bottom = dark
      ? const [Color(0xFFFF7A2E), Color(0xFFFF2D8A), Color(0xFF2A6CFF)]
      : const [Color(0xFFFF2D55), Color(0xFFB02DFF), Color(0xFF1F8BFF)];
  // Top edge (right half) round the top-right corner, down the right side.
  streak(c, tile, 0.06, 0.34, top,
      inset: 6 * k, width: 30 * k, sigma: 8 * k, core: dark ? 7 * k : 4 * k,
      coreColor: dark ? const Color(0xFFFFF4E0) : Colors.white);
  // Bottom-left corner.
  streak(c, tile, 0.55, 0.80, bottom,
      inset: 6 * k, width: 30 * k, sigma: 8 * k, core: dark ? 7 * k : 3 * k,
      coreColor: dark ? const Color(0xFFFFF4E0) : Colors.white);
  c.restore();

  // Outer hairline.
  c.drawPath(
    shape,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * k
      ..color = dark ? const Color(0x664F6478) : const Color(0x33000000),
  );

  // The note, with a chromatic fringe like light through glass.
  final note = notePath(tile);
  c.drawPath(
    note.shift(Offset(-7 * k, 5 * k)),
    Paint()
      ..color = (dark ? const Color(0xFFFF3B6B) : const Color(0xFFFF2D55))
          .withValues(alpha: dark ? 0.75 : 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, (dark ? 9 : 5) * k),
  );
  c.drawPath(
    note.shift(Offset(7 * k, -5 * k)),
    Paint()
      ..color = (dark ? const Color(0xFF2E7BFF) : const Color(0xFF1F6BFF))
          .withValues(alpha: dark ? 0.8 : 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, (dark ? 9 : 5) * k),
  );
  // Light bleeding from the rim streaks into the glyph's ends.
  void glow(Offset at, Color color, double r) => c.drawCircle(
      at,
      r * k,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6 * k));
  final b = note.getBounds();
  glow(Offset(b.left + 18 * k, b.bottom - 30 * k),
      const Color(0x882A6CFF), 60);
  c.drawPath(
    note,
    Paint()
      ..shader = ui.Gradient.linear(
        b.topCenter,
        b.bottomCenter,
        dark
            ? const [Color(0xFFFFFFFF), Color(0xFFD6D9E0)]
            : const [Color(0xFF1A1A1E), Color(0xFF050507)],
      ),
  );
}

/// The note alone, white on transparent (Android themed icon).
void paintMonochrome(Canvas c, double size) {
  final full = Rect.fromLTWH(0, 0, size, size);
  final tile = Rect.fromCenter(
      center: full.center, width: size * 0.78, height: size * 0.78);
  c.drawPath(notePath(tile), Paint()..color = Colors.white);
}

Future<void> save(String name, int size, void Function(Canvas) paint,
    {bool grayscale = false}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  if (grayscale) {
    c.saveLayer(
        null,
        Paint()
          ..colorFilter = const ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0, 0, 0, 1, 0,
          ]));
  }
  paint(c);
  if (grayscale) c.restore();
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render icons', () async {
    Directory(_out).createSync(recursive: true);
    await save('light_1024', 1024, (c) => paintIcon(c, 1024, Look.light));
    await save('dark_1024', 1024, (c) => paintIcon(c, 1024, Look.dark));
    await save('tinted_1024', 1024, (c) => paintIcon(c, 1024, Look.dark),
        grayscale: true);
    // Android adaptive foreground: transparent, the tile filling the
    // drawable (the XML insets it 16%, keeping it inside the mask).
    await save('fg_light_432', 432,
        (c) => paintIcon(c, 432, Look.light, background: false,
            tileFraction: 0.86));
    await save('fg_dark_432', 432,
        (c) => paintIcon(c, 432, Look.dark, background: false,
            tileFraction: 0.86));
    await save('mono_432', 432, (c) => paintMonochrome(c, 432));
  });
}
