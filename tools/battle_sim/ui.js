/* Battle simulator UI. Everything numeric comes from the engine / SIM_DATA. */
"use strict";

// ================================================================== small helpers
const $ = (s, r) => (r || document).querySelector(s);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const pct = (x, d = 0) => (x * 100).toFixed(d) + "%";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const capital = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const DIR_ARROW = (d) => (d.x === 1 ? "→" : d.x === -1 ? "←" : d.y === 1 ? "↓" : "↑");

const NOTHINGNESS_ORDER = ["Leviathan", "Lizen Warband", "Elder Oak", "White Dragon", "Red Wyrm", "Archmage"];
// Astral upgrades that touch the tile battle (the rest are shop/economy/run-start perks). Update when the tree changes.
const COMBAT_UPGRADES = new Set(["strength", "agility", "vigor", "reflexes_unlock", "berserker_edge", "adrenaline", "dexterity_unlock", "battle_hardened",
  "pack_leader", "prodigy", "warlord", "beastmaster", "riposte", "momentum", "rage", "hardened", "intimidation", "luck", "silver_tongue", "haggling",
  "stamina", "resilience_unlock", "herbalism", "vampiric_grit", "vigilant_defense", "undying", "block_master", "second_breath", "favour", "last_stand",
  "shield_mastery", "unbreakable_guard", "worldwalker", "warband", "battle_medic", "war_chest", "war_profiteer", "windfall", "pack_bond"]);
const PASSIVE_LABELS = {
  passive_double_hit_chance: (v) => `${pct(v)} chance to strike twice`, passive_lifesteal_pct: (v) => `Heals ${pct(v)} of damage dealt`,
  passive_free_specials: () => "Specials cost no stamina", passive_heal_chance: (v) => `${pct(v)} chance to heal on hit`, passive_stun_chance: (v) => `${pct(v)} chance to stun`,
  passive_oneshot_chance: (v) => `${pct(v)} chance to one-shot non-bosses (plain attacks)`, passive_extra_range: (v) => `+${v} attack range`,
  passive_damage_per_tile_distance: (v) => `${v > 0 ? "+" : ""}${pct(v)} damage per tile of distance`, passive_guaranteed_knockback: () => "Knockback always lands (2 tiles)",
  passive_unlimited_range: () => "Can hit any enemy on the grid", passive_ignore_cover: () => "Ignores rock cover", passive_armor_pierce_pct: (v) => `+${pct(v)} damage vs armored`,
  passive_undead_boss_bonus: (v) => `+${pct(v)} damage vs undead/bosses`, passive_free_special_chance: (v) => `${pct(v)} chance a special is free`,
  passive_double_strike: () => "", passive_execute_bonus: (v) => `+${pct(v)} vs <30% HP`, passive_self_damage_pct: (v) => `Recoil ${pct(v)} of damage dealt`, passive_cleave_pct: (v) => `Splash ${pct(v)}`,
};

// ================================================================== config
const LS_KEY = "savageLandsBattleSim.cfg.v2";
function defaultCfg() {
  return {
    level: 10, picks: {}, upgrades: {}, difficulty: "normal", coins: 0, waves_cleared: 0,
    weapon: { base: "club", tier: "Fine", material: "steel" }, blacksmith: 0, rune: "", learn_all: true, whisperer: [],
    armor: "armor_rags", armor_level: 0, clothing: { head: "", body: "", feet: "" }, shield: "",
    talismans: [], ignore_slots: false, arrows: { flame: 0, freeze: 0, bomb: 0 }, consumables: [{ id: "potion_health", n: 2 }],
    party: [], enemies: [{ name: "Goblin", elite: false, power_tier: 1 }, { name: "Goblin", elite: false, power_tier: 1 }], world: "plains",
    seed: 12345, real_miss: true, enforce_gates: false,
    policy: { heal_below: 35, stamina_reserve: 0, use_specials: true, use_heavy: true, use_arrows: true, picks: "strength,vigor,strength,vigor,agility", max_turns: 60 },
    speed: 250, show_noncombat: false,
  };
}
let cfg = (() => {
  const d = defaultCfg();
  try { const raw = localStorage.getItem(LS_KEY); if (raw) return Object.assign(d, JSON.parse(raw)); } catch (e) { /* fine */ }
  return d;
})();
function saveCfg() { try { localStorage.setItem(LS_KEY, JSON.stringify(cfg)); } catch (e) { /* fine */ } }

let sim = null, uiMenu = "main", busy = false, autoRunning = false, openSections = {};
let hoverDesc = "";

// the config actually handed to the engine (slots enforced unless overridden)
function battleCfg() {
  const c = JSON.parse(JSON.stringify(cfg));
  const slots = slotsForLevel(c.level);
  if (!c.ignore_slots) c.talismans = c.talismans.slice(0, slots);
  const used = Object.values(c.picks).reduce((a, b) => a + b, 0);
  if (used > c.level - 1) { /* clamp: more picks than level-ups can't exist */ let over = used - (c.level - 1); for (const k of Object.keys(c.picks)) { const t = Math.min(over, c.picks[k]); c.picks[k] -= t; over -= t; if (!over) break; } }
  c.consumables = c.consumables.filter((x) => x.n > 0);
  c.enemies = c.enemies.map((e) => ({ name: e.name, elite: !!e.elite, power_tier: e.power_tier || 1 }));
  c.seed = cfg.seed;
  return c;
}
function previewPlayer() {
  try { const s = new Sim(1); s.player.configure(battleCfg()); return s.player; } catch (e) { return null; }
}

// ================================================================== config panel
function opt(value, label, sel) { return `<option value="${esc(value)}"${sel ? " selected" : ""}>${esc(label)}</option>`; }
function selectHtml(path, options, current, extra = "") { return `<select data-path="${path}" ${extra}>${options.map(([v, l]) => opt(v, l, v === current)).join("")}</select>`; }
function numHtml(path, val, min, max, step = 1) { return `<input type="number" data-path="${path}" data-num="1" value="${val}" min="${min}" max="${max}" step="${step}">`; }

function section(name, body, summaryExtra = "") {
  return `<details class="sec" data-sec="${name}" ${openSections[name] === false ? "" : "open"}><summary>${name}${summaryExtra}</summary><div class="body">${body}</div></details>`;
}

function pickableStats(p) {
  const base = ["strength", "vigor", "agility", "might", "intimidation"];
  if (p.meta_resilience_unlocked) base.push("resilience");
  if (p.meta_reflexes_unlocked) base.push("reflexes");
  if (p.meta_dexterity_unlocked) base.push("dexterity");
  return base;
}

function secCharacter(p) {
  const picks = cfg.picks;
  const stats = pickableStats(p);
  const used = stats.reduce((a, s) => a + (picks[s] || 0), 0);
  const left = cfg.level - 1 - used;
  const per = (s) => (s === "agility" ? PC.AGILITY_BONUS_PER_LEVEL + p.meta_levelup_bonus_agility : s === "strength" ? 1 + p.meta_levelup_bonus_strength : s === "vigor" ? 1 + p.meta_levelup_bonus_vigor : s === "intimidation" ? 1 + p.meta_levelup_bonus_intimidation : 1) * (p.meta_bonus_levelup_stat ? 2 : 1);
  const rows = stats.map((s) => `<tr><td>${capital(s)}</td><td>${p["stat_" + s]}</td><td><span class="stepper"><button data-act="pick" data-s="${s}" data-d="-1">−</button><span>${picks[s] || 0}</span><button data-act="pick" data-s="${s}" data-d="1">+</button></span></td><td class="dim">+${per(s)}/pt</td></tr>`).join("");
  return section("Character", `
    <div class="row"><label>Level</label>${numHtml("level", cfg.level, 1, 99)}<label style="min-width:auto">Difficulty</label>${selectHtml("difficulty", D.upgrades.difficulties.map((d) => [d.id, `${d.name} (x${d.mult})`]), cfg.difficulty)}</div>
    <div class="row"><label>Coins</label>${numHtml("coins", cfg.coins, 0, 99999)}<label style="min-width:auto" title="Waves cleared this run -- Hardened upgrade gives +HP per wave">Waves cleared</label>${numHtml("waves_cleared", cfg.waves_cleared, 0, 200)}</div>
    <div class="dim" style="margin:4px 0">Every level-up gives +1 to each core stat automatically, plus <b>one</b> bonus point you place (below).</div>
    <table class="kv stats"><tr><td><b>Stat</b></td><td><b>Value</b></td><td><b>Points</b></td><td></td></tr>${rows}</table>
    <div class="row"><span class="${left < 0 ? "warn" : "dim"}">Unspent points: ${left}</span>
      <button data-act="fillpicks" data-s="strength">All Str</button><button data-act="fillpicks" data-s="vigor">All Vig</button><button data-act="fillpicks" data-s="balanced">Balanced</button><button data-act="fillpicks" data-s="reset">Reset</button></div>
    <table class="kv">
      <tr><td>Max HP</td><td>${p.max_health}</td></tr><tr><td>Attack (base damage)</td><td>${p.attack_damage}</td></tr>
      <tr><td>Move range (battle)</td><td>${MC.PLAYER_BASE_MOVE_RANGE + Math.max(0, Math.trunc((p.stat_agility - PC.AGILITY_START) / MC.AGILITY_PER_EXTRA_MOVE)) + Math.trunc(p.talisman_bonus("move_range"))} tiles</td></tr>
      <tr><td>Stamina (max / start)</td><td>${p.max_stamina} / ${round(p.max_stamina * PC.BATTLE_START_STAMINA_PCT)}</td></tr>
      <tr><td>Crit / Dodge</td><td>${pct(p.crit_chance_total(), 1)} / ${pct(p.dodge_chance_total(), 1)}</td></tr>
      <tr><td>Damage reduction (armor+clothes+shield+res.)</td><td>${pct(Math.min(0.9, p.armor_damage_reduction() + p.resilience_reduction + p.meta_war_chest_reduction + p.shield_damage_reduction_pct()), 1)}</td></tr>
      <tr><td>Talisman slots</td><td>${slotsForLevel(cfg.level)}</td></tr></table>`);
}

