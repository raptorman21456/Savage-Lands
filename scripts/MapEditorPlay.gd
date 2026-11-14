extends Node

# PLAY HERE (Map Editor): walk the map yourself, right now, without leaving the editor. A little walker with the player's body, walking speed
# and sprite is put on open ground in the picked room (or where you are looking, or under the mouse with P), the camera follows it at the
# game's own zoom (1.6), and the rooms round it are built as you go -- from the editor's WORKING COPY, so what you just changed and have not
# saved is exactly what you walk through. Trees, walls, set pieces and water collide the way they do in the game. There are no enemies, no
# doors into buildings and no battles: it is for feeling the shape of a place. Esc or P puts you back in the editor (in the room you walked
# to, or in the very same view if you stayed in the room you started in). Nothing here touches the map data or your save files.

const PlayerScript := preload("res://scripts/Player.gd")
const DebugWorldScript := preload("res://scripts/DebugWorld.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")

const PLAY_ZOOM := 1.6                    # the game's camera zoom (Main.gd): never changed
const RUN_MULT := 3.0                     # Shift: the rooms are 3,055 px wide, so there is a way to cross them
const BUILD_AHEAD := Vector2(1400.0, 1000.0)   # rooms this far round the walker are built before you get there
const START_MARGIN := 140.0               # the start spot is at least this far inside the floor's edge
const SETTLE_FRAMES := 3                  # physics frames before the start spot is checked for trees (new bodies need a step to exist)

var ed                                    # the MapEditor
var active := false
var body: CharacterBody2D = null
var sprite: Sprite2D = null
var test_dir := Vector2.ZERO              # a test can walk the walker without a keyboard
var test_run := false
var start_room_id := ""

var _prev: Dictionary = {}                # the editor's own view and pick, put back on the way out
var _settle := 0
var _banner_layer: CanvasLayer = null
var _banner_label: Label = null

func setup(editor) -> void:
	ed = editor

# --- starting and stopping -----------------------------------------------------------------------------------------------------

# Where Play here starts when nothing more exact is asked for: the middle of what you are looking at if that is inside the picked room,
# otherwise the middle of the picked room, otherwise the middle of the view.
func default_start() -> Vector2:
	var free: Rect2 = ed.ui.free_area() if ed.ui != null else Rect2(Vector2.ZERO, ed.viewport_size())
	var looking: Vector2 = ed.s2w(free.get_center())
	if ed.has_room():
		var rect: Rect2 = ed.room().rect
		return looking if rect.has_point(looking) else rect.get_center()
	return looking

# Puts the walker on the open ground nearest `at` (Vector2.INF = default_start). False, with a message, when there is none.
func start(at: Vector2 = Vector2.INF) -> bool:
	if active:
		return true
	var wanted: Vector2 = at if at.is_finite() else default_start()
	var spot: Vector2 = DebugWorldScript.floor_near(wanted, START_MARGIN)
	if not spot.is_finite():
		ed.toast("There is nowhere to stand near here: try a room with floor.", true)
		return false
	_prev = {"cam": ed.cam_pos, "zoom": ed.zoom}
	start_room_id = str(RoomsScript.room_at(spot).id)
	# whatever was half done (a shape being drawn, a drag) is put down first, and no text box keeps the keys
	ed._cancel_drag()
	ed.disarm()
	get_viewport().gui_release_focus()
	active = true
	if ed.ui != null:
		ed.ui.visible = false
	body = _make_body()
	ed.add_child(body)
	body.global_position = spot
	_follow(spot)
	_settle = SETTLE_FRAMES
	_make_banner()
	return true

func stop() -> void:
	if not active:
		return
	active = false
	var here: Vector2 = body.global_position if body != null else Vector2.ZERO
	if body != null:
		body.queue_free()
		body = null
	if _banner_layer != null:
		_banner_layer.queue_free()
		_banner_layer = null
		_banner_label = null
	if ed.ui != null:
		ed.ui.visible = true
	var room: Dictionary = RoomsScript.room_at(here)
	if str(room.id) == start_room_id:
		ed.set_view(_prev.cam, _prev.zoom)       # still in the room you began in: the editor looks exactly as you left it
	else:
		ed.pick_cell(room.cell)
		ed.focus_room()
	if ed.ui != null:
		ed.ui.refresh()

