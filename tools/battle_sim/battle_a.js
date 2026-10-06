/* Battle engine, part A -- state, setup, grid helpers.
 * Port of scripts/Main.gd (battle section). Function names match the GDScript so the
 * two can be compared side by side; leading underscores kept.
 */
"use strict";

class Sim {
  constructor(seed) {
    this.rng = new RNG(seed || 1);
    this.player = new Player(this);
    this.logLines = [];
    this.promptHandler = null;      // async (type, data) => choice, installed by the UI / auto-player
    this.reset_battle_state();
  }

  reset_battle_state() {
    this.in_battle = false;
    this.over = false;
    this.result = "";               // "victory" | "defeat" | "fled"
    this.BATTLE_GRID_W = MC.DEFAULT_BATTLE_GRID_SIZE;
    this.BATTLE_GRID_H = MC.DEFAULT_BATTLE_GRID_SIZE;
    this.battle_terrain = {};       // vkey -> {type, push_dir?, dir?}
    this.battle_units = [];
    this.battle_allies = [];
    this.battle_fainted_members = [];
    this.battle_commanding_ally = null;
    this.battle_ally_queue = [];
    this.battle_ally_moves_left = 0;
    this.battle_ally_move_undo = null;
    this.battle_player_tile = V(0, 0);
    this.battle_player_moves_left = 0;
    this.battle_target_index = 0;
    this.battle_rock_target = vclone(NONE);
    this.battle_player_defending = false;
    this.battle_player_taunting = false;
    this.battle_ironclad_move_allowed = true;
    this.battle_skill_cooldown = 0;
    this.battle_player_turns_to_skip = 0;
    this.player_poison_turns = 0; this.player_poison_dmg = 0; this.player_burning = false;
    this.player_concussed_turns = 0; this.player_bleed_turns = 0; this.player_blind_turns = 0;
    this.battle_feared_by_index = -1; this.battle_fear_cascade_depth = 0; this.battle_feared_unreachable = false;
    this.battle_momentum_stacks = 0; this.battle_momentum_chain_stacks = 0;
    this.battle_bloodmoon_quiet_turns = 0; this.battle_had_combat_action_this_cycle = false;
    this.battle_first_attack_used = false;
    this.battle_turn = "player";
    this.battle_menu_state = "main";
    this.battle_move_undo = null;
    this.battle_move_trail = [];
    this.battle_awaiting = null;    // pending prompt, for the UI
    this.ref_counter = 0;
    // run statistics
    this.stats = { turns: 0, damage_dealt: 0, damage_taken: 0, kills: 0, xp_gained: 0, potions_used: 0, stamina_spent: 0, actions: {} };
  }

  // ---------------------------------------------------------------- logging
  log(msg, cls) { this.logLines.push({ turn: this.stats.turns, msg, cls: cls || "" }); }
  stat_action(name) { this.stats.actions[name] = (this.stats.actions[name] || 0) + 1; }

  // ---------------------------------------------------------------- prompts
  async prompt(type, data) {
    this.battle_awaiting = { type, data };
    let choice;
    if (this.promptHandler) choice = await this.promptHandler(type, data);
    else choice = data && data.default !== undefined ? data.default : null;
    this.battle_awaiting = null;
    return choice;
  }

  // ---------------------------------------------------------------- player setup helpers
  _battle_player_move_range() {
    let bonus = Math.max(0, Math.trunc((this.player.stat_agility - PC.AGILITY_START) / MC.AGILITY_PER_EXTRA_MOVE));
    if (this.player.potion_energy_turns > 0) bonus += MC.ENERGY_POTION_MOVE_BONUS;
    bonus += Math.trunc(this.player.talisman_bonus("move_range"));
    return MC.PLAYER_BASE_MOVE_RANGE + bonus;
  }

