shader_type spatial;
// Stylized-Smoke-Look für den TrailPool (MultiMesh). Die Ausrichtung zur Kamera steckt schon in der
// Instanz-Transformation; die Instanzfarbe (Alpha = Rest-Lebenszeit) steuert Farbe und Auflösung.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float noise_scale = 1.6;
uniform float scroll_speed = 0.35;
uniform float edge_soft = 0.14;
uniform float shade_dark = 0.62;

varying float seed;

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.6180339);
}

void fragment() {
	vec2 nuv = UV * noise_scale + vec2(seed * 7.0, seed * 3.0 + TIME * scroll_speed);
	float n = texture(noise_tex, nuv).r;
	float d = length(UV - vec2(0.5)) * 2.0;
	float mask = 1.0 - smoothstep(0.35, 1.0, d);
	float life = clamp(COLOR.a, 0.0, 1.0);
	float cut = mix(0.78, 0.18, life);
	float v = n * 0.55 + mask * 0.65;
	float a = smoothstep(cut, cut + edge_soft, v);
	ALBEDO = COLOR.rgb * mix(shade_dark, 1.0, step(0.5, n));
	ALPHA = a * clamp(life * 1.6, 0.0, 1.0);
}