function weaponReqWarn(w) {
  const p = previewPlayer();
  const warns = [];
  if (p && (w.required_might || 0) > p.stat_might) warns.push(`needs Might ${w.required_might} (you have ${p.stat_might})`);
  if (p && (w.required_intimidation || 0) > p.stat_intimidation) warns.push(`needs Intimidation ${w.required_intimidation} (you have ${p.stat_intimidation})`);
  return warns;
}
function secWeapon(p) {
  const w = p.current_weapon;
  const sel = cfg.weapon;
  const bases = weaponBases();
  const tiers = W.tiers.map((t) => [t.tier_name, `${t.tier_name} (x${t.damage_scale} dmg${t.required_might ? ", Might " + t.required_might : ""}${t.required_intimidation ? ", Int " + t.required_intimidation : ""})`]);
  const mats = W.materials.map((m) => [m.id, `${m.name} (x${m.damage_scale} dmg, x${m.stamina_scale} stam${m.break_chance ? ", " + pct(m.break_chance) + " break" : ""})`]);
  const isClub = sel.base === "club", isMythic = sel.tier === "Mythic" && W.mythics[sel.base];
  const passives = Object.keys(w).filter((k) => k.startsWith("passive_")).map((k) => (PASSIVE_LABELS[k] ? PASSIVE_LABELS[k](w[k]) : `${k}: ${w[k]}`)).filter(Boolean);
  const matPassive = !isMythic && !isClub ? { wood: "Quick Strikes: 10% chance to strike twice", gold: "Gilded Strike: +1 coin when you land a kill", bone: "Dreadful Strike: 7.5% chance to terrify the target", silver: "Cleansing Strike: 15% chance a hit cleanses one of your afflictions", obsidian: "Splinter Strike: 5% chance a hit causes Bleeding", steel: "" }[sel.material] : "";
  const specials = (w.specials || []).map((sp) => { const hits = sp.hit_count_max ? ` x- hits` : sp.pass_count_max ? ` x- passes` : ""; const pc = sp.dmg_mult ? Math.round(sp.dmg_mult * 100) + "%" + hits : "special"; return `<tr><td>${esc(sp.name)}<div class="dim" style="font-size:11px">${pc} dmg · ${esc(sp.effect || "plain")}</div></td><td title="stamina cost">${sp.stamina_cost}</td><td class="dim" style="text-align:left;font-size:11px">${esc(sp.description || "")}</td></tr>`; }).join("");
  const warns = weaponReqWarn(w);
  return section("Weapon", `
    <div class="row"><label>Weapon</label>${selectHtml("weapon.base", bases.map((b) => [b.id, b.name]), sel.base)}</div>
    <div class="row"><label>Quality</label>${selectHtml("weapon.tier", tiers, sel.tier, isClub ? "disabled" : "")}</div>
    <div class="row"><label>Material</label>${selectHtml("weapon.material", mats, sel.material, isClub || isMythic ? "disabled" : "")}</div>
    <div class="row"><label>Blacksmith</label>${numHtml("blacksmith", cfg.blacksmith, 0, BS.WEAPON_MAX_LEVEL)}<span class="dim">+${BS.WEAPON_DAMAGE_PCT_PER_LEVEL * 100}% dmg / level, −10% break</span></div>
    <div class="row"><label>Rune</label>${selectHtml("rune", [["", "None"], ...D.runes.map((r) => [r.id, r.name])], cfg.rune, isClub ? "disabled" : "")}</div>
    <div class="row"><label></label><label><input type="checkbox" data-path="learn_all" data-bool="1" ${cfg.learn_all ? "checked" : ""}> All specials learned at the Dojo (halves miss chance)</label></div>
    ${warns.length ? `<div class="warn">Not equippable in the real game until: ${warns.join("; ")}.</div>` : ""}
    <h2 style="margin-top:8px">${esc(w.name)}</h2>
    <table class="kv">
      <tr><td>Damage multiplier</td><td>${w.damage_mult.toFixed(3)}</td></tr>
      <tr><td>Plain hit (your Attack ${p.attack_damage})</td><td>${round(p.attack_damage * w.damage_mult)} dmg</td></tr>
      <tr><td>Heavy attack (x${W.consts.HEAVY_DAMAGE_MULT}, ${w.heavy_stamina_cost_override ?? W.consts.HEAVY_STAMINA_COST} stam)</td><td>${round(p.attack_damage * w.damage_mult * W.consts.HEAVY_DAMAGE_MULT)} dmg</td></tr>
      <tr><td>Range / long-range</td><td>${w.passive_unlimited_range ? "whole grid" : (w.long_range ? 2 : 1) + (w.passive_extra_range || 0)} tiles</td></tr>
      <tr><td>Break chance per hit</td><td>${pct(w.break_chance || 0, 1)}</td></tr>
      <tr><td>Miss chance</td><td>${pct(p.miss_chance_for(w), 1)}</td></tr>
      ${w.regular_attack_stamina_cost ? `<tr><td>Regular attack stamina</td><td>${w.regular_attack_stamina_cost}</td></tr>` : ""}
    </table>
    ${matPassive ? `<div class="dim" style="margin-top:4px">Material: ${esc(matPassive)}</div>` : ""}
    ${passives.length ? `<div class="chips" style="margin-top:4px">${passives.map((x) => `<span class="chip info">${esc(x)}</span>`).join("")}</div>` : ""}
    ${specials ? `<table class="kv" style="margin-top:6px"><tr><td><b>Special</b></td><td><b>Stam</b></td><td></td></tr>${specials}</table>` : ""}`);
}

function secGear() {
  const armor = armorById(cfg.armor);
  return section("Armor, clothing & shield", `
    <div class="row"><label>Armor</label>${selectHtml("armor", D.armor.map((a) => [a.id, `${a.name} (−${pct(a.damage_reduction)})`]), cfg.armor)}</div>
    <div class="row"><label>Smithing</label>${numHtml("armor_level", armor && armor.metal ? cfg.armor_level : 0, 0, BS.ARMOR_MAX_LEVEL)} <span class="dim">${armor && armor.metal ? "+2.5% DR per level" : "(metal armor only)"}</span></div>
    ${["head", "body", "feet"].map((slot) => `<div class="row"><label>${capital(slot)}</label>${selectHtml("clothing." + slot, [["", "None"], ...D.clothing.filter((c) => c.slot === slot).map((c) => [c.id, `${c.name} (−${pct(c.damage_reduction)})`])], cfg.clothing[slot])}</div>`).join("")}
    <div class="row"><label>Shield</label>${selectHtml("shield", [["", "None"], ...Object.values(D.shields).map((s) => [s.id, s.name])], cfg.shield)}</div>
    ${cfg.shield ? `<div class="dim">${esc(D.shields[cfg.shield].description)}</div>` : ""}`);
}

function secItems() {
  const addOpts = [...D.potions, ...D.foods].map((c) => [c.id, `${c.name}`]);
  const rows = cfg.consumables.map((c, i) => {
    const it = consumableById(c.id);
    return `<div class="list-row"><span class="grow">${esc(it.name)} <small class="dim">${esc(it.description || "")}</small></span>
      <span class="stepper"><button data-act="citem" data-i="${i}" data-d="-1">−</button><span>${c.n}</span><button data-act="citem" data-i="${i}" data-d="1">+</button></span>
      <button data-act="cmove" data-i="${i}" data-d="-1">▲</button><button data-act="cmove" data-i="${i}" data-d="1">▼</button><button data-act="cdel" data-i="${i}">✕</button></div>`;
  }).join("");
  return section("Items & arrows", `
    <div class="dim">The Item button uses the first item in this list, one at a time, exactly like the game's queue.</div>
    ${rows || '<div class="dim">No items.</div>'}
    <div class="row"><select id="addItemSel">${addOpts.map(([v, l]) => opt(v, l)).join("")}</select><button data-act="cadd">Add item</button></div>
    <h2 style="margin-top:8px">Special arrows (Bow)</h2>
    <div class="row"><label>Flame</label>${numHtml("arrows.flame", cfg.arrows.flame, 0, 99)}<label style="min-width:auto">Freeze</label>${numHtml("arrows.freeze", cfg.arrows.freeze, 0, 99)}<label style="min-width:auto">Bomb</label>${numHtml("arrows.bomb", cfg.arrows.bomb, 0, 99)}</div>`);
}

function secTalismans() {
  const slots = slotsForLevel(cfg.level);
  const on = new Set(cfg.talismans);
  const grid = D.talismans.items.map((t) => `<div class="tal ${t.rarity}${on.has(t.id) ? " on" : ""}" data-act="tal" data-id="${t.id}"><b>${esc(t.name)}</b> <small class="dim">${t.rarity}</small><div class="d">${esc(t.description)}</div></div>`).join("");
  const whisp = on.has("weapon_whisperer");
  const allSpecials = []; for (const b of weaponBases()) for (const sp of (b.specials || [])) allSpecials.push([sp.id, `${b.name}: ${sp.name}`]);
  const wh = whisp ? `<div class="row"><label>Whisperer</label></div>${[0, 1, 2].map((i) => `<div class="row"><label>Slot ${i + 1}</label><select data-act="whisper" data-i="${i}">${[["", "— (weapon's own)"], ...allSpecials].map(([v, l]) => opt(v, l, (cfg.whisperer[i] || "") === v)).join("")}</select></div>`).join("")}` : "";
  return section("Talismans", `
    <div class="row"><span>${cfg.talismans.length} / ${slots} slots used (level ${cfg.level})</span><label style="min-width:auto"><input type="checkbox" data-path="ignore_slots" data-bool="1" ${cfg.ignore_slots ? "checked" : ""}> ignore slot limit</label></div>
    ${cfg.talismans.length > slots && !cfg.ignore_slots ? `<div class="warn">Over the slot limit — only the first ${slots} will be worn.</div>` : ""}
    <div class="tal-grid">${grid}</div>${wh}`, ` <small class="dim">(${cfg.talismans.length})</small>`);
}

