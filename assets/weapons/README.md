# Weapon icons

32x32 PNGs, drawn with a dark outline and light from the upper left.

## Generated icons (don't hand-edit)

`<base>_<material>.png` (e.g. `spear_gold.png`, `battle_axe_bone.png`) plus `club.png`.
Made by `tools/gen_weapon_icons.gd`; re-run it to regenerate after changing a shape or a
material palette:

    godot --headless --path . --script res://tools/gen_weapon_icons.gd
    godot --headless --editor --path . --quit      # imports the new PNGs

Bases: `spear greatsword hammer battle_axe dagger bow knuckle_gloves hand_picks`
Materials: `wood steel gold bone silver obsidian`

## Your own art (Legendary and Mythic)

Drop a 32x32 PNG in this folder with one of these names and the game uses it in place of the
generated icon. No code change needed; missing files just fall back to the generated one, so
you can add them one weapon at a time. Most specific name wins:

| File                                  | Used for                                              |
| ------------------------------------- | ----------------------------------------------------- |
| `legendary_<base>_<material>.png`     | a Legendary of that base and that material            |
| `legendary_<base>.png`                | any Legendary of that base                            |
| `mythic_<base>_<material>.png`        | a Mythic of that base (Mythics count as `gold`)       |
| `mythic_<base>.png`                   | any Mythic of that base                               |

Examples: `legendary_spear.png`, `legendary_battle_axe.png`, `mythic_dagger.png`.

Open the project in the Godot editor once after adding files so it imports them. Cards draw
the icon at 2x (64x64) with nearest-neighbour scaling, so keep the art pixel-crisp.

The red Legendary border and glow (and the gold Mythic one) come from the card, not the icon,
so don't paint a frame or glow into the art.
