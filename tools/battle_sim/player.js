/* Player model -- a port of the combat-relevant parts of scripts/Player.gd. */
"use strict";

const STAT_START = { intimidation: 0, strength: 1, vigor: 20, agility: PC.AGILITY_START, might: 0, resilience: 0, reflexes: 0, dexterity: 0 };

class PartyMemberModel {
  // Port of PartyMember.gd for the battle-relevant maths. `picks_spent` is how many
  // level-up picks went into each pickable stat.
  constructor(kind, level, picks_spent) {
    this.kind = kind;
    this.rules = D.party.kinds[kind];
    this.name = this.rules.name;
    this.level = this.rules.levels ? level : 1;
    this.bonus = { hp: 0, attack: 0, defense: 0, speed: 0, magic: 0 };
    const C = D.party.consts;
    if (this.rules.levels) {
      for (let i = 0; i < this.level - 1; i++) {
        for (const s of C.STAT_NAMES) this.bonus[s] += C.PASSIVE_GAIN[s] * this._growth(s);
      }
      for (const s of Object.keys(picks_spent || {})) {
        if (!this.pickable_stats().includes(s)) continue;
        this.bonus[s] += C.PICK_GAIN[s] * this._growth(s) * (picks_spent[s] || 0);
      }
    }
  }
  _growth(s) { return (this.rules.growth && this.rules.growth[s] !== undefined) ? this.rules.growth[s] : 1.0; }
  is_wolf() { return !!this.rules.wolf; }
  pickable_stats() { return this.rules.stats || []; }
  raw_stat(s) { return (this.rules.base[s] || 0) + (this.bonus[s] || 0); }
  stat(s) { return this.raw_stat(s) * ((this.rules.final_mult || {})[s] ?? 1.0); }
  max_hp() { return Math.max(1, round(this.stat("hp"))); }
  attack() { return this.stat("attack"); }
  defense_pct() {
    if (this.rules.defense_fixed !== undefined) return this.rules.defense_fixed;
    return Math.max(0, this.stat("defense"));
  }
  is_caster() { return !!this.rules.caster; }
  max_mana() { return this.is_caster() ? round(this.stat("magic") * D.party.consts.MANA_PER_MAGIC) : 0; }
  max_stamina() { return this.rules.stamina || 0; }
  move_tiles() {
    const mv = this.rules.move || {};
    if (mv.fixed !== undefined) return mv.fixed;
    const C = D.party.consts;
    const rating = this.raw_stat("speed");
    let tiles;
    if (mv.per_speed !== undefined) tiles = (mv.base ?? C.BASE_MOVE_TILES) + mv.per_speed * rating;
    else tiles = C.BASE_MOVE_TILES + Math.floor((rating - C.SPEED_START) / C.SPEED_PER_EXTRA_TILE);
    tiles *= (mv.tile_mult ?? 1.0);
    return Math.max(1, Math.floor(tiles + 0.0001));
  }
}

