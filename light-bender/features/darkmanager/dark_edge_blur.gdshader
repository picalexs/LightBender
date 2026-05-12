shader_type canvas_item;

uniform float blur_size : hint_range(0.0, 64.0) = 24.0;

void fragment() {
	float alpha_sum = 0.0;
	float weight_sum = 0.0;

	int radius = 4;
	float sigma = float(radius) * 0.5;

	for (int x = -radius; x <= radius; x++) {
		for (int y = -radius; y <= radius; y++) {
			float fx = float(x);
			float fy = float(y);
			float w = exp(-0.5 * (fx * fx + fy * fy) / (sigma * sigma));
			vec2 off = vec2(fx, fy) * TEXTURE_PIXEL_SIZE * (blur_size / float(radius));
			alpha_sum += textureLod(TEXTURE, SCREEN_UV + off, 0.0).a * w;
			weight_sum += w;
		}
	}

	COLOR = vec4(0.0, 0.0, 0.0, alpha_sum / weight_sum);
}
