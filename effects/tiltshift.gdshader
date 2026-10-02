shader_type canvas_item;
// Tilt-Shift (Diorama-Look): oberer/unterer Bildrand leicht unscharf, dezente Vignette. Günstig: 1 oder 5 Samples.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float max_blur = 1.6;
uniform float vignette = 0.42;
uniform vec4 post_tint : source_color = vec4(1.0);
uniform float blackout = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.2;

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = abs(uv.y - 0.5) * 2.0;
	float k = smoothstep(0.55, 1.0, d);
	vec3 c = texture(screen_tex, uv).rgb;
	if (k > 0.02) {
		vec2 px = SCREEN_PIXEL_SIZE * max_blur * k * 2.5;
		vec3 s = c * 0.4;
		s += texture(screen_tex, uv + vec2(px.x, 0.0)).rgb * 0.15;
		s += texture(screen_tex, uv - vec2(px.x, 0.0)).rgb * 0.15;
		s += texture(screen_tex, uv + vec2(0.0, px.y)).rgb * 0.15;
		s += texture(screen_tex, uv - vec2(0.0, px.y)).rgb * 0.15;
		c = s;
	}
	c *= post_tint.rgb;
	if (blackout > 0.001) {
		float dd = length((uv - center) * vec2(1.7, 1.0));
		float dk = smoothstep(radius, radius + 0.28, dd);
		c *= 1.0 - blackout * dk * 0.96;
		c += blackout * (1.0 - dk) * vec3(0.06, 0.05, 0.02);
	}
	float v = length((uv - 0.5) * vec2(1.1, 1.25));
	c *= 1.0 - vignette * smoothstep(0.35, 0.95, v);
	COLOR = vec4(c, 1.0);
}
