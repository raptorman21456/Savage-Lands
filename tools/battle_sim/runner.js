/* Runner: builds a Sim from a config, plus an auto-player and batch runner for balance runs. */
"use strict";

// Stats the level-up bonus pick can go into (Player.apply_bonus_stat).
const PICK_STATS = ["strength", "vigor", "agility", "might", "intimidation", "resilience", "reflexes", "dexterity"];

function createSim(cfg, seed) {
  const sim = new Sim(seed ?? cfg.seed ?? 1);
  sim.player.configure(cfg);
  sim.setup_battle({ enemies: cfg.enemies, world: cfg.world });
  return sim;
}

// ------------------------------------------------------------------ auto player
const DEFAULT_POLICY = {
  heal_below: 0.35,          // drink a healing item under this HP fraction
  stamina_reserve: 0,        // keep this much stamina back before using specials/heavy
  use_specials: true,
  use_heavy: true,
  use_arrows: true,
  picks: ["strength", "vigor", "strength", "vigor", "agility"],   // cycled level-up picks
  max_turns: 60,
  taunt_when_surrounded: false,
};

function bfsReachable(sim, budget) {
  // tiles the player can reach this turn with `budget` movement, mirroring _resolve_battle_step
  const start = sim.battle_player_tile;
  const best = new Map([[vkey(start), { tile: start, left: budget, path: [] }]]);
  const queue = [best.get(vkey(start))];
  while (queue.length) {
    const cur = queue.shift();
    if (cur.left <= 0) continue;
    for (const dir of CARDINAL_DIRS) {
      const saved = sim.battle_player_tile;
      sim.battle_player_tile = cur.tile;
      const r = sim._resolve_battle_step(cur.tile, dir);
      sim.battle_player_tile = saved;
      if (!r.moved) continue;
      const left = cur.left - (r.extra_cost ? 2 : 1);
      if (left < 0) continue;
      const k = vkey(r.tile);
      if (best.has(k) && best.get(k).left >= left) continue;
      if (r.fell) continue;                       // a planner never walks off a cliff
      const node = { tile: r.tile, left, path: cur.path.concat([dir]) };
      best.set(k, node);
      queue.push(node);
    }
  }
  return [...best.values()];
}

function weaponReach(sim) {
  const w = sim.player.current_weapon;
  return { range: (w.long_range ? 2 : 1) + Math.trunc(w.passive_extra_range || 0), unlimited: !!w.passive_unlimited_range, ignore_line: sim._player_has_spear() };
}

function canHitFrom(sim, tile, reach) {
  if (reach.unlimited) return sim.battle_units.length > 0;
  for (const u of sim.battle_units) {
    const size = u.size ?? 1;
    if (size > 1) { if (sim._footprint_dist(sim._footprint(u.tile, size), tile) <= reach.range) return true; }
    else if (sim._can_battle_attack(tile, u.tile, reach.range, reach.ignore_line)) return true;
  }
  return false;
}

function nearestEnemyDist(sim, tile) {
  let best = 9999;
  for (const u of sim.battle_units) best = Math.min(best, sim._footprint_dist(sim._footprint(u.tile, u.size ?? 1), tile));
  return best;
}

async function autoStatPick(sim, policy) {
  const p = sim.player;
  let n = 0;
  while (p.awaiting_bonus > 0) {
    const stat = policy.picks[n % policy.picks.length] || "strength";
    p.apply_bonus_stat(stat);
    n++;
  }
}