  _footprint(tile, size) {
    if (size <= 1) return [tile];
    const cells = [];
    for (let dx = 0; dx < size; dx++) for (let dy = 0; dy < size; dy++) cells.push(V(tile.x + dx, tile.y + dy));
    return cells;
  }
  _footprint_dist(footprint, target) {
    let best = 9999;
    for (const c of footprint) { const d = abs(c.x - target.x) + abs(c.y - target.y); if (d < best) best = d; }
    return best;
  }
  _in_battle_bounds(t) { return t.x >= 0 && t.y >= 0 && t.x < this.BATTLE_GRID_W && t.y < this.BATTLE_GRID_H; }
  terrainAt(t) { return this.battle_terrain[vkey(t)] || null; }

  _battle_tile_occupied(t, ignore_ref = null, ignore_tile = null) {
    if (veq(t, this.battle_player_tile)) return true;
    for (const u of this.battle_units) {
      if (ignore_ref !== null && u.ref === ignore_ref) continue;
      for (const cell of this._footprint(u.tile, u.size ?? 1)) if (veq(cell, t)) return true;
    }
    for (const a of this.battle_allies) {
      if (ignore_tile !== null && veq(a.tile, ignore_tile)) continue;
      if (veq(a.tile, t)) return true;
    }
    return false;
  }

  _find_empty_tile_near(origin) {
    const candidates = this.rng.shuffle(CARDINAL_DIRS.slice());
    for (const dir of candidates) {
      const t = vadd(origin, dir);
      if (!this._in_battle_bounds(t) || this._battle_tile_occupied(t)) continue;
      const terrain = this.terrainAt(t);
      if (terrain && (terrain.type === "rock" || terrain.type === "rubble")) continue;
      return t;
    }
    return vclone(NONE);
  }

  _pick_disarm_tile() {
    const cands = [];
    for (let x = 0; x < this.BATTLE_GRID_W; x++) for (let y = 0; y < this.BATTLE_GRID_H; y++) {
      const t = V(x, y);
      if (!this._battle_tile_occupied(t) && !this.battle_terrain[vkey(t)]) cands.push(t);
    }
    if (cands.length === 0) return vclone(this.battle_player_tile);
    return cands[this.rng.randi_n(cands.length)];
  }
  _check_disarm_reclaimed() {
    const p = this.player;
    if (!veq(p.disarmed_tile, NONE) && veq(this.battle_player_tile, p.disarmed_tile)) {
      p.disarmed_tile = vclone(NONE);
      this.log("You reclaim your weapon!");
    }
  }

  _player_weapon_id() { return this.player.current_weapon.id || ""; }
  _player_long_range_equipped() { return !!this.player.current_weapon.long_range; }
  _player_has_spear() { return this._player_weapon_id().startsWith("spear"); }
  _player_has_bow() { return this._player_weapon_id().startsWith("bow"); }
  _player_has_hand_picks() { return this._player_weapon_id().startsWith("hand_picks"); }
  _player_has_dagger() { return this._player_weapon_id().startsWith("dagger"); }

  _isRockish(terrain) { return terrain && (terrain.type === "rock" || terrain.type === "rubble"); }
  _targetable_rock_tiles() {
    const res = [];
    for (const dir of CARDINAL_DIRS) { const t = vadd(this.battle_player_tile, dir); if (this._isRockish(this.terrainAt(t))) res.push(t); }
    return res;
  }
  _effective_rock_target() {
    const tt = this._targetable_rock_tiles();
    if (tt.length === 0) return vclone(NONE);
    if (tt.some((t) => veq(t, this.battle_rock_target))) return this.battle_rock_target;
    return tt[0];
  }
  _has_adjacent_rock(t) {
    for (const dir of CARDINAL_DIRS) if (this._isRockish(this.terrainAt(vadd(t, dir)))) return true;
    return false;
  }