class Player {
  constructor(sim) {
    this.sim = sim;
    this.rng = sim.rng;
    this.level = 1;
    this.xp = 0;
    this.xp_to_next = PC.XP_BASE + PC.XP_PER_LEVEL * 1;
    this.stat_intimidation = 0; this.stat_strength = 1; this.stat_vigor = 20;
    this.stat_agility = PC.AGILITY_START; this.stat_might = 0;
    this.stat_resilience = 0; this.stat_reflexes = 0; this.stat_dexterity = 0;
    this.awaiting_bonus = 0;           // pending level-up stat picks (the game shows a menu)
    this.max_health = 20; this.health = 20; this.attack_damage = 1;
    this.coins = 0;
    this.potion_queue = [];
    this.current_weapon = clone(W.club); this.current_weapon_base = clone(W.club);
    this.equipped_armor = clone(D.armor[0]);
    this.equipped_shield = {};
    this.equipped_clothing = { head: "", body: "", feet: "" };
    this.weapon_enchantments = {}; this.weapon_upgrade_levels = {}; this.armor_upgrade_levels = {};
    this.learned_specials = {};
    this.equipped_talismans = []; this._talisman_cache = {};
    this.phoenix_used = false;
    this._base_max_stamina = PC.MAX_STAMINA; this.max_stamina = PC.MAX_STAMINA; this.stamina = PC.MAX_STAMINA;
    this.exhausted = false;
    this.luck_bonus = 0;
    this.resilience_reduction = 0; this.difficulty_mult = 1.0; this.difficulty_id = "normal"; this.temp_damage_bonus_pct = 0;
    // meta passives (Astral upgrades)
    this.meta_double_hit_chance = 0; this.meta_lifesteal_pct = 0; this.meta_free_specials = false;
    this.has_guardian_skill = false; this.has_merchant_prince = false;
    this.meta_dodge_chance = 0; this.meta_crit_chance = 0;
    this.meta_resilience_unlocked = false; this.meta_reflexes_unlocked = false; this.meta_dexterity_unlocked = false;
    this.meta_rage_bonus_pct = 0; this.meta_low_hp_damage_bonus_pct = 0; this.meta_bonus_coin_pct = 0;
    this.meta_healing_bonus_pct = 0; this.meta_bonus_levelup_stat = false;
    this.meta_levelup_bonus_strength = 0; this.meta_levelup_bonus_agility = 0;
    this.meta_levelup_bonus_vigor = 0; this.meta_levelup_bonus_intimidation = 0;
    this.meta_warband_bonus = 0; this.meta_battle_medic = false; this.meta_war_chest_reduction = 0;
    this.meta_war_profiteer_coins = 0; this.meta_block_negate_chance = 0; this.meta_block_heal_amount = 0;
    this.meta_last_stand_pct_per_10 = 0; this.meta_shield_block_bonus_pct = 0; this.meta_shield_universal = false;
    this.meta_riposte_chance = 0; this.meta_momentum_pct_per_kill = 0; this.meta_hardened_hp_per_wave = 0;
    this.hardened_hp_bonus = 0; this.meta_favour_chance = 0; this.second_chance_used_this_battle = false;
    this.meta_stamina_regen_per_turn = 0; this.meta_wolf_bonus_waves = 0; this.meta_arrow_cap_bonus = 0;
    this.meta_windfall_chance = 0; this.meta_worldwalker = false;
    this.max_party_slots = D.party.consts.BASE_PARTY_SLOTS ?? 2;
    this.party_members = []; this.party = [];
    // in-battle state
    this.disarmed_tile = vclone(NONE); this.shield_vengeance_active = false;
    this.potion_attack_turns = 0; this.potion_resilience_turns = 0; this.potion_energy_turns = 0;
    this.owned_arrows = { flame: 0, freeze: 0, bomb: 0 };
    this.pichaku_active = false; this.berserk_turns_remaining = 0; this.stealth_turns_remaining = 0;
    this.bloodmoon_stacks = 0; this.bloodmoon_debuffed = false;
    this.weapon_whisperer_specials = [];
    this.real_miss = true;
    this.died = false;
  }