function secUpgrades() {
  const defs = D.upgrades.defs;
  const rows = D.upgrades.ids.filter((id) => cfg.show_noncombat || COMBAT_UPGRADES.has(id)).map((id) => {
    const d = defs[id], lvl = cfg.upgrades[id] || 0, max = d.max_level || 10;
    const pre = (d.prereqs || []).filter((r) => (cfg.upgrades[r.id] || 0) < r.min_level).map((r) => `${defs[r.id].name} ${r.min_level}`);
    return `<div class="upg"><span class="n">${esc(d.name)}${d.max_level ? ` <small class="dim">max ${d.max_level}</small>` : ""}</span>
      <span class="stepper"><button data-act="upg" data-id="${id}" data-d="-1">−</button><span>${lvl}</span><button data-act="upg" data-id="${id}" data-d="1">+</button></span>
      <span class="d">${esc(d.description)}${lvl > 0 && pre.length ? `<br><span class="warn">(prereq not met in-game: ${pre.join(", ")})</span>` : ""}</span></div>`;
  }).join("");
  const n = Object.values(cfg.upgrades).filter((v) => v > 0).length;
  return section("Astral upgrades", `
    <div class="row"><button data-act="upgclear">Clear all</button><button data-act="upgmax">Max combat upgrades</button><label style="min-width:auto"><input type="checkbox" data-path="show_noncombat" data-bool="1" ${cfg.show_noncombat ? "checked" : ""}> show non-combat</label></div>
    ${rows}`, ` <small class="dim">(${n} owned)</small>`);
}

function secParty(p) {
  const kinds = Object.keys(D.party.kinds);
  const auto = [];
  if (p.party_members.length) for (const m of p.party_members) auto.push(`${m.name} (from Astral upgrade)`);
  const beast = (cfg.upgrades.beastmaster || 0) > 0;
  const cap = p.party_capacity();
  const rows = cfg.party.map((m, i) => {
    const r = D.party.kinds[m.kind];
    const pickable = r.stats || [];
    const picksUsed = pickable.reduce((a, s) => a + ((m.picks || {})[s] || 0), 0);
    const left = r.levels ? m.level - 1 - picksUsed : 0;
    const picks = r.levels ? pickable.map((s) => `<span class="stepper">${s}<button data-act="mpick" data-i="${i}" data-s="${s}" data-d="-1">−</button><span>${(m.picks || {})[s] || 0}</span><button data-act="mpick" data-i="${i}" data-s="${s}" data-d="1">+</button></span>`).join(" ") : "";
    const pm = new PartyMemberModel(m.kind, m.level, m.picks);
    return `<div class="list-row"><b class="grow">${esc(r.name)}</b>${r.levels ? `Lv <input type="number" data-act="mlevel" data-i="${i}" value="${m.level}" min="1" max="99" style="width:56px">` : ""}<button data-act="mdel" data-i="${i}">✕</button>
      <div style="width:100%" class="dim">HP ${pm.max_hp()} · ATK ${pm.attack().toFixed(1)} · DEF ${pm.defense_pct().toFixed(1)}% · move ${pm.move_tiles()} · range ${r.attack_range}</div>
      ${picks ? `<div style="width:100%">${picks} <span class="${left < 0 ? "warn" : "dim"}">(${left} pts left)</span></div>` : ""}</div>`;
  }).join("");
  return section("Party", `
    <div class="dim">Capacity ${p.party_members.length + p.party.length}/${cap} (wolves and mercenaries count). Allies fight when you command them each round.</div>
    ${auto.map((a) => `<div class="chip good">${esc(a)}</div>`).join(" ")}${beast ? '<div class="chip good">Traitor Wolf (Beastmaster)</div>' : ""}
    ${rows}
    <div class="row"><select id="addMemberSel">${kinds.map((k) => opt(k, D.party.kinds[k].name)).join("")}</select><button data-act="madd">Add member</button></div>
    ${p.party_members.length + p.party.length > cap ? `<div class="warn">Over capacity — extra recruits won't take the field (raise it with Pack Leader / Warlord / Wolf Fang).</div>` : ""}`,
    ` <small class="dim">(${cfg.party.length})</small>`);
}

const PRESETS = [
  ["Goblin pair", ["Goblin", "Goblin"]], ["Goblin trio", ["Goblin", "Goblin", "Goblin"]], ["Orc", ["Orc"]], ["Orc + 2 Goblins", ["Orc", "Goblin", "Goblin"]],
  ["Brute + Orc", ["Brute", "Orc"]], ["Brute pair", ["Brute", "Brute"]], ["Mage + 2 Goblins", ["Apprentice Mage", "Goblin", "Goblin"]], ["Wolf pack (3)", ["Wolf", "Wolf", "Wolf"]],
  ["Gnome mob (5)", ["Gnome", "Gnome", "Gnome", "Gnome", "Gnome"]], ["Centaur pack", ["Centaur Lancer", "Centaur Archer", "Centaur Archer"]], ["Shades (2)", ["Shade", "Shade"]],
  ["Fae Hut + Goblin", ["Fae Hut", "Goblin"]],
];
function secEncounter() {
  const regular = D.enemies.map((e) => e.name).filter((n, i, a) => a.indexOf(n) === i && !(TRAITS[n] || {}).is_boss_tier);
  const bosses = D.enemies.map((e) => e.name).filter((n, i, a) => a.indexOf(n) === i && (TRAITS[n] || {}).is_boss_tier);
  const eopt = (cur) => `<optgroup label="Enemies">${regular.map((n) => opt(n, n, n === cur)).join("")}</optgroup><optgroup label="Bosses & mini-bosses">${bosses.map((n) => opt(n, n, n === cur)).join("")}</optgroup>`;
  const rows = cfg.enemies.map((e, i) => {
    const isBoss = (TRAITS[e.name] || {}).is_boss_tier;
    const nIdx = NOTHINGNESS_ORDER.indexOf(e.name);
    const d = enemyByName(e.name);
    return `<div class="list-row"><select data-act="ename" data-i="${i}">${eopt(e.name)}</select>
      <label><input type="checkbox" data-act="eelite" data-i="${i}" ${e.elite ? "checked" : ""}> elite</label>
      ${isBoss ? `<label title="Nothingness fights scale boss power (x1.0 .. x2.5)">power x<input type="number" data-act="etier" data-i="${i}" value="${e.power_tier || 1}" step="0.05" min="0.1" style="width:58px"></label>${nIdx >= 0 ? `<button data-act="etier-n" data-i="${i}" title="Use the Nothingness power for this boss">Nothingness</button>` : ""}` : ""}
      <button data-act="edel" data-i="${i}">✕</button>
      <div class="dim" style="width:100%">base HP ${d.max_health}, dmg ${d.contact_damage}, XP ${d.xp_reward}${isBoss ? " · boss (solo, 15x15 grid)" : ""}${(TRAITS[e.name] || {}).armored ? " · armored" : ""}</div></div>`;
  }).join("");
  const diffId = cfg.difficulty || "normal";
  const rate = (MC.ENEMY_LEVEL_SCALING_BY_DIFFICULTY || {})[diffId] ?? MC.ENEMY_LEVEL_SCALING;
  const scale = 1 + (cfg.level - 1) * rate;
  const bossScale = 1 + (cfg.level - 1) * rate * MC.BOSS_LEVEL_SCALING_FACTOR;
  return section("Encounter", `
    <div class="row"><label>World</label>${selectHtml("world", D.worlds.map((w) => [w.id, `${w.name}${w.terrain.length ? " (" + w.terrain.join(", ") + ")" : ""}`]), cfg.world)}</div>
    <div class="row"><label>Preset</label><select id="presetSel"><option value="">— load a squad —</option>${PRESETS.map((p, i) => opt(i, p[0])).join("")}${D.worlds.slice(0, 10).map((w, i) => opt("m" + i, `${w.name}: ${w.miniboss}`) + opt("b" + i, `${w.name}: ${w.boss}`)).join("")}</select></div>
    ${rows}
    <div class="row"><select id="addEnemySel">${eopt("Goblin")}</select><button data-act="eadd">Add enemy</button></div>
    <div class="dim">Enemy stats scale ×${scale.toFixed(2)} (regular) / ×${bossScale.toFixed(2)} (boss and miniboss) with your level, ×${D.upgrades.difficulties.find((d) => d.id === cfg.difficulty).mult} difficulty, ×${MC.ELITE_HP_MULT} HP / ×${MC.ELITE_DAMAGE_MULT} dmg for elites.</div>`);
}

function secOptions() {
  const po = cfg.policy;
  return section("Options & auto-play", `
    <div class="row"><label></label><label><input type="checkbox" data-path="real_miss" data-bool="1" ${cfg.real_miss ? "checked" : ""}> Real miss chance (5% / 2.5% when all specials learned)</label></div>
    <div class="row"><label>Auto speed</label><input type="range" min="0" max="900" step="50" data-path="speed" data-num="1" value="${cfg.speed}"> <span class="dim">${cfg.speed} ms</span></div>
    <h2>Auto-player policy</h2>
    <div class="row"><label>Heal below</label>${numHtml("policy.heal_below", po.heal_below, 0, 100)}<span class="dim">% HP</span></div>
    <div class="row"><label>Stamina reserve</label>${numHtml("policy.stamina_reserve", po.stamina_reserve, 0, 200)}</div>
    <div class="row"><label>Max turns</label>${numHtml("policy.max_turns", po.max_turns, 5, 500)}</div>
    <div class="row"><label></label><label><input type="checkbox" data-path="policy.use_specials" data-bool="1" ${po.use_specials ? "checked" : ""}> specials</label><label><input type="checkbox" data-path="policy.use_heavy" data-bool="1" ${po.use_heavy ? "checked" : ""}> heavy</label><label><input type="checkbox" data-path="policy.use_arrows" data-bool="1" ${po.use_arrows ? "checked" : ""}> arrows</label></div>
    <div class="row"><label>Level-up picks</label><input class="grow" data-path="policy.picks" value="${esc(po.picks)}"></div>
    <div class="dim">The auto-player is a simple heuristic (heal when low, otherwise move into reach and use its best affordable special, then heavy, then plain attacks). It is for relative comparisons, not an optimal player.</div>
    <div class="row"><button data-act="reset">Reset everything to defaults</button></div>`);
}

