// Level: the simulation grid for one floor. Presentation never mutates it.
import { PROPS } from '../content/world.js';

export const T = { ROCK: 0, FLOOR: 1, WALL: 2, DOOR: 3, STAIRS_DOWN: 4, STAIRS_UP: 5, WATER: 6 };
export const S = { NONE: 0, OIL: 1, BLOOD: 2, ICE: 3, WEB: 4 };

export const DIRS8 = [
  [1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1],
];

export class Level {
  constructor(depth, w, h) {
    this.depth = depth;
    this.w = w;
    this.h = h;
    const n = w * h;
    this.tiles = new Uint8Array(n);
    this.surface = new Uint8Array(n);
    this.surfaceAmt = new Float32Array(n);
    this.fire = new Float32Array(n);
    this.burning = new Set();
    this.smoke = new Float32Array(n);
    this.roomId = new Int16Array(n).fill(-1);
    this.explored = new Uint8Array(n);
    this.visible = new Uint8Array(n);
    this.light = new Float32Array(n);
    this.doors = new Map();
    this.props = new Map();
    this.items = new Map();
    this.corpses = new Map();
    this.actors = [];
    this.rooms = [];
    this.up = null;
    this.down = null;
    this.gateSealed = false;
    this.lastVisit = 0;
    this.version = 0; // bumped on any structural change the view must rebuild
    this.surfaceVersion = 0;
  }

  idx(x, y) {
    return y * this.w + x;
  }

  inBounds(x, y) {
    return x >= 0 && y >= 0 && x < this.w && y < this.h;
  }

  tile(x, y) {
    return this.inBounds(x, y) ? this.tiles[this.idx(x, y)] : T.ROCK;
  }

  door(x, y) {
    return this.doors.get(this.idx(x, y)) || null;
  }

  prop(x, y) {
    return this.props.get(this.idx(x, y)) || null;
  }

  propDef(p) {
    return PROPS[p.id];
  }

  isOpaque(x, y) {
    const t = this.tile(x, y);
    if (t === T.ROCK || t === T.WALL) return true;
    const i = this.idx(x, y);
    if (t === T.DOOR) {
      const d = this.doors.get(i);
      if (d && !d.open && !d.broken) return true;
    }
    const p = this.props.get(i);
    if (p && PROPS[p.id].opaque) return true;
    return this.smoke[i] > 0.6;
  }

  // Walkable terrain ignoring actors. Closed doors and blocking props are obstacles.
  isPassable(x, y) {
    const t = this.tile(x, y);
    if (t === T.ROCK || t === T.WALL) return false;
    const i = this.idx(x, y);
    if (t === T.DOOR) {
      const d = this.doors.get(i);
      if (d && !d.open && !d.broken) return false;
    }
    const p = this.props.get(i);
    if (p && PROPS[p.id].blocks) return false;
    return true;
  }

  isFloorLike(x, y) {
    const t = this.tile(x, y);
    return t === T.FLOOR || t === T.WATER || t === T.STAIRS_DOWN || t === T.STAIRS_UP || t === T.DOOR;
  }

  actorAt(x, y) {
    for (const a of this.actors) if (a.alive && a.x === x && a.y === y) return a;
    return null;
  }

  // Diagonal moves may not cut wall corners.
  canStep(x, y, nx, ny) {
    if (!this.isPassable(nx, ny)) return false;
    if (nx !== x && ny !== y) {
      if (!this.isPassable(nx, y) && !this.isPassable(x, ny)) return false;
      const t1 = this.tile(nx, y);
      const t2 = this.tile(x, ny);
      if (t1 === T.WALL || t2 === T.WALL || t1 === T.ROCK || t2 === T.ROCK) return false;
      if (t1 === T.DOOR || t2 === T.DOOR || this.tile(x, y) === T.DOOR || this.tile(nx, ny) === T.DOOR) {
        return false;
      }
    }
    return true;
  }

  addItem(x, y, item) {
    const i = this.idx(x, y);
    const list = this.items.get(i) || [];
    list.push(item);
    this.items.set(i, list);
  }

  itemsAt(x, y) {
    return this.items.get(this.idx(x, y)) || [];
  }

  setSurface(x, y, kind, amount) {
    const i = this.idx(x, y);
    this.surface[i] = kind;
    this.surfaceAmt[i] = amount;
    this.surfaceVersion++;
  }
}