  // ------------------------------------------------------------ build from a config
  configure(cfg) {
    const up = cfg.upgrades || {};
    // Player._refresh_meta_passives: bonuses[id] = stat_bonus * owned level
    const bonuses = {};
    for (const id of D.upgrades.ids) bonuses[id] = (D.upgrades.defs[id].stat_bonus || 0) * (up[id] || 0);
    this.upgrade_levels = up;
    this._refresh_meta_passives(bonuses);
    const diff = D.upgrades.difficulties.find((d) => d.id === (cfg.difficulty || "normal"));
    this.difficulty_mult = diff ? diff.mult : 1.0;
    this.difficulty_id = diff ? diff.id : "normal";

    // stats: starting values + one automatic point in each core stat per level-up,
    // plus the one chosen bonus point per level-up (Player._level_up / apply_bonus_stat).
    this.level = clamp(cfg.level || 1, 1, PC.MAX_LEVEL);
    for (const k of Object.keys(STAT_START)) this["stat_" + k] = STAT_START[k];
    for (let l = 2; l <= this.level; l++) {
      this.stat_intimidation += 1; this.stat_strength += 1; this.stat_vigor += 1;
      this.stat_agility += 1; this.stat_might += 1;
      if (this.meta_resilience_unlocked) this.stat_resilience += 1;
      if (this.meta_reflexes_unlocked) this.stat_reflexes += 1;
      if (this.meta_dexterity_unlocked) this.stat_dexterity += 1;
    }
    this.xp = 0;
    this.xp_to_next = this.level >= PC.MAX_LEVEL ? 0 : PC.XP_BASE + PC.XP_PER_LEVEL * this.level;
    const picks = cfg.picks || {};
    const times = this.meta_bonus_levelup_stat ? 2 : 1;
    for (const stat of Object.keys(picks)) for (let n = 0; n < (picks[stat] || 0); n++) this._apply_pick(stat, times);

    this.hardened_hp_bonus = this.meta_hardened_hp_per_wave * (cfg.waves_cleared || 0);
    this.max_stamina = PC.MAX_STAMINA + Math.trunc(bonuses.stamina || 0);
    this._base_max_stamina = this.max_stamina;
    this.coins = (cfg.coins || 0);

    // gear
    this.equipped_armor = clone(armorById(cfg.armor || "armor_rags"));
    this.armor_upgrade_levels = {}; this.armor_upgrade_levels[this.equipped_armor.id] = this.equipped_armor.metal ? (cfg.armor_level || 0) : 0;
    this.equipped_clothing = Object.assign({ head: "", body: "", feet: "" }, cfg.clothing || {});
    this.equipped_shield = cfg.shield && D.shields[cfg.shield] ? clone(D.shields[cfg.shield]) : {};
    this.owned_arrows = Object.assign({ flame: 0, freeze: 0, bomb: 0 }, cfg.arrows || {});
    this.potion_queue = [];
    for (const c of (cfg.consumables || [])) for (let i = 0; i < c.n; i++) this.potion_queue.push(c.id);
    this.learned_specials = {};
    const learnAll = cfg.learn_all !== false;
    for (const b of weaponBases()) for (const sp of (b.specials || [])) if (learnAll || (cfg.learned || []).includes(sp.id)) this.learned_specials[sp.id] = true;
    this.weapon_whisperer_specials = (cfg.whisperer || []).slice(0, 3);
    this.equipped_talismans = (cfg.talismans || []).slice();
    this.real_miss = cfg.real_miss !== false;

    const wsel = cfg.weapon || { base: "club" };
    const weapon = buildWeapon(wsel);
    this.weapon_upgrade_levels = {}; this.weapon_enchantments = {};
    this.weapon_upgrade_levels[weapon.id] = cfg.blacksmith || 0;
    if (cfg.rune && weapon.id !== "club") this.weapon_enchantments[weapon.id] = cfg.rune;
    this.current_weapon_base = weapon;

    this.party_members = []; this.party = [];
    if ((bonuses.battle_hardened || 0) > 0) this.party_members.push({ name: "Knight", dmg_mult: 0.75 });
    if ((bonuses.beastmaster || 0) > 0) this.party.push(new PartyMemberModel("wolf", 1, {}));
    for (const m of (cfg.party || [])) this.party.push(new PartyMemberModel(m.kind, m.level || 1, m.picks || {}));

    this.phoenix_used = false; this.second_chance_used_this_battle = false;
    this._rebuild_talisman_cache();
    this.health = 1;
    this._recalc_stats();
    this.health = this.max_health;
    this._equip_weapon(this.current_weapon_base);
  }

  _apply_pick(stat, times) {
    for (let i = 0; i < times; i++) {
      switch (stat) {
        case "intimidation": this.stat_intimidation += 1 + this.meta_levelup_bonus_intimidation; break;
        case "strength": this.stat_strength += 1 + this.meta_levelup_bonus_strength; break;
        case "vigor": this.stat_vigor += 1 + this.meta_levelup_bonus_vigor; break;
        case "agility": this.stat_agility += PC.AGILITY_BONUS_PER_LEVEL + this.meta_levelup_bonus_agility; break;
        case "might": this.stat_might += 1; break;
        case "resilience": this.stat_resilience += 1; break;
        case "reflexes": this.stat_reflexes += 1; break;
        case "dexterity": this.stat_dexterity += 1; break;
      }
    }
  }

