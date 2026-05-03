shader_type canvas_item;
render_mode unshaded;

// ── Animation ──────────────────────────────────────────────────────────────
uniform float time_scale    : hint_range(0.0, 5.0)  = 0.5;
uniform float flow_speed    : hint_range(0.0, 3.0)  = 0.3;

// ── Shape ─────────────────────────────────────────────────────────────────
// warp_strength: FBM wobble on blob surfaces + controls smin merge softness
// ridge_strength: brightness of the bright surface-tension highlight ring
// dot_strength: intensity of the outer halo glow around each blob
uniform float pixel_size    : hint_range(1.0, 64.0) = 5.0;
uniform float noise_scale   : hint_range(0.5, 12.0) = 3.5;
uniform float warp_strength : hint_range(0.0, 6.0)  = 2.5;
uniform float ridge_strength: hint_range(0.0, 2.0)  = 0.50;
uniform float dot_strength  : hint_range(0.0, 2.0)  = 0.40;

// ── Color ──────────────────────────────────────────────────────────────────
uniform vec4  color_bg     : source_color = vec4(0.010, 0.003, 0.018, 1.0);
uniform vec4  color_mid    : source_color = vec4(0.130, 0.015, 0.200, 1.0);
uniform vec4  color_bright : source_color = vec4(0.960, 0.090, 0.820, 1.0);
uniform float brightness   : hint_range(0.0, 4.0)  = 0.75;
uniform float vignette_pow : hint_range(0.0, 2.0)  = 0.50;

// ── Pulse ─────────────────────────────────────────────────────────────────
uniform float pulse_pos_x      : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_pos_y      : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_strength   : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_brightness : hint_range(0.0, 3.0) = 0.0;

// ── Gradient noise (for FBM surface wobble) ────────────────────────────────
vec2 ghash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(ghash(i + vec2(0,0)), f - vec2(0,0)),
		    dot(ghash(i + vec2(1,0)), f - vec2(1,0)), u.x),
		mix(dot(ghash(i + vec2(0,1)), f - vec2(0,1)),
		    dot(ghash(i + vec2(1,1)), f - vec2(1,1)), u.x), u.y);
}

float fbm(vec2 p) {
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	float v = 0.0;
	v += 0.5000 * gnoise(p); p = m * p;
	v += 0.2500 * gnoise(p); p = m * p;
	v += 0.1250 * gnoise(p); p = m * p;
	v += 0.0625 * gnoise(p);
	return v;
}

// ── Smooth minimum — blends two SDF distances for organic blob merging ─────
// k = merge softness: small k = sharp join, large k = blobs flow into each other
float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// ── Five lava-lamp blobs on independent Lissajous paths ───────────────────
// bs  = blob_scale (derived from noise_scale so inspector changes work)
// k   = smin merge softness
// Returns signed distance: negative = inside merged blob, positive = outside.
float metaballs(vec2 p, float t, float bs, float k) {
	float d = 100.0;

	// Large slow blob — main anchor
	vec2 p0 = vec2(sin(t * 0.230) * bs * 1.10, cos(t * 0.170) * bs * 0.50);
	d = smin(d, length(p - p0) - bs * 0.40, k);

	// Medium blob
	vec2 p1 = vec2(cos(t * 0.190 + 1.618) * bs * 0.92, sin(t * 0.290 + 2.399) * bs * 0.48);
	d = smin(d, length(p - p1) - bs * 0.34, k);

	// Large blob on different axis
	vec2 p2 = vec2(sin(t * 0.310 + 3.141) * bs * 1.15, cos(t * 0.130 + 0.618) * bs * 0.45);
	d = smin(d, length(p - p2) - bs * 0.38, k);

	// Smaller faster blob
	vec2 p3 = vec2(cos(t * 0.170 + 4.712) * bs * 0.78, sin(t * 0.230 + 1.571) * bs * 0.52);
	d = smin(d, length(p - p3) - bs * 0.29, k);

	// Small erratic blob — breaks up symmetry
	vec2 p4 = vec2(sin(t * 0.410 + 0.785) * bs * 0.62, cos(t * 0.370 + 3.926) * bs * 0.47);
	d = smin(d, length(p - p4) - bs * 0.24, k);

	// Medium blob with high phase offset — fills gaps left by others
	vec2 p5 = vec2(cos(t * 0.250 + 2.094) * bs * 0.88, sin(t * 0.150 + 5.236) * bs * 0.49);
	d = smin(d, length(p - p5) - bs * 0.31, k);

	// Small fast blob — darts around, keeps the motion lively
	vec2 p6 = vec2(sin(t * 0.480 + 1.047) * bs * 0.58, cos(t * 0.330 + 4.189) * bs * 0.44);
	d = smin(d, length(p - p6) - bs * 0.20, k);

	// Medium blob on wide x-arc — occasionally merges with the large blobs
	vec2 p7 = vec2(cos(t * 0.200 + 3.665) * bs * 1.05, sin(t * 0.260 + 0.524) * bs * 0.43);
	d = smin(d, length(p - p7) - bs * 0.29, k);

	return d;
}

