// Procedural floor generator: rooms + hand-made vaults + A*-carved corridors,
// themed furniture, lighting, monsters and loot. Deterministic per seed.
import { Level, T, S, DIRS8 } from './level.js';
import { Rng } from './rng.js';
import { PROPS, ROOM_THEMES, VAULTS, BRANCH } from '../content/world.js';
import { MONSTERS } from '../content/monsters.js';
import { LOOT_TABLES, ITEMS } from '../content/items.js';
import { createItem, createMonster } from './entity.js';

const CONTAINER_TABLES = {
  common: 'common',
  gear: 'gear',
  rare: 'rare',
  books: [['rag', 4], ['candle', 4], ['scroll_lightning', 1], ['scroll_fire', 1], ['relic_lens', 1], ['wine', 1]],
  crypt: [['relic_coin', 4], ['relic_idol', 2], ['helmet', 1], ['mace', 1], ['rag', 3], ['heal_potion', 1]],
};

export function rollLoot(rng, table) {
  const entries = typeof table === 'string' ? LOOT_TABLES[table] : table;
  const id = rng.weighted(entries);
  const def = ITEMS[id];
  const qty = id === 'ammo45' ? rng.int(3, 7) : def.stack ? rng.int(1, 3) : 1;
  const it = createItem(id, qty);
  if (def.durability && rng.chance(0.5)) it.cond = Math.round(def.durability * rng.range(0.35, 0.9));
  if (def.magazine) it.mag = rng.int(0, 3);
  return it;
}

export function generateLevel(depth, seed, opts = {}) {
  const rng = new Rng(seed);
  for (let attempt = 0; attempt < 40; attempt++) {
    const level = tryBuild(depth, rng, opts);
    if (level) return level;
  }
  throw new Error('dungeon generation failed');
}

function tryBuild(depth, rng, opts) {
  const size = BRANCH.size;
  const level = new Level(depth, size, size);
  const reserved = new Uint8Array(size * size);
  const specs = [];

  if (depth === BRANCH.floors) specs.push({ vault: VAULTS.find((v) => v.boss) });
  if (opts.needsNecroBook) specs.push({ vault: VAULTS.find((v) => v.id === 'forbidden_library') });
  const pool = VAULTS.filter((v) => !v.boss && !v.unique && depth >= v.depth[0] && depth <= v.depth[1]);
  const extra = rng.int(1, 2);
  for (let i = 0; i < extra && pool.length; i++) {
    specs.push({ vault: rng.weighted(pool.map((v) => [v, v.weight])) });
  }
  const roomCount = rng.int(9, 12);
  for (let i = 0; i < roomCount; i++) {
    specs.push({ w: rng.int(6, 11), h: rng.int(6, 10) });
  }

  // Place rooms (outer size includes walls). Keep 2 cells between rooms for corridors.
  const rooms = [];
  for (const spec of specs) {
    const w = spec.vault ? spec.vault.map[0].length : spec.w;
    const h = spec.vault ? spec.vault.map.length : spec.h;
    let placed = false;
    for (let t = 0; t < 200 && !placed; t++) {
      const x = rng.int(1, size - w - 2);
      const y = rng.int(1, size - h - 2);
      if (rooms.some((r) => x < r.x + r.w + 2 && x + w + 2 > r.x && y < r.y + r.h + 2 && y + h + 2 > r.y)) {
        continue;
      }
      rooms.push({ id: rooms.length, x, y, w, h, vault: spec.vault || null, exits: [], doorCells: [] });
      placed = true;
    }
    if (!placed && spec.vault) return null;
  }
  if (rooms.length < 7) return null;
  level.rooms = rooms;

  for (const room of rooms) carveRoom(level, room, reserved);

  // Connect with a minimum spanning tree plus a few loops.
  const edges = mstEdges(rooms);
  const extraEdges = Math.floor(rooms.length * 0.3);
  for (let i = 0; i < extraEdges; i++) {
    const a = rng.int(0, rooms.length - 1);
    const b = nearestOther(rooms, a, rng);
    if (b !== null) edges.push([a, b]);
  }
  for (const [a, b] of edges) connect(level, rooms[a], rooms[b], reserved, rng);

  buildWalls(level);

  const startRoom = rooms.find((r) => !r.vault) || rooms[0];
  const connectivity = floodFrom(level, startRoom);
  for (const room of rooms) {
    const [cx, cy] = roomCenterFloor(level, room);
    if (!connectivity[level.idx(cx, cy)]) return null;
  }

  // Themes and furniture for procedural rooms.
  for (const room of rooms) {
    if (room.vault) continue;
    room.theme = room === startRoom ? 'barracks' : rng.weighted(Object.entries(ROOM_THEMES).map(([k, v]) => [k, v.weight]));
    furnish(level, room, rng);
  }
  repairConnectivity(level, startRoom);

  // Stairs.
  const upCell = freeCell(level, startRoom, rng, true);
  if (!upCell) return null;
  level.tiles[level.idx(...upCell)] = T.STAIRS_UP;
  level.up = { x: upCell[0], y: upCell[1] };
  const dist = bfsDistance(level, upCell[0], upCell[1]);
  if (depth < BRANCH.floors) {
    let best = null;
    for (const room of rooms) {
      if (room === startRoom || room.vault?.boss) continue;
      const c = freeCell(level, room, rng, true);
      if (!c) continue;
      const d = dist[level.idx(c[0], c[1])];
      if (d > 0 && (!best || d > best.d)) best = { c, d };
    }
    if (!best) return null;
    level.tiles[level.idx(...best.c)] = T.STAIRS_DOWN;
    level.down = { x: best.c[0], y: best.c[1] };
  } else {
    const gate = [...level.props.values()].find((p) => p.id === 'gate');
    level.props.delete(level.idx(gate.x, gate.y));
    level.tiles[level.idx(gate.x, gate.y)] = T.STAIRS_DOWN;
    level.down = { x: gate.x, y: gate.y };
    level.gateSealed = true;
  }

  populate(level, rng, depth, startRoom, dist, opts);
  scatterLoot(level, rng, depth, startRoom);
  return level;
}