function renderConfig() {
  const p = previewPlayer();
  const root = $("#config");
  if (!p) { root.innerHTML = '<div class="panel warn">Config error — reset to defaults.</div>'; return; }
  const scroll = root.scrollTop;
  root.innerHTML = secCharacter(p) + secWeapon(p) + secGear() + secItems() + secTalismans() + secUpgrades() + secParty(p) + secEncounter() + secOptions();
  root.scrollTop = scroll;
  renderSummary();
  root.querySelectorAll("details.sec").forEach((d) => d.addEventListener("toggle", () => { openSections[d.dataset.sec] = d.open; }));
}

function setPath(path, value) {
  const parts = path.split(".");
  let o = cfg;
  for (let i = 0; i < parts.length - 1; i++) o = o[parts[i]];
  o[parts[parts.length - 1]] = value;
}

function onConfigEvent(e) {
  const t = e.target;
  if (e.type === "change" && t.dataset.path) {
    let v = t.value;
    if (t.dataset.num) v = Number(v);
    if (t.dataset.bool) v = t.checked;
    setPath(t.dataset.path, v);
    if (t.dataset.path === "weapon.base") { if (v === "club") { cfg.weapon.tier = "Fine"; } }
    if (t.dataset.path === "level") { cfg.level = clamp(Math.trunc(cfg.level) || 1, 1, 99); }
    saveCfg(); renderConfig(); return;
  }
  if (e.type === "change" && t.dataset.act) {
    const a = t.dataset.act, i = Number(t.dataset.i);
    if (a === "ename") { cfg.enemies[i].name = t.value; const n = NOTHINGNESS_ORDER.indexOf(t.value); cfg.enemies[i].power_tier = 1; void n; }
    else if (a === "eelite") cfg.enemies[i].elite = t.checked;
    else if (a === "etier") cfg.enemies[i].power_tier = Number(t.value) || 1;
    else if (a === "mlevel") { cfg.party[i].level = clamp(Number(t.value) || 1, 1, 99); }
    else if (a === "whisper") { cfg.whisperer[i] = t.value; cfg.whisperer = cfg.whisperer.filter((x, k) => x || k < 3); }
    else return;
    saveCfg(); renderConfig(); return;
  }
  if (e.type === "change" && t.id === "presetSel" && t.value !== "") {
    const v = t.value;
    if (v[0] === "m" || v[0] === "b") { const w = D.worlds[Number(v.slice(1))]; cfg.enemies = [{ name: v[0] === "m" ? w.miniboss : w.boss, elite: false, power_tier: 1 }]; cfg.world = w.id; }
    else cfg.enemies = PRESETS[Number(v)][1].map((n) => ({ name: n, elite: false, power_tier: 1 }));
    saveCfg(); renderConfig(); return;
  }
  if (e.type === "click") {
    const b = t.closest("[data-act]");
    if (!b || b.tagName === "SELECT" || b.tagName === "INPUT") return;
    const a = b.dataset.act, i = Number(b.dataset.i), d = Number(b.dataset.d);
    const p = previewPlayer();
    switch (a) {
      case "pick": {
        const s = b.dataset.s, used = pickableStats(p).reduce((x, k) => x + (cfg.picks[k] || 0), 0);
        const cur = cfg.picks[s] || 0;
        if (d > 0 && used >= cfg.level - 1) break;
        cfg.picks[s] = Math.max(0, cur + d); break;
      }
      case "fillpicks": {
        const s = b.dataset.s, stats = pickableStats(p), total = cfg.level - 1;
        cfg.picks = {};
        if (s === "balanced") { let n = total, k = 0; const core = ["strength", "vigor", "agility", "might", "intimidation"]; while (n > 0) { const st = core[k++ % 5]; cfg.picks[st] = (cfg.picks[st] || 0) + 1; n--; } }
        else if (s !== "reset") cfg.picks[s] = total;
        void stats; break;
      }
      case "citem": cfg.consumables[i].n = Math.max(0, cfg.consumables[i].n + d); break;
      case "cmove": { const j = i + d; if (j >= 0 && j < cfg.consumables.length) { [cfg.consumables[i], cfg.consumables[j]] = [cfg.consumables[j], cfg.consumables[i]]; } break; }
      case "cdel": cfg.consumables.splice(i, 1); break;
      case "cadd": { const id = $("#addItemSel").value; const ex = cfg.consumables.find((c) => c.id === id); if (ex) ex.n++; else cfg.consumables.push({ id, n: 1 }); break; }
      case "tal": { const id = b.dataset.id; const k = cfg.talismans.indexOf(id); if (k >= 0) cfg.talismans.splice(k, 1); else cfg.talismans.push(id); break; }
      case "upg": { const id = b.dataset.id, def = D.upgrades.defs[id]; const max = def.max_level || 10; cfg.upgrades[id] = clamp((cfg.upgrades[id] || 0) + d, 0, max); if (!cfg.upgrades[id]) delete cfg.upgrades[id]; break; }
      case "upgclear": cfg.upgrades = {}; break;
      case "upgmax": for (const id of D.upgrades.ids) if (COMBAT_UPGRADES.has(id) && id !== "worldwalker") cfg.upgrades[id] = D.upgrades.defs[id].max_level || 3; break;
      case "madd": { const kind = $("#addMemberSel").value; cfg.party.push({ kind, level: 1, picks: {} }); break; }
      case "mdel": cfg.party.splice(i, 1); break;
      case "mpick": { const m = cfg.party[i], s = b.dataset.s; m.picks = m.picks || {}; const r = D.party.kinds[m.kind]; const used = (r.stats || []).reduce((x, k) => x + (m.picks[k] || 0), 0); if (d > 0 && used >= m.level - 1) break; m.picks[s] = Math.max(0, (m.picks[s] || 0) + d); break; }
      case "eadd": cfg.enemies.push({ name: $("#addEnemySel").value, elite: false, power_tier: 1 }); break;
      case "edel": cfg.enemies.splice(i, 1); break;
      case "etier-n": { const idx = NOTHINGNESS_ORDER.indexOf(cfg.enemies[i].name); if (idx >= 0) cfg.enemies[i].power_tier = MC.NOTHINGNESS_POWER_TIERS[idx]; break; }
      case "reset": if (confirm("Reset the whole configuration?")) cfg = defaultCfg(); break;
      default: return;
    }
    saveCfg(); renderConfig();
  }
}

// ================================================================== battle: start / refresh
function startBattle(seed) {
  if (cfg.enemies.length === 0) { alert("Add at least one enemy to the encounter."); return; }
  if (cfg.enforce_gates) { /* reserved */ }
  autoRunning = false; busy = false; uiMenu = "main"; hoverDesc = "";
  try { sim = createSim(battleCfg(), seed ?? cfg.seed); }
  catch (e) { alert("Could not start battle: " + e.message); console.error(e); return; }
  sim.promptHandler = uiPrompt;
  $("#seedBox").value = cfg.seed; $("#seedBoxSetup").value = cfg.seed;
  showView("battle");
  refresh();
  afterChange();
}

function terrainGlyph(t) {
  switch (t.type) {
    case "rock": return "🪨"; case "rubble": return "🧱"; case "water": return "🌊"; case "ledge": return "⤵"; case "cliff": return "🕳";
    case "ice": return "🧊"; case "embers": return "🔥"; case "poison_bog": return "☠"; case "quicksand": return "⏳"; case "spring": return "⛲"; case "crumbling": return "▒"; case "thicket": return "🌿"; case "caltrops": return "✖"; default: return "";
  }
}

function inMoveMode() { return sim && sim.battle_menu_state === "move"; }
function currentActor() { return sim && sim.battle_commanding_ally ? sim.battle_commanding_ally : null; }