  // ---------------------------------------------------------------- stepping / terrain
  _resolve_battle_step(from, dir, ignore_tile = null) {
    const blocked = { tile: from, moved: false, fell: false };
    const target = vadd(from, dir);
    if (!this._in_battle_bounds(target) || this._battle_tile_occupied(target, null, ignore_tile)) return blocked;
    const terrain = this.terrainAt(target);
    if (this._isRockish(terrain)) return blocked;
    if (terrain && (terrain.type === "ledge" || terrain.type === "cliff")) {
      if (!veq(dir, V(terrain.dir.x, terrain.dir.y))) return { tile: target, moved: true, fell: false };
      const landing = vadd(target, dir);
      if (!this._in_battle_bounds(landing) || this._battle_tile_occupied(landing, null, ignore_tile)) return blocked;
      const landing_terrain = this.terrainAt(landing);
      if (this._isRockish(landing_terrain)) return blocked;
      let fell = false;
      if (terrain.type === "cliff") {
        const lands_in_water = landing_terrain && landing_terrain.type === "water";
        if (!lands_in_water) fell = true;
      }
      return { tile: landing, moved: true, fell };
    }
    if (terrain && terrain.type === "ice") {
      const slide_target = vadd(target, dir);
      const slide_terrain = this.terrainAt(slide_target);
      const slide_ok = this._in_battle_bounds(slide_target) && !this._battle_tile_occupied(slide_target, null, ignore_tile) && (!slide_terrain || slide_terrain.type === "water" || slide_terrain.type === "ice");
      if (slide_ok) return { tile: slide_target, moved: true, fell: false };
      return { tile: target, moved: true, fell: false };
    }
    if (terrain && terrain.type === "caltrops") return { tile: target, moved: true, fell: false, extra_cost: true };
    return { tile: target, moved: true, fell: false };
  }

  _resolve_big_unit_step(tile, size, dir, self_ref) {
    const nt = vadd(tile, dir);
    for (const cell of this._footprint(nt, size)) {
      if (!this._in_battle_bounds(cell) || this._battle_tile_occupied(cell, self_ref)) return { tile, moved: false };
    }
    return { tile: nt, moved: true };
  }

  // Water: extinguishes burning (and Ember Charm's fire) and pushes along its current.
  _apply_water_push(tile, unit = null) {
    const terrain = this.terrainAt(tile);
    if (!terrain || terrain.type !== "water") return tile;
    if (!unit) this.player_burning = false;
    else { unit.burning = false; unit.burn_value = 0.0; }
    const pd = V(terrain.push_dir.x, terrain.push_dir.y);
    const pushed = vadd(tile, pd);
    if (!this._in_battle_bounds(pushed) || this._battle_tile_occupied(pushed)) return tile;
    const pt = this.terrainAt(pushed);
    if (pt && pt.type === "rock") return tile;
    return pushed;
  }

  _apply_terrain_tick(tile, unit = null) {
    const terrain = this.terrainAt(tile);
    if (!terrain) return;
    const is_player = !unit;
    const who = is_player ? "you" : `the ${unit.name}`;
    switch (terrain.type) {
      case "embers":
        if (is_player) this.player_burning = true; else unit.burning = true;
        this.log(`The embers set ${who} alight!`);
        break;
      case "poison_bog":
        if (is_player) { this.player_poison_turns = MC.POISON_TURNS; this.player_poison_dmg = Math.max(1, round(this.player.max_health * MC.POISON_DAMAGE_PCT)); }
        else { unit.poison_turns = MC.POISON_TURNS; unit.poison_dmg = Math.max(1, round(unit.max_hp * MC.POISON_DAMAGE_PCT)); }
        this.log(`The bog poisons ${who}!`);
        break;
      case "quicksand":
        if (is_player) this.battle_player_turns_to_skip += 1; else unit.stunned = true;
        this.log(`The quicksand traps ${who}!`);
        break;
      case "spring":
        if (is_player) this.player.heal(MC.SPRING_HEAL_AMOUNT);
        else unit.hp = Math.min(unit.max_hp, unit.hp + MC.SPRING_HEAL_AMOUNT);
        this.log(`The spring heals ${who}.`);
        break;
      case "crumbling":
        this.battle_terrain[vkey(tile)] = { type: "rock" };
        this.log("The ground crumbles into rock behind you.");
        break;
    }
  }