function carveRoom(level, room, reserved) {
  const { x, y, w, h } = room;
  for (let j = 0; j < h; j++) {
    for (let i = 0; i < w; i++) {
      const cx = x + i;
      const cy = y + j;
      const idx = level.idx(cx, cy);
      reserved[idx] = 1;
      const border = i === 0 || j === 0 || i === w - 1 || j === h - 1;
      if (!room.vault) {
        level.tiles[idx] = border ? T.WALL : T.FLOOR;
        if (!border) level.roomId[idx] = room.id;
        continue;
      }
      const ch = room.vault.map[j][i];
      if (ch === '#') {
        level.tiles[idx] = T.WALL;
        continue;
      }
      if (ch === '+') {
        level.tiles[idx] = T.WALL;
        room.exits.push([cx, cy]);
        continue;
      }
      level.tiles[idx] = ch === '~' ? T.WATER : T.FLOOR;
      level.roomId[idx] = room.id;
      stampVaultCell(level, room, ch, cx, cy);
    }
  }
}

const VAULT_PROPS = { b: 'barrel_oil', c: 'crate', s: 'bookshelf', t: 'table', h: 'chair', B: 'bed', A: 'altar', S: 'sarcophagus', r: 'weapon_rack', T: 'wall_torch', F: 'brazier', P: 'pillar', D: 'gate' };
const VAULT_MONSTERS = { g: 'goblin', k: 'knight', x: 'spider', z: 'skeleton', m: 'cultist', R: 'troll', 1: 'castellan' };

function stampVaultCell(level, room, ch, x, y) {
  if (VAULT_PROPS[ch]) placeProp(level, VAULT_PROPS[ch], x, y);
  else if (ch === 'o') level.setSurface(x, y, S.OIL, 30000);
  else if (ch === '%') level.setSurface(x, y, S.WEB, 1);
  else if (VAULT_MONSTERS[ch]) (room.spawns ||= []).push([VAULT_MONSTERS[ch], x, y]);
  else if (ch === '$' || ch === '*' || ch === '?' || ch === 'C') (room.loot ||= []).push([ch, x, y]);
}

export function placeProp(level, id, x, y, extra = {}) {
  const def = PROPS[id];
  const p = { id, x, y, hp: def.hp, items: [], searched: !def.container, ...extra };
  if (def.burns) p.fuel = def.burns;
  level.props.set(level.idx(x, y), p);
  return p;
}

function mstEdges(rooms) {
  const centers = rooms.map((r) => [r.x + r.w / 2, r.y + r.h / 2]);
  const inTree = new Set([0]);
  const edges = [];
  while (inTree.size < rooms.length) {
    let best = null;
    for (const a of inTree) {
      for (let b = 0; b < rooms.length; b++) {
        if (inTree.has(b)) continue;
        const d = Math.hypot(centers[a][0] - centers[b][0], centers[a][1] - centers[b][1]);
        if (!best || d < best.d) best = { a, b, d };
      }
    }
    inTree.add(best.b);
    edges.push([best.a, best.b]);
  }
  return edges;
}