  _refresh_meta_passives(b) {
    this.meta_levelup_bonus_strength = Math.trunc(b.strength || 0);
    this.meta_levelup_bonus_agility = Math.trunc(b.agility || 0);
    this.meta_levelup_bonus_vigor = Math.trunc(b.vigor || 0);
    this.meta_levelup_bonus_intimidation = Math.trunc(b.intimidation || 0);
    this.meta_worldwalker = (b.worldwalker || 0) > 0;
    this.luck_bonus = b.luck || 0;
    this.meta_resilience_unlocked = (b.resilience_unlock || 0) > 0;
    this.meta_reflexes_unlocked = (b.reflexes_unlock || 0) > 0;
    this.meta_dexterity_unlocked = (b.dexterity_unlock || 0) > 0;
    this.meta_rage_bonus_pct = b.rage || 0;
    this.meta_double_hit_chance = b.berserker_edge || 0;
    this.meta_lifesteal_pct = b.vampiric_grit || 0;
    this.meta_free_specials = (b.silver_tongue || 0) > 0;
    this.has_merchant_prince = (b.golden_touch || 0) > 0;
    this.has_guardian_skill = (b.undying || 0) > 0;
    if ((b.warlord || 0) > 0) this.max_party_slots = 4;
    else if ((b.pack_leader || 0) > 0) this.max_party_slots = 3;
    else this.max_party_slots = D.party.consts.BASE_PARTY_SLOTS ?? 2;
    this.meta_low_hp_damage_bonus_pct = b.adrenaline || 0;
    this.meta_bonus_coin_pct = b.haggling || 0;
    this.meta_healing_bonus_pct = b.herbalism || 0;
    this.meta_bonus_levelup_stat = (b.prodigy || 0) > 0;
    this.meta_wolf_bonus_waves = Math.trunc(b.pack_bond || 0);
    this.meta_warband_bonus = b.warband || 0;
    this.meta_battle_medic = (b.battle_medic || 0) > 0;
    this.meta_war_chest_reduction = b.war_chest || 0;
    this.meta_war_profiteer_coins = Math.trunc(b.war_profiteer || 0);
    this.meta_block_negate_chance = b.block_master || 0;
    this.meta_block_heal_amount = Math.trunc(b.vigilant_defense || 0);
    this.meta_last_stand_pct_per_10 = b.last_stand || 0;
    this.meta_shield_block_bonus_pct = b.shield_mastery || 0;
    this.meta_shield_universal = (b.unbreakable_guard || 0) > 0;
    this.meta_riposte_chance = b.riposte || 0;
    this.meta_momentum_pct_per_kill = b.momentum || 0;
    this.meta_hardened_hp_per_wave = Math.trunc(b.hardened || 0);
    this.meta_favour_chance = b.favour || 0;
    this.meta_stamina_regen_per_turn = Math.trunc(b.second_breath || 0);
    this.meta_arrow_cap_bonus = 5 * Math.trunc((this.upgrade_levels || {}).fletcher || 0);
    this.meta_windfall_chance = b.windfall || 0;
  }

  // ------------------------------------------------------------ party
  wolf_only_slots() { return this.talisman_bonus("wolf_slot") > 0 ? 1 : 0; }
  party_capacity() { return this.max_party_slots + this.wolf_only_slots(); }
  fielded_party() {
    const room = Math.max(0, this.party_capacity() - this.party_members.length);
    return this.party.slice(0, room);
  }

  // ------------------------------------------------------------ talismans
  talisman_slots() { return slotsForLevel(this.level); }
  talisman_bonus(key) { return this._talisman_cache[key] || 0.0; }
  _rebuild_talisman_cache() {
    this._talisman_cache = {};
    for (const id of this.equipped_talismans) {
      const t = talismanById(id);
      if (!t) continue;
      for (const k of Object.keys(t.effects)) this._talisman_cache[k] = (this._talisman_cache[k] || 0) + Number(t.effects[k]);
    }
  }
  _on_talismans_changed() {
    this._rebuild_talisman_cache();
    this._recalc_stats();
    this._equip_weapon(this.current_weapon_base);
  }

