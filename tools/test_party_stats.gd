extends SceneTree

# The party members' stat tables from the design doc (2026-10-30) and the five stats beyond the original six -- DXT, MGT, ITL,
# CHA, RFL. Their starting values are my drafts (0, except 6 Intelligence for the three casters so a level-1 pool is still 50);
# the per-level multipliers are the doc's.

# kind => [VGR, STR, RES, AGI, MAG, FTD] then [DXT, MGT, ITL, INM (charisma), RFL] -- copied from the doc, not from the code
const DOC := {
	"druid": [[1.4, 0.5, 0.7, 1.0, 1.5, 1.7], [1.2, 0.9, 1.5, 0.8, 1.2]],
	"guardian": [[1.5, 1.3, 2.5, 0.1, 0.8, 1.8], [0.9, 1.4, 1.1, 1.5, 0.5]],
	"marksman": [[0.7, 2.0, 0.1, 1.6, 1.0, 0.2], [1.5, 1.1, 1.2, 2.0, 2.0]],
	"rogue": [[0.7, 1.5, 0.7, 1.9, 1.0, 0.9], [1.6, 1.4, 1.0, 1.3, 1.6]],
	"knight": [[1.2, 1.6, 1.3, 1.4, 0.6, 1.2], [1.0, 1.1, 0.9, 1.4, 0.7]],
	"necromancer": [[2.4, 0.4, 0.7, 0.9, 1.8, 1.4], [0.7, 0.7, 1.2, 1.4, 0.8]],
	"brawler": [[1.5, 1.8, 1.6, 0.6, 0.5, 0.9], [1.8, 1.6, 0.5, 1.3, 1.4]],
	"shaman": [[1.4, 0.4, 1.2, 1.1, 2.1, 1.6], [1.0, 1.0, 1.7, 1.2, 0.7]],
}

func _init() -> void:
	seed(20261107)
	var rules = load("res://scripts/PartyRules.gd")
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	player.max_party_slots = 8
	player.coins = 1000

	print("--- the doc's multipliers")
	var wrong := []
	for kind in DOC:
		var g: Array = DOC[kind][0]
		var x: Array = DOC[kind][1]
		var got := [rules.growth(kind, "hp"), rules.growth(kind, "attack"), rules.growth(kind, "defense"), rules.growth(kind, "speed"), rules.growth(kind, "magic"), rules.growth(kind, "fortitude")]
		var got_x := [rules.extra_growth(kind, "dexterity"), rules.extra_growth(kind, "might"), rules.extra_growth(kind, "intelligence"), rules.extra_growth(kind, "charisma"), rules.extra_growth(kind, "reflexes")]
		for i in 6:
			if absf(float(got[i]) - float(g[i])) > 0.001:
				wrong.append("%s[%d]" % [kind, i])
		for i in 5:
			if absf(float(got_x[i]) - float(x[i])) > 0.001:
				wrong.append("%s x[%d]" % [kind, i])
	print("all eight kinds match the doc's tables: wrong=%s (expected [])" % [wrong])
	var wolf = rules.KINDS["wolf"].final_mult
	print("the Wolf's fixed multipliers: attack %.1f, VGR %.1f, AGI %.1f, MAG %.1f, FTD %.1f (expected 1.4, 0.9, 1.5, 0.5, 0.7)" % [wolf.attack, wolf.hp, wolf.speed, wolf.magic, wolf.fortitude])

	print("--- levelling feeds the new stats")
	var brawler = player.recruit("brawler")
	print("a new Brawler starts at 0 in each: %.0f %.0f %.0f %.0f %.0f (expected 0 0 0 0 0)" % [brawler.dexterity(), brawler.might(), brawler.intelligence(), brawler.charisma(), brawler.reflexes()])
	for i in 10:
		brawler._level_up()
	print("after ten levels: DXT %.1f, MGT %.1f, ITL %.1f, CHA %.1f, RFL %.1f (expected 18.0, 16.0, 5.0, 13.0, 14.0)" % [brawler.dexterity(), brawler.might(), brawler.intelligence(), brawler.charisma(), brawler.reflexes()])
	print("...Might 16 is +48 stamina: %d (expected 148)" % [brawler.max_stamina()])
	print("...Dexterity 18 is +9%% crit: %.3f (expected 0.090); Reflexes 14 is +7%% dodge: %.3f (expected 0.070)" % [brawler.crit_from_dexterity(), brawler.dodge_from_reflexes()])
	print("...its mods carry the crit: %.3f (expected 0.090)" % [float(brawler.effect_mods("").get("crit_chance", 0.0))])
	for i in 40:
		brawler._level_up()
	print("the caps hold: crit %.2f (expected 0.10), dodge %.2f (expected 0.15)" % [brawler.crit_from_dexterity(), brawler.dodge_from_reflexes()])

	print("--- mana comes from Intelligence")
	var druid = player.recruit("druid")
	print("a level-1 Druid has 6 Intelligence and %d mana (expected 50 = 20 + 5 x 6)" % [druid.max_mana()])
	for i in 4:
		druid._level_up()
	print("at level 5 her Intelligence is %.1f and her mana %d (expected 12.0 and 80)" % [druid.intelligence(), druid.max_mana()])
	print("a Brawler has no mana at all: %d (expected 0)" % [brawler.max_mana()])
	var unit: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 2), 1.0)
	print("the battle unit agrees: mana %d of %d (expected 80 of 80, plus Deep Well's %d)" % [unit.mana, unit.max_mana, player.meta_max_mana_flat])

	print("--- Reflexes dodge, Dexterity crit, Charisma prices")
	var bu: Dictionary = main._make_member_battle_unit(brawler, Vector2i(1, 2), 1.0)
	print("the Brawler's unit dodges %.2f (expected 0.15 at the cap)" % [float(bu.dodge_chance)])
	var knight = player.recruit("knight")
	for i in 20:
		knight._level_up()
	var ku: Dictionary = main._make_member_battle_unit(knight, Vector2i(2, 2), 1.0)
	print("the Knight cannot dodge, whatever his Reflexes: %.2f (expected 0.00)" % [float(ku.dodge_chance)])
	player.party = []
	var potion: Dictionary = load("res://scripts/Potions.gd").get_tier("potion_health")
	var shop_cut: float = player._shop_discount()
	var alone: int = player.get_potion_price(potion)
	print("alone, a 15-coin potion costs %d (expected %d)" % [alone, int(round(15.0 * (1.0 - shop_cut) * (1.0 - player.meta_field_surgeon_discount_pct)))])
	var r1 = player.recruit("rogue")
	for i in 8:
		r1._level_up()
	var with_rogue: int = player.get_potion_price(potion)
	var expect_cut: float = r1.charisma()
	print("with a Rogue (CHA %.1f) in the party it costs %d (expected %d, the average taken off the base first)" % [expect_cut, with_rogue, int(round(maxf(1.0, 15.0 - expect_cut) * (1.0 - shop_cut) * (1.0 - player.meta_field_surgeon_discount_pct)))])
	var wolf_member = player.recruit("wolf")
	print("a Wolf does not count towards the average: price %d (expected %d)" % [player.get_potion_price(potion), with_rogue])
	print("a free item stays free: %.1f (expected 0.0)" % [player._less_charisma(0.0)])
	quit()
