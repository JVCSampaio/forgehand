// Monster AI: perception (vision, hearing, smell, magic sense) and decisions.
// All behaviour is parameterised by monster data; no per-species branches.
import { findPath, lineOfSight, lineCells, T } from './level.js';
import { PROPS } from '../content/world.js';
import { cheb, monsterMelee, monsterBolt } from './combat.js';
import { totalBleed } from './body.js';
import { createMonster } from './entity.js';

const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

export function hostilesOf(world, a) {
  const out = [];
  const p = world.player;
  if (a.team === 'hostile') {
    if (p.alive) out.push(p);
    for (const m of world.level.actors) if (m.alive && m.team === 'player') out.push(m);
  } else {
    for (const m of world.level.actors) if (m.alive && m.team === 'hostile') out.push(m);
  }
  return out;
}

function canDetect(world, m, t) {
  const def = m.def;
  const d = dist(m, t);
  const vision = def.senses.vision;
  if (d > vision) return false;
  if (!lineOfSight(world.level, m.x, m.y, t.x, t.y)) return false;
  if (d <= 1.5) return true;
  const light = world.level.light[world.level.idx(t.x, t.y)];
  const dark = def.senses.dark ?? (def.undead || def.family === 'crawler' || def.family === 'quadruped' ? 3 : 1.5);
  const tracking = m.ai.target === t && world.now - (m.ai.seenAt || -1e9) < 1500;
  if (tracking) return light > 0.06 || d <= dark + 1.5;
  let p = light > 0.12 ? Math.min(1, 0.3 + light * 0.55) : d <= dark ? 0.45 : 0.015;
  p *= Math.max(0.12, 1 - d / (vision + 2));
  if (t.isPlayer) {
    if (t.sneaking) p *= 0.45;
    p *= 1 - Math.min(0.6, t.skills.stealth.level * 0.04);
  }
  return world.rng.chance(p);
}

export function perceive(world, m) {
  const ai = m.ai;
  if (!m.alive) return;
  if (ai.state === 'sleep') {
    const p = world.player;
    if (p.alive && cheb(m, p) <= 1 && world.rng.chance(p.sneaking ? 0.03 : 0.12)) wake(world, m);
    return;
  }
  for (const t of hostilesOf(world, m)) {
    if (!canDetect(world, m, t)) continue;
    const fresh = ai.state !== 'hunt' && ai.state !== 'flee';
    ai.target = t;
    ai.lastKnown = [t.x, t.y];
    ai.seenAt = world.now;
    if (fresh) {
      ai.state = 'hunt';
      if (t.isPlayer && m.team === 'hostile') world.onNoticed(m);
    }
    return;
  }
  // Smell: blood trails lead scavengers to wounded prey.
  const smell = m.def.senses.smell;
  const p = world.player;
  if (smell && m.team === 'hostile' && ai.state !== 'hunt' && p.alive) {
    const bleeding = totalBleed(p.body) > 0.03;
    if (bleeding && dist(m, p) <= smell) investigate(world, m, p.x, p.y, 1, 'cheiro de sangue');
  }
}

export function wake(world, m) {
  if (m.ai.state !== 'sleep') return;
  m.ai.state = 'idle';
  m.ai.nextThink = world.now + 400;
  if (world.isVisible(m.x, m.y)) world.msg(`${m.name} acorda.`, 'warn');
}

export function investigate(world, m, x, y, fuzz = 2, why = 'ruído') {
  const ai = m.ai;
  if (m.team !== 'hostile') return;
  if (ai.state === 'hunt' && world.now - (ai.seenAt || 0) < 4000) return;
  const rng = world.rng;
  ai.state = 'investigate';
  // Hearing is imprecise, but the guess must be somewhere one can stand.
  let tx = x + rng.int(-fuzz, fuzz);
  let ty = y + rng.int(-fuzz, fuzz);
  if (!world.level.isFloorLike(tx, ty)) {
    tx = x;
    ty = y;
  }
  ai.lastKnown = [tx, ty];
  ai.investigateUntil = world.now + 14000;
  ai.why = why;
  ai.path = null;
}