  // ------------------------------------------------------------ derived stats
  total_luck() { return this.luck_bonus + this.talisman_bonus("luck"); }
  block_heal_amount() { return Math.trunc(this.meta_block_heal_amount) + Math.trunc(this.talisman_bonus("block_heal")); }
  dodge_chance_total() { return this.meta_dodge_chance + this.talisman_bonus("dodge_chance"); }
  crit_chance_total() { return this.meta_crit_chance + this.talisman_bonus("crit_chance"); }
  stamina_regen_per_turn() { return Math.trunc(this.meta_stamina_regen_per_turn) + Math.trunc(this.talisman_bonus("stamina_regen")); }
  secondary_chance_mult() { return this.talisman_bonus("double_secondary_chance") > 0 ? 2.0 : 1.0; }
  hp_regen_per_turn() {
    const flat = this.talisman_bonus("hp_regen_turn");
    const scale = this.talisman_bonus("hp_regen_per_20_max_hp");
    return Math.trunc(flat) + Math.trunc(Math.floor(this.max_health / 20.0) * scale);
  }
  windfall_chance_total() { return this.meta_windfall_chance + this.talisman_bonus("windfall_chance"); }
  coins_per_kill() { return Math.trunc(this.meta_war_profiteer_coins) + Math.trunc(this.talisman_bonus("coins_per_kill")); }
  low_hp_damage_bonus_total() { return this.meta_low_hp_damage_bonus_pct + this.talisman_bonus("low_hp_damage_pct"); }
  low_hp_threshold() { const t = this.talisman_bonus("low_hp_threshold"); return t > 0 ? t : 0.3; }
  fall_damage_factor() { return Math.max(0.0, 1.0 - this.talisman_bonus("fall_reduction")); }
  crit_damage_mult() { return 2.0 + this.talisman_bonus("crit_damage_mult_bonus"); }
  coin_scaled_attack_bonus() { return this.talisman_bonus("attack_per_coin") * this.coins; }
  coin_scaled_defense_bonus() { return this.talisman_bonus("defense_per_coin") * this.coins; }
  get_weapon_upgrade_level(id) { return this.weapon_upgrade_levels[id] || 0; }
  get_armor_upgrade_level(id) { return this.armor_upgrade_levels[id] || 0; }

  armor_tier_damage_reduction() {
    const id = this.equipped_armor.id || "";
    return (this.equipped_armor.damage_reduction || 0) + armorBonus(this.get_armor_upgrade_level(id));
  }
  clothing_damage_reduction() {
    let total = 0;
    for (const slot of D.clothing_slots) {
      const piece = clothingById(this.equipped_clothing[slot] || "");
      if (piece) total += piece.damage_reduction || 0;
    }
    return total;
  }
  armor_damage_reduction() {
    let total = this.armor_tier_damage_reduction() + this.clothing_damage_reduction() + this.talisman_bonus("damage_reduction") + this.coin_scaled_defense_bonus();
    if (this.talisman_bonus("ironclad_ward") > 0) total *= 2.5;
    if (this.bloodmoon_debuffed) total *= 0.5;
    return total;
  }

  // ------------------------------------------------------------ shields
  _shield_weapon_ok() {
    const wid = this.current_weapon.id || "";
    return this.meta_shield_universal || shieldWeaponCompatible(wid);
  }
  shield_block_chance() {
    if (this.berserk_turns_remaining > 0) return 0.0;
    if (isEmpty(this.equipped_shield) || !this._shield_weapon_ok()) return 0.0;
    return (this.equipped_shield.block_chance || 0) + this.meta_shield_block_bonus_pct;
  }
  _shield_stat(key, dflt) {
    if (isEmpty(this.equipped_shield) || !this._shield_weapon_ok()) return dflt;
    return this.equipped_shield[key] ?? dflt;
  }
  shield_push_immune() { return this._shield_stat("push_immune", false); }
  shield_defend_threshold_bonus() { return this._shield_stat("defend_threshold_bonus", 0); }
  shield_damage_penalty_pct() { return this._shield_stat("damage_penalty_pct", 0.0); }
  shield_damage_reduction_pct() { return this._shield_stat("damage_reduction_pct", 0.0); }
  shield_evasion_active() {
    if (isEmpty(this.equipped_shield) || this.equipped_shield.special !== "evasive") return false;
    return this._shield_weapon_ok();
  }
  shield_special_pct() {
    if (isEmpty(this.equipped_shield)) return 0.0;
    if (shieldBaseWeaponId(this.current_weapon.id || "") === (this.equipped_shield.synergy_weapon || "")) return this.equipped_shield.synergy_special_pct || 0.0;
    return this.equipped_shield.special_pct || 0.0;
  }

  // ------------------------------------------------------------ miss chance (Player.miss_chance_for)
  miss_chance_for(weapon) {
    if (!this.real_miss) return 0.0;
    const specials = weapon.specials || [];
    if (specials.length === 0) return PC.MISS_CHANCE;
    for (const sp of specials) if (!this.learned_specials[sp.id]) return PC.MISS_CHANCE;
    return PC.MISS_CHANCE_MASTERED;
  }
  ally_miss_chance() { return this.real_miss ? PC.ALLY_MISS_CHANCE : 0.0; }

