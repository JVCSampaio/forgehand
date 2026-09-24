// Combat: melee, projectiles, spells and the DamageResolver.
import { ITEMS } from '../content/items.js';
import { HIT_PROFILES } from '../content/monsters.js';
import { SPELLS } from '../content/characters.js';
import { woundPart, limbOk, pain, WOUND_NAMES, bleedRate } from './body.js';
import { T, S, lineCells, lineOfSight, DIRS8 } from './level.js';
import { igniteCell, freezeCell, waterRegion, spillOil } from './systems.js';
import { PROPS } from '../content/world.js';

export const PART_LONG = {
  head: 'cabeça', torso: 'torso', armL: 'braço esquerdo', armR: 'braço direito', handL: 'mão esquerda',
  handR: 'mão direita', legL: 'perna esquerda', legR: 'perna direita', footL: 'pé esquerdo', footR: 'pé direito',
};

const PART_POSS = {
  head: 'sua', torso: 'seu', armL: 'seu', armR: 'seu', handL: 'sua', handR: 'sua', legL: 'sua', legR: 'sua', footL: 'seu', footR: 'seu',
};

export const cheb = (a, b) => Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y));

export function weaponOf(p) {
  const it = p.equip.main;
  return it ? { it, def: ITEMS[it.id] } : { it: null, def: ITEMS.fists };
}

export function encumbrance(p) {
  let e = 0;
  for (const it of Object.values(p.equip)) if (it && ITEMS[it.id].encumbrance) e += ITEMS[it.id].encumbrance;
  return Math.max(0, e - p.skills.armour.level * 0.35);
}

export function evasion(p) {
  return 3 + p.skills.dodging.level * 1.1 - encumbrance(p) * 0.8 - pain(p.body) * 0.03;
}

export function handPenalty(p, def) {
  const b = p.body;
  if (def.hands === 2) {
    const ok = limbOk(b, 'armL') && limbOk(b, 'armR') && limbOk(b, 'handL') && limbOk(b, 'handR');
    if (!ok) return { acc: 0.38, time: 1.7, dmg: 0.45, bad: true };
    const splinted = ['armL', 'armR', 'handL', 'handR'].some((k) => b.parts[k].wounds.some((w) => w.type === 'fracture'));
    if (splinted) return { acc: 0.15, time: 1.25, dmg: 0.8 };
  } else if (!limbOk(b, 'armR') || !limbOk(b, 'handR')) {
    return def.light ? { acc: 0.1, time: 1.15, dmg: 0.85 } : { acc: 0.3, time: 1.45, dmg: 0.6, bad: true };
  }
  return { acc: 0, time: 1, dmg: 1 };
}

export function statusMult(p) {
  let m = 1 + pain(p.body) * 0.004;
  if (p.needs.fatigue > 75) m += 0.15;
  if (p.stamina < 15) m += 0.35;
  m += encumbrance(p) * 0.03;
  if (p.effects.slowUntil > 0) m += 0.5;
  return m;
}

export function playerAttackTime(p) {
  const { def } = weaponOf(p);
  const skill = p.skills[def.skill]?.level || 0;
  return def.swing * (1 - Math.min(0.35, skill * 0.025)) * statusMult(p) * handPenalty(p, def).time;
}

function rollDamage(rng, ranges, mult) {
  const out = {};
  for (const [type, [lo, hi]] of Object.entries(ranges)) out[type] = rng.range(lo, hi) * mult;
  return out;
}

function sumDmg(d) {
  let s = 0;
  for (const v of Object.values(d)) s += v;
  return s;
}

