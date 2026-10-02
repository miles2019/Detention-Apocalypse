shader_type spatial;
// Silhouetten-Schatten: schwarzes, weich ausblendendes Abbild des Sprites, flach auf dem Boden.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	float a = texture(tex, UV).a;
	// Schatten wird zur Spitze hin schwächer (UV.y: 0 = Kopf, 1 = Fuß)
	float fade = mix(0.35, 1.0, UV.y);
	ALBEDO = vec3(0.02, 0.02, 0.06);
	ALPHA = a * opacity * fade;
}
