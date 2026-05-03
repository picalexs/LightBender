shader_type canvas_item;
render_mode unshaded;

// ── Animation ──────────────────────────────────────────────────────────────
uniform float time_scale    : hint_range(0.0, 5.0)  = 0.5;
uniform float flow_speed    : hint_range(0.0, 3.0)  = 0.3;

// ── Shape ──────────────────────────────────────────────────────────────────
uniform float pixel_size    : hint_range(1.0, 64.0) = 5.0;
uniform float noise_scale   : hint_range(0.5, 12.0) = 3.5;
uniform float warp_strength : hint_range(0.0, 6.0)  = 2.5;
uniform float ridge_strength: hint_range(0.0, 2.0)  = 0.25;
uniform float dot_strength  : hint_range(0.0, 2.0)  = 0.20;

// ── Color (3-tone gradient: dark base → dim element → bright peak) ─────────
uniform vec4  color_bg     : source_color = vec4(0.020, 0.018, 0.050, 1.0);
uniform vec4  color_mid    : source_color = vec4(0.055, 0.080, 0.380, 1.0);
uniform vec4  color_bright : source_color = vec4(0.250, 0.380, 0.950, 1.0);
uniform float brightness   : hint_range(0.0, 4.0)  = 0.75;
uniform float vignette_pow : hint_range(0.0, 2.0)  = 0.50;

// ── Pulse ────────────────────────────────────────────────────────────────
uniform float pulse_pos_x      : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_pos_y      : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_strength   : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_brightness : hint_range(0.0, 3.0) = 0.0;

// ── Gradient noise (gradient Perlin-style, output -1..1) ───────────────────
vec2 ghash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(ghash(i + vec2(0,0)), f - vec2(0,0)),
		    dot(ghash(i + vec2(1,0)), f - vec2(1,0)), u.x),
		mix(dot(ghash(i + vec2(0,1)), f - vec2(0,1)),
		    dot(ghash(i + vec2(1,1)), f - vec2(1,1)), u.x), u.y);
}

// Rotation-based FBM — rotates coords per octave to break axis alignment.
// 4 octaves, manually unrolled for GL Compatibility.
float fbm(vec2 p) {
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	float v = 0.0;
	v += 0.5000 * noise(p); p = m * p;
	v += 0.2500 * noise(p); p = m * p;
	v += 0.1250 * noise(p); p = m * p;
	v += 0.0625 * noise(p);
	return v;
}

// ── Voronoi (3×3 grid) for floating light dots ─────────────────────────────
vec2 vhash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float voronoi_dots(vec2 p, float t) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 h = vhash(n + g);
			vec2 o = 0.5 + 0.45 * sin(t * 0.6 + TAU * h);
			vec2 r = g + o - f;
			md = min(md, dot(r, r));
		}
	}
	return exp(-sqrt(md) * 7.0);
}

void fragment() {
	// ── Pixelation ────────────────────────────────────────────────────────
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px_uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float aspect = screen_size.x / screen_size.y;
	vec2 uv = vec2(px_uv.x * aspect, px_uv.y) * noise_scale;

	float t = TIME * time_scale;
	float tf = TIME * flow_speed;

	// ── Pulse displacement ───────────────────────────────────────────────
	vec2 pulse_uv = vec2(pulse_pos_x, pulse_pos_y);
	float dist_to_pulse = distance(px_uv, pulse_uv);
	float pulse_factor = smoothstep(0.3, 0.0, dist_to_pulse) * pulse_strength;
	uv += normalize(px_uv - pulse_uv) * pulse_factor * 0.8;

	// ── Two-level domain warp (Inigo Quilez) ─────────────────────────────
	vec2 q = vec2(
		fbm(uv + vec2(0.00, 0.00) + tf),
		fbm(uv + vec2(5.20, 1.30) + tf * 0.7)
	);

	vec2 r = vec2(
		fbm(uv + warp_strength * q + vec2(1.7, 9.2) + tf * 0.5),
		fbm(uv + warp_strength * q + vec2(8.3, 2.8) + tf * 0.4)
	);

	float fluid = fbm(uv + warp_strength * r);

	// ── Ridged noise layer (sharp bright veins) ───────────────────────────
	float ridge_raw = fbm(uv * 1.4 + q * 0.6 + tf * 0.35);
	float ridges = pow(1.0 - abs(ridge_raw) * 1.8, 5.0);
	ridges = clamp(ridges, 0.0, 1.0);

	// ── Voronoi dots layer ────────────────────────────────────────────────
	float dots = voronoi_dots(uv * 0.8 + r * 0.3, t);

	// ── 3-tone color gradient mapped to fluid intensity ───────────────────
	float f = clamp(fluid * 0.5 + 0.5, 0.0, 1.0);

	float effective_brightness = brightness + pulse_brightness;

	vec3 col = color_bg.rgb;
	col = mix(col, color_mid.rgb,    smoothstep(0.20, 0.58, f));
	col = mix(col, color_bright.rgb, smoothstep(0.58, 0.88, f) * effective_brightness);

	col += color_bright.rgb * ridges   * ridge_strength * effective_brightness;
	col += color_bright.rgb * dots     * dot_strength   * effective_brightness;

	// ── Vignette ──────────────────────────────────────────────────────────
	vec2 vc = px_uv * (1.0 - px_uv);
	float vignette = pow(clamp(vc.x * vc.y * 16.0, 0.0, 1.0), vignette_pow);
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
