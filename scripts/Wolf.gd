extends CharacterBody2D
class_name Wolf

const PickupScript := preload("res://scripts/Pickup.gd")

signal died(xp_reward: int)

# Fast and lean rather than tough -- closes distance quicker than any other
# enemy type, at moderate HP.
const SPEED := 130.0
const MAX_HEALTH := 8
const CONTACT_DAMAGE := 2
const DETECT_RANGE := 180.0
const CONTACT_COOLDOWN := 0.6
const BODY_RADIUS := 14.0
const CONTACT_RANGE := 34.0
const XP_REWARD := 20
const COIN_MIN := 2
const COIN_MAX := 4
const MEAT_CHANCE := 0.12

var health := MAX_HEALTH
# Set from Main.gd's _spawn_enemies on a random roll -- boosts battle stats
# (see Main.gd:_setup_battle_grid) and guarantees a Runic Shard drop.
var is_elite := false
# A rare, independent roll from is_elite (see Main.gd:TRAITOR_WOLF_CHANCE) --
# a Traitor Wolf has a chance to defect and join the player's party when it
# dies (Main.gd:_on_wolf_died) instead of just dropping loot. Purely a name/
# tint/recruitment distinction; combat stats are identical to a plain Wolf
# (see Main.gd:ENEMY_TRAITS).
var is_traitor := false
var wander_dir := Vector2.ZERO
var wander_timer := 0.0
var contact_cooldown := 0.0
var flash_timer := 0.0
var player: Node2D = null
var sprite: Sprite2D
var has_aggro := false

func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# See Player.gd -- Main is PROCESS_MODE_ALWAYS, which would otherwise
	# cascade to us via INHERIT and keep us running while paused.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = BODY_RADIUS
	collision.shape = shape
	add_child(collision)

	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/enemy_wolf.png")
	sprite.scale = Vector2(1.75, 1.75)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if contact_cooldown > 0.0:
		contact_cooldown -= delta
	if flash_timer > 0.0:
		flash_timer -= delta

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	var move_dir := Vector2.ZERO
	if player != null:
		var dist := global_position.distance_to(player.global_position)
		if dist < DETECT_RANGE:
			has_aggro = true
		if has_aggro:
			move_dir = (player.global_position - global_position).normalized()
		else:
			move_dir = _wander(delta)
	else:
		move_dir = _wander(delta)

	velocity = move_dir * SPEED
	move_and_slide()

	if move_dir.x != 0.0:
		sprite.flip_h = move_dir.x < 0.0

	sprite.modulate = Color(1.0, 0.5, 0.5) if flash_timer > 0.0 else Color(1.0, 1.0, 1.0)

	if player != null and contact_cooldown <= 0.0:
		if global_position.distance_to(player.global_position) < CONTACT_RANGE:
			_play_attack_lunge(player.global_position)
			var main := get_parent()
			if main != null and main.has_method("trigger_battle"):
				contact_cooldown = CONTACT_COOLDOWN
				main.trigger_battle(self)
			elif player.has_method("take_damage"):
				player.take_damage(CONTACT_DAMAGE)
				contact_cooldown = CONTACT_COOLDOWN + randf_range(0.0, 0.25)

func get_contact_damage() -> int:
	return CONTACT_DAMAGE

func get_display_name() -> String:
	return "Traitor Wolf" if is_traitor else "Wolf"

func set_battle_cooldown(t: float) -> void:
	contact_cooldown = t

func _wander(delta: float) -> Vector2:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.0, 2.5)
		wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	return wander_dir

# Overworld attack lunge -- a quick forward jab-and-return on the sprite
# itself, played the instant a contact attack actually connects. Safe to
# tween sprite.position/.scale directly: nothing here ever touches either
# property per-frame (only .modulate for flash and .flip_h for facing), and
# the attack cooldown (CONTACT_COOLDOWN, 0.6s+) comfortably outlasts this
# ~0.2s tween so a re-trigger can never overlap it.
func _play_attack_lunge(target_pos: Vector2) -> void:
	var dir: Vector2 = (target_pos - global_position).normalized()
	var base_scale: Vector2 = sprite.scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", dir * 8.0, 0.08)
	tween.tween_property(sprite, "scale", base_scale * 1.15, 0.08)
	tween.chain().set_parallel(true)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.12)
	tween.tween_property(sprite, "scale", base_scale, 0.12)

func take_damage(amount: int) -> void:
	# queue_free() defers to end-of-frame, so a second hit landing the same
	# frame (e.g. Knuckle Gloves' double_strike finishing a low-HP target)
	# would otherwise still see a "live" node and double-drop loot/XP/signal.
	if health <= 0:
		return
	health -= amount
	flash_timer = 0.15
	if health <= 0:
		var main := get_parent()
		if main.has_method("spawn_death_burst"):
			main.spawn_death_burst(global_position)
		_drop_loot()
		died.emit(XP_REWARD)
		queue_free()

func _drop_loot() -> void:
	var coin_count := int(round(randi_range(COIN_MIN, COIN_MAX) * (1.5 if is_elite else 1.0)))
	if coin_count > 0:
		var coin := PickupScript.new()
		coin.kind = "coin"
		coin.amount = coin_count
		coin.position = global_position
		get_parent().add_child(coin)
	if randf() < MEAT_CHANCE:
		var meat := PickupScript.new()
		meat.kind = "meat"
		meat.amount = 1
		meat.position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		get_parent().add_child(meat)
	if is_elite:
		var shard := PickupScript.new()
		shard.kind = "shard"
		shard.amount = 1
		shard.position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		get_parent().add_child(shard)