function nearestOther(rooms, a, rng) {
  const ra = rooms[a];
  const sorted = rooms
    .map((r, i) => [i, Math.hypot(r.x - ra.x, r.y - ra.y)])
    .filter(([i]) => i !== a)
    .sort((p, q) => p[1] - q[1]);
  return sorted.length ? sorted[rng.int(0, Math.min(2, sorted.length - 1))][0] : null;
}

function exitFor(level, room, other, rng) {
  const cx = room.x + room.w / 2;
  const cy = room.y + room.h / 2;
  const ox = other.x + other.w / 2;
  const oy = other.y + other.h / 2;
  if (room.vault) {
    let best = null;
    for (const [ex, ey] of room.exits) {
      const d = Math.hypot(ex - ox, ey - oy);
      if (!best || d < best.d) best = { ex, ey, d };
    }
    const { ex, ey } = best;
    const out = outward(room, ex, ey);
    return { wall: [ex, ey], out };
  }
  const horizontal = Math.abs(ox - cx) / room.w > Math.abs(oy - cy) / room.h;
  let ex;
  let ey;
  if (horizontal) {
    ex = ox > cx ? room.x + room.w - 1 : room.x;
    ey = rng.int(room.y + 2, room.y + room.h - 3);
  } else {
    ey = oy > cy ? room.y + room.h - 1 : room.y;
    ex = rng.int(room.x + 2, room.x + room.w - 3);
  }
  // Reuse an existing exit on the same side if it is close.
  for (const [px, py] of room.doorCells) {
    if ((horizontal && px === ex && Math.abs(py - ey) <= 3) || (!horizontal && py === ey && Math.abs(px - ex) <= 3)) {
      return { wall: [px, py], out: outward(room, px, py) };
    }
  }
  return { wall: [ex, ey], out: outward(room, ex, ey) };
}

function outward(room, x, y) {
  if (x === room.x) return [x - 1, y];
  if (x === room.x + room.w - 1) return [x + 1, y];
  if (y === room.y) return [x, y - 1];
  return [x, y + 1];
}

function connect(level, a, b, reserved, rng) {
  const ea = exitFor(level, a, b, rng);
  const eb = exitFor(level, b, a, rng);
  if (!level.inBounds(...ea.out) || !level.inBounds(...eb.out)) return false;
  if (reserved[level.idx(...ea.out)] || reserved[level.idx(...eb.out)]) return false;
  const path = corridorPath(level, ea.out, eb.out, reserved);
  if (!path) return false;
  for (const [x, y] of [ea.out, ...path]) {
    const i = level.idx(x, y);
    if (level.tiles[i] === T.ROCK) level.tiles[i] = T.FLOOR;
  }
  for (const [room, e] of [[a, ea], [b, eb]]) {
    const [wx, wy] = e.wall;
    const i = level.idx(wx, wy);
    if (level.tiles[i] !== T.DOOR && level.tiles[i] !== T.FLOOR) {
      const isDoor = room.vault || rng.chance(0.72);
      level.tiles[i] = isDoor ? T.DOOR : T.FLOOR;
      if (isDoor) level.doors.set(i, newDoor(rng.chance(0.25)));
    }
    if (!room.doorCells.some(([x, y]) => x === wx && y === wy)) room.doorCells.push([wx, wy]);
  }
  return true;
}

export function newDoor(open = false) {
  return { open, barricade: 0, hp: 30, maxHp: 30, broken: false };
}

function corridorPath(level, from, to, reserved) {
  // A* over rock with a preference for reusing corridors; rooms are off limits.
  const w = level.w;
  const start = level.idx(...from);
  const goal = level.idx(...to);
  const g = new Map([[start, 0]]);
  const came = new Map();
  const open = [[0, start]];
  while (open.length) {
    open.sort((p, q) => p[0] - q[0]);
    const [, cur] = open.shift();
    if (cur === goal) break;
    const cx = cur % w;
    const cy = (cur / w) | 0;
    for (const [dx, dy] of DIRS8.slice(0, 4)) {
      const nx = cx + dx;
      const ny = cy + dy;
      if (nx < 1 || ny < 1 || nx >= level.w - 1 || ny >= level.h - 1) continue;
      const ni = ny * w + nx;
      if (reserved[ni] && ni !== goal) continue;
      const step = level.tiles[ni] === T.FLOOR ? 0.35 : 1;
      const c = g.get(cur) + step;
      if (c < (g.get(ni) ?? Infinity)) {
        g.set(ni, c);
        came.set(ni, cur);
        open.push([c + Math.abs(nx - to[0]) + Math.abs(ny - to[1]), ni]);
      }
    }
    if (open.length > 6000) return null;
  }
  if (!came.has(goal) && start !== goal) return null;
  const path = [];
  let cur = goal;
  while (cur !== start) {
    path.push([cur % w, (cur / w) | 0]);
    cur = came.get(cur);
  }
  return path.reverse();
}