  // ---------------------------------------------------------------- attack range / sight
  _can_battle_attack(attacker_tile, target_tile, max_range, ignore_line = false, ignore_ledge = false) {
    const diff = vsub(target_tile, attacker_tile);
    const dist = abs(diff.x) + abs(diff.y);
    if (dist < 1 || dist > max_range) return false;
    if (dist >= 2 && !ignore_line) {
      if (diff.x !== 0 && diff.y !== 0) return false;
      const step = V(sign(diff.x), sign(diff.y));
      let cursor = vadd(attacker_tile, step);
      while (!veq(cursor, target_tile)) {
        const mid = this.terrainAt(cursor);
        if (mid && (mid.type === "rock" || mid.type === "rubble" || mid.type === "thicket")) return false;
        cursor = vadd(cursor, step);
      }
    }
    if (max_range <= 1 && !ignore_ledge) {
      const tt = this.terrainAt(target_tile);
      if (tt && (tt.type === "ledge" || tt.type === "cliff")) {
        if (veq(diff, V(-tt.dir.x, -tt.dir.y))) return false;
      }
    }
    return true;
  }

  _has_line_of_sight(from, to) {
    const dx = abs(to.x - from.x);
    const dy = -abs(to.y - from.y);
    const sx = from.x < to.x ? 1 : -1;
    const sy = from.y < to.y ? 1 : -1;
    let err = dx + dy;
    let cx = from.x, cy = from.y;
    while (!(cx === to.x && cy === to.y)) {
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; cx += sx; }
      if (e2 <= dx) { err += dx; cy += sy; }
      if (cx === to.x && cy === to.y) break;
      const mid = this.terrainAt(V(cx, cy));
      if (mid && (mid.type === "rock" || mid.type === "rubble" || mid.type === "thicket")) return false;
    }
    return true;
  }

  _enemy_can_see_player_now(u) {
    const sight = this.player.stealth_turns_remaining > 0 ? MC.STEALTH_SIGHT_RANGE : MC.ENEMY_SIGHT_RANGE;
    const fp = this._footprint(u.tile, u.size ?? 1);
    if (this._footprint_dist(fp, this.battle_player_tile) > sight) return false;
    return this._has_line_of_sight(u.tile, this.battle_player_tile);
  }
  _update_enemy_awareness() {
    for (const u of this.battle_units) {
      if (u.aware_of_player) continue;
      if ((TRAITS[u.name] || {}).is_boss_tier) continue;
      if (this._enemy_can_see_player_now(u)) u.aware_of_player = true;
    }
  }
  _enemy_currently_sees_player(u) {
    if ((TRAITS[u.name] || {}).is_boss_tier) return true;
    return !!u.aware_of_player;
  }

  // ---------------------------------------------------------------- setup (Main._setup_battle_grid)
  // cfg: { enemies:[{name, elite, power_tier}], world:'plains', fixed_terrain? }
  setup_battle(cfg) {
    const p = this.player;
    this.reset_battle_state();
    const squad = cfg.enemies;
    const first = squad[0];
    const is_boss_fight = squad.length === 1 && (TRAITS[first.name] || {}).is_boss_tier;
    this.BATTLE_GRID_W = is_boss_fight ? MC.BOSS_BATTLE_GRID_SIZE : MC.DEFAULT_BATTLE_GRID_SIZE;
    this.BATTLE_GRID_H = this.BATTLE_GRID_W;

    p.bloodmoon_stacks = 0; p.bloodmoon_debuffed = false;
    p.disarmed_tile = vclone(NONE); p.pichaku_active = false;
    p.second_chance_used_this_battle = false; p.shield_vengeance_active = false;
    p.potion_attack_turns = 0; p.potion_resilience_turns = 0; p.potion_energy_turns = 0;
    p.berserk_turns_remaining = 0; p.stealth_turns_remaining = 0;
    p.died = false;
    p._recalc_stats();

    const used = {};
    this.battle_player_tile = V(0, Math.trunc(this.BATTLE_GRID_H / 2));
    used[vkey(this.battle_player_tile)] = true;
    this.battle_player_moves_left = this._battle_player_move_range();
    p.reset_stamina_for_battle();

    const enemy_col = Math.max(1, this.BATTLE_GRID_W - 3);
    const enemy_rows = [];
    for (let i = 0; i < this.BATTLE_GRID_H; i++) enemy_rows.push(i);
    this.rng.shuffle(enemy_rows);
    // Per-level scaling: the difficulty's rate, bosses/minibosses (is_boss_tier) at a fraction of it (Main._enemy_level_scale).
    const enemy_scale = (is_boss_tier) => {
      let rate = (MC.ENEMY_LEVEL_SCALING_BY_DIFFICULTY || {})[p.difficulty_id] ?? MC.ENEMY_LEVEL_SCALING;
      if (is_boss_tier) rate *= MC.BOSS_LEVEL_SCALING_FACTOR;
      return 1.0 + (p.level - 1) * rate;
    };
    const gnome_pack_size = squad.filter((s) => s.name === "Gnome").length;

    squad.forEach((e, i) => {
      const traits = TRAITS[e.name] || {};
      const edata = enemyByName(e.name);
      const size = traits.size ?? 1;
      const col = Math.min(enemy_col, this.BATTLE_GRID_W - size);
      let tile = V(col, Math.min(enemy_rows[i % enemy_rows.length], this.BATTLE_GRID_H - size));
      for (const row_candidate of enemy_rows) {
        const cand = V(col, Math.min(row_candidate, this.BATTLE_GRID_H - size));
        let fits = true;
        for (const cell of this._footprint(cand, size)) if (used[vkey(cell)]) { fits = false; break; }
        if (fits) { tile = cand; break; }
      }
      for (const cell of this._footprint(tile, size)) used[vkey(cell)] = true;
      const elite_hp = e.elite ? MC.ELITE_HP_MULT : 1.0;
      const elite_dmg = e.elite ? MC.ELITE_DAMAGE_MULT : 1.0;
      const power_tier = e.power_tier ?? 1.0;
      const scale_mult = enemy_scale(!!traits.is_boss_tier);
      let scaled_hp = Math.max(1, round(edata.max_health * scale_mult * elite_hp * p.difficulty_mult * power_tier));
      if (e.name === "Gnome" && gnome_pack_size > 1) scaled_hp += (gnome_pack_size - 1) * MC.GNOME_HP_PER_PACKMATE;
      const scaled_damage = Math.max(1, round(edata.contact_damage * scale_mult * elite_dmg * p.difficulty_mult * power_tier));
      this.battle_units.push({
        ref: ++this.ref_counter, tile, hp: scaled_hp, max_hp: scaled_hp,
        move_range: traits.move_range ?? 2, damage: scaled_damage, name: e.name,
        winding_up: false, stunned: false, size, attack_range: traits.attack_range ?? 1,
        is_elite: !!e.elite, concussed_turns: 0, frozen_turns: 0, burning: false,
        vulnerable_turns: 0, aware_of_player: false, armored: !!traits.armored,
        disarmed_tile: vclone(NONE), xp_reward: edata.xp_reward,
      });
    });

    this._place_ally_units(used);

    const terrain_scale = (this.BATTLE_GRID_W * this.BATTLE_GRID_H) / 36.0;
    this._place_terrain("rock", Math.max(3, round(3 * terrain_scale)), used);
    this._place_terrain("water", Math.max(3, round(3 * terrain_scale)), used, true, false);
    this._place_terrain("ledge", Math.max(2, round(2 * terrain_scale)), used, false, true);
    this._place_terrain("cliff", Math.max(1, round(1 * terrain_scale)), used, false, true);
    const world = D.worlds.find((w) => w.id === (cfg.world || "plains")) || D.worlds[0];
    for (const kind of world.terrain) this._place_terrain(kind, Math.max(2, round(2 * terrain_scale)), used);
    this._prevent_boxed_in_units();

    this.in_battle = true;
    this._update_enemy_awareness();
    this.log(`Battle begins! ${squad.map((s) => s.name + (s.elite ? " (elite)" : "")).join(", ")}`, "sys");
    return this;
  }

  _place_ally_units(used) {
    const p = this.player;
    const roster = [];
    for (const m of p.party_members) roster.push({ name: m.name, dmg_mult: m.dmg_mult + p.meta_warband_bonus, move_range: MC.ALLY_MOVE_RANGE, max_hp_pct: MC.ALLY_MAX_HP_PCT });
    for (const m of p.fielded_party()) roster.push({ member: m });
    if (roster.length === 0) return;
    let candidates = [];
    for (let x = 0; x < 2; x++) for (let y = 0; y < this.BATTLE_GRID_H; y++) if (!used[vkey(V(x, y))]) candidates.push(V(x, y));
    this.rng.shuffle(candidates);
    if (candidates.length < roster.length) {
      for (let x = 0; x < this.BATTLE_GRID_W; x++) for (let y = 0; y < this.BATTLE_GRID_H; y++) {
        const t = V(x, y);
        if (!used[vkey(t)] && !candidates.some((c) => veq(c, t))) candidates.push(t);
      }
    }
    const might_mult = 1.0 + p.stat_might * MC.MIGHT_ALLY_DAMAGE_PCT_PER_POINT;
    roster.forEach((entry, i) => {
      const tile = candidates[i];
      used[vkey(tile)] = true;
      if (entry.member) { this.battle_allies.push(this._make_member_battle_unit(entry.member, tile, might_mult)); return; }
      const max_hp = Math.max(1, round(p.max_health * entry.max_hp_pct));
      this.battle_allies.push({
        ref: ++this.ref_counter, tile, hp: max_hp, max_hp, dmg_mult: entry.dmg_mult * might_mult,
        name: entry.name, kind: "mercenary", defense_pct: 0.0, move_range: entry.move_range, attack_range: MC.ALLY_ATTACK_RANGE,
      });
    });
  }

  _make_member_battle_unit(member, tile, might_mult) {
    const rules = member.rules;
    return {
      ref: ++this.ref_counter, tile, hp: member.max_hp(), max_hp: member.max_hp(), name: member.name, kind: member.kind,
      member, attack: member.attack(), dmg_mult: might_mult, defense_pct: member.defense_pct(),
      move_range: member.move_tiles(), attack_range: rules.attack_range ?? MC.ALLY_ATTACK_RANGE,
      stamina: member.max_stamina(), max_stamina: member.max_stamina(), mana: member.max_mana(), max_mana: member.max_mana(), fainted: false,
    };
  }

  _prevent_boxed_in_units() {
    for (let x = 0; x < this.BATTLE_GRID_W; x++) for (let y = 0; y < this.BATTLE_GRID_H; y++) {
      const tile = V(x, y);
      const neighbors = [];
      for (const dir of CARDINAL_DIRS) { const n = vadd(tile, dir); if (this._in_battle_bounds(n)) neighbors.push(n); }
      let all_blocked = true;
      for (const n of neighbors) { if (!this._isRockish(this.terrainAt(n))) { all_blocked = false; break; } }
      if (all_blocked && neighbors.length > 0) delete this.battle_terrain[vkey(neighbors[0])];
    }
  }

  _place_terrain(kind, count, used, needs_push = false, needs_dir = false) {
    let placed = 0, attempts = 0;
    while (placed < count && attempts < 60) {
      attempts++;
      const t = V(this.rng.randi_range(0, this.BATTLE_GRID_W - 1), this.rng.randi_range(0, this.BATTLE_GRID_H - 1));
      if (used[vkey(t)] || this.battle_terrain[vkey(t)]) continue;
      const entry = { type: kind };
      if (needs_push) entry.push_dir = vclone(CARDINAL_DIRS[this.rng.randi_n(CARDINAL_DIRS.length)]);
      if (needs_dir) entry.dir = vclone(CARDINAL_DIRS[this.rng.randi_n(CARDINAL_DIRS.length)]);
      this.battle_terrain[vkey(t)] = entry;
      used[vkey(t)] = true;
      placed++;
    }
  }
}
