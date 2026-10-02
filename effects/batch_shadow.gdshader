shader_type spatial;
// Gebatchte Silhouetten-Schatten (MultiMesh): Alpha des Sprites, schwächer zur Spitze hin.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 regions[64];

varying vec4 reg;

void vertex() {
	int idx = int(INSTANCE_CUSTOM.x + 0.5);
	reg = regions[idx];
}

void fragment() {
	vec2 uv = reg.xy + UV * reg.zw;
	float a = texture(atlas, uv).a;
	float fade = mix(0.35, 1.0, UV.y);
	ALBEDO = vec3(0.02, 0.02, 0.06);
	ALPHA = a * COLOR.a * fade;
}
