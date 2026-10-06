/* Battle engine, part B -- targeting, hit resolution, the player's actions, ally turns.
 * Port of scripts/Main.gd (_apply_single_hit .. _end_player_turn, ally commands).
 */
"use strict";

Object.assign(Sim.prototype, {

  // ---------------------------------------------------------------- targeting
  _targetable_indices() {
    const w = this.player.current_weapon;
    if (w.passive_unlimited_range) return this.battle_units.map((_, i) => i);
    let max_range = this._player_long_range_equipped() ? 2 : 1;
    max_range += Math.trunc(w.passive_extra_range || 0);
    const ignore_line = this._player_has_spear();
    const ignore_ledge = this.player.talisman_bonus("ignore_ledge_attack") > 0;
    const result = [];
    this.battle_units.forEach((u, i) => {
      const size = u.size ?? 1;
      let in_range;
      if (size > 1) in_range = this._footprint_dist(this._footprint(u.tile, size), this.battle_player_tile) <= max_range;
      else in_range = this._can_battle_attack(this.battle_player_tile, u.tile, max_range, ignore_line, ignore_ledge);
      if (in_range) result.push(i);
    });
    return result;
  },
  _effective_target_index() {
    const t = this._targetable_indices();
    if (t.length === 0) return -1;
    if (t.includes(this.battle_target_index)) return this.battle_target_index;
    return t[0];
  },
  select_target(idx) {
    if (this.battle_turn !== "player" || idx < 0 || idx >= this.battle_units.length) return;
    this.battle_target_index = idx;
  },

  _knockback_dir(from, to) { const d = vsub(to, from); return V(sign(d.x), sign(d.y)); },

  _apply_knockback(u, dir, bypass_resist = false, extra_distance = false) {
    if (!bypass_resist) {
      const resist = (TRAITS[u.name] || {}).knockback_resist || 0;
      if (resist > 0 && this.rng.randf() < resist) { this.log(`The ${u.name} holds its ground!`); return; }
    }
    const size = u.size ?? 1;
    const steps = extra_distance ? 2 : 1;
    if (size > 1) {
      for (let i = 0; i < steps; i++) {
        const r = this._resolve_big_unit_step(u.tile, size, dir, u.ref);
        if (!r.moved) return;
        u.tile = r.tile;
        this.log(`The ${u.name} is knocked back!`);
      }
      return;
    }
    for (let i = 0; i < steps; i++) {
      const r = this._resolve_battle_step(u.tile, dir);
      if (!r.moved) {
        const blocking = this.terrainAt(vadd(u.tile, dir));
        if (blocking && blocking.type === "rock") { u.stunned = true; this.log(`The ${u.name} is slammed into the rock, stunned!`); }
        else if (blocking && blocking.type === "rubble") {
          if (this.rng.randf() < MC.RUBBLE_CRUMBLE_CHANCE) { delete this.battle_terrain[vkey(vadd(u.tile, dir))]; this.log("The rubble crumbles away from the impact!"); }
          else { u.stunned = true; this.log(`The ${u.name} is slammed into the rubble, stunned!`); }
        }
        return;
      }
      u.tile = r.tile;
      this.log(`The ${u.name} is knocked back!`);
      if (r.fell) {
        const dmg = round(u.max_hp * MC.CLIFF_FALL_DAMAGE_PCT);
        u.hp -= dmg;
        this.log(`The ${u.name} tumbles off the edge and takes ${dmg} damage!`);
        return;
      }
    }
  },

  // ---------------------------------------------------------------- enemy death (Main._on_enemy_died)
  _enemy_died(u) {
    const p = this.player;
    this.stats.kills++;
    this.stats.xp_gained += u.xp_reward || 0;
    const lvl_before = p.level;
    p.gain_xp(u.xp_reward || 0);
    if (p.level > lvl_before) this.log(`Level up! You reach level ${p.level}.`, "good");
    if (p.meta_momentum_pct_per_kill > 0) this.battle_momentum_stacks += 1;
    if (this.in_battle) { p.berserk_turns_remaining = MC.BERSERK_TURNS; this.log(`Killing the ${u.name} sends you into a berserk rage!`, "good"); }
    if (p.windfall_chance_total() > 0 && this.rng.randf() < p.windfall_chance_total()) {
      const amt = this.rng.randi_range(5, 15); p.add_coins(amt); this.log(`Windfall! +${amt} gold.`);
    }
    if (p.coins_per_kill() > 0) p.add_coins(p.coins_per_kill());
    if (p.talisman_bonus("heal_on_kill") > 0) p.heal(Math.trunc(p.talisman_bonus("heal_on_kill")));
  },

  // ---------------------------------------------------------------- the damage pipeline
  _apply_single_hit(idx, dmg_mult, effect, weapon, attacker_label = "You", attacker_tile = null, flat_dmg = -1, is_multihit = false, attack_stat = -1.0) {
    attacker_tile = attacker_tile || vclone(NONE);
    if (idx < 0 || idx >= this.battle_units.length) return;
    const p = this.player;
    const rng = this.rng;
    const u = this.battle_units[idx];
    const dodge_chance = (TRAITS[u.name] || {}).dodge_chance || 0;
    if (dodge_chance > 0 && rng.randf() < dodge_chance) { this.log(`The ${u.name} dodges out of the way!`); return; }
    const you = attacker_label === "You";
    if (effect !== "thorns") {
      const miss = you ? p.miss_chance_for(weapon) : p.ally_miss_chance();
      if (miss > 0 && rng.randf() < miss) { this.log(`${you ? "You" : attacker_label} missed the ${u.name}!`); return; }
    }
    let blind_forced_crit = false;
    if (you && this.player_blind_turns > 0) {
      if (rng.randf() < MC.BLINDNESS_MISS_CHANCE) { this.log(`Blinded, you swing wildly and miss the ${u.name}!`); return; }
      blind_forced_crit = true;
    }
    let stealth_forced_crit = false, was_unaware = false;
    if (you) {
      was_unaware = !this._enemy_currently_sees_player(u);
      if (p.stealth_turns_remaining > 0) { stealth_forced_crit = true; p.stealth_turns_remaining = 0; }
    }
    const bleeding_cut_forced_crit = effect === "bleed_or_crit" && rng.randf() < 0.5;
    const base_attack = attack_stat >= 0 ? attack_stat : p.attack_damage;
    let dmg = round(base_attack * (weapon.damage_mult ?? 1.0) * dmg_mult);
    if (attack_stat >= 0) dmg = Math.max(1, dmg);
    if (flat_dmg >= 0) dmg = flat_dmg;
    else if (you) dmg += round(p.coin_scaled_attack_bonus());
    if (p.pichaku_active && effect === "") dmg = round(dmg * MC.PICHAKU_DAMAGE_MULT);
    if (you && p.shield_damage_penalty_pct() > 0) dmg = round(dmg * (1.0 - p.shield_damage_penalty_pct()));
    if (p.temp_damage_bonus_pct !== 0) dmg = round(dmg * (1.0 + p.temp_damage_bonus_pct));
    if (p.talisman_bonus("damage_pct") !== 0) dmg = round(dmg * (1.0 + p.talisman_bonus("damage_pct")));
    if (p.low_hp_damage_bonus_total() > 0 && p.health < p.max_health * p.low_hp_threshold()) dmg = round(dmg * (1.0 + p.low_hp_damage_bonus_total()));
    if (!this.battle_first_attack_used) {
      const fb = p.talisman_bonus("first_attack_damage_pct");
      if (fb > 0) dmg = round(dmg * (1.0 + fb));
      this.battle_first_attack_used = true;
    }
    if (p.meta_momentum_pct_per_kill > 0 && this.battle_momentum_stacks > 0) dmg = round(dmg * (1.0 + p.meta_momentum_pct_per_kill * this.battle_momentum_stacks));
    if (you && p.talisman_bonus("momentum_chain") > 0 && this.battle_momentum_chain_stacks > 0) dmg = round(dmg * (1.0 + MC.MOMENTUM_CHAIN_PCT_PER_STACK * this.battle_momentum_chain_stacks));
    if (you && p.bloodmoon_stacks > 0) dmg = round(dmg * (1.0 + PC.BLOODMOON_DAMAGE_PCT_PER_STACK * p.bloodmoon_stacks));
    if (you && p.bloodmoon_debuffed) dmg = round(dmg * 0.5);
    if (you && p.talisman_bonus("chaos_shard") > 0) dmg = round(dmg * rng.randf_range(MC.CHAOS_SHARD_MIN_MULT, MC.CHAOS_SHARD_MAX_MULT));
    if (you && p.berserk_turns_remaining > 0) dmg = round(dmg * (1.0 + MC.BERSERK_DAMAGE_BONUS_PCT + p.meta_rage_bonus_pct));
    if (p.shield_vengeance_active && effect === "" && you) {
      dmg = round(dmg * (1.0 + p.shield_special_pct()));
      p.shield_vengeance_active = false;
      this.log("Your shield's vengeance empowers the blow!");
    }
    let execute_bonus = weapon.passive_execute_bonus || 0;
    if (effect === "execute") execute_bonus = Math.max(execute_bonus, 0.5);
    if (execute_bonus > 0 && u.hp < u.max_hp * 0.3) dmg = round(dmg * (1.0 + execute_bonus));
    if (effect === "full_hp_bonus" && u.hp >= u.max_hp) dmg = round(dmg * 1.5);
    if (effect === "maracas" && u.armored) dmg = round(dmg * MC.MARACAS_ARMORED_MULT);
    const armor_pierce_pct = weapon.passive_armor_pierce_pct || 0;
    if (armor_pierce_pct > 0 && u.armored) dmg = round(dmg * (1.0 + armor_pierce_pct));
    const undead_boss_bonus = weapon.passive_undead_boss_bonus || 0;
    if (undead_boss_bonus > 0) {
      const ut = TRAITS[u.name] || {};
      if (ut.is_undead || ut.is_boss_tier) dmg = round(dmg * (1.0 + undead_boss_bonus));
    }
    let is_crit = blind_forced_crit || stealth_forced_crit || bleeding_cut_forced_crit;
    if (you && !is_crit && p.crit_chance_total() > 0 && rng.randf() < p.crit_chance_total()) is_crit = true;
    if (is_crit) dmg = round(dmg * p.crit_damage_mult());
    if (you && p.potion_attack_turns > 0) dmg = round(dmg * (1.0 + MC.ATTACK_POTION_DAMAGE_BONUS_PCT));
    const distance_pct = weapon.passive_damage_per_tile_distance || 0;
    if (you && distance_pct !== 0) {
      const origin = attacker_tile.x >= 0 ? attacker_tile : this.battle_player_tile;
      const distance = abs(u.tile.x - origin.x) + abs(u.tile.y - origin.y);
      dmg = Math.max(1, round(dmg * (1.0 + distance_pct * distance)));
    }
    const ignores_cover = is_crit || ["ignore_cover", "leg_blow", "piercing_thrust"].includes(effect) || !!weapon.passive_ignore_cover;
    if (!ignores_cover && this._has_adjacent_rock(u.tile)) dmg = round(dmg * (1.0 - MC.ROCK_COVER_REDUCTION));
    if ((u.frozen_turns || 0) > 0) dmg = round(dmg * 1.2);
    if (you && this.player_burning) dmg = round(dmg * (1.0 - MC.BURN_DAMAGE_DEALT_REDUCTION));
    if ((u.vulnerable_turns || 0) > 0) dmg = round(dmg * (1.0 + MC.VULNERABLE_DAMAGE_TAKEN_BONUS_PCT));
    if (is_crit && you && was_unaware && this._player_has_dagger()) dmg += MC.KNIFE_STEALTH_CRIT_BONUS;
    if (is_crit) u.vulnerable_turns = MC.VULNERABLE_TURNS;
    let splinter_triggered = false;
    if (you && (weapon.material_id || "") === "obsidian" && (u.bleed_turns || 0) <= 0) {
      let chance = MC.OBSIDIAN_SPLINTER_CHANCE;
      if (p.talisman_bonus("material_passive_boost") > 0) chance *= MC.STONE_AMULET_MATERIAL_BOOST_MULT;
      chance = this._proc(chance);
      if (rng.randf() < chance) { u.bleed_turns = MC.BLEED_BASE_TURNS; splinter_triggered = true; }
    }
    const is_boss_target = !!(TRAITS[u.name] || {}).is_boss_tier;
    if (you && p.talisman_bonus("oneshot_regular_enemies") > 0 && !is_boss_target) dmg = u.hp;
    let executioner_triggered = false;
    const oneshot_chance = weapon.passive_oneshot_chance || 0;
    if (effect === "" && oneshot_chance > 0 && !is_boss_target && rng.randf() < this._proc(oneshot_chance)) { dmg = u.hp; executioner_triggered = true; }
    // damage dealt can't exceed what the target has left (lifesteal / recoil scale off what the blow actually took)
    if (u.hp > 0) dmg = Math.min(dmg, u.hp);
    u.aware_of_player = true;
    u.hp -= dmg;
    this.stats.damage_dealt += Math.max(0, dmg);
    this.battle_had_combat_action_this_cycle = true;
    if (you) {
      const ls = p.talisman_bonus("lifesteal_pct");
      if (ls > 0 && dmg > 0) p.heal(Math.max(1, round(dmg * ls)));
      if (p.talisman_bonus("momentum_chain") > 0) this.battle_momentum_chain_stacks += 1;
      if (p.talisman_bonus("bloodmoon_fang") > 0 && p.bloodmoon_stacks < PC.BLOODMOON_MAX_STACKS && !p.bloodmoon_debuffed) { p.bloodmoon_stacks += 1; p._recalc_stats(); }
    }
    if (is_crit) this.log("Critical hit!", "good");
    if (splinter_triggered) this.log("Your obsidian blade splinters into the wound -- it's bleeding!");
    if (executioner_triggered) this.log("The axe finds the killing stroke!");
    this.log(`${attacker_label} hit the ${u.name} for ${dmg} damage.`, you ? "hit" : "ally");

    // weapon break
    const break_chance = weapon.break_chance || 0;
    if (break_chance > 0 && (p.current_weapon.id || "") === (weapon.id || "") && rng.randf() < break_chance) {
      const broken_id = weapon.id;
      this.log(`Your ${weapon.name || "weapon"} shatters! You're back to bare fists.`, "bad");
      delete p.weapon_upgrade_levels[broken_id];
      delete p.weapon_enchantments[broken_id];
      p._equip_weapon(clone(W.club));
    }
    if (effect === "lifesteal") { const h = Math.max(1, round(dmg * MC.LIFESTEAL_PCT)); p.heal(h); this.log(`You drain ${h} HP from the wound.`); }
    if (effect === "leg_blow" && u.hp > 0) { u.move_range = Math.max(1, Math.trunc(u.move_range) - 1); this.log(`The ${u.name} is hobbled, slowing it down!`); }
    if (effect === "low_sweep" && u.hp > 0 && rng.randf() < this._proc(MC.LOW_SWEEP_CHANCE)) { u.move_range = Math.max(1, Math.trunc(u.move_range / 2)); this.log(`The ${u.name} is swept off its feet, slowed dramatically!`); }
    if (effect === "crushing_collision" && u.hp > 0 && u.armored) { u.armored = false; this.log(`The ${u.name}'s armor is shattered!`); }
    if (effect === "bonk" && u.hp > 0) { u.concussed_turns = MC.BONK_CONCUSSED_TURNS; this.log(`The ${u.name} is left dazed and concussed!`); }
    if (effect === "wrist_strike" && u.hp > 0) { u.disarmed_tile = this._pick_disarm_tile(); this.log(`The ${u.name}'s weapon is knocked loose!`); }
    if (effect === "arrow_flame" && u.hp > 0) { u.burning = true; this.log(`The ${u.name} catches fire!`); }
    // Ember Charm (talisman)
    if (you && u.hp > 0 && !u.burning) {
      let burn_chance = is_multihit ? p.talisman_bonus("burn_chance_multihit") : p.talisman_bonus("burn_chance");
      burn_chance = this._proc(burn_chance);
      if (burn_chance > 0 && rng.randf() < burn_chance) { this._ignite_with_ember(u); this.log(`The ${u.name} catches fire!`); }
    }
    if (you && u.hp > 0 && (weapon.material_id || "") === "bone") {
      let dread = MC.BONE_DREAD_CHANCE;
      if (p.talisman_bonus("material_passive_boost") > 0) dread *= MC.STONE_AMULET_MATERIAL_BOOST_MULT;
      dread = this._proc(dread);
      if (dread > 0 && rng.randf() < dread) { u.feared = true; this.log(`The ${u.name} cowers in dread!`); }
    }
    if (you && (weapon.material_id || "") === "silver") {
      let cleanse = MC.SILVER_CLEANSE_CHANCE;
      if (p.talisman_bonus("material_passive_boost") > 0) cleanse *= MC.STONE_AMULET_MATERIAL_BOOST_MULT;
      cleanse = this._proc(cleanse);
      if (rng.randf() < cleanse) this._try_cleanse_one_player_status();
    }
    if (you && !is_boss_target) {
      const cdc = p.talisman_bonus("coin_drop_chance");
      if (cdc > 0 && rng.randf() < this._proc(cdc)) { p.add_coins(1); this.log("A coin drops from the blow!"); }
    }
    if (effect === "arrow_freeze" && u.hp > 0) { u.frozen_turns = rng.randi_range(MC.ARROW_FREEZE_MIN_TURNS, MC.ARROW_FREEZE_MAX_TURNS); this.log(`The ${u.name} freezes solid!`); }
    if (effect === "bleed_or_crit" && u.hp > 0 && (u.bleed_turns || 0) <= 0 && rng.randf() < this._proc(0.5)) { u.bleed_turns = MC.BLEED_BASE_TURNS; this.log(`The cut leaves the ${u.name} bleeding!`); }
    if (effect === "clotheslined" && u.hp > 0) {
      const behind_dir = this._knockback_dir(this.battle_player_tile, u.tile);
      const behind_tile = vsub(this.battle_player_tile, behind_dir);
      if (this._in_battle_bounds(behind_tile) && !this._battle_tile_occupied(behind_tile, u.ref)) { u.tile = behind_tile; this.log(`The ${u.name} is hurled behind you!`); }
    }
    const passive_ls = weapon.passive_lifesteal_pct || 0;
    if (passive_ls > 0 && dmg > 0) { const h = Math.max(1, round(dmg * passive_ls)); p.heal(h); this.log(`Your weapon drains ${h} HP from the wound.`); }
    const heal_chance = weapon.passive_heal_chance || 0;
    if (heal_chance > 0 && rng.randf() < this._proc(heal_chance)) { const hf = Math.trunc(weapon.passive_heal_flat || 0); p.heal(hf); this.log(`Your spear drinks deep -- you feel ${hf} HP return.`); }
    const self_damage_pct = weapon.passive_self_damage_pct || 0;
    if (self_damage_pct > 0 && dmg > 0 && you) {
      const recoil = Math.max(1, round(dmg * self_damage_pct));
      p.take_battle_damage(recoil);
      this.log(`The recoil sears you for ${recoil} damage.`, "bad");
      this._check_player_dead();
    }
    const stun_chance = weapon.passive_stun_chance || 0;
    if (stun_chance > 0 && u.hp > 0 && rng.randf() < this._proc(stun_chance)) { u.stunned = true; this.log(`The ${u.name} is stunned!`); }
    if (u.hp > 0) {
      const dir = this._knockback_dir(this.battle_player_tile, u.tile);
      if (effect === "guaranteed_knockback" || weapon.passive_guaranteed_knockback) this._apply_knockback(u, dir, true, true);
      else if (effect !== "whirlwind_strike" && effect !== "clotheslined" && !effect.startsWith("arrow_")) this._apply_knockback(u, dir);
      if (effect === "stun_bypass" && u.hp > 0) { u.stunned = true; this.log(`The ${u.name} is stunned!`); }
    }
    if (u.hp <= 0) {
      this.log(`The ${u.name} falls!`, "good");
      if (you && (weapon.material_id || "") === "gold") {
        let bonus = MC.GOLD_KILL_COIN_BONUS;
        if (p.talisman_bonus("material_passive_boost") > 0) bonus = round(bonus * MC.STONE_AMULET_MATERIAL_BOOST_MULT);
        p.add_coins(bonus);
        this.log("Your golden blade leaves a coin behind!");
      }
      if (p.talisman_bonus("wildfire_core") > 0 && u.burning) this._trigger_wildfire_explosion(u.tile, this._burn_tick_damage(u));
      this._enemy_died(u);
      const at = this.battle_units.indexOf(u);
      if (at >= 0) this.battle_units.splice(at, 1);
      if (this.battle_target_index >= this.battle_units.length) this.battle_target_index = 0;
    }
  },

  _check_player_dead() {
    if (this.player.died && !this.over) { this.over = true; this.in_battle = false; this.result = "defeat"; this.log("You have fallen.", "bad"); }
  },

  _try_cleanse_one_player_status() {
    const p = this.player;
    const active = [];
    if (this.player_poison_turns > 0) active.push("poison");
    if (this.player_burning) active.push("burning");
    if (this.player_concussed_turns > 0) active.push("concussed");
    if (this.player_blind_turns > 0) active.push("blind");
    if (!veq(p.disarmed_tile, NONE)) active.push("disarmed");
    if (active.length === 0) return;
    switch (active[this.rng.randi_n(active.length)]) {
      case "poison": this.player_poison_turns = 0; break;
      case "burning": this.player_burning = false; break;
      case "concussed": this.player_concussed_turns = 0; break;
      case "blind": this.player_blind_turns = 0; break;
      case "disarmed": p.disarmed_tile = vclone(NONE); break;
    }
    this.log("Your silver blade's purity washes an affliction away!");
  },

  // ---------------------------------------------------------------- fire / Lucky Clover helpers
  _burn_tick_damage(u) {
    const ev = u.burn_value || 0;
    if (ev > 0) return Math.max(1, Math.ceil(ev));
    return Math.max(1, round(u.max_hp / MC.BURN_DAMAGE_DIVISOR));
  },
  _decay_ember_burn(u) {
    if ((u.burn_value || 0) <= 0) return;
    u.burn_value *= MC.EMBER_BURN_DECAY;
    if (u.burn_value < 1.0) { u.burn_value = 0.0; u.burning = false; }
  },
  _ignite_with_ember(u) {
    u.burning = true;
    if (this.player.talisman_bonus("ember_burn") > 0) u.burn_value = MC.EMBER_BURN_BASE + this.player.attack_damage / MC.EMBER_BURN_ATTACK_DIV;
  },
  _proc(chance) { return Math.min(1.0, chance * this.player.secondary_chance_mult()); },

  _in_blast_radius(tile, center, radius) { return abs(tile.x - center.x) <= radius && abs(tile.y - center.y) <= radius; },

  _trigger_wildfire_explosion(center, fire_tick_dmg) {
    const p = this.player;
    const blast = Math.max(1, fire_tick_dmg * MC.WILDFIRE_EXPLOSION_FIRE_MULT);
    this.log("The blaze erupts outward!", "bad");
    if (this._in_blast_radius(this.battle_player_tile, center, MC.WILDFIRE_EXPLOSION_RADIUS)) {
      p.take_battle_damage(blast); this.player_burning = true;
      this.log(`You're caught in the blast for ${blast} damage and catch fire!`, "bad");
      this._check_player_dead();
    }
    for (const a of this.battle_allies) {
      if (a.hp > 0 && this._in_blast_radius(a.tile, center, MC.WILDFIRE_EXPLOSION_RADIUS)) { a.hp -= blast; this.log(`Your ${a.name} is caught in the blast!`); }
    }
    for (let i = this.battle_units.length - 1; i >= 0; i--) {
      const other = this.battle_units[i];
      if (veq(other.tile, center) || !this._in_blast_radius(other.tile, center, MC.WILDFIRE_EXPLOSION_RADIUS)) continue;
      other.hp -= blast; other.burning = true;
      this.log(`The ${other.name} is caught in the blast and catches fire!`);
      if (other.hp <= 0) {
        this.log(`The ${other.name} falls!`, "good");
        this._enemy_died(other);
        this.battle_units.splice(i, 1);
        if (this.battle_target_index >= this.battle_units.length) this.battle_target_index = 0;
      }
    }
  },

  // ---------------------------------------------------------------- the player's attack action
  async _battle_perform_attack(action) {
    const p = this.player;
    const rng = this.rng;
    const cost = action.stamina_cost || 0;
    if (cost > 0 && !p.spend_stamina(cost)) { this.log(`Not enough stamina for ${action.name}!`); return; }
    this.stats.stamina_spent += cost;
    const effect = action.effect || "";
    const targetable = this._targetable_indices();
    const no_target = effect === "diamonds" ? this.battle_units.length === 0 : targetable.length === 0;
    if (no_target) { this.log("No enemy in range."); if (cost > 0) p.regen_stamina(cost); this.stats.stamina_spent -= cost; return; }
    this.stat_action(action.name || "attack");
    const weapon = p.current_weapon;
    const dmg_mult = action.dmg_mult ?? 1.0;

    if (effect === "target_practice") this._resolve_target_practice();
    else if (effect === "wide_cleave") { if (!this._resolve_wide_cleave(weapon, dmg_mult) && cost > 0) { p.regen_stamina(cost); this.stats.stamina_spent -= cost; } }
    else if (effect === "execution") this._resolve_execution();
    else if (effect === "pichaku") { p.pichaku_active = true; this.log("You get in the zone -- lighter, faster strikes for the rest of the fight!"); }
    else if (effect === "diamonds") this._resolve_diamonds(weapon, dmg_mult);
    else if (effect === "ol_one_two") {
      const primary_idx = this._effective_target_index();
      const others = targetable.filter((i) => i !== primary_idx);
      if (others.length === 0) {
        this._apply_single_hit(primary_idx, dmg_mult, effect, weapon, "You", null, -1, true);
        if (primary_idx < this.battle_units.length) this._apply_single_hit(primary_idx, dmg_mult, effect, weapon, "You", null, -1, true);
      } else {
        const split_mult = action.split_dmg_mult ?? dmg_mult;
        others.sort((a, b) => a - b);
        const secondary_ref = this.battle_units[others[0]].ref;
        this._apply_single_hit(primary_idx, split_mult, effect, weapon, "You", null, -1, true);
        let secondary_idx = -1;
        for (let j = 0; j < this.battle_units.length; j++) if (this.battle_units[j].ref === secondary_ref) { secondary_idx = j; break; }
        if (secondary_idx >= 0) this._apply_single_hit(secondary_idx, split_mult, effect, weapon, "You", null, -1, true);
      }
    } else if (effect === "cleave_all") {
      const targets = targetable.slice().sort((a, b) => a - b).reverse();
      for (const idx of targets) this._apply_single_hit(idx, dmg_mult, effect, weapon, "You", null, -1, true);
    } else if (action.pass_count_min !== undefined) {
      const passes = rng.randi_range(action.pass_count_min, action.pass_count_max);
      for (let pass = 0; pass < passes; pass++) {
        const pts = this._targetable_indices().sort((a, b) => a - b).reverse();
        for (const idx of pts) this._apply_single_hit(idx, dmg_mult, effect, weapon, "You", null, -1, true);
      }
    } else if (action.hit_count_min !== undefined) {
      const idx = this._effective_target_index();
      let primary_ref = null;
      if (idx < this.battle_units.length) primary_ref = this.battle_units[idx].ref;
      const still = () => idx < this.battle_units.length && this.battle_units[idx].ref === primary_ref;
      let hit_count = rng.randi_range(action.hit_count_min, action.hit_count_max);
      if (action.luck_scales_hits) hit_count += Math.trunc(Math.floor(p.total_luck() * 10));
      for (let i = 0; i < hit_count; i++) {
        if (!still()) break;
        this._apply_single_hit(idx, dmg_mult, effect, weapon, "You", null, -1, true);
      }
    } else {
      const idx = this._effective_target_index();
      let primary_ref = null, primary_tile = V(-999, -999);
      if (idx < this.battle_units.length) { primary_ref = this.battle_units[idx].ref; primary_tile = vclone(this.battle_units[idx].tile); }
      const still = () => idx < this.battle_units.length && this.battle_units[idx].ref === primary_ref;
      const whirlwind_melee = !!action.is_regular_attack && p.talisman_bonus("whirlwind_double_melee") > 0 && !weapon.long_range;
      let double_hit_chance = weapon.passive_double_hit_chance || 0;
      if ((weapon.material_id || "") === "wood") {
        let wood = MC.WOOD_DOUBLE_HIT_CHANCE;
        if (p.talisman_bonus("material_passive_boost") > 0) wood *= MC.STONE_AMULET_MATERIAL_BOOST_MULT;
        double_hit_chance += wood;
      }
      double_hit_chance = this._proc(double_hit_chance);
      const multihit_capable = effect === "double_hit" || effect === "piercing_thrust"
        || (!!action.is_regular_attack && !!weapon.double_strike) || double_hit_chance > 0
        || (effect === "" && p.pichaku_active) || (weapon.passive_cleave_pct || 0) > 0 || whirlwind_melee;
      this._apply_single_hit(idx, dmg_mult, effect, weapon, "You", null, -1, multihit_capable);
      if (effect === "knife_throw" && !still()) {
        p.disarmed_tile = this._pick_disarm_tile();
        this.log("The killing throw leaves you weaponless -- it lands on a random tile!");
      }
      if (effect === "double_hit" && still()) this._apply_single_hit(idx, dmg_mult, effect, weapon, "You", null, -1, multihit_capable);
      if (action.is_regular_attack && still()) {
        if (weapon.double_strike || whirlwind_melee) this._apply_single_hit(idx, dmg_mult, effect, weapon, "You", null, -1, multihit_capable);
      }
      if (still()) { if (double_hit_chance > 0 && rng.randf() < double_hit_chance) this._apply_single_hit(idx, dmg_mult, effect, weapon, "You", null, -1, multihit_capable); }
      if (effect === "" && p.pichaku_active && still()) {
        if (rng.randf() < this._proc(MC.PICHAKU_DOUBLE_HIT_CHANCE)) this._apply_single_hit(idx, dmg_mult, effect, weapon, "You", null, -1, multihit_capable);
      }
      const cleave_pct = weapon.passive_cleave_pct || 0;
      if (cleave_pct > 0) {
        const splash = this._targetable_indices().sort((a, b) => a - b).reverse();
        for (const si of splash) if (si < this.battle_units.length && this.battle_units[si].ref !== primary_ref) this._apply_single_hit(si, dmg_mult * cleave_pct, effect, weapon, "You", null, -1, multihit_capable);
      }
      if (effect === "piercing_thrust" && primary_tile.x !== -999) {
        const pierce_dir = this._knockback_dir(this.battle_player_tile, primary_tile);
        const pierce_tile = vadd(primary_tile, pierce_dir);
        for (let j = 0; j < this.battle_units.length; j++) if (veq(this.battle_units[j].tile, pierce_tile)) { this._apply_single_hit(j, dmg_mult, effect, weapon, "You", null, -1, multihit_capable); break; }
      }
    }
    if (this.over) return;
    if (effect === "self_heal") { const h = round(p.max_health * MC.SELF_HEAL_PCT); p.heal(h); this.log(`You feel invigorated! Healed ${h} HP.`, "good"); }
    if (effect === "devastating_slash") { this.battle_player_turns_to_skip += 1; this.log("The devastating blow leaves you reeling!"); }
    if (action.is_regular_attack) p.regen_stamina(MC.STAMINA_REGEN_ON_ATTACK);
    if (this.battle_units.length === 0) { this._battle_victory(); return; }
    await this._end_player_turn();
  },

  _resolve_target_practice() {
    const idx = this._effective_target_index();
    const u = this.battle_units[idx];
    const is_boss = !!(TRAITS[u.name] || {}).is_boss_tier;
    const chance = is_boss ? MC.TARGET_PRACTICE_BOSS_CHANCE : MC.TARGET_PRACTICE_CHANCE;
    if (this.rng.randf() < chance) {
      this.log(`Target Practice finds its mark -- the ${u.name} drops instantly!`, "good");
      this._enemy_died(u);
      this.battle_units.splice(idx, 1);
      if (this.battle_target_index >= this.battle_units.length) this.battle_target_index = 0;
    } else {
      this.player.disarmed_tile = this._pick_disarm_tile();
      this.log("Target Practice misses -- your spear flies out of reach!");
    }
  },
  _resolve_execution() {
    const idx = this._effective_target_index();
    const u = this.battle_units[idx];
    if (!u.armored) {
      this.log(`Execution finds no armor to stop it -- the ${u.name} falls!`, "good");
      this._enemy_died(u);
      this.battle_units.splice(idx, 1);
      if (this.battle_target_index >= this.battle_units.length) this.battle_target_index = 0;
    } else this.log(`The ${u.name}'s armor deflects the killing blow!`);
  },
  _resolve_diamonds(weapon, dmg_mult) {
    const idx = this.battle_target_index < this.battle_units.length ? this.battle_target_index : 0;
    const target_tile = vclone(this.battle_units[idx].tile);
    if (this.rng.randf() < MC.DIAMONDS_MISS_CHANCE) {
      const self_dmg = Math.max(1, round(this.player.max_health * MC.DIAMONDS_MISS_SELF_DAMAGE_PCT));
      this.player.take_battle_damage(self_dmg);
      this.log(`You misjudge the jump and crash down hard, taking ${self_dmg} damage!`, "bad");
      this._check_player_dead();
      return;
    }
    this._apply_single_hit(idx, dmg_mult, "diamonds", weapon);
    this.battle_player_tile = target_tile;
  },
  _unit_index_at_tile(t) { for (let i = 0; i < this.battle_units.length; i++) if (veq(this.battle_units[i].tile, t)) return i; return -1; },
  _resolve_wide_cleave(weapon, dmg_mult) {
    const target_idx = this._effective_target_index();
    const dir = this._knockback_dir(this.battle_player_tile, this.battle_units[target_idx].tile);
    const line = [vadd(this.battle_player_tile, dir), vadd(this.battle_player_tile, vmul(dir, 2)), vadd(this.battle_player_tile, vmul(dir, 3))];
    for (const t of line) if (this._has_adjacent_rock(t)) { this.log("Cover blocks your Wide Cleave!"); return false; }
    for (const t of line) { const idx = this._unit_index_at_tile(t); if (idx >= 0) this._apply_single_hit(idx, dmg_mult, "wide_cleave", weapon); }
    return true;
  },

  async _battle_player_fight() {
    const cost = Math.trunc(this.player.current_weapon.regular_attack_stamina_cost || 0);
    await this._battle_perform_attack({ stamina_cost: cost, dmg_mult: 1.0, effect: "", name: "Attack", is_regular_attack: true });
  },
  async _battle_player_heavy_attack() {
    const cost = Math.trunc(this.player.current_weapon.heavy_stamina_cost_override ?? W.consts.HEAVY_STAMINA_COST);
    await this._battle_perform_attack({ stamina_cost: cost, dmg_mult: W.consts.HEAVY_DAMAGE_MULT, effect: "", name: "Heavy Attack" });
  },
  async _battle_player_special(index) {
    const specials = this.player.current_weapon.specials || [];
    if (index < 0 || index >= specials.length) return;
    let action = specials[index];
    if (action.learned === false) { this.log(`You haven't learned ${action.name} yet.`); return; }
    if (this.player.current_weapon.passive_free_specials) { action = clone(action); action.stamina_cost = 0; }
    const free_chance = this.player.current_weapon.passive_free_special_chance || 0;
    if (action.stamina_cost > 0 && free_chance > 0 && this.rng.randf() < this._proc(free_chance)) {
      action = clone(action); action.stamina_cost = 0; this.log("Frying Pans serves it up for free!");
    }
    await this._battle_perform_attack(action);
  },

  async _battle_player_arrow(kind) {
    const p = this.player;
    if ((p.owned_arrows[kind] || 0) <= 0) { this.log(`You're out of ${kind} arrows!`); return; }
    const idx = this._effective_target_index();
    if (idx < 0) { this.log("No enemy in range."); return; }
    this.stat_action(kind + " arrow");
    if (kind === "bomb") this._resolve_bomb_arrow(vclone(this.battle_units[idx].tile));
    else if (kind === "flame") {
      const flame_dmg = MC.ARROW_FLAME_FLAT_DMG + round(p.attack_damage * MC.ARROW_FLAME_DMG_STAT_PCT);
      this._apply_single_hit(idx, 1.0, "arrow_flame", p.current_weapon, "You", null, flame_dmg);
    } else this._apply_single_hit(idx, 1.0, "arrow_freeze", p.current_weapon, "You", null, MC.ARROW_FREEZE_FLAT_DMG);
    p.owned_arrows[kind] -= 1;
    if (this.over) return;
    if (this.battle_units.length === 0) { this._battle_victory(); return; }
    await this._end_player_turn();
  },

  _resolve_bomb_arrow(center) {
    const p = this.player;
    const targets = [];
    this.battle_units.forEach((u, i) => {
      let hit = false;
      for (const cell of this._footprint(u.tile, u.size ?? 1)) if (this._in_blast_radius(cell, center, MC.ARROW_BOMB_RADIUS)) { hit = true; break; }
      if (hit) targets.push(i);
    });
    targets.sort((a, b) => a - b).reverse();
    for (const idx of targets) this._apply_single_hit(idx, 1.0, "arrow_bomb", p.current_weapon, "You", null, MC.ARROW_BOMB_FLAT_DMG);
    for (const a of this.battle_allies) if (a.hp > 0 && this._in_blast_radius(a.tile, center, MC.ARROW_BOMB_RADIUS)) { a.hp -= MC.ARROW_BOMB_FLAT_DMG; this.log(`Your ${a.name} is caught in the blast!`); }
    if (this._in_blast_radius(this.battle_player_tile, center, MC.ARROW_BOMB_RADIUS)) {
      p.take_battle_damage(MC.ARROW_BOMB_FLAT_DMG);
      this.log(`You're caught in your own blast for ${MC.ARROW_BOMB_FLAT_DMG} damage!`, "bad");
      this._check_player_dead();
    }
  },

  async _resolve_mine_rock() {
    const target = this._effective_rock_target();
    if (veq(target, NONE)) { this.log("No rock to mine."); return; }
    const was = this.terrainAt(target).type === "rubble" ? "rubble" : "rock";
    delete this.battle_terrain[vkey(target)];
    this.battle_rock_target = vclone(NONE);
    this.stat_action("mine");
    this.log(`You mine away the ${was}.`);
    await this._end_player_turn();
  },

  // ---------------------------------------------------------------- items / defend / tactics
  async _battle_player_item(itemId = null) {
    const p = this.player;
    if (p.talisman_bonus("disable_healing_items") > 0) { this.log("Your pact forbids healing -- lifesteal is all you have."); return; }
    const result = itemId ? p.use_specific_potion(itemId) : p.use_healing_item();
    if (!result) { this.log("No items to use!"); return; }
    this.stats.potions_used++;
    this.stat_action("item");
    if (result.healed > 0 && (result.stamina_restored || 0) > 0) this.log(`You ate ${result.name}: +${result.healed} HP, +${result.stamina_restored} stamina.`, "good");
    else if (result.healed > 0) this.log(`You used ${result.name} and healed ${result.healed} HP.`, "good");
    else this.log(`You used ${result.name}.`);
    switch (result.effect || "") {
      case "cleanse": this._cleanse_player_status(); this.log(`The ${result.name} washes your afflictions away!`); break;
      case "attack_buff": p.potion_attack_turns = MC.POTION_BUFF_TURNS; this.log(`Your strikes hit harder for your next ${MC.POTION_BUFF_TURNS} turns!`); break;
      case "resilience_buff": p.potion_resilience_turns = MC.POTION_BUFF_TURNS; this.log("Your skin hardens against incoming blows!"); break;
      case "energy_buff": p.potion_energy_turns = MC.POTION_BUFF_TURNS; this.log("Your legs feel lighter -- extra reach on your next turns of movement!"); break;
      case "restore_stamina": p.reset_stamina(); this.log("Stamina rushes back into you!"); break;
    }
    await this._end_player_turn();
  },
  _cleanse_player_status() {
    this.player_poison_turns = 0; this.player_poison_dmg = 0; this.player_burning = false;
    this.player_bleed_turns = 0; this.player_concussed_turns = 0; this.player_blind_turns = 0;
  },
  async _battle_player_defend() {
    const p = this.player;
    this.battle_player_defending = true;
    p.regen_stamina(MC.STAMINA_REGEN_ON_DEFEND);
    this.log("You brace for impact.");
    this.stat_action("defend");
    if (p.block_heal_amount() > 0) p.heal(p.block_heal_amount());
    await this._end_player_turn();
  },
  async _battle_player_taunt() {
    const p = this.player;
    this.battle_player_defending = true; this.battle_player_taunting = true;
    for (const u of this.battle_units) u.aware_of_player = true;
    p.regen_stamina(MC.STAMINA_REGEN_ON_DEFEND);
    this.log("You taunt the enemy, daring them to attack!");
    this.stat_action("taunt");
    if (p.block_heal_amount() > 0) p.heal(p.block_heal_amount());
    await this._end_player_turn();
  },
  async _battle_player_stealth() {
    if (!this.player.spend_stamina(MC.STEALTH_STAMINA_COST)) { this.log("Not enough stamina to vanish into the shadows!"); return; }
    this.stats.stamina_spent += MC.STEALTH_STAMINA_COST;
    this.player.stealth_turns_remaining = MC.STEALTH_TURNS;
    this.log("You slip into the shadows.");
    this.stat_action("stealth");
    await this._end_player_turn();
  },
  async _battle_player_skill() {
    const p = this.player;
    if (!p.has_guardian_skill || this.battle_skill_cooldown > 0) return;
    const heal_amt = round(p.max_health * 0.4);
    p.heal(heal_amt);
    this.log(`Guardian's Ultimatum! You recover ${heal_amt} HP.`, "good");
    this.battle_skill_cooldown = 4;
    this.stat_action("skill");
    await this._end_player_turn();
  },
  _battle_flee() {
    this.log("You flee the fight!");
    this.stat_action("flee");
    this.over = true; this.in_battle = false; this.result = "fled";
  },

  // ---------------------------------------------------------------- end of the player's turn
  async _end_player_turn() {
    if (this.over) return;
    if (this.battle_skill_cooldown > 0) this.battle_skill_cooldown -= 1;
    this._advance_bloodmoon_quiet_turn();
    const p = this.player;
    if (!p.shield_push_immune()) {
      let should_push = true;
      if (p.talisman_bonus("water_push_prompt") > 0) {
        const tt = this.terrainAt(this.battle_player_tile);
        if (tt && tt.type === "water") should_push = await this._prompt_water_push();
      }
      if (should_push) this.battle_player_tile = this._apply_water_push(this.battle_player_tile);
    }
    this._apply_terrain_tick(this.battle_player_tile);
    this._check_player_dead();
    if (this.over) return;
    await this._start_ally_turn();
  },

  _advance_bloodmoon_quiet_turn() {
    const p = this.player;
    if (p.talisman_bonus("bloodmoon_fang") <= 0) return;
    if (this.battle_had_combat_action_this_cycle) this.battle_bloodmoon_quiet_turns = 0;
    else {
      this.battle_bloodmoon_quiet_turns += 1;
      if (this.battle_bloodmoon_quiet_turns >= MC.BLOODMOON_QUIET_TURNS_LIMIT && !p.bloodmoon_debuffed) {
        p.bloodmoon_debuffed = true; p.bloodmoon_stacks = 0; p._recalc_stats();
        this.log("Bloodmoon Fang crashes -- your stats are halved!", "bad");
      }
    }
    this.battle_had_combat_action_this_cycle = false;
  },

  async _prompt_water_push() {
    return await this.prompt("water_push", { text: "The current pulls at your feet. Go with it?", yes: "Go with the current", no: "Hold your ground", default: true });
  },

  _battle_victory() {
    if (this.over) return;
    this.log("Victory!", "good");
    this.over = true; this.in_battle = false; this.result = "victory";
  },

  // ---------------------------------------------------------------- ally turns (player-commanded)
  async _start_ally_turn() {
    if (this.over) return;
    if (this.battle_units.length === 0) { this._battle_victory(); return; }
    this.battle_turn = "player";
    this.battle_ally_queue = this.battle_allies.filter((u) => u.hp > 0);
    await this._advance_ally_queue();
  },
  async _advance_ally_queue() {
    while (this.battle_ally_queue.length > 0) {
      const next = this.battle_ally_queue.shift();
      if (next.hp <= 0) continue;
      this.battle_commanding_ally = next;
      this.battle_ally_moves_left = Math.trunc(next.move_range);
      next.defending = false;
      this.battle_menu_state = "main";
      this.battle_move_trail = [];
      return;                       // waits for the player's command (Move / Attack / Guard / Skip)
    }
    this.battle_commanding_ally = null;
    this._remove_fallen_allies();
    if (this.battle_units.length === 0) { this._battle_victory(); return; }
    await this._start_enemy_turn();
  },
  async ally_action(action) {
    if (this.over || this.battle_turn !== "player" || !this.battle_commanding_ally) return;
    const u = this.battle_commanding_ally;
    switch (action) {
      case "attack": await this._battle_ally_attack(); break;
      case "guard": u.defending = true; this.log(`Your ${u.name} braces for impact.`); await this._end_ally_command(); break;
      case "skip": this.log(`Your ${u.name} does nothing this turn.`); await this._end_ally_command(); break;
    }
  },
  async _end_ally_command() {
    if (this.over) return;
    const u = this.battle_commanding_ally;
    if (u && u.hp > 0) { u.tile = this._apply_water_push(u.tile, u); this._apply_terrain_tick(u.tile, u); }
    this.battle_menu_state = "main"; this.battle_move_trail = [];
    await this._advance_ally_queue();
  },
  async _battle_ally_attack() {
    const u = this.battle_commanding_ally;
    const idx = this._ally_effective_target_index(u);
    if (idx < 0) { this.log("No enemy in range."); return; }
    this._apply_single_hit(idx, u.dmg_mult, "", { damage_mult: 1.0 }, "Your " + u.name, vclone(u.tile), -1, false, u.attack !== undefined ? u.attack : -1.0);
    if (this.over) return;
    if (this.battle_units.length === 0) {
      this.battle_commanding_ally = null; this.battle_ally_queue = [];
      this._remove_fallen_allies(); this._battle_victory(); return;
    }
    await this._end_ally_command();
  },
  _ally_targetable_indices(u) {
    const result = [];
    this.battle_units.forEach((e, i) => {
      const size = e.size ?? 1;
      let in_range;
      if (size > 1) in_range = this._footprint_dist(this._footprint(e.tile, size), u.tile) <= Math.trunc(u.attack_range);
      else in_range = this._can_battle_attack(u.tile, e.tile, Math.trunc(u.attack_range));
      if (in_range) result.push(i);
    });
    return result;
  },
  _ally_effective_target_index(u) {
    const t = this._ally_targetable_indices(u);
    if (t.length === 0) return -1;
    return t.includes(this.battle_target_index) ? this.battle_target_index : t[0];
  },
  _remove_fallen_allies() {
    for (let i = this.battle_allies.length - 1; i >= 0; i--) {
      const f = this.battle_allies[i];
      if (f.hp <= 0) {
        this.log(`Your ${f.name} is knocked out!`, "bad");
        if (f.member && !this.battle_fainted_members.includes(f.member)) this.battle_fainted_members.push(f.member);
        this.battle_allies.splice(i, 1);
      }
    }
  },
});
