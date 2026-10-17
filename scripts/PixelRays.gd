extends ColorRect
class_name PixelRays

# The quality glow of a weapon: small pixel rays behind its picture that turn very slowly. The colour says the quality
# (Worn has none, Broken's is dark), the ray count rises with it, and each picture turns at its own random speed, direction and
# starting angle -- picked from a hash of its name, so a picture keeps its own pace across rebuilds of the screen instead of
# jumping. Drawn by shaders/pixel_rays.gdshader as chunky 2x2 pixels, like everything else in the pixel kit.

const SHADER := preload("res://shaders/pixel_rays.gdshader")

# quality -> ray colour, how many rays, how opaque, the faint disc behind the picture, and whether a second ring turns the other way.
# Worn (and the Club's "Starter") have no entry: no glow. Broken's glow is dark: black rays on a faintly lighter disc.
const GLOWS := {
	"Broken": {"color": Color("0a0710"), "plate": Color("342c46"), "rays": 8, "opacity": 0.95},
	"Fine": {"color": Color("cfcfd8"), "plate": Color(0.81, 0.81, 0.85, 0.18), "rays": 8, "opacity": 0.85},
	"Masterwork": {"color": Color("4aa3ff"), "plate": Color(0.29, 0.64, 1.0, 0.18), "rays": 10, "opacity": 0.9},
	"Legendary": {"color": Color("ffd84a"), "plate": Color(1.0, 0.85, 0.29, 0.18), "rays": 12, "opacity": 0.95},
	"Mythic": {"color": Color("b3203f"), "plate": Color(0.70, 0.13, 0.25, 0.18), "rays": 14, "opacity": 1.0, "second": true},
}

static func has_rays(quality: String) -> bool:
	return GLOWS.has(quality)

# The disc/tint under a picture of this quality (clear when it has no glow).
static func plate_color(quality: String) -> Color:
	return GLOWS[quality].plate if GLOWS.has(quality) else Color(0, 0, 0, 0)

# One picture's own pace, from its key: seconds per turn (26-72), direction, starting angle (seconds in) for the outer ring and the
# inner one. Stable for a given key.
static func pace(key: String) -> Dictionary:
	var h: int = absi(key.hash())
	return {
		"period_a": 26.0 + float(h % 4600) / 100.0,
		"dir_a": 1.0 if ((h >> 12) & 1) == 0 else -1.0,
		"phase_a": float((h >> 4) % 10000) / 100.0,
		"period_b": 26.0 + float((h >> 17) % 4600) / 100.0,
		"phase_b": float((h >> 9) % 10000) / 100.0,
	}

# Rays for `quality` filling an area of `area` screen pixels, ring radius `half_art` art pixels. Returns null for no glow.
static func make(quality: String, key: String, area: Vector2, half_art: float = 28.0) -> PixelRays:
	if not GLOWS.has(quality):
		return null
	var g: Dictionary = GLOWS[quality]
	var rays := PixelRays.new()
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.custom_minimum_size = area
	rays.size = area
	rays.color = Color(1, 1, 1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var p: Dictionary = pace(key)
	mat.set_shader_parameter("ray_color", g.color)
	mat.set_shader_parameter("ray_count", float(g.rays))
	mat.set_shader_parameter("opacity", float(g.opacity))
	mat.set_shader_parameter("half_size", half_art)
	mat.set_shader_parameter("pixel", 2.0)
	mat.set_shader_parameter("rect_size", area)
	mat.set_shader_parameter("period_a", p.period_a)
	mat.set_shader_parameter("dir_a", p.dir_a)
	mat.set_shader_parameter("phase_a", p.phase_a)
	mat.set_shader_parameter("second_ring", 1.0 if g.get("second", false) else 0.0)
	mat.set_shader_parameter("period_b", p.period_b)
	mat.set_shader_parameter("dir_b", -float(p.dir_a))
	mat.set_shader_parameter("phase_b", p.phase_b)
	rays.material = mat
	rays.set_meta("quality", quality)
	return rays