function renderGrid() {
  const g = $("#grid");
  if (!sim) { g.innerHTML = '<div style="padding:60px;color:var(--dim);text-align:center">Configure your build on the left,<br>then press <b>Start battle</b>.</div>'; g.style.display = "block"; $("#legend").innerHTML = ""; return; }
  const W_ = sim.BATTLE_GRID_W, H_ = sim.BATTLE_GRID_H;
  // fit the grid to the space the battle screen gives it
  const wrap = $("#gridwrap");
  const availW = Math.max(240, (wrap.clientWidth || 640) - 16), availH = Math.max(240, (wrap.clientHeight || 560) - 16);
  const cell = clamp(Math.floor(Math.min(availW / W_, availH / H_)), 30, 84);
  document.documentElement.style.setProperty("--cell", cell + "px");
  g.style.display = "grid"; g.style.gridTemplateColumns = `repeat(${W_}, ${cell}px)`; g.style.width = "max-content";
  const reach = new Set(); const trail = new Set();
  const actor = currentActor();
  if (inMoveMode()) {
    const from = actor ? actor.tile : sim.battle_player_tile;
    for (const dir of CARDINAL_DIRS) { const r = sim._resolve_battle_step(from, dir, actor ? actor.tile : null); if (r.moved) reach.add(vkey(vadd(from, dir))); }
    for (const s of sim.battle_move_trail) trail.add(vkey(s.tile));
  }
  let html = "";
  for (let y = 0; y < H_; y++) for (let x = 0; x < W_; x++) {
    const t = sim.battle_terrain[x + "," + y];
    const cls = ["tile", t ? t.type : "", reach.has(x + "," + y) ? "reach" : "", trail.has(x + "," + y) ? "trail" : ""].join(" ");
    let inner = "";
    if (t) { inner = terrainGlyph(t); if (t.push_dir) inner += `<span class="tdir">${DIR_ARROW(t.push_dir)}</span>`; if (t.dir) inner += `<span class="tdir">${DIR_ARROW(t.dir)}</span>`; }
    html += `<div class="${cls}" data-x="${x}" data-y="${y}" title="${t ? t.type : ""}">${inner}</div>`;
  }
  // units (absolutely positioned over the grid)
  const unitHtml = [];
  const targetable = actor ? sim._ally_targetable_indices(actor) : (sim.can_act() ? sim._targetable_indices() : []);
  const targetIdx = actor ? sim._ally_effective_target_index(actor) : sim._effective_target_index();
  const abbr = (n) => n.split(" ").map((w) => w[0]).join("").slice(0, 3).toUpperCase();
  const posStyle = (tile, size) => `left:${tile.x * cell + 2}px;top:${tile.y * cell + 2}px;width:${size * cell - 4}px;height:${size * cell - 4}px;`;
  const pTiles = sim.battle_player_tile;
  unitHtml.push(`<div class="unit player${actor ? "" : " acting"}" style="${posStyle(pTiles, 1)}" title="You"><span class="tags">${sim.player.stealth_turns_remaining > 0 ? "🕶" : ""}${sim.player_burning ? "🔥" : ""}${sim.player_bleed_turns > 0 ? "🩸" : ""}</span><span class="nm">YOU</span><span class="hpbar"><i style="width:${clamp(sim.player.health / sim.player.max_health, 0, 1) * 100}%"></i></span></div>`);
  sim.battle_allies.forEach((a) => {
    unitHtml.push(`<div class="unit ally${actor === a ? " acting" : ""}" style="${posStyle(a.tile, 1)}" title="${esc(a.name)} ${a.hp}/${a.max_hp}"><span class="nm">${esc(abbr(a.name))}</span><span class="hpbar"><i style="width:${clamp(a.hp / a.max_hp, 0, 1) * 100}%"></i></span></div>`);
  });
  sim.battle_units.forEach((u, i) => {
    const boss = (TRAITS[u.name] || {}).is_boss_tier;
    const tags = (u.winding_up ? "⚠" : "") + (u.burning ? "🔥" : "") + ((u.bleed_turns || 0) > 0 ? "🩸" : "") + ((u.frozen_turns || 0) > 0 ? "❄" : "") + (u.stunned ? "💫" : "") + (u.feared ? "😱" : "") + ((u.concussed_turns || 0) > 0 ? "🌀" : "") + ((u.poison_turns || 0) > 0 ? "☠" : "") + (u.aware_of_player || boss ? "" : "💤");
    unitHtml.push(`<div class="unit enemy${boss ? " boss" : ""}${u.is_elite ? " elite" : ""}${i === targetIdx ? " targeted" : ""}${targetable.includes(i) ? " inreach" : ""}" data-ei="${i}" style="${posStyle(u.tile, u.size ?? 1)}" title="${esc(u.name)} ${Math.max(0, u.hp)}/${u.max_hp}"><span class="tags">${tags}</span><span class="nm">${esc(u.name)}${u.is_elite ? " ★" : ""}</span><span class="hpbar"><i style="width:${clamp(u.hp / u.max_hp, 0, 1) * 100}%"></i></span></div>`);
  });
  g.innerHTML = html + unitHtml.join("");
  $("#legend").innerHTML = `<span>🪨 rock (cover) 🧱 rubble 🌊 water (push, douses fire) ⤵ ledge/cliff (one-way drop)</span><span>⚠ winding up · 💤 unaware · 🔥 burning · 🩸 bleeding · ❄ frozen · 💫 stunned · 😱 afraid</span><span>white outline = target · dashed = in reach</span>`;
}

function renderBanner() {
  const b = $("#banner");
  if (!sim) { b.innerHTML = '<span class="turn">No battle running</span>'; return; }
  let who = sim.battle_commanding_ally ? `Commanding ${esc(sim.battle_commanding_ally.name)}` : sim.battle_turn === "player" ? "Your turn" : "Enemy turn";
  if (sim.over) who = "Battle over";
  const res = sim.result ? `<span class="res ${sim.result}">${sim.result.toUpperCase()}</span>` : "";
  b.innerHTML = `<span class="turn">Round ${sim.stats.turns + 1} — ${who}</span><span class="dim">moves left: ${sim.battle_commanding_ally ? sim.battle_ally_moves_left : sim.battle_player_moves_left} · seed ${cfg.seed}</span>${res}`;
}

function hpBar(cur, max, cls, label) { return `<div class="bar ${cls}"><i style="width:${clamp(cur / max, 0, 1) * 100}%"></i><b>${label ?? `${Math.max(0, Math.round(cur))}/${max}`}</b></div>`; }

function renderSide() {
  const s = $("#side");
  if (!sim) { s.innerHTML = `<div class="panel"><h2>Preview</h2><div class="dim">Press Start battle. The right panel shows live HP, stamina, statuses and enemy details.</div></div>`; return; }
  const p = sim.player;
  const chips = [];
  if (p.berserk_turns_remaining > 0) chips.push(["good", `Berserk ${p.berserk_turns_remaining}`]);
  if (p.stealth_turns_remaining > 0) chips.push(["info", `Stealth ${p.stealth_turns_remaining}`]);
  if (p.potion_attack_turns > 0) chips.push(["good", `Attack potion ${p.potion_attack_turns}`]);
  if (p.potion_resilience_turns > 0) chips.push(["good", `Resilience ${p.potion_resilience_turns}`]);
  if (p.potion_energy_turns > 0) chips.push(["good", `Energy ${p.potion_energy_turns}`]);
  if (sim.battle_player_defending) chips.push(["info", "Defending"]);
  if (sim.battle_player_taunting) chips.push(["info", "Taunting"]);
  if (p.pichaku_active) chips.push(["good", "Pichaku"]);
  if (sim.player_burning) chips.push(["bad", "Burning"]);
  if (sim.player_bleed_turns > 0) chips.push(["bad", `Bleeding ${sim.player_bleed_turns}`]);
  if (sim.player_poison_turns > 0) chips.push(["bad", `Poison ${sim.player_poison_turns}`]);
  if (sim.player_concussed_turns > 0) chips.push(["bad", `Concussed ${sim.player_concussed_turns}`]);
  if (sim.player_blind_turns > 0) chips.push(["bad", `Blind ${sim.player_blind_turns}`]);
  if (sim.is_disarmed()) chips.push(["bad", "Disarmed"]);
  if (sim.battle_player_turns_to_skip > 0) chips.push(["bad", "Reeling"]);
  if (p.bloodmoon_stacks > 0) chips.push(["good", `Bloodlust ${p.bloodmoon_stacks}`]);
  if (p.bloodmoon_debuffed) chips.push(["bad", "Bloodmoon crashed"]);
  if (sim.battle_momentum_stacks > 0) chips.push(["good", `Momentum ${sim.battle_momentum_stacks}`]);
  if (sim.battle_momentum_chain_stacks > 0) chips.push(["good", `Chain ${sim.battle_momentum_chain_stacks}`]);
  const w = p.current_weapon;
  const players = `<div class="panel"><h2>You — level ${p.level}</h2>${hpBar(p.health, p.max_health, "hp")}${hpBar(p.stamina, p.max_stamina, "st", `${p.stamina}/${p.max_stamina} stamina${p.exhausted ? " (exhausted)" : ""}`)}
    <div class="chips">${chips.map(([c, t]) => `<span class="chip ${c}">${esc(t)}</span>`).join("") || '<span class="dim">no status effects</span>'}</div>
    <table class="kv" style="margin-top:6px"><tr><td>Weapon</td><td>${esc(w.name)}</td></tr><tr><td>Attack × weapon</td><td>${p.attack_damage} × ${w.damage_mult.toFixed(2)}</td></tr>
    <tr><td>Items left</td><td>${p.potion_queue.length}${p.potion_queue.length ? " (next: " + esc(consumableById(p.potion_queue[0]).name) + ")" : ""}</td></tr>
    <tr><td>Arrows F/Z/B</td><td>${p.owned_arrows.flame}/${p.owned_arrows.freeze}/${p.owned_arrows.bomb}</td></tr><tr><td>Coins</td><td>${p.coins}</td></tr>
    <tr><td>XP</td><td>${p.xp}/${p.xp_to_next || "max"}</td></tr></table></div>`;
  const allies = sim.battle_allies.length ? `<div class="panel"><h2>Allies</h2>${sim.battle_allies.map((a) => `<div class="ecard${sim.battle_commanding_ally === a ? " sel" : ""}"><span class="nm">${esc(a.name)}</span> <small class="dim">ATK ${a.attack !== undefined ? a.attack.toFixed(1) : "—"} · DEF ${a.defense_pct || 0}% · mv ${a.move_range}</small>${hpBar(a.hp, a.max_hp, "hp")}</div>`).join("")}</div>` : "";
  const targetIdx = currentActor() ? sim._ally_effective_target_index(currentActor()) : sim._effective_target_index();
  const enemies = `<div class="panel"><h2>Enemies (${sim.battle_units.length})</h2>${sim.battle_units.map((u, i) => {
    const tr = TRAITS[u.name] || {};
    const tags = [];
    if (tr.is_boss_tier) tags.push("boss"); if (u.armored) tags.push("armored"); if (tr.dodge_chance) tags.push(`dodge ${pct(tr.dodge_chance)}`); if (tr.knockback_resist) tags.push(`resist ${pct(tr.knockback_resist)}`);
    if (tr.windup) tags.push("windup"); if (tr.sweeps) tags.push("sweeps"); if (tr.attack_range > 1) tags.push(`range ${tr.attack_range}`); if (tr.kites) tags.push("kites"); if (tr.heals_allies) tags.push("heals"); if (tr.inflicts_fear) tags.push("fear");
    if (tr.inflicts_bleed) tags.push("bleed"); if (tr.inflicts_blind) tags.push("blind"); if (tr.inflicts_concussion) tags.push("concuss");
    return `<div class="ecard${i === targetIdx ? " sel" : ""}" data-ei="${i}"><span class="nm">${esc(u.name)}${u.is_elite ? " ★" : ""}</span> <small class="dim">dmg ${u.damage} · mv ${u.move_range}${u.aware_of_player || tr.is_boss_tier ? "" : " · unaware"}</small>${hpBar(u.hp, u.max_hp, "hp")}<div class="chips">${tags.map((t) => `<span class="chip">${t}</span>`).join("")}</div></div>`;
  }).join("") || '<div class="dim">All enemies defeated.</div>'}</div>`;
  const st = sim.stats;
  const stats = `<div class="panel"><h2>Battle stats</h2><table class="kv"><tr><td>Rounds</td><td>${st.turns}</td></tr><tr><td>Damage dealt</td><td>${st.damage_dealt}</td></tr><tr><td>Damage taken</td><td>${st.damage_taken}</td></tr><tr><td>Kills</td><td>${st.kills}</td></tr><tr><td>XP gained</td><td>${st.xp_gained}</td></tr><tr><td>Items used</td><td>${st.potions_used}</td></tr></table></div>`;
  s.innerHTML = players + allies + enemies + stats;
}