function buildWalls(level) {
  for (let y = 0; y < level.h; y++) {
    for (let x = 0; x < level.w; x++) {
      if (level.tile(x, y) !== T.ROCK) continue;
      for (const [dx, dy] of DIRS8) {
        const t = level.tile(x + dx, y + dy);
        if (t === T.FLOOR || t === T.WATER || t === T.DOOR) {
          level.tiles[level.idx(x, y)] = T.WALL;
          break;
        }
      }
    }
  }
}

function roomCells(level, room) {
  const cells = [];
  for (let y = room.y + 1; y < room.y + room.h - 1; y++) {
    for (let x = room.x + 1; x < room.x + room.w - 1; x++) {
      if (level.roomId[level.idx(x, y)] === room.id) cells.push([x, y]);
    }
  }
  return cells;
}

function roomCenterFloor(level, room) {
  const cells = roomCells(level, room);
  const cx = room.x + room.w / 2;
  const cy = room.y + room.h / 2;
  let best = cells[0];
  let bd = Infinity;
  for (const c of cells) {
    const t = level.tile(c[0], c[1]);
    if (t !== T.FLOOR && t !== T.WATER) continue;
    const p = level.props.get(level.idx(c[0], c[1]));
    if (p && PROPS[p.id].blocks) continue;
    const d = Math.hypot(c[0] - cx, c[1] - cy);
    if (d < bd) {
      bd = d;
      best = c;
    }
  }
  return best;
}

function floodFrom(level, room) {
  const [sx, sy] = roomCenterFloor(level, room);
  const seen = new Uint8Array(level.w * level.h);
  const stack = [[sx, sy]];
  seen[level.idx(sx, sy)] = 1;
  while (stack.length) {
    const [x, y] = stack.pop();
    for (const [dx, dy] of DIRS8.slice(0, 4)) {
      const nx = x + dx;
      const ny = y + dy;
      const i = level.idx(nx, ny);
      if (!level.inBounds(nx, ny) || seen[i]) continue;
      const t = level.tiles[i];
      if (t === T.ROCK || t === T.WALL) continue;
      const p = level.props.get(i);
      if (p && PROPS[p.id].blocks && p.id !== 'gate') continue;
      seen[i] = 1;
      stack.push([nx, ny]);
    }
  }
  return seen;
}

function nearExit(room, x, y) {
  return room.doorCells.some(([dx, dy]) => Math.max(Math.abs(dx - x), Math.abs(dy - y)) <= 1);
}

function furnish(level, room, rng) {
  const theme = ROOM_THEMES[room.theme];
  const cells = roomCells(level, room);
  const wallCells = cells.filter(([x, y]) => x === room.x + 1 || y === room.y + 1 || x === room.x + room.w - 2 || y === room.y + room.h - 2);
  const inner = cells.filter(([x, y]) => x > room.x + 2 && y > room.y + 2 && x < room.x + room.w - 3 && y < room.y + room.h - 3);

  if (theme.water) {
    for (const [x, y] of cells) if (rng.chance(0.7)) level.tiles[level.idx(x, y)] = T.WATER;
  }
  if (theme.pillars && room.w >= 8 && room.h >= 8) {
    for (const [x, y] of inner) {
      if ((x - room.x) % 3 === 0 && (y - room.y) % 3 === 0) placeProp(level, 'pillar', x, y);
    }
  }
  rng.shuffle(wallCells);
  const wallCount = Math.floor(wallCells.length * (theme.wall.length ? rng.range(0.25, 0.45) : 0));
  let placed = 0;
  for (const [x, y] of wallCells) {
    if (placed >= wallCount) break;
    if (nearExit(room, x, y) || level.props.has(level.idx(x, y))) continue;
    if (level.tile(x, y) === T.WATER) continue;
    placeProp(level, rng.weighted(theme.wall), x, y);
    placed++;
  }
  rng.shuffle(inner);
  const centerCount = theme.center.length ? rng.int(1, Math.min(3, inner.length)) : 0;
  for (let i = 0; i < centerCount && i < inner.length; i++) {
    const [x, y] = inner[i];
    if (level.props.has(level.idx(x, y))) continue;
    placeProp(level, rng.weighted(theme.center), x, y);
  }
  if (theme.braziers) {
    for (const [x, y] of inner.slice(3, 5)) if (!level.props.has(level.idx(x, y))) placeProp(level, 'brazier', x, y);
  }
  if (theme.oil) {
    for (const [x, y] of cells) if (rng.chance(0.08) && !level.props.has(level.idx(x, y))) level.setSurface(x, y, S.OIL, 30000);
  }
  if (rng.chance(theme.torches)) {
    const torches = rng.int(1, 2);
    let n = 0;
    for (const [x, y] of wallCells) {
      if (n >= torches) break;
      if (level.props.has(level.idx(x, y)) || nearExit(room, x, y)) continue;
      placeProp(level, 'wall_torch', x, y, { wallDir: wallDirection(level, x, y) });
      n++;
    }
  }
}

