extends Node
class_name Beastiary

# Discoverable creature log (SaveData.gd:mark_creature_seen/is_creature_seen,
# device-wide across every save slot) -- HUD.gd's Beastiary screen shows an
# entry the instant it's ever been clicked as a battle target or defeated,
# anywhere. Keys here must match HUD.ENEMY_ICONS/Main.ENEMY_TRAITS exactly --
# all three are keyed by the same battle_units display name.
#
# Deliberately no HP/damage numbers here -- both scale with wave/might
# progression, so there's no single fixed stat block per creature to print.
# HUD.gd's detail panel instead derives a qualitative trait summary
# (Armored/Boss-tier/dodge/etc.) straight from Main.ENEMY_TRAITS at display
# time, and pairs it with just the flavor line below.
static var DESCRIPTIONS := {
	"Goblin": "Common and cowardly alone, but they never seem to travel that way. Hits harder with every packmate still standing.",
	"Orc": "Cunning enough to flank rather than charge, and armored enough to shrug off a shove more often than not.",
	"Apprentice Mage": "Still learning -- but a poorly-aimed bolt of arcane force blinds just as well as a well-aimed one.",
	"Brute": "Built like a boulder and about as easy to knock over. Terrain doesn't slow it down -- nothing does.",
	"Shade": "A whisper of a thing -- one hit is all it takes to end it, if you can land one at all.",
	"Wolf": "Fast, and it knows it. Closes distance before you've finished your first step.",
	"Traitor Wolf": "Once loyal to another master. A rare thing to see wandering wild -- rarer still to see it change sides again.",
	"Centaur Lancer": "Charges in hard and fast, no interest in finesse.",
	"Centaur Archer": "Keeps its distance and its aim steady, retreating the instant you close in.",
	"Fae Hut": "Doesn't fight. Doesn't need to -- it just keeps sending more of them.",
	"Fae": "Small, quick, and rarely alone for long.",
	"Gnome": "Unassuming, until you realize how many just arrived.",
	"Leviathan": "An ancient, patient mind that reaches into yours from well beyond arm's length.",
	"Lizen Warband": "Not one creature, but never fights like fewer than several -- bites come often and quick.",
	"Black Dragonlet": "Young by dragon standards. Old enough to open a wound that won't stop bleeding.",
	"Treant": "Rooted, patient, and nearly impossible to push around once it plants itself.",
	"Elder Oak": "A Treant grown ancient -- and its branches now reach further than most spears.",
	"Iron Construct": "Doesn't dodge. Doesn't flinch. Doesn't move, half the time -- it doesn't need to.",
	"White Dragon": "Cold enough to freeze the fight itself -- its breath doesn't discriminate by distance.",
	"Lava Construct": "Iron Construct's molten cousin -- lumbers, rather than stands still, but hits just as hard.",
	"Red Wyrm": "The oldest and toughest dragon anyone's catalogued -- 'wyrm' isn't a compliment, it's a warning.",
	"Voidwing": "Fast, evasive, and firing bolts that don't care what's standing in the way.",
	"Archmage": "A glass cannon in the truest sense -- devastating reach, and none of the armor to back it up.",
}

static func get_description(name: String) -> String:
	return DESCRIPTIONS.get(name, "")