// ------------------------------------------------------------------ FOV
// Recursive shadowcasting over 8 octants.
const OCTANTS = [
  [1, 0, 0, 1], [0, 1, 1, 0], [0, -1, 1, 0], [-1, 0, 0, 1],
  [-1, 0, 0, -1], [0, -1, -1, 0], [0, 1, -1, 0], [1, 0, 0, -1],
];

export function computeFov(level, ox, oy, radius, visit) {
  visit(ox, oy, 0);
  const r2 = radius * radius;
  for (const [xx, xy, yx, yy] of OCTANTS) {
    castLight(level, ox, oy, 1, 1.0, 0.0, radius, r2, xx, xy, yx, yy, visit);
  }
}

function castLight(level, cx, cy, row, start, end, radius, r2, xx, xy, yx, yy, visit) {
  if (start < end) return;
  let newStart = 0;
  for (let j = row; j <= radius; j++) {
    let dx = -j - 1;
    const dy = -j;
    let blocked = false;
    while (dx <= 0) {
      dx++;
      const X = cx + dx * xx + dy * xy;
      const Y = cy + dx * yx + dy * yy;
      const lSlope = (dx - 0.5) / (dy + 0.5);
      const rSlope = (dx + 0.5) / (dy - 0.5);
      if (start < rSlope) continue;
      if (end > lSlope) break;
      const d2 = dx * dx + dy * dy;
      if (d2 <= r2 && level.inBounds(X, Y)) visit(X, Y, Math.sqrt(d2));
      const opaque = !level.inBounds(X, Y) || level.isOpaque(X, Y);
      if (blocked) {
        if (opaque) {
          newStart = rSlope;
          continue;
        }
        blocked = false;
        start = newStart;
      } else if (opaque && j < radius) {
        blocked = true;
        castLight(level, cx, cy, j + 1, start, lSlope, radius, r2, xx, xy, yx, yy, visit);
        newStart = rSlope;
      }
    }
    if (blocked) break;
  }
}

export function lineOfSight(level, x0, y0, x1, y1) {
  let dx = Math.abs(x1 - x0);
  let dy = -Math.abs(y1 - y0);
  const sx = x0 < x1 ? 1 : -1;
  const sy = y0 < y1 ? 1 : -1;
  let err = dx + dy;
  let x = x0;
  let y = y0;
  while (!(x === x1 && y === y1)) {
    const e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y += sy;
    }
    if (x === x1 && y === y1) return true;
    if (level.isOpaque(x, y)) return false;
  }
  return true;
}

export function lineCells(x0, y0, x1, y1) {
  const cells = [];
  let dx = Math.abs(x1 - x0);
  let dy = -Math.abs(y1 - y0);
  const sx = x0 < x1 ? 1 : -1;
  const sy = y0 < y1 ? 1 : -1;
  let err = dx + dy;
  let x = x0;
  let y = y0;
  while (!(x === x1 && y === y1)) {
    const e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y += sy;
    }
    cells.push([x, y]);
  }
  return cells;
}

// ------------------------------------------------------------- A* search
class MinHeap {
  constructor() {
    this.items = [];
  }
  push(node, pri) {
    const a = this.items;
    a.push([pri, node]);
    let i = a.length - 1;
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (a[p][0] <= a[i][0]) break;
      [a[p], a[i]] = [a[i], a[p]];
      i = p;
    }
  }
  pop() {
    const a = this.items;
    const top = a[0];
    const last = a.pop();
    if (a.length) {
      a[0] = last;
      let i = 0;
      for (;;) {
        const l = 2 * i + 1;
        const r = l + 1;
        let m = i;
        if (l < a.length && a[l][0] < a[m][0]) m = l;
        if (r < a.length && a[r][0] < a[m][0]) m = r;
        if (m === i) break;
        [a[m], a[i]] = [a[i], a[m]];
        i = m;
      }
    }
    return top[1];
  }
  get size() {
    return this.items.length;
  }
}