// ------------------------------------------------------------------ melee
export function playerMelee(world, p, target) {
  const rng = world.rng;
  const { it, def } = weaponOf(p);
  const skill = p.skills[def.skill]?.level || 0;
  const hp = handPenalty(p, def);
  p.stamina = Math.max(0, p.stamina - def.stamina);
  world.emitNoise(p.x, p.y, def.noise, { source: p, label: 'combate' });
  world.train(def.skill, 0.4);
  const reach = def.ranged ? 1 : def.reach;
  if (!target.alive || cheb(p, target) > reach || (reach > 1 && !lineOfSight(world.level, p.x, p.y, target.x, target.y))) {
    world.msg('Você golpeia o ar.', 'info');
    return;
  }
  let acc = 0.64 + skill * 0.03 - (target.def?.evasion || 0) * 0.025 - pain(p.body) * 0.003 - hp.acc;
  if (p.needs.fear > 60) acc -= 0.1;
  if (p.needs.fatigue > 75) acc -= 0.08;
  if (target.ai?.state === 'sleep') acc += 0.3;
  if (!rng.chance(Math.max(0.05, Math.min(0.96, acc)))) {
    world.msg(`Você erra ${target.name}.`, 'info');
    world.events.push({ type: 'miss', x: target.x, y: target.y });
    return;
  }
  let mult = (1 + skill * 0.05) * hp.dmg * (p.stamina < 10 ? 0.65 : 1);
  if (it && it.cond !== undefined && it.cond <= 0) mult *= 0.35;
  let crit = false;
  if (target.ai?.state === 'sleep' || rng.chance(0.06 + p.skills.stealth.level * 0.005)) {
    crit = true;
    mult *= target.ai?.state === 'sleep' ? 2.2 : 1.5;
  }
  const dmg = rollDamage(rng, def.meleeDmg || def.dmg, mult);
  if (p.equip.off?.id === 'torch' && p.equip.off.fuel > 0) dmg.fire = rng.range(1, 3);
  world.damage(target, dmg, { source: p, label: def.name, fracture: def.fracture, crit });
  if (it && def.durability) wearWeapon(world, p, it, target.def?.armored ? 2 : 1);
}

export function wearWeapon(world, p, it, amount) {
  const def = ITEMS[it.id];
  const before = it.cond / def.durability;
  it.cond = Math.max(0, it.cond - amount);
  const after = it.cond / def.durability;
  if (it.cond <= 0 && before > 0) world.msg(`Sua ${def.name} QUEBROU.`, 'danger');
  else if (after < 0.25 && before >= 0.25) world.msg(`Sua ${def.name} está quebrando.`, 'warn');
}

export function monsterMelee(world, m, target, atk) {
  const rng = world.rng;
  if (!target.alive || cheb(m, target) > 1) {
    if (world.isVisible(m.x, m.y)) world.msg(`${m.name} golpeia o ar.`, 'info');
    return;
  }
  world.emitNoise(m.x, m.y, 3, { source: m, label: 'combate' });
  const dmg = rollDamage(rng, atk.dmg, 1 + (world.depth - 1) * 0.06);
  if (target.isPlayer) {
    let hit = 0.8 - evasion(target) * 0.028;
    if (target.effects.stuckUntil > world.now || target.effects.fallenUntil > world.now) hit += 0.3;
    if (target.action?.type === 'rest') hit += 0.3;
    if (!rng.chance(Math.max(0.1, Math.min(0.95, hit)))) {
      world.msg(`Você se esquiva de ${m.name}.`, 'good');
      world.train('dodging', 0.3);
      return;
    }
    const shield = target.equip.off && ITEMS[target.equip.off.id].block;
    if (shield && rng.chance(ITEMS[target.equip.off.id].block + target.skills.shields.level * 0.025)) {
      world.msg(`Você bloqueia ${atk.name} com o escudo.`, 'good');
      world.emitNoise(target.x, target.y, 5, { source: target, label: 'bloqueio' });
      target.equip.off.cond = Math.max(0, (target.equip.off.cond ?? 1) - 1);
      world.train('shields', 0.4);
      return;
    }
    world.damage(target, dmg, {
      source: m, label: atk.name, profile: m.def.targets, infect: atk.infect, fracture: atk.fracture, poison: atk.poison,
    });
  } else {
    if (!rng.chance(0.75 - (target.def.evasion || 0) * 0.02)) return;
    world.damage(target, dmg, { source: m, label: atk.name, poison: atk.poison });
  }
}

// ------------------------------------------------------------ DamageResolver
export function applyDamage(world, target, dmg, info) {
  if (!target.alive) return 0;
  return target.isPlayer ? damagePlayer(world, target, dmg, info) : damageMonster(world, target, dmg, info);
}

function sourceName(info) {
  if (!info.source) return info.sourceName || info.label || 'algo';
  return info.source.isPlayer ? 'você' : info.source.name;
}

