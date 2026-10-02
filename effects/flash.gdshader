shader_type canvas_item;
// Trefferblitz: mischt das Sprite kurz zu einer Farbe (Standard: weiss)
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