# --- the walker ------------------------------------------------------------------------------------------------------------------

func _make_body() -> CharacterBody2D:
	var b := CharacterBody2D.new()
	b.name = "Walker"
	b.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PlayerScript.BODY_RADIUS
	shape.shape = circle
	b.add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/barbarian.png")
	sprite.scale = PlayerScript.BASE_SPRITE_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_child(sprite)
	return b

func _direction() -> Vector2:
	if test_dir != Vector2.ZERO:
		return test_dir.normalized()
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d.y += 1.0
	return d.normalized()

func speed_now() -> float:
	var run: bool = test_run or Input.is_key_pressed(KEY_SHIFT)
	return float(PlayerScript.AGILITY_START) * (RUN_MULT if run else 1.0)

func _physics_process(_delta: float) -> void:
	if not active or body == null:
		return
	var dir := _direction()
	body.velocity = dir * speed_now()
	body.move_and_slide()
	if dir.x != 0.0 and sprite != null:
		sprite.flip_h = dir.x < 0.0
	if _settle > 0:
		_settle -= 1
		if _settle == 0:
			_step_off_solids()
	_follow(body.global_position)

# The editor's camera goes to the walker at the game's zoom, and the rooms round it are kept built. (The editor's own camera code is not
# used: it would keep only the rooms in the window and drop the ones being built ahead.)
func _follow(pos: Vector2) -> void:
	ed.cam_pos = pos
	ed.zoom = PLAY_ZOOM
	if ed.camera != null:
		ed.camera.position = pos
		ed.camera.zoom = Vector2(PLAY_ZOOM, PLAY_ZOOM)
	if ed.world != null:
		ed.world.update_view(Rect2(pos - BUILD_AHEAD, BUILD_AHEAD * 2.0), PLAY_ZOOM)

# The room round the start spot is built by now: if a tree or a set piece stands on it, step to the nearest clear ground.
func _step_off_solids() -> void:
	if body == null or _is_clear(body.global_position):
		return
	for ring in range(1, 14):
		var radius: float = float(ring) * 60.0
		var steps: int = 8 + ring * 2
		for k in steps:
			var a: float = TAU * float(k) / float(steps)
			var p: Vector2 = body.global_position + Vector2(cos(a), sin(a)) * radius
			if _is_clear(p) and DebugWorldScript.floor_near(p, 60.0) == p:
				body.global_position = p
				return

func _is_clear(pos: Vector2) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = PlayerScript.BODY_RADIUS + 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [body.get_rid()]
	for hit in body.get_world_2d().direct_space_state.intersect_shape(query, 8):
		if hit.get("collider") is StaticBody2D:
			return false
	return true

# --- what is on screen --------------------------------------------------------------------------------------------------------

func _make_banner() -> void:
	_banner_layer = CanvasLayer.new()
	_banner_layer.layer = 20
	add_child(_banner_layer)
	var chip := PixelKit.panel("chip", 8, 3)
	chip.position = Vector2(10, 10)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_layer.add_child(chip)
	_banner_label = PixelKit.label("", "body", PixelKit.GOLD4)
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_banner_label)
	_update_banner()

func _process(_delta: float) -> void:
	if active:
		_update_banner()

func banner_text() -> String:
	if body == null:
		return ""
	var room: Dictionary = RoomsScript.room_at(body.global_position)
	var where := "%d,%d" % [int(room.cell.x), int(room.cell.y)]
	if str(room.name) != "":
		where += "  " + str(room.name)
	return "Playing  ·  room %s  ·  arrows / WASD walk  ·  Shift runs  ·  P or Esc back to the editor" % where

func _update_banner() -> void:
	if _banner_label != null:
		_banner_label.text = banner_text()