function pickPart(rng, profile) {
  const table = HIT_PROFILES[profile || 'mid'];
  return rng.weighted(Object.entries(table));
}

function damagePlayer(world, p, dmg, info) {
  const rng = world.rng;
  const part = info.part || pickPart(rng, info.profile);
  const after = {};
  const armourSkill = p.skills.armour.level;
  const covering = Object.values(p.equip).filter((it) => it && ITEMS[it.id].covers?.includes(part) && (it.cond ?? 1) > 0);
  for (const [type, raw] of Object.entries(dmg)) {
    let v = raw;
    if (type === 'fire' && p.species.fireVuln) v *= p.species.fireVuln;
    for (const it of covering) {
      const prot = ITEMS[it.id].prot?.[type] || 0;
      if (prot > 0) v -= prot * (1 + armourSkill * 0.04) * rng.range(0.5, 1);
    }
    if (v > 0.3) after[type] = v;
  }
  const absorbed = sumDmg(dmg) - sumDmg(after);
  for (const it of covering) {
    if (absorbed > 0.5 && ITEMS[it.id].durability) {
      const def = ITEMS[it.id];
      const before = it.cond / def.durability;
      it.cond = Math.max(0, it.cond - 1);
      if (before >= 0.5 && it.cond / def.durability < 0.5) world.msg(`${def.name}: armadura danificada.`, 'warn');
      if (it.cond === 0) world.msg(`${def.name} se desfaz.`, 'danger');
    }
  }
  if (absorbed > 0.5) world.train('armour', 0.25);
  const src = sourceName(info);
  const total = sumDmg(after);
  world.events.push({ type: 'hit', target: p, amount: total, x: p.x, y: p.y });
  p.needs.fear = Math.min(100, p.needs.fear + 3 + total);
  if (total <= 0.3) {
    world.msg(`${capital(src)} atinge ${PART_POSS[part]} ${PART_LONG[part]}, mas a armadura segura.`, 'info');
    return 0;
  }
  const wounds = woundPart(p.body, part, after, { source: `${info.label} de ${src}`, infect: info.infect, fracture: info.fracture }, rng);
  const desc = wounds.map((w) => WOUND_NAMES[w.type]).join(', ') || 'golpe superficial';
  if (info.source === p) world.msg(`Sua própria ${info.label} atinge ${PART_POSS[part]} ${PART_LONG[part]}: ${desc}.`, 'danger');
  else world.msg(`${capital(src)} (${info.label}) → ${PART_LONG[part].toUpperCase()}: ${desc}.`, 'danger');
  for (const w of wounds) {
    if (w.type === 'fracture') world.msg(`${capital(PART_POSS[part])} ${PART_LONG[part]} está fraturad${PART_POSS[part] === 'sua' ? 'a' : 'o'}!`, 'danger');
    if (w.infection > 0) world.msg('A mordida parece suja. Pode infeccionar.', 'warn');
  }
  if (info.poison) {
    p.effects.poison = (p.effects.poison || 0) + info.poison;
    world.msg('Você foi envenenado.', 'danger');
  }
  if (bleedRate(wounds[0] || { bleed: 0, severity: 0 }) > 0.05 && world.level.tile(p.x, p.y) !== T.WATER) {
    world.level.setSurface(p.x, p.y, S.BLOOD, 60000);
  }
  p.lastHitBy = `${info.label} de ${src}`;
  p.lastBleedSource = wounds.find((w) => w.bleed > 0) ? p.lastHitBy : p.lastBleedSource;
  world.lastPlayerHurt = world.now;
  if (p.action && p.action.interruptible) world.interrupt(p, 'Você é interrompido!');
  world.checkPlayerDeath();
  return total;
}