async function autoPlayerTurn(sim, policy) {
  const p = sim.player;
  await autoStatPick(sim, policy);
  if (!sim.can_act()) return;
  const av0 = sim.availability();
  // 1. heal when low
  if (av0.item && p.health < p.max_health * policy.heal_below) {
    const next = consumableById(p.potion_queue[0]);
    if (next && (next.heal_amount || 0) > 0) { await sim.do_action("item"); return; }
  }
  // 2. cleanse when badly afflicted
  // 3. attack if something is in reach, otherwise move and attack
  let reach = weaponReach(sim);
  let inReach = sim._targetable_indices().length > 0;
  if (!inReach && sim.availability().move) {
    // walk the shortest path (over as many turns as it takes) to a tile from which something can be hit
    const tiles = bfsReachable(sim, 99);
    let pick = null;
    for (const n of tiles) if (canHitFrom(sim, n.tile, reach) && (!pick || n.path.length < pick.path.length)) pick = n;
    if (!pick) { let bd = 1e9; for (const n of tiles) { const d = nearestEnemyDist(sim, n.tile) + n.path.length * 0.01; if (d < bd) { bd = d; pick = n; } } }
    if (pick && pick.path.length > 0) {
      sim.begin_move();
      for (const dir of pick.path) { if (sim.battle_player_moves_left <= 0) break; sim.step_move(dir); }
      sim.confirm_move();
      if (sim.over) return;
      inReach = sim._targetable_indices().length > 0;
    }
  }
  if (sim.is_disarmed()) { await sim.do_action("defend"); return; }
  if (inReach) {
    const av = sim.availability();
    const w = p.current_weapon;
    const bow = sim._player_has_bow();
    const reserve = policy.stamina_reserve;
    // bow arrows
    if (bow && policy.use_arrows) {
      const idxs = sim._targetable_indices();
      if ((p.owned_arrows.bomb || 0) > 0 && idxs.length >= 2) { await sim.do_action("arrow", "bomb"); return; }
      const strong = sim.battle_units.some((u) => u.max_hp >= p.attack_damage * 6);
      if ((p.owned_arrows.freeze || 0) > 0 && strong) { await sim.do_action("arrow", "freeze"); return; }
      if ((p.owned_arrows.flame || 0) > 0 && strong) { await sim.do_action("arrow", "flame"); return; }
    }
    // best affordable special: highest damage multiplier per stamina, leaving the reserve
    if (policy.use_specials && !bow) {
      let bestI = -1, bestV = 0;
      (w.specials || []).forEach((sp, i) => {
        if (!av.specials[i]) return;
        const cost = w.passive_free_specials ? 0 : sp.stamina_cost;
        if (p.stamina - cost < reserve) return;
        const hits = sp.hit_count_max ? (sp.hit_count_min + sp.hit_count_max) / 2 : sp.pass_count_max ? (sp.pass_count_min + sp.pass_count_max) / 2 : 1;
        const value = Math.max(sp.dmg_mult || 0, 0.01) * hits;
        const special_bonus = ["execution", "target_practice"].includes(sp.effect) ? 3 : 0;
        const v = (value + special_bonus) / Math.max(1, cost);
        if (sp.effect === "pichaku" && p.pichaku_active) return;
        if (!specialUseful(sim, sp)) return;
        if (["devastating_slash", "knife_throw", "target_practice", "diamonds"].includes(sp.effect)) return;   // risky self-penalty moves: left to manual play
        if (v > bestV) { bestV = v; bestI = i; }
      });
      if (bestI >= 0 && p.stamina >= (w.specials[bestI].stamina_cost || 0) + reserve && p.stamina > p.max_stamina * 0.5) { await sim.do_action("special", bestI); return; }
    }
    if (policy.use_heavy && av.heavy && p.stamina - (w.heavy_stamina_cost_override ?? W.consts.HEAVY_STAMINA_COST) >= reserve && p.stamina > p.max_stamina * 0.6) { await sim.do_action("heavy"); return; }
    if (av.attack) { await sim.do_action("attack"); return; }
    if (av.heavy) { await sim.do_action("heavy"); return; }
  }
  await sim.do_action("defend");
}

async function autoAllyTurn(sim) {
  const u = sim.battle_commanding_ally;
  if (!u) return;
  if (sim._ally_targetable_indices(u).length === 0 && sim.battle_ally_moves_left > 0) {
    sim.begin_move();
    const reach = u.attack_range;
    // walk toward the nearest enemy, one step at a time, stopping once something is in reach
    for (let guard = 0; guard < 12 && sim.battle_ally_moves_left > 0 && sim._ally_targetable_indices(u).length === 0; guard++) {
      let target = null, td = 9999;
      for (const e of sim.battle_units) { const d = sim._footprint_dist(sim._footprint(e.tile, e.size ?? 1), u.tile); if (d < td) { td = d; target = e; } }
      if (!target) break;
      const dx = target.tile.x - u.tile.x, dy = target.tile.y - u.tile.y;
      const dirs = [];
      if (Math.abs(dx) >= Math.abs(dy)) { if (dx) dirs.push(V(sign(dx), 0)); if (dy) dirs.push(V(0, sign(dy))); }
      else { if (dy) dirs.push(V(0, sign(dy))); if (dx) dirs.push(V(sign(dx), 0)); }
      let moved = false;
      for (const d of dirs) { const before = u.tile; sim.step_move(d); if (!veq(before, u.tile)) { moved = true; break; } }
      if (!moved) break;
      void reach;
    }
    sim.confirm_move();
  }
  if (sim.over) return;
  if (sim._ally_targetable_indices(u).length > 0) await sim.ally_action("attack");
  else await sim.ally_action("guard");
}

