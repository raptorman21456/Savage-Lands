extends Area2D
class_name Pickup

# Gold is plentiful: every ordinary enemy's coin range is scaled by this (a
# Goblin's 1-2 becomes 3-6). Bosses and minibosses, whose ranges start at
# BOSS_COIN_FLOOR or more, are already big and rare, so they are left as they
# were. Elites still pay 1.5x on top. Every enemy script's _drop_loot rolls
# through roll_coins, so this one number tunes the whole economy's income.
const COIN_DROP_MULT := 3.0
const BOSS_COIN_FLOOR := 50

static func roll_coins(coin_min: int, coin_max: int, is_elite: bool) -> int:
	var scale: float = 1.0 if coin_min >= BOSS_COIN_FLOOR else COIN_DROP_MULT
	var rolled: int = randi_range(int(round(coin_min * scale)), int(round(coin_max * scale)))
	return int(round(rolled * (1.5 if is_elite else 1.0)))

var kind := "coin"
var amount := 1
var sprite: Sprite2D

func _ready() -> void:
	add_to_group("pickups")
	monitoring = true

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	collision.shape = shape
	add_child(collision)

	sprite = Sprite2D.new()
	sprite.texture = _texture_for_kind()
	sprite.scale = Vector2(1.5, 1.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	body_entered.connect(_on_body_entered)

func _texture_for_kind() -> Texture2D:
	match kind:
		"coin":
			return preload("res://assets/coin.png")
		"shard":
			return preload("res://assets/runic_shard.png")
		_:
			return preload("res://assets/meat.png")

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if kind == "coin" and body.has_method("add_coins"):
		body.add_coins(amount)
		_play_pickup_sfx("coin")
		queue_free()
	elif kind == "meat" and body.has_method("add_healing_item"):
		body.add_healing_item(1)
		_play_pickup_sfx("item")
		queue_free()
	elif kind == "shard" and body.has_method("add_runic_shards"):
		body.add_runic_shards(amount)
		_play_pickup_sfx("shard")
		queue_free()

# Pickups are always added as a direct child of Main (see every enemy's
# _drop_loot() and test_pickups.gd), which is where play_sfx() lives.
func _play_pickup_sfx(sfx_name: String) -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("play_sfx"):
		parent.play_sfx(sfx_name)