  // ------------------------------------------------------------ weapon pipeline
  _equip_weapon(weapon) {
    this.current_weapon_base = weapon;
    this.current_weapon = this._apply_meta_passives_to_weapon(this._apply_talisman_to_weapon(this._apply_upgrade_to_weapon(this._apply_enchantment_to_weapon(weapon))));
    for (const sp of (this.current_weapon.specials || [])) sp.learned = !!this.learned_specials[sp.id];
  }
  _apply_enchantment_to_weapon(weapon) {
    const rune_id = this.weapon_enchantments[weapon.id || ""] || "";
    if (!rune_id) return weapon;
    const rune = runeById(rune_id);
    if (!rune) return weapon;
    const eq = clone(weapon);
    const p = rune.passive;
    if (p.damage_bonus_pct !== undefined) eq.damage_mult *= (1.0 + p.damage_bonus_pct);
    if (p.stamina_discount_pct !== undefined) for (const sp of eq.specials) sp.stamina_cost = round(sp.stamina_cost * (1.0 - p.stamina_discount_pct));
    if (p.break_chance_bonus_pct !== undefined) eq.break_chance = (eq.break_chance || 0) + p.break_chance_bonus_pct;
    if (p.lifesteal_pct !== undefined) eq.passive_lifesteal_pct = (eq.passive_lifesteal_pct || 0) + p.lifesteal_pct;
    if (p.self_damage_pct !== undefined) eq.passive_self_damage_pct = (eq.passive_self_damage_pct || 0) + p.self_damage_pct;
    if (p.guaranteed_knockback) eq.passive_guaranteed_knockback = true;
    if (p.ignore_cover) eq.passive_ignore_cover = true;
    return eq;
  }
  _apply_upgrade_to_weapon(weapon) {
    const level = this.weapon_upgrade_levels[weapon.id || ""] || 0;
    if (level <= 0) return weapon;
    const up = clone(weapon);
    up.damage_mult *= weaponDamageFactor(level);
    if ((up.break_chance || 0) > 0) up.break_chance *= weaponBreakFactor(level);
    up.name = `${up.name || "Weapon"} +${level}`;
    return up;
  }
  _apply_talisman_to_weapon(weapon) {
    const discount = this.talisman_bonus("special_stamina_discount");
    const flat_reduction = Math.trunc(this.talisman_bonus("special_stamina_flat_reduction"));
    const pct_increase = this.talisman_bonus("special_stamina_pct_increase");
    const break_cut = this.talisman_bonus("break_reduction");
    const whisperer_active = this.talisman_bonus("weapon_whisperer") > 0 && this.weapon_whisperer_specials.length > 0;
    let amulet_material = null;
    if (this.talisman_bonus("material_passive_boost") > 0) amulet_material = materialById(weapon.material_id || "");
    if (discount <= 0 && flat_reduction <= 0 && pct_increase <= 0 && break_cut <= 0 && !whisperer_active && !amulet_material) return weapon;
    const w = clone(weapon);
    if (amulet_material) {
      const boosted = stoneAmuletScales(amulet_material);
      w.damage_mult = w.damage_mult * boosted.damage_scale / amulet_material.damage_scale;
      if (w.price !== undefined) w.price = round(w.price * boosted.price_scale / amulet_material.price_scale);
      if (amulet_material.break_chance > 0 && (w.break_chance || 0) > 0) w.break_chance = w.break_chance * boosted.break_chance / amulet_material.break_chance;
      const base = weaponBases().find((b) => (weapon.id || "").startsWith(b.id + "_")) || null;
      const raw_costs = {};
      if (base) for (const rs of (base.specials || [])) raw_costs[rs.id] = Math.trunc(rs.stamina_cost);
      for (const sp of (w.specials || [])) {
        if (sp.stamina_cost > 0) {
          const raw = raw_costs[sp.id] ?? -1;
          let scaled;
          if (raw >= 0 && sp.stamina_cost === round(raw * amulet_material.stamina_scale)) scaled = round(raw * boosted.stamina_scale);
          else scaled = round(sp.stamina_cost * boosted.stamina_scale / amulet_material.stamina_scale);
          sp.stamina_cost = Math.max(1, scaled);
        }
      }
    }
    if (whisperer_active) {
      const slots = w.specials || [];
      const n = Math.min(this.weapon_whisperer_specials.length, slots.length);
      for (let i = 0; i < n; i++) {
        const found = locateSpecial(this.weapon_whisperer_specials[i]);
        if (found) slots[i] = clone(found);
      }
    }
    if (discount > 0 || flat_reduction > 0 || pct_increase > 0) {
      for (const sp of (w.specials || [])) {
        if (sp.stamina_cost > 0) {
          let cost = sp.stamina_cost;
          if (discount > 0) cost = round(cost * (1.0 - discount));
          cost -= flat_reduction;
          if (pct_increase > 0) cost = round(cost * (1.0 + pct_increase));
          sp.stamina_cost = Math.max(1, cost);
        }
      }
    }
    if (break_cut > 0 && (w.break_chance || 0) > 0) w.break_chance *= Math.max(0, 1.0 - break_cut);
    return w;
  }
  _apply_meta_passives_to_weapon(weapon) {
    const w = clone(weapon);
    if (this.meta_double_hit_chance > 0) w.passive_double_hit_chance = (w.passive_double_hit_chance || 0) + this.meta_double_hit_chance;
    if (this.meta_lifesteal_pct > 0) w.passive_lifesteal_pct = (w.passive_lifesteal_pct || 0) + this.meta_lifesteal_pct;
    if (this.meta_free_specials) w.passive_free_specials = true;
    return w;
  }