function renderLog() {
  const el = $("#log");
  if (!sim) { el.innerHTML = ""; return; }
  const atBottom = el.scrollTop + el.clientHeight >= el.scrollHeight - 30;
  el.innerHTML = sim.logLines.slice(-400).map((l) => `<div class="${l.cls}"><span class="turn">R${l.turn + 1}</span>${esc(l.msg)}</div>`).join("");
  if (atBottom) el.scrollTop = el.scrollHeight;
}

// ================================================================== menu
function btn(label, act, arg, enabled, cost, desc) {
  return `<button data-bact="${act}" ${arg !== undefined ? `data-arg="${esc(arg)}"` : ""} ${enabled ? "" : "disabled"} data-desc="${esc(desc || "")}">${esc(label)}${cost !== undefined && cost !== "" ? `<span class="c">${cost}</span>` : ""}</button>`;
}

function renderMenu() {
  const m = $("#menu");
  if (!sim) { m.innerHTML = '<div class="dim">Press <b>Start battle</b> to begin.</div>'; return; }
  if (sim.over) { m.innerHTML = `<div class="btns"><button class="primary" data-bact="restart">Fight again (same seed)</button><button data-bact="newseed">New seed</button><button data-bact="back">&larr; Back to setup</button></div><div class="desc">Result: ${sim.result}. ${sim.result === "victory" ? "You survived with " + sim.player.health + "/" + sim.player.max_health + " HP." : ""}</div>`; return; }
  const p = sim.player, w = p.current_weapon;
  if (p.awaiting_bonus > 0) { m.innerHTML = '<div class="desc">Level up! Choose your bonus stat…</div>'; return; }
  if (sim.battle_turn !== "player") { m.innerHTML = '<div class="desc">Enemies are acting…</div>'; return; }
  if (sim.battle_commanding_ally) {
    const a = sim.battle_commanding_ally;
    if (inMoveMode()) { m.innerHTML = `<div class="btns"><button class="primary" data-bact="confirm">Confirm move</button><button data-bact="cancel">Cancel</button></div><div class="desc">Moving ${esc(a.name)} — ${sim.battle_ally_moves_left} left. Click a highlighted tile or use arrow keys / WASD.</div>`; return; }
    const inRange = sim._ally_targetable_indices(a).length > 0;
    m.innerHTML = `<div class="btns">${btn("Move", "ally-move", "", sim.battle_ally_moves_left > 0, sim.battle_ally_moves_left, `Move ${a.name} up to ${sim.battle_ally_moves_left} tiles.`)}${btn("Attack", "ally-attack", "", inRange, "", `${a.name} attacks the selected enemy in range.`)}${btn("Guard", "ally-guard", "", true, "", "Halves damage taken until its next turn.")}${btn("Skip", "ally-skip", "", true, "", "Do nothing.")}<button data-bact="autoturn">Auto</button></div><div class="desc" id="mdesc">${esc(hoverDesc || `Commanding ${a.name}: ${a.hp}/${a.max_hp} HP. Click an enemy to pick its target.`)}</div>`;
    return;
  }
  if (inMoveMode()) {
    m.innerHTML = `<div class="btns"><button class="primary" data-bact="confirm">Confirm move</button><button data-bact="cancel">Cancel (undo)</button></div><div class="desc">Moving — ${sim.battle_player_moves_left} tiles left. Click a highlighted tile or use arrow keys / WASD. Cancel undoes the move.</div>`;
    return;
  }
  const av = sim.availability();
  const reg = w.regular_attack_stamina_cost || 0, hv = w.heavy_stamina_cost_override ?? W.consts.HEAVY_STAMINA_COST;
  let html = "";
  if (uiMenu === "main") {
    html = `${btn("Move", "move", "", av.move, sim.battle_player_moves_left, "Reposition (Move, then Confirm).")}${btn("Fight", "menu", "fight", av.fight, "", "Attack, Heavy Attack and weapon specials.")}${btn("Item", "item", "", av.item, p.potion_queue.length, p.potion_queue.length ? "Use: " + consumableById(p.potion_queue[0]).name : "No items")}${btn("Defend", "defend", "", av.defend, `+${MC.STAMINA_REGEN_ON_DEFEND} st`, "Brace: small hits are negated, big ones halved. Regains stamina.")}`;
    if (p.has_guardian_skill) html += btn("Skill", "skill", "", av.skill, sim.battle_skill_cooldown > 0 ? `cd ${sim.battle_skill_cooldown}` : "", "Guardian's Ultimatum: heal 40% max HP.");
    if (sim._player_has_bow()) html += btn("Arrow", "menu", "arrow", av.arrow, "", "Fire a special arrow.");
    html += btn("Tactics", "menu", "tactics", av.tactics, "", "Taunt or Stealth.") + btn("Flee", "flee", "", av.flee, "", "Leave the battle.");
    html += `<button data-bact="autoturn">Auto turn</button>`;
  } else if (uiMenu === "fight") {
    html = btn("Attack", "attack", "", av.attack, reg ? reg + " st" : "free", `Plain attack: ${round(p.attack_damage * w.damage_mult)} dmg (+${MC.STAMINA_REGEN_ON_ATTACK} stamina).`) + btn("Heavy", "heavy", "", av.heavy, hv + " st", `Heavy attack x${W.consts.HEAVY_DAMAGE_MULT}: ~${round(p.attack_damage * w.damage_mult * W.consts.HEAVY_DAMAGE_MULT)} dmg.`);
    (w.specials || []).forEach((sp, i) => { html += btn(sp.name, "special", i, av.specials[i], (w.passive_free_specials ? 0 : sp.stamina_cost) + " st", `${sp.description || ""}${sp.learned === false ? " (not learned)" : ""}`); });
    if (sim._player_has_hand_picks() && sim._targetable_rock_tiles().length) html += btn("Mine rock", "mine", "", av.mine, "", "Break an adjacent rock (costs the turn).");
    html += `<button data-bact="menu" data-arg="main">« Back</button>`;
  } else if (uiMenu === "arrow") {
    html = ["flame", "freeze", "bomb"].map((k) => btn(`${capital(k)} arrow`, "arrow", k, (p.owned_arrows[k] || 0) > 0 && av.arrow, `x${p.owned_arrows[k] || 0}`, D.weapons.arrows[k].description)).join("") + `<button data-bact="menu" data-arg="main">« Back</button>`;
  } else if (uiMenu === "tactics") {
    html = btn("Taunt", "taunt", "", av.taunt, `+${MC.STAMINA_REGEN_ON_DEFEND} st`, "Enemies converge on you; you also Defend.") + btn("Stealth", "stealth", "", av.stealth, MC.STEALTH_STAMINA_COST + " st", "Next hit is a guaranteed crit; enemies' sight range drops.") + `<button data-bact="menu" data-arg="main">« Back</button>`;
  }
  const feared = sim.battle_feared_unreachable ? '<div class="warn">Fear holds you — you can only move, defend or flee.</div>' : "";
  m.innerHTML = `<div class="btns">${html}</div>${feared}<div class="desc" id="mdesc">${esc(hoverDesc || "Click an enemy (grid or right panel) to choose your target.")}</div>`;
}

function refresh() { renderBanner(); renderGrid(); renderMenu(); renderLog(); renderSide(); }

// ================================================================== prompts & modals
function modal(html) { const r = $("#modalRoot"); r.innerHTML = `<div class="modal"><div class="box">${html}</div></div>`; return r; }
function closeModal() { $("#modalRoot").innerHTML = ""; }

function uiPrompt(type, data) {
  refresh();
  if (autoRunning) return Promise.resolve(type === "evasion" ? Object.keys(data.options)[0] : type === "water_push" ? false : data.default);
  return new Promise((resolve) => {
    if (type === "evasion") {
      const r = modal(`<h2>Dodge-roll!</h2><div>Your Phantom Guard grants a free dodge-roll. Pick a direction:</div><div class="row">${Object.keys(data.options).map((k) => `<button data-choice="${k}">${capital(k)}</button>`).join("")}</div>`);
      r.onclick = (e) => { const c = e.target.dataset.choice; if (c) { closeModal(); resolve(c); } };
    } else {
      const r = modal(`<h2>${esc(data.text)}</h2><div class="row"><button data-choice="1">${esc(data.yes)}</button><button data-choice="0">${esc(data.no)}</button></div>`);
      r.onclick = (e) => { const c = e.target.dataset.choice; if (c !== undefined) { closeModal(); resolve(c === "1"); } };
    }
  });
}

