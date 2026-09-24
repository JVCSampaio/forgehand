// Entity factories: items, monsters and the player. Components are plain objects.
import { ITEMS } from '../content/items.js';
import { MONSTERS } from '../content/monsters.js';
import { SPECIES, BACKGROUNDS, SKILLS } from '../content/characters.js';
import { createBody } from './body.js';

let UID = 1;
export const nextUid = () => UID++;

export function createItem(id, qty = 1) {
  const def = ITEMS[id];
  if (!def) throw new Error(`unknown item ${id}`);
  const it = { uid: UID++, id, qty: def.stack ? qty : 1 };
  if (def.durability) it.cond = def.durability;
  if (def.maxCharges) it.charges = id === 'waterskin' ? 5 : def.maxCharges;
  if (def.magazine) it.mag = def.magazine;
  if (def.fuelMax) it.fuel = def.fuelMax;
  if (def.burnTime) it.fuel = def.burnTime;
  return it;
}

export function itemName(it) {
  const def = ITEMS[it.id];
  let name = it.name || def.name;
  if (def.stack && it.qty > 1) name += ` ×${it.qty}`;
  if (def.magazine) name += ` [${it.mag}/${def.magazine}]`;
  if (def.maxCharges && !def.stack) name += ` (${it.charges}/${def.maxCharges})`;
  if (def.durability && it.cond !== undefined) {
    const r = it.cond / def.durability;
    if (it.cond <= 0) name += ' (quebrado)';
    else if (r < 0.25) name += ' (quase quebrando)';
    else if (r < 0.6) name += ' (desgastado)';
  }
  return name;
}

export function itemWeight(it) {
  const def = ITEMS[it.id];
  let w = def.weight * (def.stack ? it.qty : 1);
  if (def.chargeWeight) w += def.chargeWeight * (it.charges || 0);
  return w;
}

export function createMonster(defId, x, y, rng, opts = {}) {
  const def = MONSTERS[defId];
  const hp = opts.hp || def.hp;
  return {
    id: UID++, isPlayer: false, defId, def, name: opts.name || def.name,
    x, y, px: x, py: y, moveT0: 0, moveT1: 0, facing: rng.range(0, Math.PI * 2),
    team: opts.team || 'hostile', hp, maxHp: hp, alive: true,
    ai: {
      state: opts.awake || !(rng.chance(def.behavior?.sleeps ?? 0.25)) ? 'idle' : 'sleep',
      lastKnown: null, path: null, target: null, investigateUntil: 0, nextThink: 0,
      home: [x, y], alerted: false,
    },
    action: null, effects: {}, cooldowns: {}, loot: opts.loot || [],
    expires: opts.expires || 0, hollowed: opts.hollowed || null, lastHitBy: null,
  };
}

export function createPlayer(name, speciesId, backgroundId) {
  const sp = SPECIES[speciesId];
  const bg = BACKGROUNDS[backgroundId];
  const skills = {};
  for (const id of Object.keys(SKILLS)) {
    const level = bg.skills[id] || 0;
    skills[id] = { level, train: level > 0 };
  }
  const p = {
    id: UID++, isPlayer: true, name, speciesId, backgroundId, species: sp, background: bg,
    x: 0, y: 0, px: 0, py: 0, moveT0: 0, moveT1: 0, facing: Math.PI * 1.25,
    team: 'player', alive: true, body: createBody(),
    needs: { hunger: 12, thirst: 10, fatigue: 8, fear: 5 },
    stamina: 100, mana: 0, maxMana: 0, inv: [], equip: {}, skills, xpPool: 0,
    spells: [...bg.spells], lanternOn: true, sneaking: false,
    action: null, queued: null, path: null, effects: {}, kills: 0, cooldowns: {},
    lastHitBy: null, deathCause: null, stats: { floorsSeen: 1, shots: 0, spells: 0 },
  };
  p.maxMana = 10 + Math.round((skills.spellcasting.level || 0) * 4 + (skills.necromancy.level || 0) * 1.5);
  p.mana = p.maxMana;
  for (const id of bg.equip) {
    const it = createItem(id);
    const def = ITEMS[id];
    p.equip[def.slot] = it;
  }
  for (const [id, qty] of bg.items) {
    if (ITEMS[id].stack) p.inv.push(createItem(id, qty));
    else for (let i = 0; i < qty; i++) p.inv.push(createItem(id));
  }
  return p;
}

export function carryCapacity(p) {
  const back = p.equip.back ? ITEMS[p.equip.back.id].capacity || 0 : 0;
  return p.species.carry + back;
}

export function carriedWeight(p) {
  let w = 0;
  for (const it of p.inv) w += itemWeight(it);
  for (const it of Object.values(p.equip)) if (it) w += itemWeight(it) * 0.5;
  return w;
}

export function countItem(p, id) {
  let n = 0;
  for (const it of p.inv) if (it.id === id) n += ITEMS[id].stack ? it.qty : 1;
  return n;
}

export function consumeItem(p, id, qty = 1) {
  for (let i = p.inv.length - 1; i >= 0 && qty > 0; i--) {
    const it = p.inv[i];
    if (it.id !== id) continue;
    if (ITEMS[id].stack) {
      const take = Math.min(qty, it.qty);
      it.qty -= take;
      qty -= take;
      if (it.qty <= 0) p.inv.splice(i, 1);
    } else {
      p.inv.splice(i, 1);
      qty--;
    }
  }
  return qty === 0;
}

export function addToInventory(p, it) {
  const def = ITEMS[it.id];
  if (def.stack) {
    const same = p.inv.find((o) => o.id === it.id);
    if (same) {
      same.qty += it.qty;
      return same;
    }
  }
  p.inv.push(it);
  return it;
}