  // ------------------------------------------------------------ health / stamina
  heal(amount) { this.health = clamp(this.health + amount, 0, this.max_health); }
  restore_health(amount) { this.health = clamp(amount, 0, this.max_health); }
  reset_stamina() { this.stamina = this.max_stamina; this.exhausted = false; }
  reset_stamina_for_battle() { this.stamina = round(this.max_stamina * PC.BATTLE_START_STAMINA_PCT); this.exhausted = false; }
  spend_stamina(amount) {
    if (this.stamina < amount) return false;
    this.stamina -= amount;
    if (this.stamina <= 0) this.exhausted = true;
    return true;
  }
  regen_stamina(amount) {
    let gain = amount;
    if (this.exhausted) gain = round(amount * PC.EXHAUSTED_STAMINA_REGEN_MULT);
    this.stamina = clamp(this.stamina + gain, 0, this.max_stamina);
    if (this.exhausted && this.stamina >= this.max_stamina * PC.EXHAUSTED_CLEAR_STAMINA_PCT) this.exhausted = false;
  }
  add_coins(amount) {
    let bonus_amount = amount;
    const pct = this.meta_bonus_coin_pct + this.talisman_bonus("coin_pct");
    if (pct > 0) bonus_amount = round(amount * (1.0 + pct));
    this.coins += bonus_amount;
  }

  // ------------------------------------------------------------ items
  use_healing_item() {
    if (this.potion_queue.length === 0 || this.talisman_bonus("disable_healing_items") > 0) return null;
    return this._consume_potion(this.potion_queue.shift());
  }
  use_specific_potion(id) {
    if (this.talisman_bonus("disable_healing_items") > 0) return null;
    const idx = this.potion_queue.indexOf(id);
    if (idx === -1) return null;
    this.potion_queue.splice(idx, 1);
    return this._consume_potion(id);
  }
  _consume_potion(id) {
    const tier = consumableById(id);
    let heal_amount = tier.heal_amount !== undefined ? tier.heal_amount : PC.ITEM_HEAL_AMOUNT;
    const heal_bonus_pct = this.meta_healing_bonus_pct + this.talisman_bonus("heal_pct");
    if (heal_bonus_pct > 0) heal_amount = round(heal_amount * (1.0 + heal_bonus_pct));
    this.heal(heal_amount);
    let stamina_restored = tier.stamina_amount || 0;
    if (stamina_restored > 0) {
      const before = this.stamina;
      this.regen_stamina(stamina_restored);
      stamina_restored = this.stamina - before;
    }
    if (this.meta_battle_medic) this.regen_stamina(20);
    return Object.assign({}, tier, { healed: heal_amount, stamina_restored });
  }

