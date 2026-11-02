// Liquid Glass backdrop shader (Impeller only; see GlassContainer).
//
// Models a slab of glass with a flat, clear centre and a rounded bevel along
// its edge. Across the bevel the surface curves away, so light reaching the
// eye there was bent in from *outside* the shape: content around the glass is
// pulled into and squeezed along the rim (lensing), with a little chromatic
// dispersion. The centre passes the backdrop through nearly untouched (an
// optional light frost, a vibrancy boost and a faint adaptive tint), while
// frost and tint thicken toward the rim, so the glass reads as clear in the
// middle and frosted at its edges.
//
// Coordinates: as a BackdropFilter, FlutterFragCoord() is in render-target
// pixels (top-left origin on every backend) and the input texture is the
// whole backdrop, so u_rect must be the glass bounds in that same space.

#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;          // Set by the engine: backdrop texture size (px).
uniform vec4 u_rect;          // Glass bounds in backdrop px: x, y, w, h.
uniform vec4 u_shape;         // Corner radius, bevel width, max refraction
                              // offset, normal-field radius (all px).
uniform vec4 u_optics;        // Dispersion (0..1), frost radius (px),
                              // saturation, specular strength.
uniform vec4 u_tint;          // Tint colour (straight alpha) and base opacity.
uniform float u_adaptive;     // Extra tint where content would fight legibility.
uniform vec4 u_edge;          // Rim frost radius (px), rim veil opacity,
                              // width of the frosted band (px), how far the
                              // veil is lifted toward white (0..1).

uniform sampler2D u_texture;  // Set by the engine: the backdrop.

out vec4 frag_color;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

// Signed distance to a rounded box centred at the origin (negative inside).
float sdRoundBox(vec2 q, vec2 halfSize, float r) {
  vec2 a = abs(q) - halfSize + r;
  return length(max(a, 0.0)) + min(max(a.x, a.y), 0.0) - r;
}

// Outward surface direction. Uses a corner radius of at least the bevel width
// so the field is smooth wherever the bevel bends light.
vec2 outwardNormal(vec2 q, vec2 halfSize, float r) {
  vec2 s = vec2(q.x < 0.0 ? -1.0 : 1.0, q.y < 0.0 ? -1.0 : 1.0);
  vec2 a = abs(q) - halfSize + r;
  if (a.x > 0.0 && a.y > 0.0) {
    return s * normalize(a);
  }
  return a.x > a.y ? vec2(s.x, 0.0) : vec2(0.0, s.y);
}

vec3 tap(vec2 px) {
  px = clamp(px, vec2(0.5), u_size - vec2(0.5));
  vec2 uv = px / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_texture, uv).rgb;
}

// Per-pixel pseudo-random angle (interleaved gradient noise), so the frost
// kernel is rotated differently at every pixel. That turns the ghosting a
// small kernel would leave into a fine grain, like real frosted glass.
float grainAngle(vec2 p) {
  return 6.2831853 *
         fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// Backdrop colour at px, optionally softened by a 12-tap Vogel disc of radius
// `frost` (plus the centre), weighted toward the middle.
vec3 scene(vec2 px, float frost, float angle) {
  if (frost < 0.5) {
    return tap(px);
  }
  vec3 col = tap(px);
  float total = 1.0;
  for (int i = 0; i < 12; i++) {
    float f = (float(i) + 0.5) / 12.0;
    float r = sqrt(f);
    float a = float(i) * 2.3999632 + angle;   // Golden angle.
    float w = 1.0 - 0.6 * f;
    col += tap(px + vec2(cos(a), sin(a)) * r * frost) * w;
    total += w;
  }
  return col / total;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 halfSize = u_rect.zw * 0.5;
  vec2 q = p - (u_rect.xy + halfSize);

  float radius = u_shape.x;
  float bevel = max(u_shape.y, 1.0);
  float refraction = u_shape.z;

  // 1 at the rim, 0 where the bevel meets the flat centre.
  float depth = max(-sdRoundBox(q, halfSize, radius), 0.0);
  float k = 1.0 - clamp(depth / bevel, 0.0, 1.0);
  // Circular bevel profile: zero slope at the centre, steep at the rim.
  float lens = 1.0 - sqrt(max(1.0 - k * k, 0.0));

  vec2 n = outwardNormal(q, halfSize, u_shape.w);
  vec2 offset = n * refraction * lens;

  // Frosted band: 1 at the rim, easing to 0 a band-width in, where the glass
  // is clear.
  float edge = 1.0 - clamp(depth / max(u_edge.z, 1.0), 0.0, 1.0);
  edge = edge * edge * (3.0 - 2.0 * edge);

  float dispersion = u_optics.x;
  float frost = mix(u_optics.y, u_edge.x, edge);
  float angle = frost < 0.5 ? 0.0 : grainAngle(p);
  vec3 col;
  if (dot(offset, offset) * dispersion * dispersion < 0.25) {
    col = scene(p + offset, frost, angle);
  } else {
    // Shorter wavelengths bend more.
    col.r = scene(p + offset * (1.0 - dispersion), frost, angle).r;
    col.g = scene(p + offset, frost, angle).g;
    col.b = scene(p + offset * (1.0 + dispersion), frost, angle).b;
  }

  // Vibrancy.
  col = clamp(mix(vec3(dot(col, kLuma)), col, u_optics.z), 0.0, 1.0);

  // Adaptive tint: a dark tint thickens over bright content and a light tint
  // over dark content, so foreground text stays legible on clear glass. It
  // only ramps up for strongly conflicting content; mid-tones stay clear.
  float lum = dot(col, kLuma);
  float fight = dot(u_tint.rgb, kLuma) > 0.5 ? 1.0 - lum : lum;
  fight = smoothstep(0.35, 1.0, fight);
  col = mix(col, u_tint.rgb, clamp(u_tint.a + u_adaptive * fight, 0.0, 1.0));
  // Frosted rim: a milky veil of the tint lifted toward white, so it reads as
  // scattered light rather than a darker ring on dark glass.
  vec3 milk = mix(u_tint.rgb, vec3(1.0), u_edge.w);
  col = mix(col, milk, clamp(u_edge.y * edge, 0.0, 1.0));

  // Light from the top-left catching the bevel, and a fainter internal
  // reflection on the opposite edge.
  float facing = dot(n, vec2(-0.7071, -0.7071));
  float band = k * k * k;
  float spec = band * (0.55 * pow(max(facing, 0.0), 2.0) +
                       0.25 * pow(max(-facing, 0.0), 2.0));
  col += u_optics.w * spec;

  frag_color = vec4(clamp(col, 0.0, 1.0), 1.0);
}
