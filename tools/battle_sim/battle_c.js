/* Battle engine, part C -- movement, damage taken, the enemy turn, and the action dispatcher.
 * Port of scripts/Main.gd (_try_battle_player_move, _enemy_apply_damage, _process_enemy_turn, ...).
 */
"use strict";

Object.assign(Sim.prototype, {

  // ---------------------------------------------------------------- player movement
  _extend_bleed_on_move() {
    if (this.player_bleed_turns <= 0) return;
    this.player_bleed_turns += 1;
    this.log("Bleeding, the movement tears the wound further.");
  },

  begin_move() {
    const p = this.player;
    if (this.battle_commanding_ally) {
      if (this.battle_ally_moves_left <= 0) { this.log(`Your ${this.battle_commanding_ally.name} has no moves left.`); return false; }
      this.battle_menu_state = "move";
      this.battle_ally_move_undo = { tile: vclone(this.battle_commanding_ally.tile), moves_left: this.battle_ally_moves_left, hp: this.battle_commanding_ally.hp };
      this.battle_move_trail = [];
      return true;
    }
    if (p.talisman_bonus("ironclad_ward") > 0 && !this.battle_ironclad_move_allowed) { this.log("Ironclad Ward roots you to the spot this turn."); return false; }
    if (this.battle_player_moves_left <= 0) { this.log("No moves left this turn."); return false; }
    this.battle_menu_state = "move";
    this.battle_move_undo = {
      tile: vclone(this.battle_player_tile), moves_left: this.battle_player_moves_left, health: p.health,
      awareness: this.battle_units.map((u) => !!u.aware_of_player),
    };
    this.battle_move_trail = [];
    return true;
  },

  step_move(dir) {
    if (this.over || this.battle_menu_state !== "move") return;
    if (this.battle_commanding_ally) return this._try_battle_ally_move(dir);
    return this._try_battle_player_move(dir);
  },

  _try_battle_player_move(dir) {
    const p = this.player;
    if (this.battle_player_moves_left <= 0) return;
    const r = this._resolve_battle_step(this.battle_player_tile, dir);
    if (!r.moved) return;
    this.battle_player_tile = r.tile;
    this._update_enemy_awareness();
    this.battle_player_moves_left -= r.extra_cost ? 2 : 1;
    this.battle_move_trail.push({ tile: vclone(r.tile), dir });
    this._check_disarm_reclaimed();
    this._extend_bleed_on_move();
    if (r.fell) {
      const fall_mult = (this.player.equipped_armor.fall_damage_mult ?? 1.0) * p.fall_damage_factor();
      if (fall_mult <= 0) this.log(`Your ${p.equipped_armor.name} lets you shrug off the fall.`);
      else {
        const dmg = round(p.max_health * MC.CLIFF_FALL_DAMAGE_PCT * fall_mult);
        p.take_battle_damage(dmg);
        this.log(`You fall! Took ${dmg} damage.`, "bad");
        this._check_player_dead();
      }
    }
  },

  _try_battle_ally_move(dir) {
    if (this.battle_ally_moves_left <= 0) return;
    const u = this.battle_commanding_ally;
    const r = this._resolve_battle_step(u.tile, dir, u.tile);
    if (!r.moved) return;
    u.tile = r.tile;
    this.battle_ally_moves_left -= r.extra_cost ? 2 : 1;
    this.battle_move_trail.push({ tile: vclone(r.tile), dir });
    if (r.fell) {
      const dmg = round(u.max_hp * MC.CLIFF_FALL_DAMAGE_PCT);
      u.hp -= dmg;
      this.log(`Your ${u.name} falls and takes ${dmg} damage!`, "bad");
      if (u.hp <= 0) { this.battle_menu_state = "main"; this._ally_command_over(); }
    }
  },

  confirm_move() {
    if (this.battle_menu_state !== "move") return;
    this.battle_menu_state = "main"; this.battle_move_trail = [];
  },
  cancel_move() {
    if (this.battle_menu_state !== "move") return;
    if (this.battle_commanding_ally) {
      const a = this.battle_commanding_ally, un = this.battle_ally_move_undo;
      a.tile = un.tile; this.battle_ally_moves_left = un.moves_left; a.hp = un.hp;
    } else {
      const un = this.battle_move_undo, p = this.player;
      this.battle_player_tile = un.tile; this.battle_player_moves_left = un.moves_left; p.restore_health(un.health);
      this.battle_units.forEach((u, i) => { if (i < un.awareness.length) u.aware_of_player = un.awareness[i]; });
    }
    this.battle_menu_state = "main"; this.battle_move_trail = [];
    this.log("Movement undone.");
  },

  // ---------------------------------------------------------------- damage the player takes
  _apply_incoming_reductions(dmg, traits) {
    const p = this.player;
    let reduced = dmg;
    if (this.battle_player_defending) {
      let negate = p.meta_block_negate_chance;
      if (p.berserk_turns_remaining > 0) negate *= MC.BERSERK_DEFENSE_MULT;
      if (negate > 0 && this.rng.randf() < negate) return 0;
      // Bastion Mail raises the threshold Defend negates a hit below.
      const threshold = MC.DEFEND_FULL_NEGATE_THRESHOLD + p.shield_defend_threshold_bonus() + Math.trunc(p.armor_trait_value("defend_threshold_bonus", 0));
      if (dmg < threshold) return 0;
      reduced = round(reduced * (1.0 - MC.DEFEND_DAMAGE_REDUCTION));
    }
    // Harm is BODILY (armour, Resilience, shield, cover), MAGICAL (Fortitude) or "both", half and half.
    const harm = traits.harm || "bodily";
    let bodily_part = reduced;
    let magical_part = 0;
    if (harm === "magical") { bodily_part = 0; magical_part = reduced; }
    else if (harm === "both") { bodily_part = round(reduced * 0.5); magical_part = reduced - bodily_part; }
    let total = 0;
    if (bodily_part > 0) total += this._reduce_bodily(bodily_part, traits);
    if (magical_part > 0) total += this._reduce_magical(magical_part);
    return total;
  },

  // The cuts that apply to either kind of harm: a Resilience Potion and Last Stand.
  _generic_reduction() {
    const p = this.player;
    let generic = p.potion_resilience_turns > 0 ? MC.RESILIENCE_POTION_DAMAGE_REDUCTION_PCT : 0.0;
    if (p.meta_last_stand_pct_per_10 > 0) {
      const missing = 1.0 - p.health / p.max_health;
      generic += p.meta_last_stand_pct_per_10 * Math.floor(missing * 10.0);
    }
    return generic;
  },

  _reduce_bodily(dmg, traits) {
    const p = this.player;
    let reduced = dmg;
    if (!traits.ignore_cover && this._has_adjacent_rock(this.battle_player_tile)) reduced = round(reduced * (1.0 - MC.ROCK_COVER_REDUCTION));
    let points = p.bodily_defense_points() + this._generic_reduction() * 100.0;
    if (p.armor_trait() === "martyr") {
      const missing = 1.0 - p.health / p.max_health;
      points += p.armor_trait_value("bodily_per_10_missing", 0.0) * Math.floor(missing * 10.0) * 100.0;
    }
    reduced = round(reduced * (1.0 - defense_reduction(points)));
    const flat_cut = Math.trunc(p.armor_trait_value("flat_reduction", 0));
    if (flat_cut > 0 && reduced > 0) reduced = Math.max(1, reduced - flat_cut);
    return reduced;
  },

  _reduce_magical(dmg) {
    const p = this.player;
    let reduced = dmg;
    const spellward = p.armor_trait() === "spellward";
    if (spellward && !this.battle_spellward_used) {
      this.battle_spellward_used = true;
      reduced = 0;
      this.log("Your wards swallow the spell whole!");
    } else {
      const points = p.fortitude_total() + this._generic_reduction() * 100.0;
      reduced = round(reduced * (1.0 - defense_reduction(points)));
    }
    if (spellward) p.regen_stamina(Math.trunc(p.armor_trait_value("magic_hit_stamina", 0)));
    return reduced;
  },

  // What the worn armour does when a blow actually lands on the hero.
  _armor_on_hit(u, dmg, traits) {
    const p = this.player;
    const trait_id = p.armor_trait();
    if (!trait_id) return;
    const melee = (u.attack_range ?? 1) <= 1 && (traits.harm || "bodily") !== "magical";
    switch (trait_id) {
      case "bloodrage": {
        const max_stacks = Math.trunc(p.armor_trait_value("max_stacks", 5));
        if (this.battle_bloodrage_stacks < max_stacks) this.battle_bloodrage_stacks += 1;
        this.battle_bloodrage_turns = Math.trunc(p.armor_trait_value("turns", 2));
        this.log(`The blow feeds your rage! (+${round(this.battle_bloodrage_stacks * p.armor_trait_value("dmg_per_stack", 0.1) * 100.0)}% damage)`);
        break;
      }
      case "thorns":
        if (melee && u.hp !== undefined) {
          const reflected = Math.max(1, round(dmg * p.armor_trait_value("reflect_pct", 0.0)));
          u.hp -= reflected;
          this.log(`Your thorns throw ${reflected} damage back at the ${u.name ?? "attacker"}!`);
        }
        break;
      case "cinder":
        if (melee && !u.burning) { u.burning = true; this.log(`The ${u.name ?? "attacker"} catches fire from your cinders!`); }
        break;
    }
  },

  // Shadowweave: slipping a blow sets up a guaranteed crit on your next hit.
  _on_hero_dodged() {
    if (this.player.armor_trait() === "shadowweave") {
      this.battle_shadow_crit = true;
      this.log("Slipping the blow, you set up a killing strike!");
    }
  },

  _resolve_shield_block(attacker, raw_dmg) {
    const p = this.player;
    const shield = p.equipped_shield;
    switch (shield.special || "") {
      case "knockback": {
        const extra = p.shield_special_pct() > 0;
        this.log(`Your shield slams the ${attacker.name} back!`);
        this._apply_knockback(attacker, this._knockback_dir(this.battle_player_tile, attacker.tile), true, extra);
        break;
      }
      case "thorns": {
        const idx = this._unit_index_at_tile(attacker.tile);
        if (idx >= 0) {
          const reflected = round(raw_dmg * p.shield_special_pct());
          if (reflected > 0) this._apply_single_hit(idx, 1.0, "thorns", p.current_weapon, "Your shield", null, reflected);
        }
        break;
      }
      case "vengeance": p.shield_vengeance_active = true; this.log("Your shield leaves you itching to strike back!"); break;
    }
  },

  _evasion_directions(attacker_tile) {
    const diff = vsub(this.battle_player_tile, attacker_tile);
    let back;
    if (abs(diff.x) >= abs(diff.y)) back = V(diff.x !== 0 ? sign(diff.x) : 1, 0);
    else back = V(0, sign(diff.y));
    const candidates = { back, left: V(-back.y, back.x), right: V(back.y, -back.x) };
    const valid = {};
    for (const label of Object.keys(candidates)) if (this._resolve_battle_step(this.battle_player_tile, candidates[label]).moved) valid[label] = candidates[label];
    return valid;
  },
  async _prompt_evasion_reposition(attacker_tile) {
    const options = this._evasion_directions(attacker_tile);
    if (Object.keys(options).length === 0) return;
    this.log("You have an opening -- pick a direction to dodge-roll!");
    const first = Object.keys(options)[0];
    const label = await this.prompt("evasion", { options, default: first });
    if (label && options[label]) this._apply_evasion_step(options[label]);
  },
  _apply_evasion_step(dir) {
    const p = this.player;
    const r = this._resolve_battle_step(this.battle_player_tile, dir);
    if (!r.moved) return;
    this.battle_player_tile = r.tile;
    this._extend_bleed_on_move();
    if (r.fell) {
      const fall_mult = (p.equipped_armor.fall_damage_mult ?? 1.0) * p.fall_damage_factor();
      if (fall_mult <= 0) this.log(`Your ${p.equipped_armor.name} lets you shrug off the fall.`);
      else { const dmg = round(p.max_health * MC.CLIFF_FALL_DAMAGE_PCT * fall_mult); p.take_battle_damage(dmg); this.log(`You fall! Took ${dmg} damage.`, "bad"); this._check_player_dead(); }
    }
  },

  // ---------------------------------------------------------------- enemy targeting
  _assign_enemy_targets() {
    const ally_tiles = this.battle_allies.map((a) => a.tile);
    const committed = {};
    for (const t of ally_tiles) committed[vkey(t)] = 0;
    committed[vkey(this.battle_player_tile)] = 0;
    const assigned = new Map();
    for (const u of this.battle_units) {
      const targets = ally_tiles.slice();
      if (this._enemy_currently_sees_player(u)) targets.push(this.battle_player_tile);
      if (targets.length === 0) continue;
      const fp = this._footprint(u.tile, u.size ?? 1);
      const dists = targets.map((t) => ({ tile: t, dist: this._footprint_dist(fp, t) }));
      dists.sort((a, b) => a.dist - b.dist);
      const min_dist = dists[0].dist;
      const close = [];
      for (const d of dists) if (d.dist <= min_dist + MC.TARGET_DECONFLICT_TOLERANCE) close.push(d.tile);
      let chosen = close[0];
      if (close.length > 1) {
        let best = committed[vkey(chosen)];
        for (const t of close) { if (committed[vkey(t)] < best) { best = committed[vkey(t)]; chosen = t; } }
      }
      committed[vkey(chosen)] += 1;
      assigned.set(u.ref, chosen);
    }
    return assigned;
  },
  _pick_enemy_target_tile(u) {
    const fp = this._footprint(u.tile, u.size ?? 1);
    let best_tile = vclone(NONE), best_dist = -1;
    if (this._enemy_currently_sees_player(u)) { best_tile = this.battle_player_tile; best_dist = this._footprint_dist(fp, this.battle_player_tile); }
    for (const a of this.battle_allies) {
      const d = this._footprint_dist(fp, a.tile);
      if (best_dist < 0 || d < best_dist) { best_dist = d; best_tile = a.tile; }
    }
    return best_tile;
  },
  _pick_confused_target_tile(u) {
    const fp = this._footprint(u.tile, u.size ?? 1);
    const tiles = [this.battle_player_tile], dists = [this._footprint_dist(fp, this.battle_player_tile)];
    for (const a of this.battle_allies) { tiles.push(a.tile); dists.push(this._footprint_dist(fp, a.tile)); }
    for (const o of this.battle_units) { if (o.ref === u.ref) continue; tiles.push(o.tile); dists.push(this._footprint_dist(fp, o.tile)); }
    const best = Math.min(...dists);
    const nearest = [];
    for (let i = 0; i < tiles.length; i++) if (dists[i] === best) nearest.push(tiles[i]);
    return nearest[this.rng.randi_n(nearest.length)];
  },

  // ---------------------------------------------------------------- one enemy attack landing
  async _enemy_apply_damage(u, target_tile, raw_dmg, traits) {
    const p = this.player;
    const rng = this.rng;
    if (u.burning) raw_dmg = round(raw_dmg * (1.0 - MC.BURN_DAMAGE_DEALT_REDUCTION));
    if (veq(target_tile, this.battle_player_tile)) {
      let dodge = p.dodge_chance_total();
      if (p.berserk_turns_remaining > 0) dodge *= MC.BERSERK_DEFENSE_MULT;
      if (dodge > 0 && rng.randf() < dodge) {
        this._on_hero_dodged();
        if (p.meta_riposte_chance > 0 && rng.randf() < p.meta_riposte_chance) {
          const aidx = this._unit_index_at_tile(u.tile);
          if (aidx >= 0) { this.log("You riposte!", "good"); this._apply_single_hit(aidx, MC.RIPOSTE_DAMAGE_PCT, "riposte", p.current_weapon); }
        }
        if (p.shield_evasion_active()) await this._prompt_evasion_reposition(u.tile);
        return { dmg: 0, is_player: true, target_name: "", dodged: true };
      }
      const block = p.shield_block_chance();
      if (block > 0 && rng.randf() < block) {
        this._resolve_shield_block(u, raw_dmg);
        return { dmg: 0, is_player: true, target_name: "", blocked: true };
      }
      const dmg = this._apply_incoming_reductions(raw_dmg, traits);
      p.take_battle_damage(dmg);
      this.stats.damage_taken += dmg;
      if (dmg > 0) this._armor_on_hit(u, dmg, traits);
      this.battle_had_combat_action_this_cycle = true;
      if (dmg > 0 && p.talisman_bonus("momentum_chain") > 0 && this.battle_momentum_chain_stacks > 0) {
        this.battle_momentum_chain_stacks = 0; this.battle_player_turns_to_skip += 1;
        this.log("The chain breaks -- you're staggered!", "bad");
      }
      if (traits.inflicts_concussion && rng.randf() < MC.CONCUSSION_INFLICT_CHANCE) { this.player_concussed_turns = MC.PLAYER_CONCUSSION_TURNS; this.log("The blow leaves you dazed!", "bad"); }
      if (traits.inflicts_bleed && this.player_bleed_turns <= 0) { this.player_bleed_turns = MC.BLEED_BASE_TURNS; this.log("The wound leaves you bleeding!", "bad"); }
      if (traits.inflicts_blind) { this.player_blind_turns = MC.BLINDNESS_TURNS; this.log("Your vision swims -- you're blinded!", "bad"); }
      this._check_player_dead();
      return { dmg, is_player: true, target_name: "", dodged: false };
    }
    let dmg = raw_dmg;
    // Bodily harm is turned by cover and defense, magical harm by neither (Fortitude instead, below).
    const harm = traits.harm || "bodily";
    const bodily_share = harm === "bodily" ? 1.0 : (harm === "magical" ? 0.0 : 0.5);
    if (!traits.ignore_cover && this._has_adjacent_rock(target_tile)) dmg = round(dmg * (1.0 - MC.ROCK_COVER_REDUCTION * bodily_share));
    let target_name = "";
    let target_ally = null;
    for (const a of this.battle_allies) if (veq(a.tile, target_tile)) { target_ally = a; break; }
    if (target_ally) {
      // Defense and Fortitude bend on the Defense.gd curve (80% ceiling, the Guardian's 90%); Guardian Knot and
      // Last Stand are extra points pooled into both. Bodily harm uses Defense, magical harm Fortitude (both: half and half).
      let ally_extra = p.talisman_bonus("ally_defense_pct") * 100.0;
      if (p.meta_last_stand_pct_per_10 > 0) {
        const ally_missing = 1.0 - target_ally.hp / Math.max(1, target_ally.max_hp);
        ally_extra += p.meta_last_stand_pct_per_10 * Math.floor(ally_missing * 10.0) * 100.0;
      }
      const ally_cap = target_ally.defense_cap ?? DEF.BASE_CAP;
      const ally_cut = bodily_share * defense_reduction((target_ally.defense_pct || 0) + ally_extra, ally_cap) + (1.0 - bodily_share) * defense_reduction((target_ally.fortitude || 0) + ally_extra, ally_cap);
      if (ally_cut !== 0) dmg = Math.max(1, round(dmg * (1.0 - ally_cut)));
      // Warden's Aegis: allies standing near the hero take less.
      if (p.armor_trait() === "warden" && abs(target_ally.tile.x - this.battle_player_tile.x) + abs(target_ally.tile.y - this.battle_player_tile.y) <= Math.trunc(p.armor_trait_value("ally_radius", 2))) dmg = Math.max(1, round(dmg * (1.0 - p.armor_trait_value("ally_reduction", 0.0))));
      if (target_ally.defending) dmg = Math.max(1, round(dmg * (1.0 - MC.DEFEND_DAMAGE_REDUCTION)));
      target_ally.hp -= dmg;
      target_name = target_ally.name;
      this.battle_had_combat_action_this_cycle = true;
    } else {
      for (const other of this.battle_units) {
        if (veq(other.tile, target_tile) && other.ref !== u.ref) { other.hp -= dmg; target_name = other.name; break; }
      }
    }
    return { dmg, is_player: false, target_name, dodged: false };
  },

  _sweep_targets(u) {
    const fp = this._footprint(u.tile, u.size ?? 1);
    const range = u.attack_range ?? 1;
    const targets = [];
    if (this._footprint_dist(fp, this.battle_player_tile) <= range) targets.push(this.battle_player_tile);
    for (const a of this.battle_allies) if (this._footprint_dist(fp, a.tile) <= range) targets.push(a.tile);
    return targets;
  },

  // ---------------------------------------------------------------- the enemy turn
  async _start_enemy_turn() {
    if (this.over) return;
    this.battle_turn = "enemy";
    await this._process_enemy_turn();
  },

  // One enemy's whole turn (Main.gd:_enemy_take_turn): statuses tick, then it moves and attacks. The old whole-phase
  // _process_enemy_turn below runs each enemy through it once; with turn order live each takes it on its own turn.
  async _enemy_take_turn(u, assigned, fae_spawns) {
    const p = this.player;
    const rng = this.rng;
    if (u.burning) {
      const burn_dmg = this._burn_tick_damage(u);
      this._decay_ember_burn(u);
      u.hp -= burn_dmg;
      this.log(`The ${u.name} burns for ${burn_dmg} damage!`);
      if (u.hp <= 0) { if (p.talisman_bonus("wildfire_core") > 0) this._trigger_wildfire_explosion(u.tile, burn_dmg); if (this.over) return; return; }
    }
    if ((u.poison_turns || 0) > 0) {
      u.poison_turns -= 1; u.hp -= u.poison_dmg;
      this.log(`The ${u.name} is poisoned for ${u.poison_dmg} damage!`);
      if (u.hp <= 0) return;
    }
    if ((u.bleed_turns || 0) > 0) {
      u.bleed_turns -= 1;
      const bleed_dmg = Math.max(1, round(u.max_hp * MC.BLEED_DAMAGE_PCT));
      u.hp -= bleed_dmg;
      this.log(`The ${u.name} bleeds for ${bleed_dmg} damage!`);
      if (u.hp <= 0) return;
    }
    if ((u.frozen_turns || 0) > 0) {
      u.frozen_turns -= 1;
      this.log(`The ${u.name} is frozen solid and can't act!`);
      u.tile = this._apply_water_push(u.tile, u);
      return;
    }
    if (u.disarmed_tile && !veq(u.disarmed_tile, NONE)) {
      if (veq(u.tile, u.disarmed_tile)) u.disarmed_tile = vclone(NONE);
      else {
        if ((u.size ?? 1) > 1) this._move_big_unit(u, u.disarmed_tile, u.disarmed_tile);
        else this._move_enemy_unit(u, 0, u.disarmed_tile, u.disarmed_tile, false);
        u.tile = this._apply_water_push(u.tile, u);
        return;
      }
    }
    let self_hit_this_turn = false;
    if ((u.concussed_turns || 0) > 0) { u.concussed_turns -= 1; self_hit_this_turn = rng.randf() < 0.33; }
    if ((u.vulnerable_turns || 0) > 0) u.vulnerable_turns -= 1;
    if (u.stunned) { u.stunned = false; this.log(`The ${u.name} is stunned and can't act!`); u.tile = this._apply_water_push(u.tile, u); return; }
    if (u.feared) { u.feared = false; this.log(`The ${u.name} cowers in fear and can't act!`); u.tile = this._apply_water_push(u.tile, u); return; }
    const traits = TRAITS[u.name] || {};
    const size = u.size ?? 1;
    const attack_range = u.attack_range ?? 1;
    const ignore_line = !!traits.ignore_line;

    if (traits.heals_allies) {
      const has_other = this.battle_units.some((o) => o.ref !== u.ref);
      if (has_other) {
        if (!this._try_heal_ally(u)) {
          if (!(traits.buffs_allies && this._try_buff_ally(u))) this.log(`The ${u.name} hangs back, waiting for an opening.`);
        }
        u.tile = this._apply_water_push(u.tile, u);
        return;
      }
    }
    if (traits.spawns_fae) {
      u.turns_since_spawn = (u.turns_since_spawn || 0) + 1;
      if (u.turns_since_spawn >= MC.FAE_HUT_SPAWN_INTERVAL) { u.turns_since_spawn = 0; fae_spawns.push(vclone(u.tile)); }
      return;
    }

    let target_tile = assigned.has(u.ref) ? assigned.get(u.ref) : this._pick_enemy_target_tile(u);
    if (this.battle_player_taunting) {
      if (p.talisman_bonus("taunt_confusion") > 0) target_tile = this._pick_confused_target_tile(u);
      else target_tile = this.battle_player_tile;
    }
    if (veq(target_tile, NONE)) {
      this._move_enemy_wander(u);
      u.tile = this._apply_water_push(u.tile, u);
      return;
    }
    const was_cornered = !!traits.kites && this._can_battle_attack(u.tile, target_tile, 1, ignore_line);
    if (was_cornered) {
      const away = this._knockback_dir(target_tile, u.tile);
      const retreat = this._resolve_battle_step(u.tile, away);
      if (retreat.moved) {
        u.tile = retreat.tile;
        if (retreat.fell) {
          const fd = round(u.max_hp * MC.CLIFF_FALL_DAMAGE_PCT);
          u.hp -= fd;
          this.log(`The ${u.name} falls and takes ${fd} damage!`);
          if (u.hp <= 0) return;
        }
        this.log(`The ${u.name} backs away to keep its distance!`);
      }
    }
    if (!was_cornered && traits.strafes && this._can_battle_attack(u.tile, target_tile, attack_range, ignore_line) && !this._can_battle_attack(u.tile, target_tile, 1, ignore_line)) {
      const diff = vsub(target_tile, u.tile);
      let perp = V(0, 0);
      if (diff.x === 0) perp = V(u.strafe_flip ? 1 : -1, 0);
      else if (diff.y === 0) perp = V(0, u.strafe_flip ? 1 : -1);
      if (perp.x !== 0 || perp.y !== 0) {
        const sr = this._resolve_battle_step(u.tile, perp);
        if (sr.moved) { u.tile = sr.tile; this.log(`The ${u.name} strafes to the side!`); u.tile = this._apply_water_push(u.tile, u); return; }
        else u.strafe_flip = !u.strafe_flip;
      }
    }
    let movement_target = target_tile;
    if (traits.corners) {
      const flank = this._flank_target_tile(target_tile);
      if (!veq(u.tile, flank)) movement_target = flank;
    }
    let holds_formation = false;
    if (ignore_line) {
      let pre;
      if (size > 1) pre = this._footprint_dist(this._footprint(u.tile, size), target_tile) <= attack_range;
      else pre = this._can_battle_attack(u.tile, target_tile, attack_range, ignore_line);
      if (!pre) {
        const my_dist = this._footprint_dist(this._footprint(u.tile, size), target_tile);
        for (const o of this.battle_units) {
          if (o.ref === u.ref) continue;
          if ((TRAITS[o.name] || {}).ignore_line) continue;
          const od = this._footprint_dist(this._footprint(o.tile, o.size ?? 1), target_tile);
          if (od < my_dist) { holds_formation = true; break; }
        }
      }
      if (holds_formation) this.log(`The ${u.name} holds position behind its ally!`);
    }
    if (size > 1) { if (!holds_formation) this._move_big_unit(u, movement_target, target_tile); }
    else if (!holds_formation) this._move_enemy_unit(u, attack_range, movement_target, target_tile, ignore_line);
    if (u.hp <= 0) return;

    let can_attack;
    if (size > 1) can_attack = this._footprint_dist(this._footprint(u.tile, size), target_tile) <= attack_range;
    else can_attack = this._can_battle_attack(u.tile, target_tile, attack_range, ignore_line);

    if (can_attack && self_hit_this_turn) {
      u.hp -= u.damage;
      this.log(`The ${u.name}, concussed, strikes itself for ${u.damage} damage!`);
      u.winding_up = false;
    } else if (can_attack) {
      const already = !!u.winding_up;
      const has_windup = !!traits.windup;
      const jab = traits.quick_jab_chance || 0;
      if (has_windup && !already && jab > 0 && rng.randf() < jab) {
        const jr = await this._enemy_apply_damage(u, target_tile, u.damage, traits);
        if (jr.dodged) this.log(`You dodge the ${u.name}'s jab!`, "good");
        else if (jr.blocked) this.log(`Your shield blocks the ${u.name}'s jab!`, "good");
        else if (jr.is_player) { this.log(`The ${u.name} jabs you for ${jr.dmg} damage!`, "bad"); if (p.health <= 0) { this._check_player_dead(); return; } }
        else this.log(`The ${u.name} jabs your ${jr.target_name} for ${jr.dmg} damage!`);
      } else if (has_windup && !already) {
        u.winding_up = true;
        this.log(`The ${u.name} winds up a heavy attack!`);
      } else {
        let dmg = u.damage;
        if (already) dmg = round(dmg * MC.ORC_WINDUP_DAMAGE_MULT);
        u.winding_up = false;
        const pack = traits.pack_bonus_mult || 1.0;
        if (pack > 1.0) {
          if (this.battle_units.some((o) => o.ref !== u.ref && o.name === u.name)) { dmg = round(dmg * pack); this.log(`The ${u.name} fights fiercely alongside its pack!`); }
        }
        if (u.name === "Gnome") {
          const live = this.battle_units.filter((o) => o.name === "Gnome").length;
          if (live > 1) { dmg = round(dmg * (1.0 + MC.GNOME_DAMAGE_PCT_PER_PACKMATE * (live - 1))); this.log(`The Gnome mob swarms with ${live} strong!`); }
        }
        if ((u.buffed_dmg_turns || 0) > 0) { dmg = round(dmg * (1.0 + (u.buffed_dmg_pct || 0))); u.buffed_dmg_turns -= 1; }
        const enrage = traits.enrage_threshold || 0;
        if (enrage > 0 && u.hp < u.max_hp * enrage) { dmg = round(dmg * (traits.enrage_mult ?? 1.0)); this.log(`The ${u.name} is enraged!`, "bad"); }
        const sweep_targets = traits.sweeps ? this._sweep_targets(u) : [target_tile];
        let player_was_hit = false;
        for (const t of sweep_targets) {
          const hr = await this._enemy_apply_damage(u, t, dmg, traits);
          if (hr.dodged) this.log(`You dodge the ${u.name}'s attack!`, "good");
          else if (hr.blocked) this.log(`Your shield blocks the ${u.name}'s attack!`, "good");
          else if (hr.is_player) { player_was_hit = true; this.log(`The ${u.name} hits you for ${hr.dmg} damage.`, "bad"); }
          else this.log(`The ${u.name} hits your ${hr.target_name} for ${hr.dmg} damage!`);
        }
        if (player_was_hit && p.health <= 0) { this._check_player_dead(); return; }
      }
    } else u.winding_up = false;
    if (size === 1) { u.tile = this._apply_water_push(u.tile, u); this._apply_terrain_tick(u.tile, u); }
  },

  // The housekeeping after enemy turns (Main.gd:_finish_enemy_actions): false = the battle ended, stop here.
  _finish_enemy_actions(fae_spawns) {
    const p = this.player;
    // deferred removal of anything that died this enemy turn
    for (let i = this.battle_units.length - 1; i >= 0; i--) {
      if (this.battle_units[i].hp <= 0) {
        this.log(`The ${this.battle_units[i].name} falls!`, "good");
        this._enemy_died(this.battle_units[i]);
        this.battle_units.splice(i, 1);
      }
    }
    if (this.battle_target_index >= this.battle_units.length) this.battle_target_index = 0;

    for (const hut_tile of fae_spawns) {
      const spawn = this._find_empty_tile_near(hut_tile);
      if (veq(spawn, NONE)) { this.log("The Fae Hut has no room to summon a Fae."); continue; }
      const fd = enemyByName("Fae"), ft = TRAITS["Fae"] || {};
      const scale = 1.0 + (p.level - 1) * MC.ENEMY_LEVEL_SCALING;
      void scale;
      this.battle_units.push({
        ref: ++this.ref_counter, tile: spawn, hp: fd.max_health, max_hp: fd.max_health,
        move_range: ft.move_range ?? 2, damage: fd.contact_damage, name: "Fae", winding_up: false, stunned: false, size: 1,
        attack_range: ft.attack_range ?? 1, is_elite: false, concussed_turns: 0, frozen_turns: 0, burning: false,
        vulnerable_turns: 0, aware_of_player: false, armored: false, disarmed_tile: vclone(NONE), xp_reward: fd.xp_reward,
      });
      this.log("The Fae Hut summons a Fae!");
    }

    this._remove_fallen_allies();
    if (this.battle_units.length === 0) { this._battle_victory(); return false; }
    if (!this.in_battle) return false;
    return true;
  },

  async _process_enemy_turn() {
    const fae_spawns = [];
    this._update_enemy_awareness();
    const assigned = this._assign_enemy_targets();
    for (let ui = 0; ui < this.battle_units.length; ui++) {
      const health_before = this.player.health;
      await this._enemy_take_turn(this.battle_units[ui], assigned, fae_spawns);
      if (this.over || (this.player.health <= 0 && health_before > 0)) return;
    }
    if (!this._finish_enemy_actions(fae_spawns)) return;
    await this._begin_hero_turn();
  },

  // The hero lost a turn (reeling): hand play on to whoever is next.
  async _hero_turn_skipped() {
    if (this.battle_use_timeline) await this._timeline_advance();
    else await this._start_ally_turn();
  },

  // The hero's turn comes round (Main.gd:_begin_hero_turn): damage-over-time ticks, per-turn buffs count down, the menu opens.
  async _begin_hero_turn() {
    const p = this.player;
    const rng = this.rng;
    // end-of-round statuses on the player
    if (this.player_poison_turns > 0) {
      this.player_poison_turns -= 1; p.take_battle_damage(this.player_poison_dmg);
      this.log(`You're poisoned for ${this.player_poison_dmg} damage!`, "bad");
      if (p.health <= 0) { this._check_player_dead(); return; }
    }
    if (this.player_bleed_turns > 0) {
      this.player_bleed_turns -= 1;
      const bd = Math.max(1, round(p.max_health * MC.BLEED_DAMAGE_PCT));
      p.take_battle_damage(bd); this.log(`You're bleeding for ${bd} damage!`, "bad");
      if (p.health <= 0) { this._check_player_dead(); return; }
    }
    if (this.player_burning) {
      const bd = Math.max(1, round(p.max_health / MC.BURN_DAMAGE_DIVISOR));
      p.take_battle_damage(bd); this.log(`You burn for ${bd} damage!`, "bad");
      if (p.health <= 0) { this._check_player_dead(); return; }
    }
    if (this.player_concussed_turns > 0) {
      this.player_concussed_turns -= 1;
      if (rng.randf() < MC.PLAYER_CONCUSSION_CHANCE) {
        const cd = p.stat_might; p.take_battle_damage(cd);
        this.log(`You're concussed and stumble, taking ${cd} damage!`, "bad");
        if (p.health <= 0) { this._check_player_dead(); return; }
      }
    }
    if (this.player_blind_turns > 0) this.player_blind_turns -= 1;
    if (p.berserk_turns_remaining > 0) p.berserk_turns_remaining -= 1;
    if (p.stealth_turns_remaining > 0) p.stealth_turns_remaining -= 1;
    if (p.potion_attack_turns > 0) p.potion_attack_turns -= 1;
    if (p.potion_resilience_turns > 0) p.potion_resilience_turns -= 1;
    if (p.potion_energy_turns > 0) p.potion_energy_turns -= 1;
    if (this.battle_bloodrage_turns > 0) {
      this.battle_bloodrage_turns -= 1;
      if (this.battle_bloodrage_turns === 0) this.battle_bloodrage_stacks = 0;
    }

    this.stats.turns += 1;
    if (this.battle_player_turns_to_skip > 0) {
      this.battle_player_turns_to_skip -= 1;
      this.log("You're reeling and can't act this turn!", "bad");
      await this._hero_turn_skipped();
      return;
    }
    this.battle_turn = "player";
    this.battle_menu_state = "main";
    this.battle_move_trail = [];
    this.battle_player_defending = false;
    this.battle_player_taunting = false;
    this.battle_ironclad_move_allowed = !this.battle_ironclad_move_allowed;
    this.battle_feared_unreachable = false;
    this.battle_player_moves_left = this._battle_player_move_range();
    if (p.stamina_regen_per_turn() > 0) p.regen_stamina(p.stamina_regen_per_turn());
    if (p.hp_regen_per_turn() > 0) p.heal(p.hp_regen_per_turn());
    this._check_disarm_reclaimed();
    this._update_enemy_awareness();

    this.battle_feared_by_index = this._find_fear_target();
    if (this.battle_feared_by_index >= 0 && this.battle_fear_cascade_depth < MC.FEAR_CASCADE_LIMIT) {
      this.battle_fear_cascade_depth += 1;
      await this._resolve_feared_turn(this.battle_feared_by_index);
      return;
    }
    this.battle_fear_cascade_depth = 0;
  },

  // ---------------------------------------------------------------- turn order (Main.gd "Turn order")
  // SPEED decides who acts next: the hero, every ally and every enemy are entries on one timeline; taking a turn books
  // the next one TURN_TIME_BASE / speed later. Ties go hero, then allies, then enemies (in field order).
  _hero_speed() {
    const rating = 5 + Math.trunc((this.player.stat_agility - PC.AGILITY_START) / PC.AGILITY_BONUS_PER_LEVEL);
    return Math.max(MC.MIN_BATTLE_SPEED, rating + this.player.armor_speed_bonus());
  },
  _unit_speed(kind, u) {
    if (kind === "hero") return this._hero_speed();
    const base = kind === "ally" ? (u.speed ?? MC.MERCENARY_SPEED) : (MC.ENEMY_SPEEDS[u.name] ?? MC.ENEMY_SPEED_DEFAULT);
    return Math.max(MC.MIN_BATTLE_SPEED, base * (u.speed_mult ?? 1.0));
  },
  _turn_delay(speed) { return MC.TURN_TIME_BASE / Math.max(MC.MIN_BATTLE_SPEED, speed); },
  _timeline_rank(kind) { return kind === "hero" ? 0 : (kind === "ally" ? 1 : 2); },
  _timeline_before(a, b) {
    if (Math.abs(a.time - b.time) > 0.000001) return a.time < b.time;
    const ra = this._timeline_rank(a.kind), rb = this._timeline_rank(b.kind);
    if (ra !== rb) return ra < rb;
    return a.tid < b.tid;
  },
  async timeline_begin() {
    this.battle_use_timeline = true;
    this.battle_timeline = []; this.battle_timeline_clock = 0.0; this.battle_tid_counter = 0;
    this.battle_timeline_running = false; this.battle_timeline_pending = false; this.battle_hero_turns = 0; this.battle_current_actor = null;
    this._timeline_sync();
    await this._timeline_advance();
  },
  _timeline_sync() {
    const present = new Set(this.battle_timeline.map((e) => e.tid));
    if (!present.has(0)) this.battle_timeline.push({ tid: 0, kind: "hero", time: this.battle_timeline_clock + this._turn_delay(this._hero_speed()) });
    for (const [kind, pool] of [["ally", this.battle_allies], ["enemy", this.battle_units]]) {
      for (const u of pool) {
        if (u.tid === undefined) u.tid = ++this.battle_tid_counter;
        if (u.hp > 0 && !present.has(u.tid)) this.battle_timeline.push({ tid: u.tid, kind, time: this.battle_timeline_clock + this._turn_delay(this._unit_speed(kind, u)) });
      }
    }
  },
  _timeline_find(e) {
    if (e.kind === "hero") return { hero: true };
    const pool = e.kind === "ally" ? this.battle_allies : this.battle_units;
    return pool.find((u) => u.tid === e.tid && u.hp > 0) || null;
  },
  _timeline_pop() {
    this._timeline_sync();
    this.battle_timeline = this.battle_timeline.filter((e) => this._timeline_find(e));
    let best = null;
    for (const e of this.battle_timeline) if (!best || this._timeline_before(e, best)) best = e;
    if (!best) return null;
    const unit = this._timeline_find(best);
    this.battle_timeline_clock = best.time;
    best.time += this._turn_delay(this._unit_speed(best.kind, unit));
    return { kind: best.kind, tid: best.tid, unit };
  },
  _timeline_preview(count) {
    this._timeline_sync();
    const sim = [];
    for (const e of this.battle_timeline) { const unit = this._timeline_find(e); if (unit) sim.push({ kind: e.kind, tid: e.tid, time: e.time, unit }); }
    const result = [];
    for (let n = 0; n < count; n++) {
      let best = null;
      for (const s of sim) if (!best || this._timeline_before(s, best)) best = s;
      if (!best) break;
      result.push({ kind: best.kind, unit: best.unit });
      best.time += this._turn_delay(this._unit_speed(best.kind, best.unit));
    }
    return result;
  },
  async _timeline_advance() {
    if (this.battle_timeline_running) { this.battle_timeline_pending = true; return; }
    this.battle_timeline_running = true;
    try {
      while (this.in_battle && !this.over) {
        this.battle_timeline_pending = false;
        const next = this._timeline_pop();
        if (!next) break;
        this.battle_current_actor = next;
        if (next.kind === "hero") {
          this.battle_turn = "player";
          this.battle_hero_turns += 1;
          if (this.battle_hero_turns === 1) this._open_first_hero_turn();
          else await this._begin_hero_turn();
          if (!this.battle_timeline_pending) break;
        } else if (next.kind === "ally") {
          this.battle_turn = "player";
          this._begin_ally_turn(next.unit);
          if (!this.battle_timeline_pending) break;
        } else {
          this.battle_turn = "enemy";
          await this._run_enemy_actor(next.unit);
          if (this.over || this.player.health <= 0) break;
        }
      }
    } finally { this.battle_timeline_running = false; }
  },
  _open_first_hero_turn() {
    this.battle_turn = "player"; this.battle_menu_state = "main"; this.battle_move_trail = [];
    this.battle_player_moves_left = this._battle_player_move_range();
  },
  async _run_enemy_actor(u) {
    u.turns_taken = (u.turns_taken || 0) + 1;
    const fae_spawns = [];
    this._update_enemy_awareness();
    const assigned = this._assign_enemy_targets();
    await this._enemy_take_turn(u, assigned, fae_spawns);
    if (this.over || this.player.health <= 0) return;
    this._finish_enemy_actions(fae_spawns);
  },
  _begin_ally_turn(next) {
    this.battle_commanding_ally = next;
    this.battle_ally_moves_left = Math.trunc(next.move_range);
    next.defending = false;
    this.battle_menu_state = "main"; this.battle_move_trail = [];
  },
  async _ally_command_over() {
    if (!this.battle_use_timeline) { await this._advance_ally_queue(); return; }
    this.battle_commanding_ally = null;
    this._remove_fallen_allies();
    if (this.battle_units.length === 0) { this._battle_victory(); return; }
    await this._timeline_advance();
  },

  _find_fear_target() {
    for (let i = 0; i < this.battle_units.length; i++) {
      const u = this.battle_units[i];
      if (!(TRAITS[u.name] || {}).inflicts_fear) continue;
      if (this._footprint_dist(this._footprint(u.tile, u.size ?? 1), this.battle_player_tile) <= (u.attack_range ?? 1)) return i;
    }
    return -1;
  },
  async _resolve_feared_turn(fear_idx) {
    this.battle_target_index = fear_idx;
    this.log(`Fear grips you -- you can only attack the ${this.battle_units[fear_idx].name}!`, "bad");
    if (this._targetable_indices().includes(fear_idx)) await this._battle_player_fight();
    else { this.battle_feared_unreachable = true; this.log("...but it's out of your reach! Terrified, you can only move or flee.", "bad"); }
  },

  _try_heal_ally(u) {
    let target = null, worst = 0;
    for (const o of this.battle_units) {
      if (o.ref === u.ref) continue;
      const missing = o.max_hp - o.hp;
      if (missing > worst) { worst = missing; target = o; }
    }
    if (!target) return false;
    const heal = Math.max(1, round(target.max_hp * MC.SHAMAN_HEAL_PCT));
    target.hp = Math.min(target.max_hp, target.hp + heal);
    this.log(`The ${u.name} chants, healing the ${target.name} for ${heal} HP!`);
    return true;
  },
  _try_buff_ally(u) {
    let target = null;
    for (const o of this.battle_units) { if (o.ref === u.ref) continue; if ((o.buffed_dmg_turns || 0) <= 0) { target = o; break; } }
    if (!target) return false;
    target.buffed_dmg_turns = MC.DRUID_BUFF_TURNS; target.buffed_dmg_pct = MC.DRUID_BUFF_DMG_PCT;
    this.log(`The ${u.name} empowers the ${target.name}!`);
    return true;
  },

  _move_enemy_unit(u, attack_range, movement_target, attack_check_target, ignore_line = false) {
    let budget = Math.trunc(u.move_range);
    while (budget > 0) {
      if (this._can_battle_attack(u.tile, attack_check_target, attack_range, ignore_line)) break;
      let dx = 0, dy = 0;
      if (movement_target.x !== u.tile.x) dx = sign(movement_target.x - u.tile.x);
      if (movement_target.y !== u.tile.y) dy = sign(movement_target.y - u.tile.y);
      const options = [];
      if (dx !== 0) options.push(V(dx, 0));
      if (dy !== 0) options.push(V(0, dy));
      let stepped = false;
      for (const dir of options) {
        const r = this._resolve_battle_step(u.tile, dir);
        if (r.moved) {
          u.tile = r.tile;
          if ((u.bleed_turns || 0) > 0) u.bleed_turns += 1;
          if (r.fell) {
            const dmg = round(u.max_hp * MC.CLIFF_FALL_DAMAGE_PCT);
            u.hp -= dmg; this.log(`The ${u.name} falls and takes ${dmg} damage!`);
            if (u.hp <= 0) return;
          }
          stepped = true;
          budget -= r.extra_cost ? 2 : 1;
          break;
        }
      }
      if (!stepped) break;
    }
  },
  _move_big_unit(u, movement_target, attack_check_target) {
    const size = u.size ?? 1;
    const attack_range = u.attack_range ?? 1;
    for (let i = 0; i < Math.trunc(u.move_range); i++) {
      if (this._footprint_dist(this._footprint(u.tile, size), attack_check_target) <= attack_range) break;
      let dx = 0, dy = 0;
      if (movement_target.x !== u.tile.x) dx = sign(movement_target.x - u.tile.x);
      if (movement_target.y !== u.tile.y) dy = sign(movement_target.y - u.tile.y);
      const options = [];
      if (dx !== 0) options.push(V(dx, 0));
      if (dy !== 0) options.push(V(0, dy));
      let stepped = false;
      for (const dir of options) {
        const r = this._resolve_big_unit_step(u.tile, size, dir, u.ref);
        if (r.moved) { u.tile = r.tile; if ((u.bleed_turns || 0) > 0) u.bleed_turns += 1; stepped = true; break; }
      }
      if (!stepped) break;
    }
  },
  _move_enemy_wander(u) {
    const dir = WANDER_DIRS[this.rng.randi_n(WANDER_DIRS.length)];
    const budget = Math.min(Math.trunc(u.move_range), MC.WANDER_MOVE_RANGE_CAP);
    const size = u.size ?? 1;
    for (let i = 0; i < budget; i++) {
      if (size > 1) {
        const r = this._resolve_big_unit_step(u.tile, size, dir, u.ref);
        if (!r.moved) break;
        u.tile = r.tile;
      } else {
        const r = this._resolve_battle_step(u.tile, dir);
        if (!r.moved) break;
        u.tile = r.tile;
        if (r.fell) { const dmg = round(u.max_hp * MC.CLIFF_FALL_DAMAGE_PCT); u.hp -= dmg; this.log(`The ${u.name} falls and takes ${dmg} damage!`); if (u.hp <= 0) return; }
      }
    }
  },
  _flank_target_tile(target) {
    const cx = Math.trunc(this.BATTLE_GRID_W / 2), cy = Math.trunc(this.BATTLE_GRID_H / 2);
    const ax = target.x >= cx ? 1 : -1, ay = target.y >= cy ? 1 : -1;
    return V(clamp(target.x + ax, 0, this.BATTLE_GRID_W - 1), clamp(target.y + ay, 0, this.BATTLE_GRID_H - 1));
  },

  // ---------------------------------------------------------------- action gating (what the buttons allow)
  can_act() { return this.in_battle && !this.over && this.battle_turn === "player" && !this.battle_commanding_ally && this.player.awaiting_bonus <= 0 && this.battle_menu_state === "main"; },
  can_command_ally() { return this.in_battle && !this.over && !!this.battle_commanding_ally && this.player.awaiting_bonus <= 0; },
  is_disarmed() { return !veq(this.player.disarmed_tile, NONE); },

  availability() {
    const p = this.player, w = p.current_weapon;
    const a = {};
    const live = this.can_act();
    const feared = this.battle_feared_unreachable;
    a.move = live && this.battle_player_moves_left > 0 && !(p.talisman_bonus("ironclad_ward") > 0 && !this.battle_ironclad_move_allowed);
    a.fight = live && !this.is_disarmed() && !feared;
    const reg = Math.trunc(w.regular_attack_stamina_cost || 0);
    const hv = Math.trunc(w.heavy_stamina_cost_override ?? W.consts.HEAVY_STAMINA_COST);
    a.attack = a.fight && p.stamina >= reg && this._targetable_indices().length > 0;
    a.heavy = a.fight && p.stamina >= hv && this._targetable_indices().length > 0;
    a.specials = (w.specials || []).map((sp) => a.fight && sp.learned !== false && p.stamina >= (w.passive_free_specials ? 0 : sp.stamina_cost) && (sp.effect === "diamonds" ? this.battle_units.length > 0 : this._targetable_indices().length > 0));
    a.mine = a.fight && this._player_has_hand_picks() && this._targetable_rock_tiles().length > 0;
    a.item = live && p.potion_queue.length > 0 && !feared && p.talisman_bonus("disable_healing_items") <= 0;
    a.defend = live;
    a.skill = live && p.has_guardian_skill && this.battle_skill_cooldown <= 0 && !feared;
    a.arrow = live && this._player_has_bow() && !feared;
    a.tactics = live && !feared;
    a.taunt = a.tactics;
    a.stealth = a.tactics && p.stamina >= MC.STEALTH_STAMINA_COST;
    a.flee = live;
    return a;
  },

  // The one entry point for every player command; returns a promise that resolves when
  // control is back with the player (or the battle ended).
  async do_action(kind, arg) {
    if (!this.can_act()) return false;
    const av = this.availability();
    switch (kind) {
      case "attack": if (!av.attack) return false; await this._battle_player_fight(); return true;
      case "heavy": if (!av.heavy) return false; await this._battle_player_heavy_attack(); return true;
      case "special": if (!av.specials[arg]) return false; await this._battle_player_special(arg); return true;
      case "mine": if (!av.mine) return false; await this._resolve_mine_rock(); return true;
      case "item": if (!av.item) return false; await this._battle_player_item(arg || null); return true;
      case "defend": await this._battle_player_defend(); return true;
      case "skill": if (!av.skill) return false; await this._battle_player_skill(); return true;
      case "arrow": if ((this.player.owned_arrows[arg] || 0) <= 0 || !av.arrow) return false; await this._battle_player_arrow(arg); return true;
      case "taunt": if (!av.taunt) return false; await this._battle_player_taunt(); return true;
      case "stealth": if (!av.stealth) return false; await this._battle_player_stealth(); return true;
      case "flee": this._battle_flee(); return true;
    }
    return false;
  },
});