// Called when a noise reaches a monster.
export function hearNoise(world, m, x, y, remaining) {
  if (m.team !== 'hostile' || !m.alive) return;
  const heard = remaining * m.def.senses.hearing;
  if (m.ai.state === 'sleep') {
    if (heard >= 2.5 || world.rng.chance(heard / 5)) wake(world, m);
    else return;
  }
  if (heard >= 0.8) investigate(world, m, x, y, heard > 10 ? 1 : 2);
}

function wait(world, m, ms, label = 'aguardando') {
  world.startAction(m, { type: 'wait', label, duration: ms });
}

export function think(world, m) {
  const ai = m.ai;
  const def = m.def;
  const now = world.now;
  if (m.expires && now > m.expires) {
    world.crumble(m);
    return;
  }
  if (m.effects.stuckUntil > now) return wait(world, m, m.effects.stuckUntil - now, 'preso na teia');
  if (ai.state === 'sleep') return wait(world, m, 800, 'dormindo');
  if (m.team === 'player') return thinkAlly(world, m);

  const cow = def.behavior?.cowardice;
  if (cow && ai.state === 'hunt' && m.hp < m.maxHp * cow && !ai.fled) {
    ai.state = 'flee';
    ai.fled = true;
    ai.fleeUntil = now + 7000;
    if (world.isVisible(m.x, m.y)) world.msg(`${m.name} foge!`, 'info');
  }
  if (ai.state === 'flee') {
    if (now > ai.fleeUntil || !ai.target?.alive) {
      ai.state = 'investigate';
      ai.investigateUntil = now + 8000;
    } else return flee(world, m, ai.target);
  }
  if (ai.state === 'hunt') {
    const t = ai.target;
    if (!t || !t.alive) {
      ai.state = 'idle';
      return wait(world, m, 500);
    }
    if (now - (ai.seenAt || 0) > 5000) {
      investigate(world, m, ...(ai.lastKnown || [m.x, m.y]), 0, 'rastro');
      return wait(world, m, 200);
    }
    return hunt(world, m, t);
  }
  if (ai.state === 'investigate') {
    if (now > ai.investigateUntil || !ai.lastKnown) {
      ai.state = 'idle';
      return wait(world, m, 600, 'escutando');
    }
    const [tx, ty] = ai.lastKnown;
    if (cheb(m, { x: tx, y: ty }) <= 1) {
      ai.lastKnown = null;
      return wait(world, m, 1600, 'procurando');
    }
    if (!stepToward(world, m, tx, ty, !world.level.isPassable(tx, ty) || !!world.actorAt(tx, ty))) {
      ai.lastKnown = null;
      return wait(world, m, 700);
    }
    return;
  }
  // idle
  if (def.behavior?.wanders && world.rng.chance(0.35)) {
    const rng = world.rng;
    for (let t = 0; t < 6; t++) {
      const tx = m.x + rng.int(-6, 6);
      const ty = m.y + rng.int(-6, 6);
      if (world.level.isPassable(tx, ty) && !world.actorAt(tx, ty)) {
        ai.state = 'investigate';
        ai.lastKnown = [tx, ty];
        ai.investigateUntil = now + 9000;
        ai.why = 'vagando';
        return wait(world, m, 300, 'vagando');
      }
    }
  }
  return wait(world, m, world.rng.int(900, 2200), 'parado');
}

function hunt(world, m, t) {
  const def = m.def;
  const now = world.now;
  const d = cheb(m, t);
  const los = lineOfSight(world.level, m.x, m.y, t.x, t.y);
  for (const ab of def.abilities || []) {
    if ((m.cooldowns[ab.type] || 0) > now) continue;
    if (tryAbility(world, m, t, ab, d, los)) {
      m.cooldowns[ab.type] = now + ab.cooldown;
      return;
    }
  }
  if (def.behavior?.caster && d < 3 && los && world.rng.chance(0.6)) {
    if (flee(world, m, t, true)) return;
  }
  if (d <= 1) {
    const atk = world.rng.weighted(def.attacks.map((a) => [a, a.weight || 1]));
    const slow = m.effects.slowUntil > now ? 1.5 : 1;
    const total = (atk.windup + atk.recover) * slow;
    world.startAction(m, {
      type: 'attack', label: atk.name, duration: total, commitAt: atk.windup / (atk.windup + atk.recover),
      target: t, onCommit: () => monsterMelee(world, m, t, atk),
    });
    m.facing = Math.atan2(t.y - m.y, t.x - m.x);
    return;
  }
  if (!stepToward(world, m, t.x, t.y, true)) wait(world, m, 400, 'rondando');
}