function maybeLevelUpModal() {
  if (!sim || !sim.player || sim.player.awaiting_bonus <= 0 || autoRunning) return;
  if ($("#modalRoot").innerHTML) return;
  const p = sim.player, stats = pickableStats(p);
  const per = (s) => (s === "agility" ? PC.AGILITY_BONUS_PER_LEVEL + p.meta_levelup_bonus_agility : s === "strength" ? 1 + p.meta_levelup_bonus_strength : s === "vigor" ? 1 + p.meta_levelup_bonus_vigor : s === "intimidation" ? 1 + p.meta_levelup_bonus_intimidation : 1) * (p.meta_bonus_levelup_stat ? 2 : 1);
  const r = modal(`<h2>Level up! — level ${p.level}</h2><div class="dim">+1 to every core stat was applied automatically. Choose where your bonus point goes (${p.awaiting_bonus} pending):</div>
    <div class="row">${stats.map((s) => `<button data-choice="${s}">${capital(s)} (${p["stat_" + s]} → ${p["stat_" + s] + per(s)})</button>`).join("")}</div>`);
  r.onclick = (e) => { const c = e.target.dataset.choice; if (c) { p.apply_bonus_stat(c); closeModal(); refresh(); maybeLevelUpModal(); } };
}

function afterChange() { refresh(); maybeLevelUpModal(); }

// ================================================================== interaction
async function runAction(fn) {
  if (busy || !sim) return;
  busy = true;
  try { await fn(); } catch (e) { console.error(e); alert("Engine error: " + e.message); }
  busy = false;
  afterChange();
}

function onMenuClick(e) {
  const b = e.target.closest("[data-bact]");
  if (!b || b.disabled) return;
  const a = b.dataset.bact, arg = b.dataset.arg;
  switch (a) {
    case "menu": uiMenu = arg; refresh(); return;
    case "move": if (sim.begin_move()) refresh(); else afterChange(); return;
    case "ally-move": if (sim.begin_move()) refresh(); return;
    case "confirm": sim.confirm_move(); afterChange(); return;
    case "cancel": sim.cancel_move(); afterChange(); return;
    case "back": backToSetup(); return;
    case "restart": startBattle(cfg.seed); return;
    case "newseed": cfg.seed = (Math.random() * 1e9) >>> 0; saveCfg(); startBattle(cfg.seed); return;
    case "autoturn": runAction(async () => { await autoOneStep(); }); return;
  }
  runAction(async () => {
    const act = async (k, x) => { await sim.do_action(k, x); uiMenu = "main"; };
    switch (a) {
      case "attack": case "heavy": case "mine": case "item": case "defend": case "skill": case "taunt": case "stealth": case "flee": await act(a); break;
      case "special": await act("special", Number(arg)); break;
      case "arrow": await act("arrow", arg); break;
      case "ally-attack": await sim.ally_action("attack"); break;
      case "ally-guard": await sim.ally_action("guard"); break;
      case "ally-skip": await sim.ally_action("skip"); break;
    }
  });
}

function onGridClick(e) {
  if (!sim) return;
  const eu = e.target.closest(".unit.enemy");
  if (eu) { sim.select_target(Number(eu.dataset.ei)); refresh(); return; }
  const tile = e.target.closest(".tile.reach");
  if (tile && inMoveMode()) {
    const x = Number(tile.dataset.x), y = Number(tile.dataset.y);
    const from = currentActor() ? currentActor().tile : sim.battle_player_tile;
    const dir = V(x - from.x, y - from.y);
    sim.step_move(dir); refresh(); afterChange();
  }
}
function onSideClick(e) { const c = e.target.closest(".ecard[data-ei]"); if (c && sim) { sim.select_target(Number(c.dataset.ei)); refresh(); } }

document.addEventListener("keydown", (e) => {
  if (!sim || !inMoveMode() || e.target.tagName === "INPUT" || e.target.tagName === "SELECT") return;
  const map = { ArrowUp: V(0, -1), w: V(0, -1), ArrowDown: V(0, 1), s: V(0, 1), ArrowLeft: V(-1, 0), a: V(-1, 0), ArrowRight: V(1, 0), d: V(1, 0) };
  const d = map[e.key];
  if (d) { e.preventDefault(); sim.step_move(d); refresh(); }
  else if (e.key === "Enter") { sim.confirm_move(); afterChange(); }
  else if (e.key === "Escape") { sim.cancel_move(); afterChange(); }
});

// ================================================================== auto-play
function policyFromCfg() {
  const po = cfg.policy;
  return { heal_below: po.heal_below / 100, stamina_reserve: po.stamina_reserve, use_specials: po.use_specials, use_heavy: po.use_heavy, use_arrows: po.use_arrows, picks: String(po.picks).split(",").map((s) => s.trim()).filter(Boolean), max_turns: po.max_turns };
}
async function autoOneStep() {
  const pol = Object.assign({}, DEFAULT_POLICY, policyFromCfg());
  const prev = sim.promptHandler;
  sim.promptHandler = async (type, data) => (type === "evasion" ? Object.keys(data.options)[0] : type === "water_push" ? false : data.default);
  if (sim.battle_commanding_ally) await autoAllyTurn(sim); else await autoPlayerTurn(sim, pol);
  sim.promptHandler = prev;
}
async function autoRun() {
  if (!sim || sim.over) return;
  if (autoRunning) { autoRunning = false; $("#btnAuto").textContent = "Auto-play"; return; }
  autoRunning = true; $("#btnAuto").textContent = "Stop auto";
  const pol = policyFromCfg();
  const keep = sim.promptHandler;
  while (autoRunning && sim.in_battle && !sim.over) {
    if (sim.stats.turns >= (pol.max_turns || 60)) { sim.over = true; sim.in_battle = false; sim.result = "timeout"; break; }
    busy = true;
    try { await autoOneStep(); } catch (e) { console.error(e); autoRunning = false; alert("Engine error: " + e.message); }
    busy = false;
    refresh();
    if (cfg.speed > 0) await sleep(cfg.speed);
  }
  autoRunning = false; $("#btnAuto").textContent = "Auto-play"; sim.promptHandler = keep; afterChange();
}

// ================================================================== batch & sweeps
function fmtRow(label, r) {
  return `<tr><td>${esc(label)}</td><td>${pct(r.win_rate)}</td><td>${r.avg_turns.toFixed(1)}</td><td>${r.victories ? pct(r.avg_hp_pct_win) : "—"}</td><td>${r.avg_damage_taken.toFixed(1)}</td><td>${r.avg_potions.toFixed(2)}</td><td>${r.defeats}/${r.timeouts}</td></tr>`;
}
const BATCH_HEAD = "<tr><th>Build</th><th>Win</th><th>Rounds</th><th>HP left (wins)</th><th>Dmg taken</th><th>Items</th><th>Loss/timeout</th></tr>";

function openBatch() {
  const r = modal(`<h2>Batch run</h2>
    <div class="dim">Runs the auto-player on the current encounter and build with different seeds. The seed also changes terrain, enemy rows and every roll.</div>
    <div class="row"><label>Battles</label><input id="bN" type="number" value="200" min="1" max="5000"> <button class="primary" id="bRun">Run current build</button></div>
    <div class="row"><label>Sweep</label><select id="bSweep"><option value="weapons">Each weapon type (Fine, current material)</option><option value="tiers">Each quality tier (current weapon)</option><option value="materials">Each material (current weapon)</option><option value="talismans">Each talisman alone (added to current)</option><option value="levels">Levels 1,5,10,…,60 (even stat spread)</option><option value="armors">Each armor</option><option value="shields">Each shield</option></select> <button id="bSweepRun">Run sweep</button></div>
    <div class="progress"><i id="bProg"></i></div><div id="bOut" style="margin-top:8px"></div>
    <div class="row"><button id="bClose">Close</button><button id="bCopy">Copy results (CSV)</button></div>`);
  let csv = "";
  const prog = async (done, total) => { $("#bProg").style.width = `${(done / total) * 100}%`; await sleep(0); };
  $("#bClose").onclick = closeModal;
  $("#bCopy").onclick = () => { navigator.clipboard && navigator.clipboard.writeText(csv); };
  $("#bRun").onclick = async () => {
    const n = clamp(Number($("#bN").value) || 100, 1, 5000);
    const res = await runBatch(battleCfg(), n, policyFromCfg(), prog);
    $("#bOut").innerHTML = `<table class="res-t">${BATCH_HEAD}${fmtRow("Current build", res)}</table>`;
    csv = "build,win_rate,avg_rounds,avg_hp_pct_win,avg_damage_taken,avg_items,losses,timeouts\n" + `current,${res.win_rate},${res.avg_turns},${res.avg_hp_pct_win},${res.avg_damage_taken},${res.avg_potions},${res.defeats},${res.timeouts}`;
  };
  $("#bSweepRun").onclick = async () => {
    const n = clamp(Number($("#bN").value) || 100, 1, 2000), kind = $("#bSweep").value;
    const variants = sweepVariants(kind);
    const rows = [];
    let done = 0;
    for (const v of variants) {
      const c = battleCfg(); v.apply(c);
      const res = await runBatch(c, n, policyFromCfg(), null);
      rows.push([v.label, res]);
      done++; await prog(done, variants.length);
      $("#bOut").innerHTML = `<table class="res-t">${BATCH_HEAD}${rows.map(([l, r]) => fmtRow(l, r)).join("")}</table>`;
    }
    rows.sort((a, b) => b[1].win_rate - a[1].win_rate || a[1].avg_damage_taken - b[1].avg_damage_taken);
    $("#bOut").innerHTML = `<table class="res-t">${BATCH_HEAD}${rows.map(([l, r]) => fmtRow(l, r)).join("")}</table>`;
    csv = "build,win_rate,avg_rounds,avg_hp_pct_win,avg_damage_taken,avg_items,losses,timeouts\n" + rows.map(([l, r]) => `"${l}",${r.win_rate},${r.avg_turns},${r.avg_hp_pct_win},${r.avg_damage_taken},${r.avg_potions},${r.defeats},${r.timeouts}`).join("\n");
  };
}

