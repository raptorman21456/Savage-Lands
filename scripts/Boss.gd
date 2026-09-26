extends CharacterBody2D
class_name Boss

const PickupScript := preload("res://scripts/Pickup.gd")

signal died(xp_reward: int)

const SPEED := 45.0
const WINDUP_SPEED_FRACTION := 0.3
const MAX_HEALTH := 150
const ATTACK_DAMAGE := 6
const DETECT_RANGE := 200.0
const ATTACK_RANGE := 56.0
const HURTBOX_RADIUS := 110.0
const WINDUP_TIME := 0.7
const ATTACK_COOLDOWN := 1.2
const BODY_RADIUS := 30.0
# A boss only shows up once every BOSS_WAVE_INTERVAL waves and replaces that
# whole wave's usual goblin/orc roster with one hard solo fight, so its
# payout needs to clearly beat what clearing a full normal wave would have
# given -- not just edge it out.
const XP_REWARD := 500
const COIN_MIN := 80
const COIN_MAX := 120
const MEAT_CHANCE := 1.0

var health := MAX_HEALTH
# Always false in practice -- Boss spawns via its own separate path
# (_spawn_boss_wave) which never rolls elite, but the field still needs to
# exist so Main.gd's generic elite check in _setup_battle_grid doesn't have
# to special-case "this squad member might not have this property."
var is_elite := false
var wander_dir := Vector2.ZERO
var wander_timer := 0.0
var windup_timer := 0.0
var is_winding_up := false
var attack_cooldown := 0.0
var flash_timer := 0.0
var player: Node2D = null
var sprite: Sprite2D

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
	sprite.texture = preload("res://assets/enemy_boss.png")
	sprite.scale = Vector2(3.75, 3.75)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if flash_timer > 0.0:
		flash_timer -= delta

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if is_winding_up:
		var track_dir := Vector2.ZERO
		if player != null:
			track_dir = (player.global_position - global_position).normalized()
		velocity = track_dir * SPEED * WINDUP_SPEED_FRACTION
		move_and_slide()
		if track_dir.x != 0.0:
			sprite.flip_h = track_dir.x < 0.0
		windup_timer -= delta
		if windup_timer <= 0.0:
			_finish_windup()
	else:
		var move_dir := Vector2.ZERO
		if player != null:
			var dist := global_position.distance_to(player.global_position)
			if dist < ATTACK_RANGE and attack_cooldown <= 0.0:
				is_winding_up = true
				windup_timer = WINDUP_TIME
			elif dist < DETECT_RANGE:
				move_dir = (player.global_position - global_position).normalized()
			else:
				move_dir = _wander(delta)
		else:
			move_dir = _wander(delta)

		velocity = move_dir * SPEED
		move_and_slide()

		if move_dir.x != 0.0:
			sprite.flip_h = move_dir.x < 0.0

	if flash_timer > 0.0:
		sprite.modulate = Color(1.0, 0.5, 0.5)
	elif is_winding_up:
		var progress: float = 1.0 - clamp(windup_timer / WINDUP_TIME, 0.0, 1.0)
		sprite.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.35, 0.05), progress)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0)

func _finish_windup() -> void:
	is_winding_up = false
	attack_cooldown = ATTACK_COOLDOWN + randf_range(0.0, 0.3)
	if player != null and global_position.distance_to(player.global_position) < HURTBOX_RADIUS:
		_play_attack_lunge(player.global_position)
		var main := get_parent()
		if main != null and main.has_method("trigger_battle"):
			main.trigger_battle(self)
		elif player.has_method("take_damage"):
			player.take_damage(ATTACK_DAMAGE)

func get_contact_damage() -> int:
	return ATTACK_DAMAGE

func get_display_name() -> String:
	return "Boss"

func set_battle_cooldown(t: float) -> void:
	attack_cooldown = t
	is_winding_up = false

func _wander(delta: float) -> Vector2:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.0, 2.5)
		wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	return wander_dir

# The telegraphed windup finally landing gets a bigger, snappier strike than
# a plain contact enemy's jab (see Enemy.gd etc.) -- on top of the existing
# orange windup tint (a different property, .modulate vs .position/.scale,
# so the two never conflict). Safe to tween sprite.position/.scale directly:
# nothing here ever touches either property per-frame. No tween-kill guard
# needed -- ATTACK_COOLDOWN (1.2s+) comfortably outlasts this ~0.25s tween.
func _play_attack_lunge(target_pos: Vector2) -> void:
	var dir: Vector2 = (target_pos - global_position).normalized()
	var base_scale: Vector2 = sprite.scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", dir * 12.0, 0.1)
	tween.tween_property(sprite, "scale", base_scale * 1.2, 0.1)
	tween.chain().set_parallel(true)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.15)
	tween.tween_property(sprite, "scale", base_scale, 0.15)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	flash_timer = 0.15
	if is_winding_up:
		is_winding_up = false
		attack_cooldown = ATTACK_COOLDOWN * 0.5
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
