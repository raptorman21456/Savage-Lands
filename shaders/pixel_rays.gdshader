shader_type canvas_item;

// The slowly turning rays behind a weapon's picture, drawn as chunky pixels: the rect is cut into art pixels (`pixel` screen pixels
// each), and a pixel is lit when it falls inside one of the rays. Long and short rays alternate and taper to a point; a Mythic
// weapon gets a second, shorter ring turning the other way. Each picture sets its own speed, direction and starting angle, so no two
// turn together. Port of the mockup's canvas version (tools/ui_mockups/inventory_mockup.html).

uniform vec4 ray_color : source_color = vec4(1.0);
uniform float ray_count = 8.0;
uniform float opacity = 0.9;
uniform float half_size = 28.0;      // radius of the ring, in art pixels
uniform float pixel = 2.0;           // screen pixels per art pixel
uniform vec2 rect_size = vec2(104.0, 84.0);
uniform float period_a = 40.0;       // seconds for one full turn
uniform float dir_a = 1.0;
uniform float phase_a = 0.0;
uniform float second_ring = 0.0;     // 1.0: add the counter-turning inner ring (Mythic)
uniform float period_b = 55.0;
uniform float dir_b = -1.0;
uniform float phase_b = 0.0;

float ring(vec2 p, float count, float out_r, float inn_r, float rot) {
	float r = length(p);
	if (r < inn_r || r > out_r) {
		return 0.0;
	}
	float sector = 6.28318530718 / count;
	float ph = atan(p.y, p.x) - rot;
	float k = floor(ph / sector);
	float loc = ph - k * sector - sector * 0.5;
	float idx = mod(k, count);
	float ray_len = (mod(idx, 2.0) < 0.5) ? out_r : out_r * 0.68;
	if (r > ray_len) {
		return 0.0;
	}
	float t = (r - inn_r) / (ray_len - inn_r);
	if (abs(loc) > 0.15 * (1.0 - t) + 0.03) {
		return 0.0;
	}
	return (t < 0.55) ? opacity : opacity * 0.55;
}

void fragment() {
	vec2 cells = rect_size / pixel;
	vec2 px = floor(UV * cells);
	vec2 p = px + vec2(0.5) - cells * 0.5;
	float a = ring(p, ray_count, half_size * 0.98, half_size * 0.44, dir_a * (TIME + phase_a) / period_a * 6.28318530718);
	if (second_ring > 0.5) {
		float b = ring(p, max(1.0, round(ray_count * 0.7)), half_size * 0.72, half_size * 0.36, dir_b * (TIME + phase_b) / period_b * 6.28318530718);
		a = max(a, b);
	}
	COLOR = vec4(ray_color.rgb, a);
}
