extends TextureRect

# A picture made of equal frames side by side in one PNG, played in a loop: the shaking eyes of Bloodboost and Bloodcrash
# (assets/ui/status_bloodboost.png and status_bloodcrash.png). One frame is just a still icon, so the battle screen's status
# slots use this for every icon and swap what they show with show_strip(). UIIcons.rect() and UIIcons.strip() are the usual way in.
# Every strip plays off the same clock, so two eyes on the screen shake together.

const FRAME_MS := 80

var _strip: Texture2D
var _frames := 1
var _atlas: AtlasTexture
var _shown := -1

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

# `strip` is the whole PNG (null hides the slot), `frames` how many pictures lie side by side in it.
func show_strip(strip: Texture2D, frames: int = 1) -> void:
	_strip = strip
	_frames = maxi(1, frames)
	_shown = -1
	if strip == null:
		texture = null
		visible = false
		set_process(false)
		return
	visible = true
	if _frames == 1:
		texture = strip
		set_process(false)
		return
	if _atlas == null:
		_atlas = AtlasTexture.new()
	_atlas.atlas = strip
	texture = _atlas
	_show_frame(_frame_now())
	set_process(true)

# Which frame is showing (0 for a still).
func frame_shown() -> int:
	return maxi(0, _shown)

func _frame_now() -> int:
	return int(Time.get_ticks_msec() / float(FRAME_MS)) % _frames

func _process(_delta: float) -> void:
	_show_frame(_frame_now())

func _show_frame(i: int) -> void:
	if i == _shown or _strip == null:
		return
	_shown = i
	var w: int = int(_strip.get_width() / float(_frames))
	_atlas.region = Rect2(i * w, 0, w, _strip.get_height())