function damageMonster(world, m, dmg, info) {
  const rng = world.rng;
  const def = m.def;
  let total = 0;
  const hitTypes = [];
  if (def.block && info.source && !info.spell && rng.chance(def.block)) {
    if (world.isVisible(m.x, m.y)) world.msg(`${m.name} bloqueia o golpe.`, 'info');
    world.emitNoise(m.x, m.y, 5, { source: m, label: 'bloqueio' });
    return 0;
  }
  for (const [type, raw] of Object.entries(dmg)) {
    let v = raw;
    const ac = def.ac?.[type];
    if (ac) v -= ac * rng.range(0.5, 1);
    if (def.resists?.[type]) v *= def.resists[type];
    if (type === 'poison' && def.undead) v = 0;
    if (v > 0) {
      total += v;
      hitTypes.push(type);
    }
  }
  if (info.poison && !def.undead) m.effects.poison = (m.effects.poison || 0) + info.poison;
  if (dmg.fire) m.effects.burnedAt = world.now;
  total = Math.round(total * 10) / 10;
  if (m.ai.state === 'sleep') m.ai.state = 'idle';
  if (info.source && info.source !== m) {
    m.ai.alerted = true;
    if (m.team === 'hostile' || info.source.team === 'hostile') {
      m.ai.target = info.source;
      m.ai.state = 'hunt';
      m.ai.lastKnown = [info.source.x, info.source.y];
      m.ai.seenAt = world.now;
    }
  }
  world.events.push({ type: 'hit', target: m, amount: total, x: m.x, y: m.y, crit: info.crit });
  if (def.bleeds && total > 2 && world.level.tile(m.x, m.y) === T.FLOOR) world.level.setSurface(m.x, m.y, S.BLOOD, 45000);
  if (total <= 0) {
    if (world.isVisible(m.x, m.y) && info.source?.isPlayer) world.msg(`O golpe não penetra ${m.name}.`, 'info');
    return 0;
  }
  m.hp -= total;
  m.lastHitBy = info.source;
  if (world.isVisible(m.x, m.y) && info.source?.isPlayer) {
    const wounded = m.hp / m.maxHp;
    const state = m.hp <= 0 ? '' : wounded < 0.25 ? ' (quase morto)' : wounded < 0.6 ? ' (ferido)' : '';
    world.msg(`${info.crit ? 'Crítico! ' : ''}Você acerta ${m.name} com ${info.label}${state}.`, 'good');
  }
  if (m.action?.interruptible && m.hp > 0) {
    world.interrupt(m, `${m.name} perde a concentração!`);
  }
  if (m.hp <= 0) world.kill(m, info.source);
  return total;
}