export function wallDirection(level, x, y) {
  for (const [dx, dy] of [[0, -1], [-1, 0], [0, 1], [1, 0]]) {
    if (level.tile(x + dx, y + dy) === T.WALL) return [dx, dy];
  }
  return [0, -1];
}

// Remove furniture until every walkable cell is reachable again.
function repairConnectivity(level, startRoom) {
  for (let guard = 0; guard < 60; guard++) {
    const seen = floodFrom(level, startRoom);
    let fixed = true;
    for (let i = 0; i < level.tiles.length && fixed; i++) {
      const t = level.tiles[i];
      if ((t === T.FLOOR || t === T.WATER || t === T.DOOR) && !seen[i] && !(level.props.get(i) && PROPS[level.props.get(i).id].blocks)) {
        const x = i % level.w;
        const y = (i / level.w) | 0;
        for (const [dx, dy] of DIRS8.slice(0, 4)) {
          const j = level.idx(x + dx, y + dy);
          const p = level.props.get(j);
          if (p && PROPS[p.id].blocks && p.id !== 'gate' && p.id !== 'altar') {
            level.props.delete(j);
            fixed = false;
            break;
          }
        }
        if (fixed) {
          // Isolated cell with no furniture neighbour: fill it in.
          level.tiles[i] = T.WALL;
          level.roomId[i] = -1;
          fixed = false;
        }
      }
    }
    if (fixed) return;
  }
}

export function freeCell(level, room, rng, strict = false) {
  const cells = rng.shuffle(roomCells(level, room));
  for (const [x, y] of cells) {
    const i = level.idx(x, y);
    if (level.tiles[i] !== T.FLOOR) continue;
    if (level.props.has(i) || level.actorAt(x, y)) continue;
    if (strict && nearExit(room, x, y)) continue;
    if (level.surface[i] === S.OIL && strict) continue;
    return [x, y];
  }
  return null;
}

function bfsDistance(level, sx, sy) {
  const dist = new Int32Array(level.w * level.h).fill(-1);
  const q = [[sx, sy]];
  dist[level.idx(sx, sy)] = 0;
  for (let h = 0; h < q.length; h++) {
    const [x, y] = q[h];
    for (const [dx, dy] of DIRS8.slice(0, 4)) {
      const nx = x + dx;
      const ny = y + dy;
      if (!level.inBounds(nx, ny)) continue;
      const i = level.idx(nx, ny);
      if (dist[i] >= 0) continue;
      const t = level.tiles[i];
      if (t === T.ROCK || t === T.WALL) continue;
      dist[i] = dist[level.idx(x, y)] + 1;
      q.push([nx, ny]);
    }
  }
  return dist;
}