// opts: canOpenDoors, bashes, avoidActors (actor to ignore), maxCost, toAdjacent
export function findPath(level, sx, sy, tx, ty, opts = {}) {
  const w = level.w;
  const start = sy * w + sx;
  const goal = ty * w + tx;
  if (start === goal) return [];
  const g = new Map([[start, 0]]);
  const came = new Map();
  const open = new MinHeap();
  const h = (i) => {
    const x = i % w;
    const y = (i / w) | 0;
    const dx = Math.abs(x - tx);
    const dy = Math.abs(y - ty);
    return Math.max(dx, dy) + 0.4 * Math.min(dx, dy);
  };
  open.push(start, h(start));
  let expanded = 0;
  const maxNodes = opts.maxNodes || 4000;
  while (open.size) {
    const cur = open.pop();
    if (cur === goal) break;
    const cx = cur % w;
    const cy = (cur / w) | 0;
    if (opts.toAdjacent && Math.max(Math.abs(cx - tx), Math.abs(cy - ty)) <= 1 && cur !== start) {
      return rebuild(came, start, cur, w);
    }
    if (++expanded > maxNodes) return null;
    for (const [dx, dy] of DIRS8) {
      const nx = cx + dx;
      const ny = cy + dy;
      if (!level.inBounds(nx, ny)) continue;
      const ni = ny * w + nx;
      const step = stepCost(level, cx, cy, nx, ny, ni, opts, ni === goal);
      if (step === Infinity) continue;
      const cost = g.get(cur) + step * (dx && dy ? 1.41 : 1);
      if (cost < (g.get(ni) ?? Infinity)) {
        g.set(ni, cost);
        came.set(ni, cur);
        open.push(ni, cost + h(ni));
      }
    }
  }
  if (!came.has(goal)) return null;
  return rebuild(came, start, goal, w);
}

function rebuild(came, start, end, w) {
  const path = [];
  let cur = end;
  while (cur !== start) {
    path.push([cur % w, (cur / w) | 0]);
    cur = came.get(cur);
  }
  return path.reverse();
}

function stepCost(level, cx, cy, nx, ny, ni, opts, isGoal) {
  const t = level.tiles[ni];
  if (t === T.ROCK || t === T.WALL) return Infinity;
  let cost = 1;
  if (nx !== cx && ny !== cy) {
    const a = level.tile(nx, cy);
    const b = level.tile(cx, ny);
    if (a === T.WALL || a === T.ROCK || b === T.WALL || b === T.ROCK) return Infinity;
    if (a === T.DOOR || b === T.DOOR || t === T.DOOR || level.tile(cx, cy) === T.DOOR) return Infinity;
  }
  if (t === T.DOOR) {
    const d = level.doors.get(ni);
    if (d && !d.open && !d.broken) {
      if (d.barricade > 0) {
        if (!opts.bashes) return Infinity;
        cost += 10 + d.barricade * 4;
      } else if (opts.canOpenDoors) cost += 1.5;
      else if (opts.bashes) cost += 8;
      else return Infinity;
    }
  }
  const p = level.props.get(ni);
  if (p && PROPS[p.id].blocks) {
    if (opts.bashes && PROPS[p.id].hp < 999) cost += 10;
    else return Infinity;
  }
  if (t === T.WATER) cost += 0.6;
  if (level.fire[ni] > 0) cost += 25;
  if (level.surface[ni] === S.WEB && !opts.webWalker) cost += 3;
  if (opts.avoidActors && !isGoal) {
    for (const a of level.actors) {
      if (a.alive && a !== opts.avoidActors && a.x === nx && a.y === ny) {
        cost += 6;
        break;
      }
    }
  }
  return cost;
}

// Flood-fill reachability over passable terrain, treating doors as passable.
export function reachable(level, sx, sy) {
  const seen = new Uint8Array(level.w * level.h);
  const stack = [[sx, sy]];
  seen[level.idx(sx, sy)] = 1;
  let count = 0;
  while (stack.length) {
    const [x, y] = stack.pop();
    count++;
    for (const [dx, dy] of DIRS8.slice(0, 4)) {
      const nx = x + dx;
      const ny = y + dy;
      if (!level.inBounds(nx, ny)) continue;
      const i = level.idx(nx, ny);
      if (seen[i]) continue;
      const t = level.tiles[i];
      if (t === T.ROCK || t === T.WALL) continue;
      const p = level.props.get(i);
      if (p && PROPS[p.id].blocks && !PROPS[p.id].movable) continue;
      seen[i] = 1;
      stack.push([nx, ny]);
    }
  }
  return { seen, count };
}
