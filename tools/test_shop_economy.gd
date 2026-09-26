extends SceneTree

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var weapons = load("res://scripts/Weapons.gd")

	player.stat_intimidation = 20
	var spear_price: int = player.get_weapon_price(weapons.SPEAR)
	print("spear price at intimidation=20: %d (expected round(15*0.8)=12)" % spear_price)

	player.coins = 12
	var bought: bool = player.try_buy_weapon(weapons.SPEAR)
	print("bought spear=%s coins_left=%d owns_spear=%s" % [bought, player.coins, player.owned_weapons.has("spear")])

	var equipped_club: bool = player.try_buy_weapon(weapons.CLUB)
	print("re-equip club=%s coins_unchanged=%d current=%s" % [equipped_club, player.coins, player.current_weapon.id])

	var reequip_spear: bool = player.try_buy_weapon(weapons.SPEAR)
	print("re-equip owned spear=%s coins_still=%d current=%s (expect free, no coin change)" % [reequip_spear, player.coins, player.current_weapon.id])

	var greatsword_price: int = player.get_weapon_price(weapons.GREATSWORD)
	var failed_buy: bool = player.try_buy_weapon(weapons.GREATSWORD)
	print("greatsword price=%d, buy with 0 coins succeeded=%s (expected false), current still=%s" % [
		greatsword_price, failed_buy, player.current_weapon.id
	])

	player.stat_intimidation = 500
	var capped_price: int = player.get_weapon_price(weapons.BATTLE_AXE)
	print("battle axe price at intimidation=500: %d (expected capped at round(40*0.25)=10)" % capped_price)

	quit()
