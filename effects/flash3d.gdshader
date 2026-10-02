shader_type spatial;
// Billboard-Sprite im 3D-Raum: unbeleuchtet, weiche Kanten, Trefferblitz + Tönung.
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 light_tint : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(tex, UV) * tint;
	vec3 rgb = c.rgb * light_tint.rgb;
	ALBEDO = mix(rgb, flash_color.rgb, flash);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