function capital(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// ---------------------------------------------------------------- firearms
export function shoot(world, p, tx, ty) {
  const rng = world.rng;
  const { it, def } = weaponOf(p);
  if (!def.ranged) return;
  if (it.mag <= 0) {
    world.msg('Clique. O pente está vazio.', 'warn');
    world.emitNoise(p.x, p.y, 2, { source: p, label: 'clique' });
    return;
  }
  it.mag--;
  p.stats.shots++;
  wearWeapon(world, p, it, 1);
  world.emitNoise(p.x, p.y, def.noise, { source: p, label: 'tiro' });
  world.flash(p.x, p.y, 5, 1.6, 0xffd08a, 90);
  world.train('firearms', 0.6);
  const cells = lineCells(p.x, p.y, tx, ty);
  // Extend the line past the target up to weapon range.
  const dx = tx - p.x;
  const dy = ty - p.y;
  const len = Math.max(Math.abs(dx), Math.abs(dy)) || 1;
  const far = lineCells(p.x, p.y, p.x + Math.round((dx / len) * def.range), p.y + Math.round((dy / len) * def.range));
  const path = far.length >= cells.length ? far : cells;
  let end = [p.x, p.y];
  const skill = p.skills.firearms.level;
  for (const [x, y] of path) {
    end = [x, y];
    const t = world.level.tile(x, y);
    if (t === T.WALL || t === T.ROCK || world.level.isOpaque(x, y)) {
      const prop = world.level.prop(x, y);
      if (prop && prop.id === 'barrel_oil') breakBarrel(world, prop);
      break;
    }
    const prop = world.level.prop(x, y);
    if (prop && PROPS[prop.id].blocks && prop.id === 'barrel_oil') {
      breakBarrel(world, prop);
      break;
    }
    const a = world.actorAt(x, y);
    if (a && a !== p) {
      const dist = Math.hypot(x - p.x, y - p.y);
      const acc = 0.62 + skill * 0.045 - dist * 0.025 - pain(p.body) * 0.004 - (a.def?.evasion || 0) * 0.015;
      if (rng.chance(Math.max(0.08, Math.min(0.95, acc)))) {
        const dmg = rollDamage(rng, def.dmg, 1 + skill * 0.03);
        world.damage(a, dmg, { source: p, label: def.name });
        break;
      }
      world.msg(`A bala passa raspando por ${a.name}.`, 'info');
    }
  }
  world.events.push({ type: 'tracer', x0: p.x, y0: p.y, x1: end[0], y1: end[1] });
  if (it.mag === 0) world.msg('Último tiro no pente.', 'warn');
}

function breakBarrel(world, prop) {
  const level = world.level;
  level.props.delete(level.idx(prop.x, prop.y));
  level.version++;
  spillOil(world, prop.x, prop.y, 1, 0.8);
  world.msg('O barril se rompe e óleo se espalha pelo chão.', 'warn');
  world.emitNoise(prop.x, prop.y, 6, { source: null, label: 'madeira quebrando' });
}

// ------------------------------------------------------------------ magic
export function spellFailure(p, spellId) {
  const sp = SPELLS[spellId];
  const school = p.skills[sp.school]?.level || 0;
  const casting = p.skills.spellcasting.level;
  let bonus = 0;
  for (const it of Object.values(p.equip)) if (it && ITEMS[it.id].spellBonus) bonus += ITEMS[it.id].spellBonus;
  let fail = 22 + sp.level * 12 - casting * 5 - school * 6 - bonus + encumbrance(p) * 6 + pain(p.body) * 0.25;
  if (p.needs.fear > 60) fail += 10;
  if (p.needs.fatigue > 80) fail += 8;
  return Math.max(1, Math.min(98, Math.round(fail)));
}

export function spellPower(p, spellId) {
  const sp = SPELLS[spellId];
  return 1 + (p.skills[sp.school]?.level || 0) * 0.08 + p.skills.spellcasting.level * 0.04;
}

export function castSpell(world, p, spellId, tx, ty) {
  const sp = SPELLS[spellId];
  const rng = world.rng;
  p.stats.spells++;
  world.train('spellcasting', 0.5);
  world.train(sp.school, 0.7);
  // Casting is felt by anything with magic sense.
  world.emitMagic(p.x, p.y, sp.level * 3 + 3);
  if (rng.chance(spellFailure(p, spellId) / 100)) {
    world.msg(`${sp.name} falha e se dissipa em faíscas.`, 'warn');
    world.emitNoise(p.x, p.y, 4, { source: p, label: 'magia' });
    world.events.push({ type: 'fizzle', x: p.x, y: p.y, color: sp.projectile?.color || 0xaaaaff });
    return;
  }
  const power = spellPower(p, spellId);
  if (sp.projectile) {
    world.spawnProjectile({
      owner: p, x: p.x, y: p.y, tx, ty, speed: sp.projectile.speed, color: sp.projectile.color,
      kind: spellId, range: sp.range, onHit: (x, y, victim) => detonate(world, p, spellId, x, y, victim, power),
    });
    world.emitNoise(p.x, p.y, spellId === 'fireball' ? 8 : 3, { source: p, label: 'magia' });
    return;
  }
  if (spellId === 'lightning') {
    const cells = lineCells(p.x, p.y, tx, ty);
    let end = [tx, ty];
    for (const [x, y] of cells) {
      if (world.level.isOpaque(x, y)) break;
      end = [x, y];
      if (world.actorAt(x, y)) break;
    }
    world.events.push({ type: 'lightning', x0: p.x, y0: p.y, x1: end[0], y1: end[1] });
    world.flash(end[0], end[1], 6, 1.6, 0xbfe3ff, 160);
    world.emitNoise(end[0], end[1], sp.noise, { source: p, label: 'trovão' });
    const victim = world.actorAt(end[0], end[1]);
    if (victim && victim !== p) world.damage(victim, rollDamage(rng, sp.dmg, power), { source: p, label: sp.name, spell: true });
    const region = waterRegion(world.level, end[0], end[1]);
    if (region.length) {
      world.msg('A descarga percorre a água!', 'magic');
      for (const [x, y] of region) {
        world.events.push({ type: 'spark', x, y });
        const a = world.actorAt(x, y);
        if (a && a !== victim) world.damage(a, rollDamage(rng, sp.dmg, power * 0.7), { source: p, label: 'corrente elétrica', spell: true });
      }
    }
    return;
  }
  if (spellId === 'raise_dead') {
    const corpse = world.corpseAt(tx, ty, (c) => c.monsterId && !c.charred && !c.raised);
    if (!corpse) {
      world.msg('Não há um cadáver utilizável ali.', 'warn');
      return;
    }
    world.raiseDead(corpse, tx, ty, power);
  }
}

function detonate(world, caster, spellId, x, y, victim, power) {
  const sp = SPELLS[spellId];
  const rng = world.rng;
  const level = world.level;
  if (spellId === 'fireball') {
    world.emitNoise(x, y, sp.noise, { source: caster, label: 'explosão' });
    world.flash(x, y, 8, 2.0, 0xff8a2a, 650);
    world.events.push({ type: 'explosion', x, y, color: 0xff6a10 });
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx;
        const ny = y + dy;
        if (!level.inBounds(nx, ny) || level.tile(nx, ny) === T.WALL) continue;
        igniteCell(world, nx, ny, { flash: true });
        level.smoke[level.idx(nx, ny)] = Math.min(1, level.smoke[level.idx(nx, ny)] + 0.25);
        const a = world.actorAt(nx, ny);
        if (a) {
          const k = dx || dy ? 0.7 : 1;
          world.damage(a, rollDamage(rng, sp.dmg, power * k), { source: caster, label: sp.name, spell: true, part: a.isPlayer ? 'torso' : undefined });
        }
      }
    }
    world.lightDirty = true;
  } else if (spellId === 'frost') {
    world.emitNoise(x, y, sp.noise, { source: caster, label: 'gelo' });
    world.events.push({ type: 'frost', x, y });
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        freezeCell(world, x + dx, y + dy);
        const a = world.actorAt(x + dx, y + dy);
        if (a) {
          const k = dx || dy ? 0.5 : 1;
          world.damage(a, rollDamage(rng, sp.dmg, power * k), { source: caster, label: sp.name, spell: true });
          if (a.alive) a.effects.slowUntil = world.now + 4000;
        }
      }
    }
    world.lightDirty = true;
  }
}

