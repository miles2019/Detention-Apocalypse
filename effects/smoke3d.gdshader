shader_type spatial;
// Stylized Smoke – angepasst nach "Stylized Smoke For Godot 4.5" (godotshaders.com).
// Für Billboard-Partikel: Die Partikelfarbe (inkl. Alpha-Rampe über die Lebenszeit) steuert Farbe und Auflösung.
// Cel-Look: Zellrauschen schneidet weiche Wölkchen aus, zwei Helligkeitsstufen, Rand löst sich mit der Zeit auf.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float noise_scale = 1.6;
uniform float scroll_speed = 0.35;
uniform float edge_soft = 0.14;
uniform float shade_split = 0.5;
uniform float shade_dark = 0.62;
uniform float emission_boost = 0.0;
uniform float alpha_mult = 1.0;

varying vec4 vcol;
varying float seed;

void vertex() {
	// Billboard (Skalierung bleibt erhalten) – funktioniert für CPU- und GPU-Partikel
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	vcol = COLOR;
	// Jede Wolke bekommt einen eigenen Rausch-Versatz (aus der Weltposition)
	seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 nuv = uv * noise_scale + vec2(seed * 7.0, seed * 3.0 + TIME * scroll_speed);
	float n = texture(noise_tex, nuv).r;
	float d = length(uv - vec2(0.5)) * 2.0;
	float mask = 1.0 - smoothstep(0.35, 1.0, d);
	float life = clamp(vcol.a, 0.0, 1.0);
	// mit sinkender Lebensdauer steigt der Schnitt: die Wolke löst sich vom Rand her auf
	float cut = mix(0.78, 0.18, life);
	float v = n * 0.55 + mask * 0.65;
	float a = smoothstep(cut, cut + edge_soft, v);
	float lit = step(shade_split, n);
	vec3 base = vcol.rgb * mix(shade_dark, 1.0, lit);
	ALBEDO = base + base * emission_boost;
	ALPHA = a * alpha_mult * clamp(life * 1.6, 0.0, 1.0);
}
