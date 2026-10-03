shader_type canvas_item;
// Sogfeld der Magnet-Kanone: drei Spiralarme im Cel-Look, die sich zur Mitte drehen; heller Kern.
uniform vec4 tint : source_color = vec4(0.45, 0.7, 1.0, 1.0);
uniform float fade = 1.0;
uniform float spin = 7.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float arms = sin(a * 3.0 + r * 10.0 - TIME * spin);
	float cel = floor(smoothstep(-0.2, 0.8, arms) * 3.0) / 3.0;
	float rings = step(0.86, fract(r * 4.0 + TIME * 1.4));
	float edge = smoothstep(1.0, 0.82, r);
	float core = smoothstep(0.3, 0.0, r);
	vec3 col = mix(tint.rgb, vec3(1.0), core * 0.85 + cel * 0.3);
	float alpha = (cel * 0.5 + rings * 0.25 + core + 0.1) * edge * fade * tint.a;
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