function sweepVariants(kind) {
  const out = [];
  const sel = cfg.weapon;
  if (kind === "weapons") for (const b of weaponBases()) out.push({ label: b.name, apply: (c) => { c.weapon = { base: b.id, tier: "Fine", material: sel.material === undefined ? "steel" : sel.material }; if (b.id === "club") c.weapon.tier = "Fine"; c.rune = ""; } });
  if (kind === "tiers") for (const t of W.tiers) out.push({ label: t.tier_name, apply: (c) => { c.weapon.tier = t.tier_name; } });
  if (kind === "materials") for (const m of W.materials) out.push({ label: m.name, apply: (c) => { c.weapon.tier = c.weapon.tier === "Mythic" ? "Fine" : c.weapon.tier; c.weapon.material = m.id; } });
  if (kind === "talismans") { out.push({ label: "(none added)", apply: () => {} }); for (const t of D.talismans.items) out.push({ label: t.name, apply: (c) => { c.ignore_slots = true; if (!c.talismans.includes(t.id)) c.talismans.push(t.id); } }); }
  if (kind === "levels") for (let l = 1; l <= 60; l += (l === 1 ? 4 : 5)) out.push({ label: "Level " + l, apply: (c) => { c.level = l; c.picks = {}; const core = ["strength", "vigor", "agility", "might", "intimidation"]; for (let k = 0; k < l - 1; k++) c.picks[core[k % 5]] = (c.picks[core[k % 5]] || 0) + 1; } });
  if (kind === "armors") for (const a of D.armor) out.push({ label: a.name, apply: (c) => { c.armor = a.id; } });
  if (kind === "shields") { out.push({ label: "No shield", apply: (c) => { c.shield = ""; } }); for (const s of Object.values(D.shields)) out.push({ label: s.name, apply: (c) => { c.shield = s.id; } }); }
  return out;
}

// ================================================================== save / load / wiring
function openSaveLoad(save) {
  const r = modal(`<h2>${save ? "Save" : "Load"} configuration</h2><div class="dim">${save ? "Copy this JSON somewhere safe." : "Paste a configuration JSON, then press Load."}</div>
    <textarea id="cfgText" style="width:100%;height:260px;background:#0e0c0a;color:var(--text);border:1px solid var(--line);border-radius:6px">${save ? esc(JSON.stringify(cfg, null, 1)) : ""}</textarea>
    <div class="row">${save ? '<button id="cfgCopy">Copy</button>' : '<button class="primary" id="cfgLoad">Load</button>'}<button id="cfgClose">Close</button></div>`);
  $("#cfgClose").onclick = closeModal;
  if (save) $("#cfgCopy").onclick = () => { $("#cfgText").select(); document.execCommand("copy"); };
  else $("#cfgLoad").onclick = () => { try { cfg = Object.assign(defaultCfg(), JSON.parse($("#cfgText").value)); saveCfg(); closeModal(); renderConfig(); } catch (e) { alert("Invalid JSON: " + e.message); } };
  void r;
}

// Two completely separate screens. The battle screen is a full-viewport takeover; browser Back / #setup returns.
function showView(v, fromHash) {
  $("#setupView").hidden = v !== "setup"; $("#battleView").hidden = v !== "battle";
  document.body.style.overflow = v === "battle" ? "hidden" : "";
  if (!fromHash) { const want = v === "battle" ? "#battle" : "#setup"; if (location.hash !== want) { try { history.pushState(null, "", want); } catch (e) { location.hash = want; } } }
  window.scrollTo(0, 0);
  if (v === "battle") requestAnimationFrame(() => { renderGrid(); });
}
function backToSetup(fromHash) { autoRunning = false; $("#btnAuto").textContent = "Auto-play"; closeModal(); showView("setup", fromHash === true); renderConfig(); }
window.addEventListener("hashchange", () => {
  const h = location.hash;
  if (h === "#battle" && sim && $("#battleView").hidden) showView("battle", true);
  else if (h !== "#battle" && !$("#battleView").hidden) backToSetup(true);
  else if (h === "#battle" && !sim) { history.replaceState(null, "", "#setup"); }
});
window.addEventListener("popstate", () => { if (location.hash !== "#battle" && !$("#battleView").hidden) backToSetup(true); });
window.addEventListener("resize", () => { if (sim && !$("#battleView").hidden) renderGrid(); });
function renderSummary() {
  const p = previewPlayer();
  const el = $("#setupSummary");
  if (!p || !el) return;
  const foes = cfg.enemies.map((e) => e.name + (e.elite ? "★" : "")).join(", ") || "no enemies";
  el.innerHTML = `<b>Lv ${cfg.level}</b> · ${esc(p.current_weapon.name)} · ${esc(p.equipped_armor.name)}${cfg.shield ? " + " + esc(D.shields[cfg.shield].name) : ""} · ${p.max_health} HP / ${p.attack_damage} ATK · ${cfg.talismans.length} talismans · ${cfg.party.length + p.party_members.length} allies · vs <b>${esc(foes)}</b>`;
}

function init() {
  const cfgEl = $("#config");
  cfgEl.addEventListener("change", onConfigEvent);
  cfgEl.addEventListener("click", onConfigEvent);
  $("#menu").addEventListener("click", onMenuClick);
  $("#menu").addEventListener("mouseover", (e) => { const b = e.target.closest("[data-desc]"); if (b && b.dataset.desc) { const d = $("#mdesc"); if (d) d.textContent = b.dataset.desc; } });
  $("#grid").addEventListener("click", onGridClick);
  $("#side").addEventListener("click", onSideClick);
  $("#btnStart").onclick = () => startBattle(cfg.seed);
  $("#btnBack").onclick = backToSetup;
  $("#btnBatchSetup").onclick = openBatch;
  $("#btnSeedSetup").onclick = () => { cfg.seed = (Math.random() * 1e9) >>> 0; saveCfg(); $("#seedBoxSetup").value = cfg.seed; };
  $("#seedBoxSetup").value = cfg.seed;
  $("#seedBoxSetup").onchange = (e) => { cfg.seed = Number(e.target.value) >>> 0; saveCfg(); };
  $("#btnRestart").onclick = () => startBattle(cfg.seed);
  $("#btnNewSeed").onclick = () => { cfg.seed = (Math.random() * 1e9) >>> 0; saveCfg(); $("#seedBox").value = cfg.seed; if (sim) startBattle(cfg.seed); };
  $("#seedBox").value = cfg.seed;
  $("#seedBox").onchange = (e) => { cfg.seed = Number(e.target.value) >>> 0; saveCfg(); };
  $("#btnAuto").onclick = autoRun;
  $("#btnAutoTurn").onclick = () => runAction(autoOneStep);
  $("#btnBatch").onclick = openBatch;
  $("#btnSave").onclick = () => openSaveLoad(true);
  $("#btnLoad").onclick = () => openSaveLoad(false);
  showView("setup", true);
  if (location.hash !== "#setup") { try { history.replaceState(null, "", "#setup"); } catch (e) { /* file:// quirks */ } }
  renderConfig();
  refresh();
}
init();

// ================================================================== about / log copy
function openAbout() {
  modal(`<h2>About this simulator</h2>
    <p>A standalone port of Savage Lands' tile-battle engine (Main.gd / Player.gd), built for balance testing. Every number — weapons, tiers, materials, Mythics, talismans, Astral upgrades, enemies, party members, and every combat constant — was exported straight from the game's scripts${SIM_DATA.exported ? " on <b>" + esc(SIM_DATA.exported) + "</b>" : ""}.</p>
    <p><b>Verified against the real game:</b> 1,146 randomized comparisons (player stats &amp; weapon pipeline, the full single-hit damage pipeline, damage-taken reductions, enemy AI turns including movement/targeting/wind-ups/sweeps/terrain, and whole player-action rounds) produce identical results to the game's own code.</p>
    <p><b>Modelled:</b> the 8×8 / 15×15 battle grid with terrain, line of sight, awareness &amp; stealth, all enemy behaviours, bosses, elites, difficulty, every weapon special / Heavy / arrows, material passives, bleeding / burning / poison / concussion / blindness / fear / freeze, shields, Defend / Taunt / Stealth, items, XP &amp; mid-battle level-ups, Berserk, talismans, Astral upgrades, and player-commanded allies.</p>
    <p><b>Not modelled:</b> the overworld, shops, events/shrines, and anything that happens between battles (essence, loot, wolf loyalty). The auto-player is a simple heuristic meant for relative comparisons.</p>
    <p class="dim">When the game's data changes, regenerate with <code>tools/export_battle_sim_data.gd</code> then <code>tools/battle_sim/build.sh</code>; combat-logic changes need the matching edit in the engine files (see <code>tools/export_battle_sim_parity.gd</code> to re-verify).</p>
    <div class="row"><button id="aboutClose">Close</button></div>`);
  $("#aboutClose").onclick = closeModal;
}
$("#btnAbout").onclick = openAbout;
$("#btnCopyLog").onclick = () => { if (sim && navigator.clipboard) navigator.clipboard.writeText(sim.logLines.map((l) => `R${l.turn + 1} ${l.msg}`).join("\n")); };
