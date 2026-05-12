shader_type canvas_item;
render_mode unshaded;

// The menu keeps the liquid theme, but now reads as a tiled, pixel-art
// marbling surface with multiple drifting vortex pockets across the screen.
uniform float time_scale    : hint_range(0.0, 3.0)  = 0.15;
uniform float flow_speed    : hint_range(0.0, 3.0)  = 0.16;
uniform float pixel_size    : hint_range(1.0, 64.0) = 8.0;
uniform float noise_scale   : hint_range(0.5, 12.0) = 2.3;
uniform float warp_strength : hint_range(0.0, 6.0)  = 2.1;
uniform float ridge_strength: hint_range(0.0, 2.0)  = 0.42;
uniform float dot_strength  : hint_range(0.0, 2.0)  = 0.22;
uniform vec4  color_bg      : source_color = vec4(0.008, 0.010, 0.026, 1.0);
uniform vec4  color_mid     : source_color = vec4(0.040, 0.120, 0.240, 1.0);
uniform vec4  color_bright  : source_color = vec4(0.620, 0.760, 0.860, 1.0);
uniform float brightness    : hint_range(0.0, 4.0)  = 0.68;
uniform float vignette_pow  : hint_range(0.0, 2.0)  = 0.45;
uniform float manual_time = 0.0;

vec2 ghash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(ghash(i + vec2(0, 0)), f - vec2(0, 0)),
		    dot(ghash(i + vec2(1, 0)), f - vec2(1, 0)), u.x),
		mix(dot(ghash(i + vec2(0, 1)), f - vec2(0, 1)),
		    dot(ghash(i + vec2(1, 1)), f - vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	float v = 0.0;
	v += 0.5000 * noise(p); p = m * p;
	v += 0.2500 * noise(p); p = m * p;
	v += 0.1250 * noise(p); p = m * p;
	v += 0.0625 * noise(p);
	return v;
}

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
			vec2 o = 0.5 + 0.40 * sin(t * 0.8 + TAU * h);
			vec2 r = g + o - f;
			md = min(md, dot(r, r));
		}
	}
	return exp(-sqrt(md) * 8.0);
}

// Returns:
// xy = local vector to nearest animated vortex center
// z  = squared distance to the nearest center
// w  = gap between the second and first nearest centers
vec4 vortex_cells(vec2 p, float t) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 nearest = vec2(0.0);

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 h = vhash(n + g);
			vec2 o = 0.5 + 0.38 * sin(t * (0.55 + h.x * 0.25) + TAU * h);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				nearest = r;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}

	return vec4(nearest, d1, d2 - d1);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px_uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float aspect = screen_size.x / screen_size.y;
	vec2 uv = vec2(px_uv.x * aspect, px_uv.y) * noise_scale;

	float time_value = TIME + manual_time;
	float t = time_value * time_scale;
	float tf = time_value * flow_speed;
	vec2 drift = vec2(tf * 0.12, -tf * 0.08);

	vec2 q = vec2(
		fbm(uv + drift),
		fbm(uv + vec2(5.20, 1.30) - drift * 0.5)
	);

	vec2 r = vec2(
		fbm(uv + warp_strength * q + vec2(1.7, 9.2) + drift * 0.4),
		fbm(uv + warp_strength * q + vec2(8.3, 2.8) - drift * 0.3)
	);

	vec2 domain = uv + warp_strength * r * 0.72 + drift;
	vec4 vortex = vortex_cells(domain * 0.56 + q * 0.18, t * 0.55);
	vec2 local = vortex.xy;
	float cell_dist = sqrt(vortex.z);
	float cell_gap = vortex.w;

	float fluid = fbm(domain + vec2(cell_dist, local.x - local.y));
	float local_angle = atan(local.y, local.x);
	float swirl_a = 0.5 + 0.5 * sin(local_angle * 3.5 - cell_dist * 11.0 - tf * 0.9 + fluid * 4.0);
	float swirl_b = 0.5 + 0.5 * sin((local.x + local.y) * 5.5 + local_angle * 2.0 + tf * 0.7 + q.x * 2.5);
	float marbling = mix(swirl_a, swirl_b, 0.28);

	float eddies = fbm((domain + vec2(marbling, fluid) * 1.1) * 0.85 - drift * 0.25);
	float channels = pow(max(0.0, fbm(domain * 1.05 - q * 0.70 + tf * 0.03) - 0.58), 2.8);
	float droplets = voronoi_dots(domain * 0.40 + r * 0.16 - drift * 0.12, t * 0.70);
	float border = 1.0 - smoothstep(0.0, 0.045, cell_gap);
	float pearl = exp(-cell_dist * 5.6) * (0.25 + 0.35 * pow(swirl_b, 2.0));

	float pools = smoothstep(0.50, 0.95, fluid * 0.38 + marbling * 0.22 + eddies * 0.16 + channels * 0.14);
	float stepped_pools = floor(pools * 4.0) / 4.0;
	float contour = pow(1.0 - abs(marbling * 2.0 - 1.0), 5.0);

	vec3 col = color_bg.rgb;
	col = mix(col, color_mid.rgb, smoothstep(0.18, 0.84, stepped_pools));
	col = mix(col, color_bright.rgb, smoothstep(0.68, 0.98, stepped_pools) * brightness);
	col += mix(color_mid.rgb, color_bright.rgb, 0.35) * border * 0.10;
	col += color_bright.rgb * contour * ridge_strength * 0.45 * brightness;
	col += mix(color_mid.rgb, color_bright.rgb, 0.40) * droplets * dot_strength * 0.25 * brightness;
	col += color_bright.rgb * channels * 0.10 * brightness;
	col += color_bright.rgb * pearl * 0.08 * brightness;

	vec2 vc = px_uv * (1.0 - px_uv);
	float vignette = pow(clamp(vc.x * vc.y * 16.0, 0.0, 1.0), vignette_pow);
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