function tryAbility(world, m, t, ab, d, los) {
  const now = world.now;
  const slow = m.effects.slowUntil > now ? 1.5 : 1;
  switch (ab.type) {
    case 'shout':
      if (m.ai.shouted) return false;
      m.ai.shouted = true;
      world.startAction(m, {
        type: 'ability', label: ab.name, duration: ab.windup,
        onCommit: () => {
          world.emitNoise(m.x, m.y, ab.noise, { source: m, label: 'um grito' });
          if (world.isVisible(m.x, m.y)) world.msg(`${m.name} grita, alertando o andar!`, 'warn');
        },
      });
      return true;
    case 'bolt':
      if (!los || d < 2 || d > ab.range) return false;
      world.startAction(m, {
        type: 'cast', label: `conjurando ${ab.name}`, duration: ab.windup * slow, interruptible: true, target: t,
        onCommit: () => {
          if (t.alive && lineOfSight(world.level, m.x, m.y, t.x, t.y)) monsterBolt(world, m, ab, t);
        },
      });
      world.emitMagic(m.x, m.y, 0);
      return true;
    case 'pounce': {
      if (!los || d < 2 || d > ab.range) return false;
      world.startAction(m, {
        type: 'ability', label: `preparando ${ab.name}`, duration: ab.windup * slow, target: t,
        onCommit: () => pounce(world, m, t, ab),
      });
      return true;
    }
    case 'sweep': {
      if (d > 1 || !world.rng.chance(0.45)) return false;
      world.startAction(m, {
        type: 'ability', label: ab.name, duration: ab.windup * slow,
        onCommit: () => {
          for (const h of hostilesOf(world, m)) if (cheb(m, h) <= 1) monsterMelee(world, m, h, { name: ab.name, dmg: ab.dmg, fracture: 0.1 });
          world.events.push({ type: 'sweep', x: m.x, y: m.y });
        },
      });
      return true;
    }
    case 'summon': {
      if (m.hp > m.maxHp * ab.hpBelow) return false;
      world.startAction(m, {
        type: 'ability', label: ab.name, duration: ab.windup * slow,
        onCommit: () => summon(world, m, ab),
      });
      return true;
    }
    default:
      return false;
  }
}

function pounce(world, m, t, ab) {
  if (!t.alive) return;
  const cells = lineCells(m.x, m.y, t.x, t.y);
  let land = null;
  for (const [x, y] of cells) {
    if (x === t.x && y === t.y) break;
    if (!world.level.isPassable(x, y) || world.actorAt(x, y)) break;
    land = [x, y];
  }
  if (land) {
    m.px = m.x;
    m.py = m.y;
    m.x = land[0];
    m.y = land[1];
    m.moveT0 = world.now;
    m.moveT1 = world.now + 180;
    m.leap = true;
  }
  world.emitNoise(m.x, m.y, 3, { source: m, label: 'algo saltando' });
  if (cheb(m, t) <= 1) monsterMelee(world, m, t, { name: ab.name, dmg: ab.dmg, poison: ab.poison });
  else if (world.isVisible(m.x, m.y)) world.msg(`${m.name} salta e erra o bote.`, 'good');
}

function summon(world, m, ab) {
  world.emitNoise(m.x, m.y, ab.noise || 12, { source: m, label: 'um brado' });
  if (world.isVisible(m.x, m.y)) world.msg(`${m.name}: ${ab.name} O chão se abre em ossos.`, 'danger');
  let n = 0;
  for (let r = 1; r <= 3 && n < ab.count; r++) {
    for (let dy = -r; dy <= r && n < ab.count; dy++) {
      for (let dx = -r; dx <= r && n < ab.count; dx++) {
        const x = m.x + dx;
        const y = m.y + dy;
        if (!world.level.isPassable(x, y) || world.actorAt(x, y)) continue;
        if (world.level.tile(x, y) === T.DOOR) continue;
        const s = createMonster(ab.summon, x, y, world.rng, { awake: true });
        s.ai.state = 'hunt';
        s.ai.target = m.ai.target;
        s.ai.lastKnown = m.ai.lastKnown;
        s.ai.seenAt = world.now;
        world.level.actors.push(s);
        world.events.push({ type: 'raise', x, y });
        n++;
      }
    }
  }
}

