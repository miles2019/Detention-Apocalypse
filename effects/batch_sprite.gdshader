shader_type spatial;
// Gebatchte Billboard-Sprites (MultiMesh): ein Atlas, pro Instanz Region (custom.x), Blitz (custom.y),
// Status-Effekt (custom.z: 1 brennt, 2 nass, 3 gefroren) und Tönung (COLOR).
render_mode unshaded, cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 regions[64];

varying vec4 reg;
varying float flashv;
varying float fxv;
varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	int idx = int(INSTANCE_CUSTOM.x + 0.5);
	reg = regions[idx];
	flashv = INSTANCE_CUSTOM.y;
	fxv = INSTANCE_CUSTOM.z;
	seed = fract(float(INSTANCE_ID) * 0.6180339);
}

void fragment() {
	vec2 uv = reg.xy + UV * reg.zw;
	vec4 c = texture(atlas, uv);
	vec3 rgb = c.rgb * COLOR.rgb;
	if (fxv > 0.5 && fxv < 1.5) {
		// brennt: gestufte Flammen züngeln von unten nach oben
		float n = vnoise(vec2(UV.x * 7.0 + seed * 9.0, UV.y * 5.0 + TIME * 4.0));
		float flame = clamp(UV.y * 1.25 - 0.45 + n * 0.6, 0.0, 1.0);
		float cel = floor(flame * 3.0 + 0.5) / 3.0;
		vec3 fire = mix(vec3(1.0, 0.35, 0.05), vec3(1.0, 0.9, 0.35), cel);
		rgb = mix(rgb, fire, cel * 0.8);
	} else if (fxv > 1.5 && fxv < 2.5) {
		// nass: bläulich, mit herablaufenden Glanzstreifen
		rgb = mix(rgb, vec3(0.35, 0.62, 1.0), 0.3);
		float col_id = floor(UV.x * 9.0);
		float drip = fract(UV.y * 1.3 - TIME * 0.7 + hash(vec2(col_id, seed)));
		rgb += vec3(0.5) * smoothstep(0.12, 0.0, abs(drip - 0.5)) * step(0.5, hash(vec2(col_id + 3.0, seed)));
	} else if (fxv > 2.5) {
		// gefroren: Eisfarbe mit funkelnden Kristallen
		float g = dot(rgb, vec3(0.3, 0.6, 0.1));
		rgb = mix(vec3(g), vec3(0.72, 0.9, 1.0), 0.6) + vec3(0.12);
		float sp = step(0.94, vnoise(UV * 22.0 + seed * 20.0 + floor(TIME * 6.0) * 0.37));
		rgb += vec3(sp * 0.7);
	}
	ALBEDO = mix(rgb, vec3(1.0), flashv);
	ALPHA = c.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
