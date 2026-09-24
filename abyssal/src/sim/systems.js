// World systems: noise propagation, lighting and the environment (fire, smoke,
// ice, oil, webs, water conduction). They operate on Level data only.
import { T, S, DIRS8, computeFov } from './level.js';
import { PROPS } from '../content/world.js';
import { ITEMS } from '../content/items.js';

// ------------------------------------------------------------------ noise
// Sound is a second vision: it flows through open space, is muffled by doors
// and heavily damped by stone. Returns Map(cellIndex -> remaining volume).
export function propagateNoise(level, x, y, volume) {
  const out = new Map();
  const start = level.idx(x, y);
  out.set(start, volume);
  const frontier = [[volume, start]];
  while (frontier.length) {
    let bi = 0;
    for (let i = 1; i < frontier.length; i++) if (frontier[i][0] > frontier[bi][0]) bi = i;
    const [vol, cur] = frontier[bi];
    frontier[bi] = frontier[frontier.length - 1];
    frontier.pop();
    if (vol < (out.get(cur) ?? -1)) continue;
    const cx = cur % level.w;
    const cy = (cur / level.w) | 0;
    for (const [dx, dy] of DIRS8) {
      const nx = cx + dx;
      const ny = cy + dy;
      if (!level.inBounds(nx, ny)) continue;
      const ni = level.idx(nx, ny);
      const t = level.tiles[ni];
      let cost = dx && dy ? 1.4 : 1;
      // Stone muffles heavily but does not stop a loud enough sound.
      if (t === T.WALL || t === T.ROCK) cost += 2.5;
      else if (t === T.DOOR) {
        const d = level.doors.get(ni);
        if (d && !d.open && !d.broken) cost += 2 + d.barricade;
      }
      const nv = vol - cost;
      if (nv <= 0) continue;
      if (nv > (out.get(ni) ?? 0)) {
        out.set(ni, nv);
        frontier.push([nv, ni]);
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------- lighting
export function gatherLights(world) {
  const level = world.level;
  const lights = [];
  for (const p of level.props.values()) {
    const def = PROPS[p.id];
    if (def.light && (p.fuel === undefined || p.fuel > 0)) {
      lights.push({ x: p.x, y: p.y, ...def.light, kind: p.id, flicker: true });
    }
  }
  for (const i of level.burning) {
    const x = i % level.w;
    const y = (i / level.w) | 0;
    lights.push({ x, y, radius: 3.5, intensity: 0.9, color: 0xff6a1a, kind: 'fire', flicker: true });
  }
  const pl = world.player;
  if (pl.alive) {
    const lantern = pl.equip.belt;
    if (lantern && pl.lanternOn && lantern.fuel > 0) {
      lights.push({ x: pl.x, y: pl.y, ...ITEMS[lantern.id].light, kind: 'lantern', actor: pl });
    }
    const off = pl.equip.off;
    if (off && ITEMS[off.id].light && off.fuel > 0) {
      lights.push({ x: pl.x, y: pl.y, ...ITEMS[off.id].light, kind: 'torch', actor: pl, flicker: true });
    }
  }
  for (const a of level.actors) {
    if (a.alive && a.def.light) lights.push({ x: a.x, y: a.y, ...a.def.light, kind: 'monster', actor: a });
  }
  for (const f of world.flashes) {
    if (f.until > world.now) lights.push({ ...f, kind: 'flash' });
  }
  return lights;
}

export function computeLighting(world) {
  const level = world.level;
  const light = level.light;
  light.fill(0);
  const lights = gatherLights(world);
  for (const L of lights) {
    const r = L.radius;
    computeFov(level, L.x, L.y, Math.ceil(r), (x, y, d) => {
      if (d > r) return;
      const k = 1 - (d / r) * (d / r);
      const i = level.idx(x, y);
      light[i] = Math.min(2, light[i] + L.intensity * k);
    });
  }
  world.lights = lights;
}

// ------------------------------------------------------------ environment
function cellFuel(level, i) {
  let fuel = 0;
  if (level.surface[i] === S.OIL) fuel = Math.max(fuel, 4000 + level.surfaceAmt[i] * 0.1);
  if (level.surface[i] === S.WEB) fuel = Math.max(fuel, 1200);
  const p = level.props.get(i);
  if (p && PROPS[p.id].flammable) fuel = Math.max(fuel, PROPS[p.id].fuel || 6000);
  if (level.corpses.get(i)?.some((c) => !c.charred)) fuel = Math.max(fuel, 7000);
  return fuel;
}

export function igniteCell(world, x, y, opts = {}) {
  const level = world.level;
  if (!level.inBounds(x, y)) return false;
  const i = level.idx(x, y);
  const t = level.tiles[i];
  if (t === T.WALL || t === T.ROCK) return false;
  if (t === T.WATER && level.surface[i] !== S.OIL) {
    level.smoke[i] = Math.min(1, level.smoke[i] + 0.3);
    return false;
  }
  if (level.surface[i] === S.ICE) {
    level.setSurface(x, y, S.NONE, 0);
    level.smoke[i] = Math.min(1, level.smoke[i] + 0.25);
    return false;
  }
  const fuel = cellFuel(level, i);
  const p = level.props.get(i);
  if (p && PROPS[p.id].explosive && !p.exploding) {
    p.exploding = true;
    world.later(250, () => explodeBarrel(world, p));
  }
  if (fuel <= 0) {
    if (opts.flash) {
      level.fire[i] = Math.max(level.fire[i], 700);
      level.burning.add(i);
    }
    return false;
  }
  if (level.fire[i] <= 0) level.burning.add(i);
  level.fire[i] = Math.max(level.fire[i], fuel);
  return true;
}

function explodeBarrel(world, p) {
  const level = world.level;
  if (level.props.get(level.idx(p.x, p.y)) !== p) return;
  level.props.delete(level.idx(p.x, p.y));
  level.version++;
  world.msg('Um barril de óleo explode!', 'danger');
  world.emitNoise(p.x, p.y, 25, { source: null, label: 'explosão' });
  world.flash(p.x, p.y, 7, 1.8, 0xffa040, 500);
  world.events.push({ type: 'explosion', x: p.x, y: p.y, color: 0xff7a1a });
  for (const [dx, dy] of [[0, 0], ...DIRS8]) {
    const nx = p.x + dx;
    const ny = p.y + dy;
    if (!level.isFloorLike(nx, ny)) continue;
    if (level.tile(nx, ny) !== T.WATER || dx || dy) level.setSurface(nx, ny, S.OIL, 20000);
    igniteCell(world, nx, ny);
    const a = world.actorAt(nx, ny);
    if (a) world.damage(a, { fire: world.rng.int(5, 10), blunt: world.rng.int(3, 8) }, { source: 'explosão de barril', label: 'explosão' });
  }
}

export function spillOil(world, x, y, radius, chance = 0.7) {
  const level = world.level;
  for (let dy = -radius; dy <= radius; dy++) {
    for (let dx = -radius; dx <= radius; dx++) {
      const nx = x + dx;
      const ny = y + dy;
      if (!level.isFloorLike(nx, ny)) continue;
      if ((dx || dy) && !world.rng.chance(chance)) continue;
      level.setSurface(nx, ny, S.OIL, 25000);
    }
  }
}

export function freezeCell(world, x, y) {
  const level = world.level;
  if (!level.inBounds(x, y)) return;
  const i = level.idx(x, y);
  if (level.fire[i] > 0) {
    level.fire[i] = 0;
    level.burning.delete(i);
    level.smoke[i] = Math.min(1, level.smoke[i] + 0.35);
  }
  const t = level.tiles[i];
  if (t === T.WATER) level.setSurface(x, y, S.ICE, 90000);
  else if (t === T.FLOOR && level.surface[i] !== S.OIL) level.setSurface(x, y, S.ICE, 20000);
}

// Connected water region (4-neighbour) for electric conduction.
export function waterRegion(level, x, y, limit = 400) {
  const out = [];
  if (level.tile(x, y) !== T.WATER || level.surface[level.idx(x, y)] === S.ICE) return out;
  const seen = new Set([level.idx(x, y)]);
  const q = [[x, y]];
  while (q.length && out.length < limit) {
    const [cx, cy] = q.shift();
    out.push([cx, cy]);
    for (const [dx, dy] of DIRS8.slice(0, 4)) {
      const nx = cx + dx;
      const ny = cy + dy;
      const i = level.idx(nx, ny);
      if (!level.inBounds(nx, ny) || seen.has(i)) continue;
      if (level.tiles[i] !== T.WATER || level.surface[i] === S.ICE) continue;
      seen.add(i);
      q.push([nx, ny]);
    }
  }
  return out;
}

// Fire, smoke and surfaces. Called every 200 ms of simulation time.
export function tickEnvironment(world, dt) {
  const level = world.level;
  const rng = world.rng;
  if (level.burning.size) {
    const spread = [];
    for (const i of [...level.burning]) {
      level.fire[i] -= dt;
      const x = i % level.w;
      const y = (i / level.w) | 0;
      level.smoke[i] = Math.min(1, level.smoke[i] + 0.05);
      // Burning spreads to fuel next door.
      for (const [dx, dy] of DIRS8) {
        const nx = x + dx;
        const ny = y + dy;
        if (!level.inBounds(nx, ny)) continue;
        const ni = level.idx(nx, ny);
        if (level.fire[ni] > 0) continue;
        const oil = level.surface[ni] === S.OIL;
        const web = level.surface[ni] === S.WEB;
        const p = level.props.get(ni);
        const wood = p && PROPS[p.id].flammable;
        const diag = dx && dy;
        const pr = oil ? 0.5 : web ? 0.6 : wood ? 0.035 : level.corpses.get(ni) ? 0.02 : 0;
        if (pr && rng.chance(diag ? pr * 0.5 : pr)) spread.push([nx, ny]);
      }
      // Items on the floor may be destroyed.
      const items = level.items.get(i);
      if (items) {
        for (let k = items.length - 1; k >= 0; k--) {
          if (ITEMS[items[k].id].flammable && rng.chance(0.06)) {
            if (world.isVisible(x, y)) world.msg(`${ITEMS[items[k].id].name} é consumido pelas chamas.`, 'warn');
            items.splice(k, 1);
          }
        }
        if (!items.length) level.items.delete(i);
      }
      const p = level.props.get(i);
      if (p && PROPS[p.id].flammable) {
        p.hp -= dt / 400;
        if (p.hp <= 0 && !PROPS[p.id].explosive) {
          level.props.delete(i);
          level.version++;
        }
      }
      if (level.fire[i] <= 0) {
        level.fire[i] = 0;
        level.burning.delete(i);
        if (level.surface[i] === S.OIL || level.surface[i] === S.WEB) level.setSurface(x, y, S.NONE, 0);
        const corpses = level.corpses.get(i);
        if (corpses) for (const c of corpses) c.charred = true;
        if (p && PROPS[p.id].flammable && level.props.get(i) === p) {
          level.props.delete(i);
          level.version++;
        }
      }
    }
    for (const [x, y] of spread) igniteCell(world, x, y);
    world.lightDirty = true;
  }
  // Smoke diffuses through open cells and slowly clears.
  const sm = level.smoke;
  const next = world._smokeBuf && world._smokeBuf.length === sm.length ? world._smokeBuf : (world._smokeBuf = new Float32Array(sm.length));
  let any = false;
  next.fill(0);
  for (let i = 0; i < sm.length; i++) {
    const s = sm[i];
    if (s < 0.01) continue;
    any = true;
    const x = i % level.w;
    const y = (i / level.w) | 0;
    let share = 0;
    const open = [];
    for (const [dx, dy] of DIRS8.slice(0, 4)) {
      const nx = x + dx;
      const ny = y + dy;
      if (!level.inBounds(nx, ny)) continue;
      const t = level.tile(nx, ny);
      if (t === T.WALL || t === T.ROCK) continue;
      const d = level.door(nx, ny);
      if (d && !d.open && !d.broken) continue;
      open.push(level.idx(nx, ny));
    }
    share = s * 0.09;
    for (const ni of open) next[ni] += share;
    next[i] += s - share * open.length;
  }
  if (any) {
    for (let i = 0; i < sm.length; i++) sm[i] = Math.max(0, next[i] * 0.985 - 0.002);
    world.smokeActive = true;
  } else world.smokeActive = false;
  // Surfaces: ice melts, blood dries.
  for (let i = 0; i < level.surface.length; i++) {
    const s = level.surface[i];
    if (s === S.ICE || s === S.BLOOD) {
      level.surfaceAmt[i] -= dt;
      if (level.surfaceAmt[i] <= 0) {
        level.surface[i] = S.NONE;
        level.surfaceVersion++;
      }
    }
  }
}