void fragment() {
	// ── Pixelation ────────────────────────────────────────────────────────
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px_uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float aspect = screen_size.x / screen_size.y;
	// uv_raw: scaled UV (0..noise_scale range), used for FBM lookups
	vec2 uv_raw = vec2(px_uv.x * aspect, px_uv.y) * noise_scale;

	float t = TIME * time_scale;
	float tf = TIME * flow_speed;

	// ── Pulse displacement (same as other chapters) ───────────────────────
	vec2 pulse_uv = vec2(pulse_pos_x, pulse_pos_y);
	float dist_to_pulse = distance(px_uv, pulse_uv);
	float pulse_factor = smoothstep(0.3, 0.0, dist_to_pulse) * pulse_strength;
	uv_raw += normalize(px_uv - pulse_uv) * pulse_factor * 0.8;

	// Center the UV so blob positions sit at screen-center
	vec2 uv = uv_raw - vec2(aspect, 1.0) * (noise_scale * 0.5);

	// ── FBM wobble — makes blob surfaces feel liquid/jelly, not rigid ─────
	vec2 q = vec2(
		fbm(uv_raw * 0.55 + tf * 0.18),
		fbm(uv_raw * 0.55 + vec2(3.7, 1.9) + tf * 0.14)
	);
	vec2 uv_warped = uv + warp_strength * 0.16 * q;

	// ── Metaball SDF ──────────────────────────────────────────────────────
	float bs = noise_scale * 0.50;               // scales with inspector noise_scale
	float k  = clamp(warp_strength * 0.11, 0.12, 0.50); // merge softness
	float d  = metaballs(uv_warped, t, bs, k);

	// ── Layer extraction ──────────────────────────────────────────────────
	// inside: 1.0 deep inside the blob, 0.0 outside
	float inside      = smoothstep(0.06, -0.30, d);
	// surface: peaks right at the blob boundary (surface-tension ring)
	float surface     = exp(-abs(d + 0.05) * 6.0);
	// outer_glow: faint halo visible outside the blob
	float outer_glow  = exp(-max(0.0, d) * 2.0);

	float effective_brightness = brightness + pulse_brightness;

	vec3 col = color_bg.rgb;
	// Faint outer halo that bleeds from each blob
	col += color_mid.rgb * 0.6 * outer_glow * dot_strength;
	// Blob body
	col = mix(col, color_mid.rgb,    inside);
	// Bright interior — blobs are lightest at their core like real lava lamp
	col = mix(col, color_bright.rgb, smoothstep(0.15, 0.88, inside) * effective_brightness);
	// Sharp bright surface-tension ring at the blob boundary
	col += color_bright.rgb * surface * ridge_strength * effective_brightness;

	// ── Vignette ──────────────────────────────────────────────────────────
	vec2 vc = px_uv * (1.0 - px_uv);
	float vignette = pow(clamp(vc.x * vc.y * 16.0, 0.0, 1.0), vignette_pow);
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
