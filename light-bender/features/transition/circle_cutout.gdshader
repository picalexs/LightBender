shader_type canvas_item;
render_mode unshaded;

uniform vec2 hole_center = vec2(0.0, 0.0);
uniform float hole_radius = 0.0;
uniform float edge_softness = 2.0;
uniform vec2 viewport_size = vec2(1920.0, 1080.0);

void fragment() {
	vec2 pixel_pos = UV * viewport_size;
	float dist = distance(pixel_pos, hole_center);
	float alpha = smoothstep(hole_radius, hole_radius + max(edge_softness, 0.001), dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