  // ------------------------------------------------------------ damage
  _try_phoenix() {
    if (this.phoenix_used || this.talisman_bonus("phoenix") <= 0) return false;
    this.phoenix_used = true; this.health = 1; return true;
  }
  take_battle_damage(amount) {
    this.health -= amount;
    if (this.health <= 0) {
      const survive = this.meta_favour_chance + this.talisman_bonus("survive_lethal");
      if (survive > 0 && this.rng.randf() < survive && !this.second_chance_used_this_battle) {
        this.second_chance_used_this_battle = true; this.health = 1; return;
      }
      if (this._try_phoenix()) return;
      this.health = 0;
      this.died = true;
    }
  }

  // ------------------------------------------------------------ xp / level-up
  gain_xp(amount) {
    if (this.level >= PC.MAX_LEVEL) return 0;
    const xp_pct = this.talisman_bonus("xp_pct");
    if (xp_pct > 0) amount = round(amount * (1.0 + xp_pct));
    this.xp += amount;
    let ups = 0;
    while (this.xp >= this.xp_to_next && this.level < PC.MAX_LEVEL) {
      this.xp -= this.xp_to_next;
      this._level_up();
      ups++;
    }
    return ups;
  }
  _level_up() {
    this.level += 1;
    this.stat_intimidation += 1; this.stat_strength += 1; this.stat_vigor += 1; this.stat_agility += 1; this.stat_might += 1;
    if (this.meta_resilience_unlocked) this.stat_resilience += 1;
    if (this.meta_reflexes_unlocked) this.stat_reflexes += 1;
    if (this.meta_dexterity_unlocked) this.stat_dexterity += 1;
    if (this.level >= PC.MAX_LEVEL) { this.xp = 0; this.xp_to_next = 0; }
    else this.xp_to_next = PC.XP_BASE + PC.XP_PER_LEVEL * this.level;
    this._recalc_stats();
    this.awaiting_bonus += 1;
  }
  apply_bonus_stat(stat) {
    if (this.awaiting_bonus <= 0) return false;
    this._apply_pick(stat, this.meta_bonus_levelup_stat ? 2 : 1);
    this.awaiting_bonus -= 1;
    this._recalc_stats();
    return true;
  }
  _recalc_stats() {
    const old_max = this.max_health;
    this.max_health = this.meta_worldwalker ? round(this.stat_vigor * (1.0 + PC.WORLDWALKER_HP_BONUS_PCT)) : this.stat_vigor;
    this.max_health += Math.trunc(this.talisman_bonus("max_hp")) + this.hardened_hp_bonus;
    const pct = this.talisman_bonus("max_hp_pct");
    if (pct !== 0) this.max_health = Math.max(1, round(this.max_health * (1.0 + pct)));
    this.health += this.max_health - old_max;
    this.health = clamp(this.health, 0, this.max_health);
    if (this.talisman_bonus("lock_hp_to_one") > 0) { this.max_health = 1; this.health = Math.min(this.health, 1); }
    this.attack_damage = this.meta_worldwalker ? round(this.stat_strength * (1.0 + PC.WORLDWALKER_DAMAGE_BONUS_PCT)) : this.stat_strength;
    this.move_speed = this.stat_agility * (1.0 + this.talisman_bonus("move_speed_pct") + this.bloodmoon_stacks * PC.BLOODMOON_SPEED_PCT_PER_STACK);
    this.resilience_reduction = Math.min(PC.RESILIENCE_REDUCTION_CAP, this.stat_resilience * PC.RESILIENCE_PCT_PER_POINT);
    this.meta_dodge_chance = Math.min(PC.REFLEXES_DODGE_CAP, this.stat_reflexes * PC.REFLEXES_PCT_PER_POINT);
    this.meta_crit_chance = Math.min(PC.DEXTERITY_CRIT_CAP, this.stat_dexterity * PC.DEXTERITY_PCT_PER_POINT);
  }
}

// ---------------------------------------------------------------- shared small helpers
function isEmpty(o) { return !o || Object.keys(o).length === 0; }
function shieldBaseWeaponId(id) {
  for (const b of D.shield_compatible) if (id === b || id.startsWith(b + "_")) return b;
  return id;
}
function shieldWeaponCompatible(id) { return D.shield_compatible.includes(shieldBaseWeaponId(id)); }
// Dojo.locate_special: any special (any weapon) by id; returns a copy-able special dict.
function locateSpecial(id) {
  for (const b of weaponBases()) for (const sp of (b.specials || [])) if (sp.id === id) return sp;
  return null;
}
