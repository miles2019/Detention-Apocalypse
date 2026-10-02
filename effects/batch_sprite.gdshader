shader_type spatial;
// Gebatchte Billboard-Sprites (MultiMesh): ein Atlas, pro Instanz Region (custom.x), Blitz (custom.y), Tönung (COLOR).
render_mode unshaded, cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 regions[64];

varying vec4 reg;
varying float flashv;

void vertex() {
	int idx = int(INSTANCE_CUSTOM.x + 0.5);
	reg = regions[idx];
	flashv = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 uv = reg.xy + UV * reg.zw;
	vec4 c = texture(atlas, uv);
	vec3 rgb = c.rgb * COLOR.rgb;
	ALBEDO = mix(rgb, vec3(1.0), flashv);
	ALPHA = c.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