// Plays one battle to the end. onStep (optional) is awaited after every player/ally command.
async function autoPlay(sim, policy, onStep) {
  policy = Object.assign({}, DEFAULT_POLICY, policy || {});
  sim.promptHandler = async (type, data) => (type === "evasion" ? Object.keys(data.options)[0] : type === "water_push" ? false : data.default);
  if (!sim.battle_use_timeline) await sim.timeline_begin();   // speed decides who acts first
  let guard = 0;
  while (sim.in_battle && !sim.over && guard++ < 5000) {
    if (sim.stats.turns >= policy.max_turns) { sim.over = true; sim.in_battle = false; sim.result = "timeout"; break; }
    if (sim.battle_commanding_ally) await autoAllyTurn(sim);
    else await autoPlayerTurn(sim, policy);
    if (onStep) await onStep();
  }
  return summarize(sim);
}

function summarize(sim) {
  const p = sim.player;
  return {
    result: sim.result || (sim.in_battle ? "unfinished" : "unknown"),
    turns: sim.stats.turns, hp_left: Math.max(0, p.health), hp_pct: Math.max(0, p.health) / p.max_health,
    damage_taken: sim.stats.damage_taken, damage_dealt: sim.stats.damage_dealt,
    potions: sim.stats.potions_used, stamina_spent: sim.stats.stamina_spent, kills: sim.stats.kills,
    xp: sim.stats.xp_gained, level_end: p.level,
  };
}

async function runBatch(cfg, n, policy, onProgress) {
  const rows = [];
  const base = (cfg.seed || 1) >>> 0;
  for (let i = 0; i < n; i++) {
    const sim = createSim(cfg, (base + i * 7919) >>> 0);
    const r = await autoPlay(sim, policy);
    rows.push(r);
    if (onProgress && (i % 10 === 0 || i === n - 1)) { await onProgress(i + 1, n); }
  }
  return aggregate(rows);
}

function aggregate(rows) {
  const n = rows.length;
  const count = (res) => rows.filter((r) => r.result === res).length;
  const avg = (f) => rows.reduce((a, r) => a + f(r), 0) / n;
  const wins = rows.filter((r) => r.result === "victory");
  const winAvg = (f) => (wins.length ? wins.reduce((a, r) => a + f(r), 0) / wins.length : 0);
  return {
    n, victories: count("victory"), defeats: count("defeat"), timeouts: count("timeout"), fled: count("fled"),
    win_rate: count("victory") / n,
    avg_turns: avg((r) => r.turns), avg_turns_win: winAvg((r) => r.turns),
    avg_hp_pct_win: winAvg((r) => r.hp_pct), avg_damage_taken: avg((r) => r.damage_taken),
    avg_damage_dealt: avg((r) => r.damage_dealt), avg_potions: avg((r) => r.potions), avg_xp: avg((r) => r.xp),
    rows,
  };
}

// A few specials are wasted (or refused outright) in some situations; a sensible player skips them then.
function specialUseful(sim, sp) {
  const p = sim.player;
  const ti = sim._effective_target_index();
  const target = ti >= 0 ? sim.battle_units[ti] : null;
  switch (sp.effect) {
    case "wide_cleave": {
      if (!target) return false;
      const dir = sim._knockback_dir(sim.battle_player_tile, target.tile);
      for (let k = 1; k <= 3; k++) if (sim._has_adjacent_rock(vadd(sim.battle_player_tile, vmul(dir, k)))) return false;
      return true;
    }
    case "execution": return !!target && !target.armored;
    case "crushing_collision": return !!target && !!target.armored;
    case "self_heal": return p.health < p.max_health * 0.6;
    case "leg_blow": return !!target && target.move_range > 1;
    default: return true;
  }
}
