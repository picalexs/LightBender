shader_type canvas_item;
render_mode unshaded;

// ── Animation ──────────────────────────────────────────────────────────────
uniform float time_scale    : hint_range(0.0, 5.0)  = 0.5;
uniform float flow_speed    : hint_range(0.0, 3.0)  = 0.3;

// ── Shape ─────────────────────────────────────────────────────────────────
// warp_strength: how much FBM melts the square cell walls
// ridge_strength: brightness of cell border lines
// dot_strength: brightness of glow at cell centers
uniform float pixel_size    : hint_range(1.0, 64.0) = 5.0;
uniform float noise_scale   : hint_range(0.5, 12.0) = 3.5;
uniform float warp_strength : hint_range(0.0, 6.0)  = 2.0;
uniform float ridge_strength: hint_range(0.0, 2.0)  = 0.50;
uniform float dot_strength  : hint_range(0.0, 2.0)  = 0.40;

// ── Color ──────────────────────────────────────────────────────────────────
uniform vec4  color_bg     : source_color = vec4(0.018, 0.008, 0.002, 1.0);
uniform vec4  color_mid    : source_color = vec4(0.200, 0.080, 0.010, 1.0);
uniform vec4  color_bright : source_color = vec4(0.900, 0.620, 0.060, 1.0);
uniform float brightness   : hint_range(0.0, 4.0)  = 0.75;
uniform float vignette_pow : hint_range(0.0, 2.0)  = 0.50;

// ── Pulse ─────────────────────────────────────────────────────────────────
uniform float pulse_pos_x      : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_pos_y      : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_strength   : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_brightness : hint_range(0.0, 3.0) = 0.0;

// ── Gradient noise ─────────────────────────────────────────────────────────
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

float fbm(vec2 p) {
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	float v = 0.0;
	v += 0.5000 * noise(p); p = m * p;
	v += 0.2500 * noise(p);
	return v;
}

// ── Voronoi hash ───────────────────────────────────────────────────────────
vec2 vhash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// ── Chebyshev (L∞) Voronoi — produces true square cells ──────────────────
// Chebyshev distance = max(|dx|, |dy|) → iso-contours are squares aligned to axes.
// The liquid feel comes from the animated cell centers, not from distorting the shape.
// Returns vec3(d_nearest, d_second_nearest, cell_hash_x)
vec3 square_voronoi(vec2 p, float t) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	float cell_id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 h = vhash(n + g);
			// Cell centers drift slowly over time — this is what makes it liquid
			vec2 o = 0.5 + 0.45 * sin(t * 0.5 + TAU * h);
			vec2 r = g + o - f;
			// Chebyshev: iso-contours are squares, borders are axis-aligned lines
			float d = max(abs(r.x), abs(r.y));
			if (d < d1) { d2 = d1; d1 = d; cell_id = h.x; }
			else if (d < d2) { d2 = d; }
		}
	}
	return vec3(d1, d2, cell_id);
}

void fragment() {
	// ── Pixelation ────────────────────────────────────────────────────────
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px_uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float aspect = screen_size.x / screen_size.y;
	vec2 uv = vec2(px_uv.x * aspect, px_uv.y) * noise_scale;

	float t = TIME * time_scale;
	float tf = TIME * flow_speed;

	// ── Pulse displacement ────────────────────────────────────────────────
	vec2 pulse_uv = vec2(pulse_pos_x, pulse_pos_y);
	vec2 pulse_delta = px_uv - pulse_uv;
	float dist_to_pulse = length(pulse_delta);
	float pulse_factor = smoothstep(0.3, 0.0, dist_to_pulse) * pulse_strength;
	vec2 pulse_dir = pulse_delta / max(dist_to_pulse, 0.0001);
	uv += pulse_dir * pulse_factor * 0.8;

	// ── Light FBM warp: subtle organic undulation at border edges ───────────
	// Low coefficient keeps cell shapes recognizably square.
	// The primary liquid motion comes from the animated cell centers.
	vec2 q = vec2(
		fbm(uv + vec2(0.00, 0.00) + tf),
		fbm(uv + vec2(5.20, 1.30) + tf * 0.7)
	);
	vec2 warped_uv = uv + warp_strength * 0.18 * q;

	// ── Square Voronoi on the lightly warped UV ───────────────────────────
	vec3 sv = square_voronoi(warped_uv, t);
	float d1 = sv.x;
	float d2 = sv.y;
	float cell_id = sv.z;

	// Crisp border along the square cell edges
	float border = 1.0 - smoothstep(0.0, 0.05, d2 - d1);

	// Within-cell: subtle dark-to-mid gradient; bright accent is carried by borders only
	float cell_body = smoothstep(0.0, 0.48, d1);

	// Wide per-cell shade variation so individual squares read clearly in the dark
	float shade = 0.20 + 0.65 * cell_id;
	float fluid = clamp(cell_body * shade, 0.0, 1.0);

	float effective_brightness = brightness + pulse_brightness;

	vec3 col = color_bg.rgb;
	// Cell interiors stay dark — only go as far as color_mid
	col = mix(col, color_mid.rgb, smoothstep(0.08, 0.75, fluid));

	// Bright accent lives entirely in the border lines
	col += color_bright.rgb * border * ridge_strength * effective_brightness;

	// Very faint center spark — just enough to hint at cell depth
	float center_glow = exp(-d1 * 9.0);
	col += color_bright.rgb * center_glow * dot_strength * effective_brightness;

	// ── Vignette ──────────────────────────────────────────────────────────
	vec2 vc = px_uv * (1.0 - px_uv);
	float vignette = pow(clamp(vc.x * vc.y * 16.0, 0.0, 1.0), vignette_pow);
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