export function monsterBolt(world, m, ab, target) {
  world.emitNoise(m.x, m.y, ab.noise || 8, { source: m, label: 'magia' });
  world.spawnProjectile({
    owner: m, x: m.x, y: m.y, tx: target.x, ty: target.y, speed: 11, color: ab.color || 0xb45cff,
    kind: 'bolt', range: ab.range + 2,
    onHit: (x, y, victim) => {
      world.events.push({ type: 'burst', x, y, color: ab.color || 0xb45cff });
      if (victim) world.damage(victim, rollDamage(world.rng, ab.dmg, 1 + (world.depth - 1) * 0.06), { source: m, label: ab.name, spell: true, profile: 'mid' });
    },
  });
}

export function throwItem(world, p, it, tx, ty) {
  const def = ITEMS[it.id];
  const rng = world.rng;
  const skill = p.skills.throwing.level;
  const dist = Math.hypot(tx - p.x, ty - p.y);
  let x = tx;
  let y = ty;
  if (!rng.chance(0.55 + skill * 0.05 - dist * 0.03)) {
    const [dx, dy] = rng.pick(DIRS8);
    if (world.level.isFloorLike(tx + dx, ty + dy)) {
      x = tx + dx;
      y = ty + dy;
    }
  }
  world.train('throwing', 0.5);
  world.spawnProjectile({
    owner: p, x: p.x, y: p.y, tx: x, ty: y, speed: 10, color: def.effect === 'fire' ? 0xff9a3c : 0x6b5a2a,
    kind: 'throw', range: def.range + 2, arc: true, passActors: true,
    onHit: (hx, hy) => {
      world.emitNoise(hx, hy, def.noise || 3, { source: p, label: 'vidro quebrando' });
      spillOil(world, hx, hy, 1, def.effect === 'fire' ? 0.6 : 0.5);
      if (def.effect === 'fire') {
        igniteCell(world, hx, hy, { flash: true });
        world.flash(hx, hy, 5, 1.4, 0xff8a2a, 400);
        world.msg('O coquetel explode em chamas!', 'magic');
      } else world.msg('O frasco se quebra e o óleo se espalha.', 'info');
    },
  });
}
