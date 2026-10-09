/* Savage Lands battle simulator -- core helpers.
 *
 * Everything numeric comes from SIM_DATA (tools/export_battle_sim_data.gd dumps
 * it straight from the real scripts). The engine files mirror the GDScript they
 * are ported from -- same function names, same order of operations -- so a
 * balance change in the game is a re-export plus (rarely) a small engine edit.
 */
"use strict";

const D = SIM_DATA;
const MC = D.main_consts;     // Main.gd constants
const PC = D.player_consts;   // Player.gd constants
const DEF = D.defense;        // Defense.gd constants

// Defense.gd:reduction -- points of Defense/Fortitude bent into a cut (diminishing returns, ceiling `cap`).
function defense_reduction(points, cap = DEF.BASE_CAP) {
  if (points >= 0) return cap * points / (points + DEF.HALF_POINTS);
  const p = -points;
  return DEF.NEGATIVE_FLOOR * p / (p + DEF.HALF_POINTS);
}
const TRAITS = D.traits;      // Main.gd ENEMY_TRAITS

// ---------------------------------------------------------------- RNG
// Seeded (mulberry32) so a battle can be replayed exactly and batch runs are reproducible.
class RNG {
  constructor(seed) { this.s = (seed >>> 0) || 1; }
  next() {
    this.s = (this.s + 0x6D2B79F5) >>> 0;
    let t = this.s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  randf() { return this.next(); }
  randf_range(a, b) { return a + (b - a) * this.next(); }
  randi_range(a, b) { return a + Math.floor(this.next() * (b - a + 1)); }
  randi_n(n) { return Math.floor(this.next() * n); }
  shuffle(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(this.next() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }
}

// ---------------------------------------------------------------- Vec2i helpers
const V = (x, y) => ({ x, y });
const NONE = V(-1, -1);
const vadd = (a, b) => V(a.x + b.x, a.y + b.y);
const vsub = (a, b) => V(a.x - b.x, a.y - b.y);
const vmul = (a, n) => V(a.x * n, a.y * n);
const veq = (a, b) => a.x === b.x && a.y === b.y;
const vkey = (t) => t.x + "," + t.y;
const vclone = (t) => V(t.x, t.y);
const sign = (n) => (n > 0 ? 1 : n < 0 ? -1 : 0);
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const abs = Math.abs;
// GDScript's round() rounds half away from zero; JS Math.round rounds half up.
const round = (x) => (x < 0 ? -Math.round(-x) : Math.round(x));
const CARDINAL_DIRS = MC.CARDINAL_DIRS.map((d) => V(d[0], d[1]));
const WANDER_DIRS = MC.WANDER_DIRS.map((d) => V(d[0], d[1]));

// ---------------------------------------------------------------- data lookups
const clone = (o) => JSON.parse(JSON.stringify(o));
const W = D.weapons;
function weaponBases() { return [W.club, ...W.bases]; }
function baseById(id) { return weaponBases().find((b) => b.id === id) || null; }
function tierByName(n) { return W.tiers.find((t) => t.tier_name === n) || null; }
function materialById(id) { return W.materials.find((m) => m.id === id) || null; }
function armorById(id) { return D.armor.find((a) => a.id === id) || null; }
function clothingById(id) { return D.clothing.find((c) => c.id === id) || null; }
function potionById(id) { return D.potions.find((p) => p.id === id) || null; }
function foodById(id) { return D.foods.find((f) => f.id === id) || null; }
function consumableById(id) { return potionById(id) || foodById(id) || null; }
function runeById(id) { return D.runes.find((r) => r.id === id) || null; }
function talismanById(id) { return D.talismans.items.find((t) => t.id === id) || null; }
function enemyByName(n) { return D.enemies.find((e) => e.name === n) || null; }
function slotsForLevel(level) {
  let slots = 1;
  for (const req of D.talismans.slot_levels) if (level >= req) slots++;
  return slots;
}

// ---------------------------------------------------------------- weapon variants (Weapons.gd)
// Mirrors Weapons._build_tiered_variant / _build_mythic_variant exactly.
function buildTieredVariant(base, tier, material) {
  const v = clone(base);
  v.tier_name = tier.tier_name;
  v.required_might = tier.required_might;
  if (tier.required_intimidation !== undefined) v.required_intimidation = tier.required_intimidation;
  v.material_name = material.name;
  v.material_id = material.id;
  v.damage_mult = base.damage_mult * tier.damage_scale * material.damage_scale;
  v.price = round(base.price * tier.price_scale * material.price_scale);
  v.break_chance = material.break_chance;
  for (const sp of v.specials) sp.stamina_cost = round(sp.stamina_cost * material.stamina_scale);
  v.id = `${base.id}_${tier.tier_name.toLowerCase()}_${material.id}`;
  const parts = [];
  if (tier.tier_name !== "Fine") parts.push(tier.tier_name);
  if (material.id !== "steel") parts.push(material.name);
  parts.push(base.name);
  v.name = parts.join(" ");
  return v;
}

function buildMythicVariant(base, tier) {
  const myth = W.mythics[base.id];
  const v = clone(base);
  v.tier_name = tier.tier_name;
  v.required_might = tier.required_might;
  if (tier.required_intimidation !== undefined) v.required_intimidation = tier.required_intimidation;
  v.id = `${base.id}_mythic`;
  v.name = myth.name;
  v.description = myth.description;
  v.damage_mult = base.damage_mult * tier.damage_scale;
  v.price = round(base.price * tier.price_scale);
  for (const k of Object.keys(myth.passive)) v[k] = myth.passive[k];
  return v;
}

// Build any weapon from a picker selection: {base, tier, material}. tier "Mythic"
// ignores material; the Club has no variants at all.
function buildWeapon(sel) {
  if (sel.base === "club") return clone(W.club);
  const base = baseById(sel.base);
  const tier = tierByName(sel.tier);
  if (sel.tier === "Mythic" && W.mythics[base.id]) return buildMythicVariant(base, tier);
  return buildTieredVariant(base, tier, materialById(sel.material));
}

// Stone Amulet's doubled material (Weapons.stone_amulet_scales).
function stoneAmuletScales(material) {
  if (material.id === "steel") return { damage_scale: 1.2, price_scale: 0.8, stamina_scale: 0.8, break_chance: 0.0 };
  const m = W.consts.STONE_AMULET_MULT;
  return {
    damage_scale: Math.max(0, 1 + (material.damage_scale - 1) * m),
    price_scale: Math.max(0, 1 + (material.price_scale - 1) * m),
    stamina_scale: Math.max(0, 1 + (material.stamina_scale - 1) * m),
    break_chance: material.break_chance * m,
  };
}

// Blacksmith (Blacksmith.gd)
const BS = D.blacksmith;
const weaponDamageFactor = (lvl) => 1.0 + BS.WEAPON_DAMAGE_PCT_PER_LEVEL * Math.max(lvl, 0);
const weaponBreakFactor = (lvl) => Math.max(0.0, 1.0 - BS.WEAPON_BREAK_REDUCTION_PER_LEVEL * Math.max(lvl, 0));
const armorBonus = (lvl) => BS.ARMOR_DR_PER_LEVEL * Math.max(lvl, 0);