function populate(level, rng, depth, startRoom, dist, opts) {
  // Vault fixed spawns.
  for (const room of level.rooms) {
    for (const [id, x, y] of room.spawns || []) {
      const m = createMonster(id, x, y, rng, id === 'castellan' ? { awake: false } : {});
      if (id === 'castellan') m.ai.state = 'sleep';
      level.actors.push(m);
    }
    for (const [ch, x, y] of room.loot || []) {
      if (ch === '$') level.addItem(x, y, rollLoot(rng, 'rare'));
      else if (ch === '*') level.addItem(x, y, rollLoot(rng, 'gear'));
      else if (ch === '?') level.addItem(x, y, createItem(opts.needsNecroBook ? 'book_necro' : 'scroll_lightning'));
      else if (ch === 'C') {
        addCorpse(level, x, y, { name: 'Restos de um aventureiro', monsterId: null, time: -1e9 });
        level.addItem(x, y, rollLoot(rng, 'gear'));
        level.addItem(x, y, rollLoot(rng, 'common'));
      }
    }
  }
  // Budgeted random population away from the entrance.
  const budget = BRANCH.budget[depth - 1];
  const eligible = Object.entries(MONSTERS).filter(([, d]) => depth >= d.depth[0] && depth <= d.depth[1] && !d.boss);
  let spent = 0;
  const candidates = level.rooms.filter((r) => r !== startRoom && !r.vault?.boss);
  for (let guard = 0; spent < budget && guard < 200; guard++) {
    const [id, def] = rng.weighted(eligible.map((e) => [e, e[1].weight]));
    const room = rng.pick(candidates);
    const n = def.behavior?.pack ? rng.int(...def.behavior.pack) : 1;
    for (let k = 0; k < n; k++) {
      const c = freeCell(level, room, rng);
      if (!c) break;
      if (dist[level.idx(c[0], c[1])] < 12) break;
      const m = createMonster(id, c[0], c[1], rng);
      if (def.loot && rng.chance(def.loot)) m.loot.push(rollLoot(rng, def.lootTable || 'common'));
      level.actors.push(m);
      spent += def.xp;
      if (def.webs) spinWebs(level, c[0], c[1], rng);
    }
  }
  // The Hollowed: a previous character waits at the depth they died.
  if (opts.hollowed) {
    const room = rng.pick(candidates);
    const c = freeCell(level, room, rng);
    if (c) {
      const h = opts.hollowed;
      const loot = (h.gear || []).filter((id) => ITEMS[id]).map((id) => createItem(id));
      const m = createMonster('hollowed', c[0], c[1], rng, {
        name: `${h.name.split(' ')[0]}, o Esvaziado`, loot, hollowed: h, awake: true,
      });
      m.ai.state = 'idle';
      level.actors.push(m);
    }
  }
}

function spinWebs(level, x, y, rng) {
  for (const [dx, dy] of DIRS8) {
    const nx = x + dx;
    const ny = y + dy;
    if (level.tile(nx, ny) === T.FLOOR && rng.chance(0.45) && !level.props.has(level.idx(nx, ny))) {
      level.setSurface(nx, ny, S.WEB, 1);
    }
  }
}

export function addCorpse(level, x, y, corpse) {
  const i = level.idx(x, y);
  const list = level.corpses.get(i) || [];
  list.push(corpse);
  level.corpses.set(i, list);
}

function scatterLoot(level, rng, depth, startRoom) {
  // Containers.
  for (const p of level.props.values()) {
    const def = PROPS[p.id];
    if (!def.container) continue;
    const table = CONTAINER_TABLES[def.container];
    const n = rng.chance(0.55) ? rng.int(1, 2) : 0;
    for (let i = 0; i < n; i++) p.items.push(rollLoot(rng, table));
    if (def.container === 'gear' && rng.chance(0.6)) p.items.push(rollLoot(rng, 'gear'));
  }
  // Floor loot, with guaranteed survival supplies.
  const rooms = level.rooms.filter((r) => !r.vault?.boss);
  const drop = (it) => {
    for (let t = 0; t < 20; t++) {
      const room = rng.pick(rooms);
      const c = freeCell(level, room, rng);
      if (c) {
        level.addItem(c[0], c[1], it);
        return;
      }
    }
  };
  for (const id of ['ration', 'bread', 'rag', 'plank', 'plank']) drop(createItem(id));
  drop(createItem(rng.chance(0.5) ? 'waterskin' : 'wine'));
  if (depth >= 2) drop(createItem(rng.chance(0.5) ? 'bandage' : 'heal_potion'));
  if (depth === 1) drop(createItem('oil_flask'));
  const n = BRANCH.loot[depth - 1];
  for (let i = 0; i < n; i++) {
    drop(rollLoot(rng, rng.weighted([['common', 6], ['gear', 2], ['rare', 1 + depth * 0.3]])));
  }
  // A starter cache in the entrance room so the first minutes have a decision.
  const c = freeCell(level, startRoom, rng);
  if (c && depth === 1) level.addItem(c[0], c[1], createItem('plank', 2));
}