function flee(world, m, t, backOff = false) {
  let best = null;
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      if (!dx && !dy) continue;
      const nx = m.x + dx;
      const ny = m.y + dy;
      if (!world.level.canStep(m.x, m.y, nx, ny) || world.actorAt(nx, ny)) continue;
      const d = Math.hypot(nx - t.x, ny - t.y);
      if (!best || d > best.d) best = { nx, ny, d };
    }
  }
  if (!best || best.d <= Math.hypot(m.x - t.x, m.y - t.y)) {
    if (backOff) return false;
    return hunt(world, m, t);
  }
  world.startMove(m, best.nx, best.ny);
  return true;
}

function thinkAlly(world, m) {
  const p = world.player;
  let best = null;
  for (const h of hostilesOf(world, m)) {
    const d = dist(m, h);
    if (d > 9 || !lineOfSight(world.level, m.x, m.y, h.x, h.y)) continue;
    if (!best || d < best.d) best = { h, d };
  }
  if (best) {
    m.ai.target = best.h;
    return hunt(world, m, best.h);
  }
  if (p.alive && cheb(m, p) > 2) {
    if (stepToward(world, m, p.x, p.y, true)) return;
  }
  return wait(world, m, 700, 'seguindo');
}

// Move one step toward (tx,ty), dealing with doors and furniture on the way.
export function stepToward(world, m, tx, ty, adjacent) {
  const level = world.level;
  const b = m.def.behavior || {};
  const path = findPath(level, m.x, m.y, tx, ty, {
    canOpenDoors: b.canOpenDoors, bashes: b.bashes || b.doorBreaker, avoidActors: m, toAdjacent: adjacent,
    maxNodes: 5000, webWalker: m.def.webs,
  });
  if (!path || !path.length) return false;
  const [nx, ny] = path[0];
  const door = level.door(nx, ny);
  if (door && !door.open && !door.broken) {
    if (b.canOpenDoors && door.barricade === 0) {
      world.startAction(m, {
        type: 'door', label: 'abrindo porta', duration: 500,
        onCommit: () => world.setDoor(nx, ny, true, m),
      });
      return true;
    }
    if (b.bashes || b.doorBreaker) {
      world.startAction(m, {
        type: 'bash', label: 'arrombando', duration: 900, target: { x: nx, y: ny },
        onCommit: () => world.bashDoor(m, nx, ny),
      });
      return true;
    }
    return false;
  }
  const prop = level.prop(nx, ny);
  if (prop && PROPS[prop.id].blocks) {
    if (!(b.bashes || b.doorBreaker) || PROPS[prop.id].hp >= 999) return false;
    world.startAction(m, {
      type: 'bash', label: 'quebrando obstáculo', duration: 900, target: { x: nx, y: ny },
      onCommit: () => world.bashProp(m, prop),
    });
    return true;
  }
  const other = world.actorAt(nx, ny);
  if (other) {
    if (other.team !== m.team) return false;
    wait(world, m, 250, 'esperando passagem');
    return true;
  }
  if (!level.canStep(m.x, m.y, nx, ny)) return false;
  world.startMove(m, nx, ny);
  return true;
}

export function intentLabel(world, a) {
  if (!a.alive) return '';
  const act = a.action;
  const ai = a.ai;
  if (ai?.state === 'sleep') return 'dormindo';
  if (act) {
    const pct = Math.round(((world.now - act.t0) / Math.max(1, act.t1 - act.t0)) * 100);
    if (act.type === 'attack') return `atacando: ${act.label} ${Math.min(99, pct)}%`;
    if (act.type === 'cast' || act.type === 'ability') return `${act.label} ${Math.min(99, pct)}%`;
    if (act.type === 'bash') return act.label;
    if (act.type === 'door') return act.label;
    if (act.type === 'wait' && act.label === 'preso na teia') return act.label;
  }
  if (a.team === 'player') return 'servo';
  switch (ai?.state) {
    case 'hunt': return 'avançando';
    case 'flee': return 'fugindo';
    case 'investigate': return ai.why === 'vagando' ? 'vagando' : `investigando ${ai.why || 'ruído'}`;
    default: return act?.label || 'parado';
  }
}

