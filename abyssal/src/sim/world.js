// World: SimulationClock + action scheduler ("Continuous Roguelike Time").
// Every actor, player included, runs timed actions on the same clock. The clock
// advances in fixed 20 ms ticks; presentation decides how fast real time feeds it
// (1x exploring, 0.35x tactical slowdown, 0 when paused, 40x while resting).
import { Rng } from './rng.js';
import { T, S, DIRS8, computeFov, findPath, lineOfSight } from './level.js';
import { generateLevel, newDoor, placeProp, addCorpse, freeCell } from './dungeon.js';
import { createPlayer, createItem, createMonster, itemName, carryCapacity, carriedWeight, countItem, consumeItem, addToInventory } from './entity.js';
import { propagateNoise, computeLighting, tickEnvironment, igniteCell } from './systems.js';
import { perceive, think, hearNoise, investigate, wake } from './ai.js';
import {
  applyDamage, playerMelee, playerAttackTime, weaponOf, statusMult, shoot, castSpell, spellFailure,
  throwItem, cheb, encumbrance,
} from './combat.js';
import { tickBody, deathCheck, legPenalty, worstWound, totalBleed, bleedRate, pain, PARTS } from './body.js';
import { ITEMS, RECIPES } from '../content/items.js';
import { MONSTERS } from '../content/monsters.js';
import { SPELLS, SKILLS } from '../content/characters.js';
import { PROPS, BRANCH } from '../content/world.js';

export const TICK = 20;
const START_MINUTE = 8 * 60 + 10;
const GAME_MS_PER_MINUTE = 1000; // 1 simulated second = 1 in-game minute

export class World {
  constructor(opts) {
    this.seed = opts.seed >>> 0;
    this.rng = new Rng(this.seed ^ 0x9e3779b9);
    this.now = 0;
    this.levels = {};
    this.depth = 0;
    this.level = null;
    this.events = [];
    this.log = [];
    this.flashes = [];
    this.projectiles = [];
    this.timers = [];
    this.lights = [];
    this.paused = false;
    this.autoSlow = opts.autoSlow ?? true;
    this.danger = false;
    this.seenHostiles = new Set();
    this.gameOver = null;
    this.victory = null;
    this.tickCount = 0;
    this.accum = 0;
    this.input = { heldDir: null };
    this.hall = opts.hallOfDead || [];
    this.hollowTarget = this.hall.find((h) => !h.laidToRest && h.depth >= 1 && h.depth <= BRANCH.floors) || null;
    this.onDeath = opts.onDeath || null;
    this.onLaidToRest = opts.onLaidToRest || null;
    this.lastPlayerHurt = -1e9;
    this.heardAt = new Map();
    this.player = createPlayer(opts.name, opts.species, opts.background);
    this.enterLevel(1, 'down');
    this.msg(`${this.player.name}, ${this.player.species.name} ${this.player.background.name}, desce à Fortaleza Esquecida.`, 'good');
    this.msg('Espaço pausa. T liga/desliga a câmera lenta tática. H mostra os controles.', 'info');
  }

  // ----------------------------------------------------------- clock
  timeScale() {
    if (this.paused || this.gameOver || this.victory) return 0;
    const act = this.player.action;
    if (act?.type === 'rest') return 40;
    if (act?.type === 'read' || act?.type === 'craft') return this.danger ? 1 : 3;
    if (this.autoSlow && this.danger) return 0.35;
    return 1;
  }

  update(realDt) {
    const simDt = Math.min(realDt, 100) * this.timeScale();
    this.accum += simDt;
    let steps = 0;
    while (this.accum >= TICK && steps < 400) {
      this.accum -= TICK;
      this.tick(TICK);
      steps++;
      if (this.gameOver || this.victory) break;
    }
  }

  tick(dt) {
    this.now += dt;
    this.tickCount++;
    const level = this.level;
    for (let i = this.timers.length - 1; i >= 0; i--) {
      if (this.timers[i].at <= this.now) {
        const t = this.timers[i];
        this.timers.splice(i, 1);
        t.fn();
      }
    }
    this.processActor(this.player);
    for (const m of level.actors) if (m.alive) this.processActor(m);
    this.updateProjectiles(dt);
    if (this.player.alive && !this.player.action) this.playerIdle();
    for (const m of level.actors) {
      if (m.alive && !m.action && this.now >= m.ai.nextThink) think(this, m);
    }
    if (this.tickCount % 5 === 0) {
      this.tickEffects(100);
      computeLighting(this);
      this.computeVisibility();
    }
    if (this.tickCount % 10 === 0) tickEnvironment(this, 200);
    if (this.tickCount % 12 === 0) {
      for (const m of level.actors) perceive(this, m);
      this.updateDanger();
    }
    if (this.tickCount % 50 === 0) this.tickNeeds(1000);
    if (this.tickCount % 250 === 0) {
      level.actors = level.actors.filter((a) => a.alive);
      this.flashes = this.flashes.filter((f) => f.until > this.now);
    }
  }

  later(ms, fn) {
    this.timers.push({ at: this.now + ms, fn });
  }

  processActor(a) {
    const act = a.action;
    if (!act) return;
    if (!act.committed && this.now >= act.t0 + (act.t1 - act.t0) * act.commitAt) {
      act.committed = true;
      act.onCommit?.();
      if (!a.alive) return;
    }
    if (a.action === act && this.now >= act.t1) {
      a.action = null;
      act.onFinish?.();
    }
  }

  startAction(a, spec) {
    const duration = Math.max(TICK, spec.duration);
    a.action = {
      commitAt: 1, ...spec, t0: this.now, t1: this.now + duration, committed: false,
    };
    if (a.action.commitAt === 0) {
      a.action.committed = true;
      a.action.onCommit?.();
    }
  }

  interrupt(a, text) {
    if (!a.action) return;
    a.action = null;
    if (a.ai) a.ai.nextThink = this.now + 350;
    if (text && (a.isPlayer || this.isVisible(a.x, a.y))) this.msg(text, a.isPlayer ? 'warn' : 'good');
  }

  // ---------------------------------------------------------- queries
  actorAt(x, y) {
    const p = this.player;
    if (p.alive && p.x === x && p.y === y) return p;
    return this.level.actorAt(x, y);
  }

  isVisible(x, y) {
    return this.level.inBounds(x, y) && this.level.visible[this.level.idx(x, y)] === 1;
  }

  gameTime() {
    const minutes = START_MINUTE + Math.floor(this.now / GAME_MS_PER_MINUTE);
    const day = Math.floor(minutes / 1440) + 1;
    const h = Math.floor((minutes % 1440) / 60);
    const m = minutes % 60;
    return { day, h, m, text: `Dia ${day}, ${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}` };
  }

  survivedText() {
    const minutes = Math.floor(this.now / GAME_MS_PER_MINUTE);
    const d = Math.floor(minutes / 1440);
    const h = Math.floor((minutes % 1440) / 60);
    const m = minutes % 60;
    return `${d} dia${d === 1 ? '' : 's'}, ${h} hora${h === 1 ? '' : 's'} e ${m} min`;
  }

  msg(text, cls = 'info') {
    this.log.push({ text, cls, t: this.now });
    if (this.log.length > 250) this.log.shift();
    this.events.push({ type: 'msg', text, cls });
  }

  flash(x, y, radius, intensity, color, duration) {
    this.flashes.push({ x, y, radius, intensity, color, until: this.now + duration });
  }

  corpseAt(x, y, pred = () => true) {
    const list = this.level.corpses.get(this.level.idx(x, y));
    return list?.find(pred) || null;
  }

  // ---------------------------------------------------------- levels
  enterLevel(depth, via) {
    const prev = this.level;
    const p = this.player;
    const followers = [];
    if (prev) {
      prev.lastVisit = this.now;
      for (const m of prev.actors) {
        if (!m.alive || cheb(m, p) > 1) continue;
        if (m.team === 'player' || (m.ai.state === 'hunt' && m.ai.target === p)) followers.push(m);
      }
      prev.actors = prev.actors.filter((m) => !followers.includes(m));
    }
    let level = this.levels[depth];
    let firstVisit = false;
    if (!level) {
      level = generateLevel(depth, (this.seed * 31 + depth * 7919) >>> 0, {
        needsNecroBook: depth === BRANCH.necroBookFloor,
        hollowed: this.hollowTarget && this.hollowTarget.depth === depth ? this.hollowTarget : null,
      });
      level.nextWander = this.now + 480000;
      this.levels[depth] = level;
      firstVisit = true;
    } else if (this.now - level.lastVisit > 720000 && this.rng.chance(0.5)) {
      this.dungeonRemembers(level);
    }
    this.level = level;
    this.depth = depth;
    const spot = via === 'down' ? level.up : level.down;
    p.x = p.px = spot.x;
    p.y = p.py = spot.y;
    p.moveT0 = p.moveT1 = this.now;
    p.path = null;
    p.action = null;
    this.projectiles = [];
    this.flashes = [];
    this.seenHostiles.clear();
    for (const m of followers) {
      const c = this.freeAdjacent(p.x, p.y);
      if (!c) continue;
      m.x = m.px = c[0];
      m.y = m.py = c[1];
      m.action = null;
      level.actors.push(m);
    }
    if (followers.length) this.msg('Algo desce as escadas atrás de você.', 'warn');
    computeLighting(this);
    this.computeVisibility();
    this.msg(`Profundidade ${depth} — ${BRANCH.name}.`, 'good');
    if (firstVisit && depth > 1) {
      this.gainXp(8 + depth * 2);
      p.stats.floorsSeen = Math.max(p.stats.floorsSeen, depth);
    }
    if (depth === BRANCH.floors && firstVisit) this.msg('Um silêncio pesado. Algo antigo guarda este andar.', 'danger');
  }

  freeAdjacent(x, y) {
    for (const [dx, dy] of DIRS8) {
      const nx = x + dx;
      const ny = y + dy;
      if (this.level.isPassable(nx, ny) && !this.actorAt(nx, ny)) return [nx, ny];
    }
    return null;
  }

  // The dungeon remembers: rarely, a floor you return to has changed.
  dungeonRemembers(level) {
    const rng = this.rng;
    const candidates = [];
    for (let y = 2; y < level.h - 2; y++) {
      for (let x = 2; x < level.w - 2; x++) {
        if (level.tile(x, y) !== T.WALL) continue;
        const horiz = level.isFloorLike(x - 1, y) && level.isFloorLike(x + 1, y) && !level.isFloorLike(x, y - 1) && !level.isFloorLike(x, y + 1);
        const vert = level.isFloorLike(x, y - 1) && level.isFloorLike(x, y + 1) && !level.isFloorLike(x - 1, y) && !level.isFloorLike(x + 1, y);
        if (!horiz && !vert) continue;
        const a = horiz ? [x - 1, y] : [x, y - 1];
        const b = horiz ? [x + 1, y] : [x, y + 1];
        const ra = level.roomId[level.idx(...a)];
        const rb = level.roomId[level.idx(...b)];
        if (ra === rb || (ra < 0 && rb < 0)) continue;
        let nearDoor = false;
        for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) if (level.tile(x + dx, y + dy) === T.DOOR) nearDoor = true;
        if (!nearDoor) candidates.push([x, y, ra, rb]);
      }
    }
    if (!candidates.length) return;
    const [x, y, ra, rb] = rng.pick(candidates);
    const i = level.idx(x, y);
    level.tiles[i] = T.DOOR;
    level.doors.set(i, { ...newDoor(false), anomaly: true });
    for (const r of [ra, rb]) if (r >= 0) level.rooms[r].doorCells.push([x, y]);
    level.version++;
    level.anomalies = [...(level.anomalies || []), i];
    this.later(10, () => this.msg('Algo neste andar parece diferente.', 'warn'));
  }

  // ------------------------------------------------------- perception
  computeVisibility() {
    const level = this.level;
    const p = this.player;
    level.visible.fill(0);
    const dv = Math.max(1.5, p.species.darkvision);
    computeFov(level, p.x, p.y, 16, (x, y, d) => {
      const i = level.idx(x, y);
      if (level.light[i] > 0.1 || d <= dv) {
        level.visible[i] = 1;
        level.explored[i] = 1;
      }
    });
    if (level.anomalies?.length) {
      for (const i of [...level.anomalies]) {
        if (level.visible[i]) {
          this.msg('Você tem certeza de que essa porta não estava ali.', 'danger');
          level.anomalies = level.anomalies.filter((k) => k !== i);
        }
      }
    }
  }

  updateDanger() {
    const visible = [];
    for (const m of this.level.actors) {
      if (!m.alive || m.team !== 'hostile') continue;
      if (!this.isVisible(m.x, m.y)) continue;
      visible.push(m);
      if (!this.seenHostiles.has(m.id)) {
        this.seenHostiles.add(m.id);
        this.msg(`Você vê: ${m.name}${m.ai.state === 'sleep' ? ' (dormindo)' : ''}.`, 'warn');
        const p = this.player;
        if (p.path) {
          p.path = null;
          p.attackTarget = null;
        }
        if (p.action && ['rest', 'read', 'craft'].includes(p.action.type)) this.interrupt(p, 'Você interrompe o que fazia.');
      }
    }
    this.visibleHostiles = visible;
    this.danger = visible.some((m) => m.ai.state === 'hunt' || m.ai.state === 'investigate') ||
      this.projectiles.some((pr) => pr.owner?.team === 'hostile');
  }

  onNoticed(m) {
    if (this.isVisible(m.x, m.y)) this.msg(`${m.name} nota você!`, 'danger');
    this.player.needs.fear = Math.min(100, this.player.needs.fear + 6);
  }

  // Sound: a second vision. Monsters hear, the player hears unseen things.
  emitNoise(x, y, volume, info = {}) {
    if (volume < 1) return;
    const field = propagateNoise(this.level, x, y, volume);
    for (const m of this.level.actors) {
      if (!m.alive || m === info.source) continue;
      const rem = field.get(this.level.idx(m.x, m.y));
      if (rem) hearNoise(this, m, x, y, rem);
    }
    const p = this.player;
    if (info.source?.isPlayer || info.self) {
      this.events.push({ type: 'noise', x, y, volume, own: true });
      return;
    }
    const rem = field.get(this.level.idx(p.x, p.y));
    if (!rem || rem < 1) return;
    if (p.action?.type === 'rest' && rem >= 2.5) this.interrupt(p, `Um barulho te acorda: ${info.label || 'algo'}.`);
    if (this.isVisible(x, y)) return;
    this.events.push({ type: 'heard', x, y, volume: rem });
    const key = info.source ? info.source.id : `${x},${y}`;
    if ((this.heardAt.get(key) || -1e9) + 7000 > this.now) return;
    this.heardAt.set(key, this.now);
    const label = info.label || 'algo';
    this.msg(`Você ouve ${label} ${direction(p.x, p.y, x, y)}.`, 'sound');
  }

  emitMagic(x, y, range) {
    for (const m of this.level.actors) {
      if (!m.alive || m.team !== 'hostile') continue;
      const sense = m.def.senses.magic;
      if (!sense) continue;
      if (Math.hypot(m.x - x, m.y - y) <= sense + range * 0.3) {
        if (m.ai.state === 'sleep') wake(this, m);
        investigate(this, m, x, y, 1, 'magia');
      }
    }
  }

  // --------------------------------------------------------- movement
  moveTime(a, nx, ny) {
    const diag = nx !== a.x && ny !== a.y ? 1.35 : 1;
    let t;
    if (a.isPlayer) {
      t = (a.sneaking ? 540 : 300) * legPenalty(a.body) * statusMult(a);
      const over = carriedWeight(a) - carryCapacity(a);
      if (over > 0) t *= 1 + over / 8;
    } else {
      t = a.def.move * (a.effects.slowUntil > this.now ? 1.6 : 1);
    }
    if (this.level.tile(nx, ny) === T.WATER) t *= 1.3;
    return t * diag;
  }

  startMove(a, nx, ny) {
    const t = this.moveTime(a, nx, ny);
    a.px = a.x;
    a.py = a.y;
    a.x = nx;
    a.y = ny;
    a.moveT0 = this.now;
    a.moveT1 = this.now + t;
    a.leap = false;
    a.facing = Math.atan2(ny - a.py, nx - a.px);
    this.startAction(a, { type: 'move', label: 'andando', duration: t, commitAt: 0 });
    this.onEnterCell(a, nx, ny);
  }

  onEnterCell(a, x, y) {
    const level = this.level;
    const i = level.idx(x, y);
    const surf = level.surface[i];
    const rng = this.rng;
    // Footsteps.
    let noise;
    if (a.isPlayer) {
      noise = a.sneaking ? Math.max(0, 1.2 - a.skills.stealth.level * 0.2) : 2 + (encumbrance(a) > 3 ? 2 : 0);
      if (level.tile(x, y) === T.WATER) noise += 2;
      if (noise >= 1) this.emitNoise(x, y, noise, { source: a, label: 'passos' });
      if (!a.sneaking) this.train('stealth', 0);
      else this.train('stealth', 0.05);
    } else {
      noise = a.def.stepNoise || 0;
      if (level.tile(x, y) === T.WATER) noise += 1;
      if (noise >= 1) this.emitNoise(x, y, noise, { source: a, label: noise >= 4 ? 'passos pesados' : noise >= 2 ? 'passos' : 'algo se arrastando' });
    }
    if (surf === S.WEB && !a.def?.webs) {
      a.effects.stuckUntil = this.now + 1800;
      if (a.action) a.action.t1 += 1800;
      if (rng.chance(0.5)) level.setSurface(x, y, S.NONE, 0);
      if (a.isPlayer) this.msg('Você fica preso na teia!', 'warn');
    }
    if (surf === S.ICE && !rng.chance(a.isPlayer ? 0.55 + a.skills.dodging.level * 0.03 : 0.5)) {
      a.effects.fallenUntil = this.now + 1200;
      if (a.action) {
        a.action.t1 += 1200;
        a.moveT1 += 200;
      }
      if (a.isPlayer || this.isVisible(x, y)) this.msg(a.isPlayer ? 'Você escorrega no gelo!' : `${a.name} escorrega no gelo.`, a.isPlayer ? 'warn' : 'good');
      this.emitNoise(x, y, 3, { source: a, label: 'algo caindo' });
    }
    if (level.fire[i] > 0) {
      this.damage(a, { fire: rng.range(3, 6) }, { sourceName: 'fogo', label: 'chamas', part: a.isPlayer ? rng.pick(['footL', 'footR', 'legL', 'legR']) : undefined });
    }
    if (a.isPlayer) {
      const items = level.itemsAt(x, y);
      if (items.length) this.msg(`Aqui: ${items.map(itemName).join(', ')}.`, 'info');
      const corpses = level.corpses.get(i);
      if (corpses?.length) this.msg(`Aqui jaz: ${corpses.map((c) => c.name).join(', ')}.`, 'info');
      const t = level.tile(x, y);
      if (t === T.STAIRS_DOWN) this.msg(level.gateSealed ? 'O Portão do Profundo, selado.' : 'Escadas para baixo. [Enter] para descer.', 'good');
      if (t === T.STAIRS_UP) this.msg('Escadas para cima. [Enter] para subir.', 'good');
    }
  }

  setDoor(x, y, open, who) {
    const d = this.level.door(x, y);
    if (!d || d.broken) return;
    d.open = open;
    this.emitNoise(x, y, 3, { source: who, label: open ? 'uma porta rangendo' : 'uma porta batendo' });
    this.lightDirty = true;
  }

  bashDoor(m, x, y) {
    const d = this.level.door(x, y);
    if (!d || d.open || d.broken) return;
    const dmg = m.def.behavior?.doorBreaker ? 14 : 5;
    d.hp -= dmg;
    d.barricade = Math.max(0, Math.ceil((d.hp - 30) / 25));
    this.emitNoise(x, y, 9, { source: m, label: 'pancadas numa porta' });
    this.events.push({ type: 'bash', x, y });
    if (d.hp <= 0) {
      d.broken = true;
      d.open = true;
      d.barricade = 0;
      this.level.version++;
      this.msg(this.isVisible(x, y) ? `${m.name} arrebenta a porta!` : 'Você ouve madeira se partindo.', 'danger');
    }
  }

  bashProp(m, prop) {
    const level = this.level;
    if (level.props.get(level.idx(prop.x, prop.y)) !== prop) return;
    prop.hp -= m.def.behavior?.doorBreaker ? 14 : 5;
    this.emitNoise(prop.x, prop.y, 7, { source: m, label: 'algo sendo destruído' });
    this.events.push({ type: 'bash', x: prop.x, y: prop.y });
    if (prop.hp <= 0) this.destroyProp(prop);
  }

  destroyProp(prop) {
    const level = this.level;
    level.props.delete(level.idx(prop.x, prop.y));
    for (const it of prop.items) level.addItem(prop.x, prop.y, it);
    if (PROPS[prop.id].spills) {
      for (const [dx, dy] of [[0, 0], ...DIRS8]) if (level.isFloorLike(prop.x + dx, prop.y + dy) && this.rng.chance(0.6)) level.setSurface(prop.x + dx, prop.y + dy, S.OIL, 20000);
    }
    if (PROPS[prop.id].wood) level.addItem(prop.x, prop.y, createItem('plank', 1));
    level.version++;
    if (this.isVisible(prop.x, prop.y)) this.msg(`${PROPS[prop.id].name} se despedaça.`, 'info');
  }

  // ----------------------------------------------------------- combat
  damage(target, dmg, info) {
    return applyDamage(this, target, dmg, info);
  }

  kill(m, killer) {
    if (!m.alive) return;
    m.alive = false;
    m.action = null;
    const level = this.level;
    const def = m.def;
    for (const it of m.loot) level.addItem(m.x, m.y, it);
    for (const id of def.drops || []) level.addItem(m.x, m.y, createItem(id));
    if (m.team === 'player') {
      if (this.isVisible(m.x, m.y)) this.msg(`${m.name} desmorona em pó.`, 'info');
    } else {
      if (def.corpse) {
        addCorpse(level, m.x, m.y, {
          name: m.hollowed ? `Restos de ${m.hollowed.name}` : def.corpse, monsterId: m.hollowed ? null : m.defId,
          time: this.now, bleeds: def.bleeds, charred: false,
        });
      }
      if (this.isVisible(m.x, m.y) || killer?.isPlayer) this.msg(`${m.name} morre.`, 'good');
      if (killer && (killer.isPlayer || killer.team === 'player')) {
        this.player.kills++;
        this.gainXp(def.xp);
      }
    }
    this.events.push({ type: 'death', actor: m, x: m.x, y: m.y });
    if (def.boss) {
      level.gateSealed = false;
      this.msg('O Castelão Oco cai. O Portão do Profundo se abre com um gemido de pedra.', 'good');
      this.emitNoise(m.x, m.y, 30, { self: true, label: 'pedra se movendo' });
    }
    if (m.hollowed) {
      this.msg(`${m.hollowed.name} finalmente descansa.`, 'good');
      m.hollowed.laidToRest = true;
      this.onLaidToRest?.(m.hollowed);
    }
  }

  crumble(m) {
    m.alive = false;
    m.action = null;
    if (this.isVisible(m.x, m.y)) this.msg(`${m.name} desmorona: a necromancia se esgota.`, 'info');
    this.events.push({ type: 'death', actor: m, x: m.x, y: m.y });
  }

  raiseDead(corpse, x, y, power) {
    const level = this.level;
    const list = level.corpses.get(level.idx(x, y));
    list.splice(list.indexOf(corpse), 1);
    if (!list.length) level.corpses.delete(level.idx(x, y));
    const def = MONSTERS[corpse.monsterId];
    const cell = !this.actorAt(x, y) ? [x, y] : this.freeAdjacent(x, y);
    if (!cell) return;
    const ally = createMonster(corpse.monsterId, cell[0], cell[1], this.rng, {
      team: 'player', name: `Servo (${def.name})`, hp: Math.max(4, Math.round(def.hp * 0.7 * power)),
      awake: true, expires: this.now + 240000 * power,
    });
    ally.raised = true;
    ally.ai.state = 'idle';
    level.actors.push(ally);
    this.events.push({ type: 'raise', x: cell[0], y: cell[1] });
    this.msg(`${def.corpse || def.name} se ergue e obedece.`, 'magic');
  }

  // ------------------------------------------------------ projectiles
  spawnProjectile(spec) {
    const { x, y, tx, ty } = spec;
    const dx = tx - x;
    const dy = ty - y;
    const len = Math.max(Math.abs(dx), Math.abs(dy)) || 1;
    const cells = [];
    // Walk the line to the target, then continue up to range.
    let cx = x;
    let cy = y;
    const steps = Math.max(len, spec.range || len);
    for (let s = 1; s <= steps; s++) {
      cx = Math.round(x + (dx / len) * s);
      cy = Math.round(y + (dy / len) * s);
      cells.push([cx, cy]);
      if (s >= len && spec.kind !== 'bolt') break;
    }
    this.projectiles.push({ ...spec, cells, idx: 0, progress: 0, fx: x, fy: y, id: this.rng.int(1, 1e9), from: [x, y] });
  }

  updateProjectiles(dt) {
    for (let k = this.projectiles.length - 1; k >= 0; k--) {
      const pr = this.projectiles[k];
      pr.progress += (pr.speed * dt) / 1000;
      let done = false;
      while (pr.idx < pr.cells.length && pr.idx < pr.progress && !done) {
        const [x, y] = pr.cells[pr.idx];
        const prev = pr.idx > 0 ? pr.cells[pr.idx - 1] : pr.from;
        const prop = this.level.prop(x, y);
        if (prop && PROPS[prop.id].blocks && !pr.passActors) {
          // Furniture takes the hit itself (and burns, freezes or breaks).
          pr.onHit(x, y, this.actorAt(x, y));
          done = true;
          break;
        }
        if (this.level.isOpaque(x, y) || (prop && PROPS[prop.id].blocks)) {
          pr.onHit(prev[0], prev[1], null);
          done = true;
          break;
        }
        const a = this.actorAt(x, y);
        if (a && a !== pr.owner && !pr.passActors) {
          pr.onHit(x, y, a);
          done = true;
          break;
        }
        pr.idx++;
        if (pr.idx >= pr.cells.length) {
          pr.onHit(x, y, this.actorAt(x, y));
          done = true;
        }
      }
      const c = pr.cells[Math.min(pr.cells.length - 1, Math.floor(pr.progress))] || pr.from;
      const f = pr.progress - Math.floor(pr.progress);
      const a0 = pr.cells[Math.floor(pr.progress) - 1] || pr.from;
      pr.fx = a0[0] + (c[0] - a0[0]) * f;
      pr.fy = a0[1] + (c[1] - a0[1]) * f;
      if (done) this.projectiles.splice(k, 1);
    }
  }

  // -------------------------------------------------- periodic systems
  tickEffects(dt) {
    const p = this.player;
    if (p.alive) {
      const recently = this.now - (p.lastAttackAt || -1e9) < 1500;
      let regen = recently ? 0.4 : 1.4;
      if (p.needs.hunger > 70) regen *= 0.5;
      if (p.needs.fatigue > 80) regen *= 0.6;
      p.stamina = Math.min(100, p.stamina + regen * (dt / 100));
      p.mana = Math.min(p.maxMana, p.mana + 0.03 * (1 + p.skills.spellcasting.level * 0.1) * (dt / 100));
      if (p.effects.stuckUntil && p.effects.stuckUntil < this.now) p.effects.stuckUntil = 0;
      // Smoke: the room fills, you cough, you choke.
      const sm = this.level.smoke[this.level.idx(p.x, p.y)];
      if (sm > 0.35 && !p.equip.face?.id?.includes('gas_mask')) {
        if (this.rng.chance(0.06)) {
          this.msg('Você tosse na fumaça.', 'warn');
          this.emitNoise(p.x, p.y, 4, { source: p, label: 'tosse' });
        }
        p.needs.fatigue = Math.min(100, p.needs.fatigue + 0.05);
        if (sm > 0.7) {
          p.body.parts.torso.hp -= 0.05;
          p.lastTorsoCause = 'asfixia pela fumaça';
          this.checkPlayerDeath();
        }
      }
    }
  }

  tickNeeds(dt) {
    const p = this.player;
    if (!p.alive) return;
    const sec = dt / 1000;
    const sp = p.species.needs;
    const act = p.action;
    const sleeping = act?.type === 'rest' && act.sleep;
    const safe = this.isSafeRoom();
    this.safe = safe;
    p.needs.hunger = Math.min(100, p.needs.hunger + 0.045 * sp.hunger * (sleeping ? 0.6 : 1) * sec);
    p.needs.thirst = Math.min(100, p.needs.thirst + 0.065 * sp.thirst * (sleeping ? 0.6 : 1) * sec);
    if (sleeping) {
      const bed = this.level.prop(p.x, p.y) && PROPS[this.level.prop(p.x, p.y).id].rest ? 1.5 : 1;
      p.needs.fatigue = Math.max(0, p.needs.fatigue - 0.28 * sp.fatigue * bed * (safe ? 1.5 : 1) * sec);
      if (p.needs.fatigue <= 1) {
        this.interrupt(p);
        this.msg('Você acorda descansado.', 'good');
      }
    } else {
      const over = Math.max(0, carriedWeight(p) - carryCapacity(p));
      p.needs.fatigue = Math.min(100, p.needs.fatigue + 0.05 * sp.fatigue * (1 + encumbrance(p) * 0.08 + over * 0.05) * sec);
    }
    // Fear/stress.
    const hostiles = (this.visibleHostiles || []).filter((m) => m.ai.state !== 'sleep').length;
    const lightHere = this.level.light[this.level.idx(p.x, p.y)];
    let dFear = -0.5;
    if (hostiles) dFear = Math.min(4, hostiles * 1.2);
    else if (lightHere < 0.1 && p.species.darkvision < 1) dFear = 0.25;
    if (safe && !hostiles) dFear -= 1.5;
    if (this.nearWarmth(p)) dFear -= 1;
    p.needs.fear = Math.max(0, Math.min(100, p.needs.fear + dFear * sec));
    // Light fuel.
    const lantern = p.equip.belt;
    if (lantern && p.lanternOn && lantern.fuel > 0) {
      lantern.fuel = Math.max(0, lantern.fuel - sec);
      if (lantern.fuel === 0) this.msg('A lamparina se apaga. Escuridão.', 'danger');
      else if (Math.abs(lantern.fuel - 600) < sec) this.msg('A chama da lamparina está fraca. Pouco óleo.', 'warn');
    }
    const off = p.equip.off;
    if (off?.id === 'torch' && off.fuel > 0) {
      off.fuel = Math.max(0, off.fuel - sec);
      if (off.fuel === 0) {
        this.msg('A tocha se apaga.', 'warn');
        p.equip.off = null;
      }
    }
    for (const prop of this.level.props.values()) {
      if (prop.fuel !== undefined && prop.fuel > 0) {
        prop.fuel -= sec;
        if (prop.fuel <= 0) {
          this.level.props.delete(this.level.idx(prop.x, prop.y));
          this.level.version++;
        }
      }
    }
    // Starvation and thirst.
    const starving = p.needs.hunger >= 100;
    const dehydrated = p.needs.thirst >= 100;
    if (starving) {
      p.body.parts.torso.hp -= 0.12 * sec;
      p.lastTorsoCause = 'inanição';
    }
    if (dehydrated) {
      p.body.parts.torso.hp -= 0.2 * sec;
      p.lastTorsoCause = p.species.bloodDrinker ? 'sede de sangue' : 'desidratação';
    }
    if (p.effects.poison > 0) {
      p.body.parts.torso.hp -= 0.3 * sec;
      p.effects.poison = Math.max(0, p.effects.poison - sec);
      p.lastTorsoCause = 'envenenamento';
    }
    let healMult = sleeping ? 1.8 : 1;
    if (p.species.regen && p.needs.thirst < 50) healMult *= 2;
    const infected = worstWound(p.body, (w) => w.infection > 0.3);
    if (infected) p.lastTorsoCause = `infecção (${infected.wound.source})`;
    tickBody(p.body, dt, { rng: this.rng, starving, dehydrated, healMult });
    if (totalBleed(p.body) > 0.08 && this.rng.chance(0.5) && this.level.tile(p.x, p.y) === T.FLOOR) {
      this.level.setSurface(p.x, p.y, S.BLOOD, 60000);
    }
    this.checkPlayerDeath();
    // Monsters: regeneration, poison, expiry.
    for (const m of this.level.actors) {
      if (!m.alive) continue;
      if (m.def.regen && m.hp < m.maxHp && this.now - (m.effects.burnedAt || -1e9) > 6000) m.hp = Math.min(m.maxHp, m.hp + m.def.regen * sec);
      if (m.effects.poison > 0) {
        m.hp -= 0.5 * sec;
        m.effects.poison -= sec;
        if (m.hp <= 0) this.kill(m, this.player);
      }
      if (m.expires && this.now > m.expires) this.crumble(m);
    }
    // The dungeon restocks itself while you are away from the stairs.
    if (this.now >= this.level.nextWander) {
      this.level.nextWander = this.now + 480000;
      this.spawnWanderers();
    }
  }

  nearWarmth(p) {
    for (const [dx, dy] of [[0, 0], ...DIRS8]) {
      const prop = this.level.prop(p.x + dx, p.y + dy);
      if (prop && PROPS[prop.id].warm) return true;
    }
    return false;
  }

  spawnWanderers() {
    const level = this.level;
    const p = this.player;
    const eligible = Object.entries(MONSTERS).filter(([, d]) => this.depth >= d.depth[0] && this.depth <= d.depth[1] && !d.boss);
    if (!eligible.length) return;
    const rooms = level.rooms.filter((r) => Math.hypot(r.x - p.x, r.y - p.y) > 16);
    if (!rooms.length) return;
    const room = this.rng.pick(rooms);
    const [id, def] = this.rng.weighted(eligible.map((e) => [e, e[1].weight]));
    const n = def.behavior?.pack ? this.rng.int(...def.behavior.pack) : 1;
    for (let k = 0; k < n; k++) {
      const c = freeCell(level, room, this.rng);
      if (!c || this.isVisible(c[0], c[1])) continue;
      const m = createMonster(id, c[0], c[1], this.rng, { awake: true });
      m.def = { ...def, behavior: { ...def.behavior, wanders: true } };
      level.actors.push(m);
    }
    this.msg('Em algum lugar, a masmorra se reabastece.', 'sound');
  }

  isSafeRoom() {
    const level = this.level;
    const p = this.player;
    const rid = level.roomId[level.idx(p.x, p.y)];
    if (rid < 0) return false;
    const room = level.rooms[rid];
    if (!room.doorCells.length) return false;
    for (const [x, y] of room.doorCells) {
      if (level.tile(x, y) !== T.DOOR) return false;
      const d = level.door(x, y);
      if (!d || d.open || d.broken) return false;
      if (d.barricade > 0) continue;
      let blocked = false;
      for (const [dx, dy] of DIRS8.slice(0, 4)) {
        const pr = level.prop(x + dx, y + dy);
        if (pr && PROPS[pr.id].blocks && level.roomId[level.idx(x + dx, y + dy)] === rid) blocked = true;
      }
      if (!blocked) return false;
    }
    for (const m of level.actors) if (m.alive && m.team === 'hostile' && level.roomId[level.idx(m.x, m.y)] === rid) return false;
    return true;
  }

  checkPlayerDeath() {
    const p = this.player;
    if (!p.alive) return;
    const cause = deathCheck(p.body, { lastBleedSource: p.lastBleedSource, lastHit: p.lastHitBy, lastTorsoCause: p.lastTorsoCause });
    if (cause) this.die(cause);
  }

  die(cause) {
    const p = this.player;
    p.alive = false;
    p.action = null;
    const t = this.gameTime();
    const relics = [...p.inv, ...Object.values(p.equip)].filter((it) => it && ITEMS[it.id].kind === 'relic');
    const record = {
      name: p.name, species: p.species.name, background: p.background.name, speciesId: p.speciesId,
      backgroundId: p.backgroundId, depth: this.depth, cause, day: t.day, survived: this.survivedText(),
      kills: p.kills, relics: relics.reduce((s, it) => s + ITEMS[it.id].value * (it.qty || 1), 0),
      gear: Object.values(p.equip).filter(Boolean).map((it) => it.id).concat(p.inv.filter((it) => ITEMS[it.id].kind === 'weapon').map((it) => it.id)),
      date: new Date().toISOString(), laidToRest: false,
    };
    this.gameOver = record;
    this.msg(`Você morreu: ${cause}.`, 'danger');
    this.onDeath?.(record);
  }

  // --------------------------------------------------------------- XP
  gainXp(amount) {
    const p = this.player;
    const training = Object.entries(p.skills).filter(([, s]) => s.train);
    if (!training.length) return;
    const share = amount / training.length;
    for (const [id, s] of training) {
      const before = Math.floor(s.level);
      const apt = p.species.aptitudes[id] || 0;
      const cost = (4 + s.level * 2.4) * Math.pow(0.85, apt);
      s.level = Math.min(27, s.level + share / cost);
      if (Math.floor(s.level) > before) this.msg(`${SKILLS[id].name} sobe para ${Math.floor(s.level)}.`, 'good');
    }
    p.maxMana = 10 + Math.round(p.skills.spellcasting.level * 4 + p.skills.necromancy.level * 1.5);
  }

  // Tiny practice gain; the real growth is XP deliberately allocated (DCSS-style).
  train(skillId, amount) {
    const s = this.player.skills[skillId];
    if (!s || !amount || !s.train) return;
    s.level = Math.min(27, s.level + (amount * 0.004) / (1 + s.level * 0.3));
  }

  // --------------------------------------------------- player control
  playerIdle() {
    const p = this.player;
    if (p.queued) {
      const q = p.queued;
      p.queued = null;
      p.queuedLabel = null;
      q();
      return;
    }
    if (p.attackTarget) {
      const t = p.attackTarget;
      if (!t.alive || !this.isVisible(t.x, t.y)) {
        p.attackTarget = null;
        p.path = null;
      } else if (cheb(p, t) <= weaponOf(p).def.reach && (weaponOf(p).def.reach === 1 || lineOfSight(this.level, p.x, p.y, t.x, t.y))) {
        this.doMelee(t);
        return;
      } else {
        p.path = findPath(this.level, p.x, p.y, t.x, t.y, { canOpenDoors: true, toAdjacent: true, avoidActors: p });
      }
    }
    if (p.path && !p.path.length) p.path = null;
    if (p.path) {
      const [nx, ny] = p.path[0];
      if (Math.max(Math.abs(nx - p.x), Math.abs(ny - p.y)) !== 1 || !this.stepPlayer(nx - p.x, ny - p.y, true)) {
        p.path = null;
        return;
      }
      if (p.x === nx && p.y === ny) p.path.shift();
      return;
    }
    if (this.input.heldDir) {
      const [dx, dy] = this.input.heldDir;
      // Slide along walls: a blocked diagonal tries its two axis components.
      if (!this.stepPlayer(dx, dy, false) && dx && dy) {
        if (!this.stepPlayer(dx, 0, true)) this.stepPlayer(0, dy, true);
      }
    }
  }

  command(label, fn) {
    const p = this.player;
    if (!p.alive || this.victory) return;
    if (p.action?.type === 'rest') this.interrupt(p, 'Você se levanta.');
    if (p.action || this.paused) {
      p.queued = fn;
      p.queuedLabel = label;
      return;
    }
    fn();
  }

  // Bump-to-act: attack, open doors, push furniture, remove barricades, walk.
  stepPlayer(dx, dy, auto) {
    const p = this.player;
    const level = this.level;
    if (p.effects.stuckUntil > this.now) {
      this.startAction(p, { type: 'wait', label: 'soltando-se da teia', duration: p.effects.stuckUntil - this.now });
      return true;
    }
    const nx = p.x + dx;
    const ny = p.y + dy;
    if (!level.inBounds(nx, ny)) return false;
    const other = this.actorAt(nx, ny);
    if (other && other !== p) {
      if (other.team === 'hostile') {
        this.doMelee(other);
        return true;
      }
      // Swap with allies.
      if (!level.canStep(p.x, p.y, nx, ny)) return false;
      other.x = p.x;
      other.y = p.y;
      other.px = nx;
      other.py = ny;
      other.moveT0 = this.now;
      other.moveT1 = this.now + 300;
      this.startMove(p, nx, ny);
      return true;
    }
    const door = level.door(nx, ny);
    if (door && !door.open && !door.broken) {
      if (door.barricade > 0) {
        this.startAction(p, {
          type: 'work', label: 'arrancando tábuas', duration: 2500, interruptible: true,
          onCommit: () => {
            door.barricade--;
            door.hp = Math.min(door.hp, 30 + door.barricade * 25);
            addToInventory(p, createItem('plank', 1));
            this.emitNoise(nx, ny, 6, { source: p, label: 'madeira rangendo' });
            this.msg(`Você remove uma tábua (${door.barricade} restantes).`, 'info');
          },
        });
        return !auto;
      }
      this.startAction(p, {
        type: 'door', label: 'abrindo porta', duration: 350, commitAt: 1,
        onCommit: () => this.setDoor(nx, ny, true, p),
      });
      return true;
    }
    const prop = level.prop(nx, ny);
    if (prop && PROPS[prop.id].blocks) {
      if (auto || (dx && dy)) return false;
      if (PROPS[prop.id].movable) return this.pushProp(prop, dx, dy);
      this.blockedMsg(`${PROPS[prop.id].name} bloqueia o caminho.`);
      return false;
    }
    if (!level.canStep(p.x, p.y, nx, ny)) return false;
    this.startMove(p, nx, ny);
    return true;
  }

  blockedMsg(text) {
    if (this.now - (this.lastBlockMsg || -1e9) < 2000) return;
    this.lastBlockMsg = this.now;
    this.msg(text, 'info');
  }

  pushProp(prop, dx, dy) {
    const p = this.player;
    const level = this.level;
    const tx = prop.x + dx;
    const ty = prop.y + dy;
    const t = level.tile(tx, ty);
    const ok = (t === T.FLOOR || t === T.WATER) && !level.prop(tx, ty) && !this.actorAt(tx, ty) && !(dx && dy);
    const def = PROPS[prop.id];
    if (!ok) {
      this.blockedMsg(`Não há espaço para arrastar ${def.name.toLowerCase()}.`);
      return false;
    }
    this.startAction(p, {
      type: 'push', label: `arrastando ${def.name.toLowerCase()}`, duration: def.pushTime * statusMult(p),
      onCommit: () => {
        if (level.props.get(level.idx(prop.x, prop.y)) !== prop || level.prop(tx, ty) || this.actorAt(tx, ty)) return;
        level.props.delete(level.idx(prop.x, prop.y));
        const ox = prop.x;
        const oy = prop.y;
        prop.x = tx;
        prop.y = ty;
        level.props.set(level.idx(tx, ty), prop);
        level.version++;
        this.emitNoise(ox, oy, def.pushNoise, { source: p, label: 'móveis arrastados' });
        p.px = p.x;
        p.py = p.y;
        p.x = ox;
        p.y = oy;
        p.moveT0 = this.now;
        p.moveT1 = this.now + 200;
        p.needs.fatigue = Math.min(100, p.needs.fatigue + 0.4);
        if (this.isSafeRoom()) this.msg('Sala segura: todas as portas estão fechadas e bloqueadas.', 'good');
      },
    });
    return true;
  }

  doMelee(target) {
    const p = this.player;
    const { def } = weaponOf(p);
    if (def.ranged && cheb(p, target) > 1) return this.cmdShoot(target.x, target.y);
    p.facing = Math.atan2(target.y - p.y, target.x - p.x);
    p.lastAttackAt = this.now;
    const time = playerAttackTime(p);
    this.startAction(p, {
      type: 'attack', label: `atacando com ${def.name}`, duration: time, commitAt: 0.6, target,
      onCommit: () => playerMelee(this, p, target),
    });
  }

  cmdMoveDir(dx, dy) {
    this.command('mover', () => this.stepPlayer(dx, dy, false));
  }

  cmdMoveTo(x, y) {
    const p = this.player;
    if (!this.level.inBounds(x, y) || !this.level.explored[this.level.idx(x, y)]) return;
    const path = findPath(this.level, p.x, p.y, x, y, { canOpenDoors: true, avoidActors: p });
    if (!path) {
      this.msg('Não há caminho conhecido até lá.', 'info');
      return;
    }
    p.attackTarget = null;
    this.command('caminhar', () => {
      p.path = path;
    });
  }

  cmdAttack(target) {
    const p = this.player;
    this.command(`atacar ${target.name}`, () => {
      p.attackTarget = target;
      p.path = null;
    });
  }

  // Click on a cell: attack, open/close door, search, stairs or walk.
  cmdInteract(x, y) {
    const p = this.player;
    const level = this.level;
    const a = this.actorAt(x, y);
    if (a && a !== p && a.team === 'hostile' && this.isVisible(x, y)) return this.cmdAttack(a);
    const near = cheb(p, { x, y }) <= 1;
    if (x === p.x && y === p.y) {
      const t = level.tile(x, y);
      if (t === T.STAIRS_DOWN || t === T.STAIRS_UP) return this.cmdStairs();
      return this.cmdPickupAll();
    }
    const door = level.door(x, y);
    if (door && near && !door.broken) {
      if (!door.open) return this.cmdMoveDir(x - p.x, y - p.y);
      return this.cmdCloseDoor(x, y);
    }
    const prop = level.prop(x, y);
    if (prop && near && PROPS[prop.id].container) return this.cmdSearch(prop);
    this.cmdMoveTo(x, y);
  }

  cmdCloseDoor(x, y) {
    const p = this.player;
    this.command('fechar porta', () => {
      if (this.actorAt(x, y) || this.level.itemsAt(x, y).length) {
        this.msg('Algo está no caminho da porta.', 'info');
        return;
      }
      this.startAction(p, { type: 'door', label: 'fechando porta', duration: 350, onCommit: () => {
        this.setDoor(x, y, false, p);
        if (this.isSafeRoom()) this.msg('Sala segura: todas as portas estão fechadas e bloqueadas.', 'good');
      } });
    });
  }

  cmdToggleNearestDoor() {
    const p = this.player;
    for (const [dx, dy] of DIRS8) {
      const d = this.level.door(p.x + dx, p.y + dy);
      if (d && !d.broken) {
        if (d.open) return this.cmdCloseDoor(p.x + dx, p.y + dy);
        return this.cmdMoveDir(dx, dy);
      }
    }
    this.msg('Não há porta ao alcance.', 'info');
  }

  cmdSearch(prop) {
    const p = this.player;
    this.command('vasculhar', () => {
      this.startAction(p, {
        type: 'search', label: `vasculhando ${PROPS[prop.id].name.toLowerCase()}`, duration: 900, interruptible: true,
        onCommit: () => {
          prop.searched = true;
          this.emitNoise(prop.x, prop.y, 1.5, { source: p });
          if (prop.items.length) this.msg(`${PROPS[prop.id].name}: ${prop.items.map(itemName).join(', ')}. [I] para pegar.`, 'good');
          else this.msg(`${PROPS[prop.id].name}: vazio.`, 'info');
          this.events.push({ type: 'searched', prop });
        },
      });
    });
  }

  // Items reachable for looting: floor under player + adjacent searched containers + corpses.
  lootSources() {
    const p = this.player;
    const level = this.level;
    const out = [];
    const floor = level.itemsAt(p.x, p.y);
    if (floor.length) out.push({ label: 'Chão', items: floor, list: floor });
    for (const [dx, dy] of [[0, 0], ...DIRS8]) {
      const prop = level.prop(p.x + dx, p.y + dy);
      if (prop && PROPS[prop.id].container && prop.searched && prop.items.length) {
        out.push({ label: PROPS[prop.id].name, items: prop.items, list: prop.items });
      }
    }
    return out;
  }

  unsearchedNearby() {
    const p = this.player;
    for (const [dx, dy] of DIRS8) {
      const prop = this.level.prop(p.x + dx, p.y + dy);
      if (prop && PROPS[prop.id].container && !prop.searched) return prop;
    }
    return null;
  }

  cmdPickupAll() {
    const p = this.player;
    const items = this.level.itemsAt(p.x, p.y);
    if (!items.length) {
      const prop = this.unsearchedNearby();
      if (prop) return this.cmdSearch(prop);
      this.msg('Nada para pegar aqui.', 'info');
      return;
    }
    this.command('pegar', () => {
      this.startAction(p, {
        type: 'pickup', label: 'pegando itens', duration: 300 + items.length * 150,
        onCommit: () => {
          const list = this.level.itemsAt(p.x, p.y);
          for (const it of list) addToInventory(p, it);
          this.msg(`Você pega: ${list.map(itemName).join(', ')}.`, 'good');
          this.level.items.delete(this.level.idx(p.x, p.y));
          this.checkWeight();
        },
      });
    });
  }

  cmdTake(sourceList, uid) {
    const p = this.player;
    this.command('pegar', () => {
      this.startAction(p, {
        type: 'pickup', label: 'pegando', duration: 350,
        onCommit: () => {
          const i = sourceList.findIndex((it) => it.uid === uid);
          if (i < 0) return;
          const [it] = sourceList.splice(i, 1);
          if (!sourceList.length) {
            for (const [k, v] of this.level.items) if (v === sourceList) this.level.items.delete(k);
          }
          addToInventory(p, it);
          this.msg(`Você pega ${itemName(it)}.`, 'good');
          this.checkWeight();
        },
      });
    });
  }

  checkWeight() {
    const p = this.player;
    const over = carriedWeight(p) - carryCapacity(p);
    if (over > 0) this.msg(`Sobrecarga: ${over.toFixed(1)} kg acima da capacidade. Você está mais lento.`, 'warn');
  }

  findInv(uid) {
    return this.player.inv.find((it) => it.uid === uid) || null;
  }

  cmdDrop(uid) {
    const p = this.player;
    this.command('largar', () => {
      this.startAction(p, {
        type: 'drop', label: 'largando', duration: 250,
        onCommit: () => {
          const i = p.inv.findIndex((it) => it.uid === uid);
          if (i < 0) return;
          const [it] = p.inv.splice(i, 1);
          this.level.addItem(p.x, p.y, it);
          this.msg(`Você larga ${itemName(it)}.`, 'info');
        },
      });
    });
  }

  equipTime(def) {
    if (def.kind === 'weapon') return 700;
    if (def.slot === 'belt' || def.slot === 'back') return 900;
    return 1200 + (def.encumbrance || 0) * 600 + (def.weight > 5 ? 1500 : 0);
  }

  cmdEquip(uid) {
    const p = this.player;
    const it = this.findInv(uid);
    if (!it) return;
    const def = ITEMS[it.id];
    if (!def.slot) return;
    this.command('equipar', () => {
      this.startAction(p, {
        type: 'equip', label: `equipando ${def.name}`, duration: this.equipTime(def) * statusMult(p), interruptible: true,
        onCommit: () => {
          const idx = p.inv.indexOf(it);
          if (idx < 0) return;
          p.inv.splice(idx, 1);
          if (def.slot === 'main' && def.hands === 2 && p.equip.off) {
            p.inv.push(p.equip.off);
            p.equip.off = null;
          }
          if (def.slot === 'off' && p.equip.main && ITEMS[p.equip.main.id].hands === 2) {
            p.inv.push(p.equip.main);
            p.equip.main = null;
          }
          if (p.equip[def.slot]) p.inv.push(p.equip[def.slot]);
          p.equip[def.slot] = it;
          this.msg(`Você equipa ${itemName(it)}.`, 'good');
          if (def.hands === 2) {
            const hp = weaponOf(p);
            if (hp.def === def && !['armL', 'armR', 'handL', 'handR'].every((k) => !p.body.parts[k].wounds.some((w) => w.type === 'fracture'))) {
              this.msg('Com o membro fraturado, uma arma de duas mãos é quase inútil.', 'warn');
            }
          }
        },
      });
    });
  }

  cmdUnequip(slot) {
    const p = this.player;
    const it = p.equip[slot];
    if (!it) return;
    const def = ITEMS[it.id];
    this.command('desequipar', () => {
      this.startAction(p, {
        type: 'equip', label: `removendo ${def.name}`, duration: this.equipTime(def) * 0.8, interruptible: true,
        onCommit: () => {
          if (p.equip[slot] !== it) return;
          p.equip[slot] = null;
          p.inv.push(it);
          this.msg(`Você remove ${itemName(it)}.`, 'info');
        },
      });
    });
  }

  // Using items: eat, drink, treat wounds, read, refuel, repair, place.
  cmdUse(uid) {
    const p = this.player;
    const it = this.findInv(uid) || Object.values(p.equip).find((e) => e && e.uid === uid);
    if (!it) return;
    const def = ITEMS[it.id];
    const rng = this.rng;
    if (p.inv.includes(it) && def.slot && ['weapon', 'armour', 'light'].includes(def.kind)) return this.cmdEquip(uid);
    if (it.id === 'torch' && p.equip.off === it) {
      this.msg('Escolha uma célula adjacente para atear fogo.', 'info');
      this.events.push({ type: 'target', mode: 'ignite' });
      return;
    }
    switch (def.kind) {
      case 'food':
        return this.command('comer', () => this.startAction(p, {
          type: 'eat', label: `comendo ${def.name}`, duration: def.time, interruptible: true,
          onCommit: () => {
            if (!consumeOne(p, it)) return;
            p.needs.hunger = Math.max(0, p.needs.hunger + def.hunger * (p.species.bloodDrinker ? 0.3 : 1));
            if (def.thirst) p.needs.thirst = Math.min(100, p.needs.thirst + def.thirst);
            this.msg(`Você come ${def.name}.`, 'good');
            if (def.poison && rng.chance(def.poison)) {
              p.effects.poison = (p.effects.poison || 0) + 10;
              this.msg('Seu estômago revira. Envenenado!', 'danger');
            }
          },
        }));
      case 'drink': {
        if (def.refill && it.charges <= 0) return this.cmdRefill(it);
        return this.command('beber', () => this.startAction(p, {
          type: 'drink', label: `bebendo ${def.name}`, duration: def.time, interruptible: true,
          onCommit: () => {
            if (def.refill) {
              if (it.charges <= 0) return;
              it.charges--;
            } else if (!consumeOne(p, it)) return;
            if (it.dirty && rng.chance(0.25)) {
              p.effects.poison = (p.effects.poison || 0) + 5;
              this.msg('A água estava contaminada.', 'danger');
            }
            if (p.species.bloodDrinker) this.msg('Não é disso que você tem sede.', 'warn');
            else p.needs.thirst = Math.max(0, p.needs.thirst + def.thirst);
            if (def.fear) p.needs.fear = Math.max(0, p.needs.fear + def.fear);
            this.msg(`Você bebe ${def.name}.`, 'good');
          },
        }));
      }
      case 'medical':
        return this.cmdTreatWith(it);
      case 'material':
        if (def.use === 'bandage') return this.cmdTreatWith(it);
        this.msg(it.id === 'plank' ? 'Tábuas: [X] barricar uma porta ou fazer uma fogueira (Construir).' : 'Material de construção.', 'info');
        return;
      case 'potion':
        return this.command('beber poção', () => this.startAction(p, {
          type: 'drink', label: `bebendo ${def.name}`, duration: def.time,
          onCommit: () => {
            if (!consumeOne(p, it)) return;
            if (def.mana) {
              p.mana = Math.min(p.maxMana, p.mana + def.mana);
              this.msg('Energia arcana formiga nos seus dedos.', 'magic');
            }
            if (def.blood) {
              p.body.blood = Math.min(100, p.body.blood + def.blood);
              for (const part of PARTS) {
                for (const w of p.body.parts[part].wounds) {
                  w.severity *= 1 - def.woundHeal;
                  w.infection *= 0.3;
                }
                p.body.parts[part].hp = Math.min(p.body.parts[part].max, p.body.parts[part].hp + p.body.parts[part].max * 0.3);
              }
              p.effects.poison = 0;
              this.msg('Calor se espalha pelas feridas.', 'good');
            }
          },
        }));
      case 'throwable':
        this.msg('Use [Q] ou o botão Arremessar e escolha o alvo.', 'info');
        this.events.push({ type: 'target', mode: 'throw', uid });
        return;
      case 'tool':
        return this.cmdRepair(it);
      case 'placeable':
        return this.cmdPlaceCandle(it);
      case 'book':
        return this.command('ler', () => this.startAction(p, {
          type: 'read', label: `lendo ${def.name}`, duration: def.time, interruptible: true,
          onCommit: () => {
            if (p.spells.includes(def.teaches)) {
              this.msg('Você já conhece este feitiço.', 'info');
              return;
            }
            p.spells.push(def.teaches);
            const sp = SPELLS[def.teaches];
            if (!p.skills[sp.school].train) p.skills[sp.school].train = true;
            if (def.teaches === 'raise_dead') p.skills.necromancy.level = Math.max(p.skills.necromancy.level, 1);
            consumeOne(p, it);
            this.msg(`Você aprende ${sp.name} [${sp.key}]. Falha: ${spellFailure(p, def.teaches)}%.`, 'magic');
            p.maxMana = 10 + Math.round(p.skills.spellcasting.level * 4 + p.skills.necromancy.level * 1.5);
          },
        }));
      case 'light':
        return this.cmdRefuel();
      case 'relic':
        this.msg(`${def.name}: vale ${def.value} moedas na superfície — se você voltar.`, 'info');
        return;
      default:
        this.msg('Você não sabe como usar isso aqui.', 'info');
    }
  }

  cmdRefill(it) {
    const p = this.player;
    let water = null;
    for (const [dx, dy] of [[0, 0], ...DIRS8]) if (this.level.tile(p.x + dx, p.y + dy) === T.WATER) water = true;
    if (!water) {
      this.msg('O odre está vazio. Encontre água parada para enchê-lo.', 'warn');
      return;
    }
    this.command('encher odre', () => this.startAction(p, {
      type: 'drink', label: 'enchendo o odre', duration: 2000,
      onCommit: () => {
        it.charges = ITEMS[it.id].maxCharges;
        this.emitNoise(p.x, p.y, 2, { source: p, label: 'água' });
        this.msg('Você enche o odre com água parada. Talvez não seja muito limpa.', 'info');
        if (this.rng.chance(0.15)) it.dirty = true;
      },
    }));
  }

  cmdRefuel() {
    const p = this.player;
    const lantern = p.equip.belt;
    if (!lantern) return;
    const flask = p.inv.find((it) => it.id === 'oil_flask');
    if (!flask) {
      this.msg(`Lamparina: ${Math.round(lantern.fuel / 60)} min de óleo. Sem frascos de óleo para reabastecer.`, 'info');
      return;
    }
    this.command('reabastecer', () => this.startAction(p, {
      type: 'work', label: 'reabastecendo a lamparina', duration: 1500,
      onCommit: () => {
        consumeOne(p, flask);
        lantern.fuel = Math.min(ITEMS[lantern.id].fuelMax, lantern.fuel + ITEMS.oil_flask.fuel);
        this.msg('A chama da lamparina cresce.', 'good');
      },
    }));
  }

  cmdToggleLantern() {
    const p = this.player;
    if (!p.equip.belt) return this.msg('Você não carrega uma lamparina.', 'info');
    p.lanternOn = !p.lanternOn;
    this.msg(p.lanternOn ? 'Você acende a lamparina.' : 'Você apaga a lamparina. A escuridão esconde você — e eles.', 'info');
  }

  cmdToggleSneak() {
    const p = this.player;
    p.sneaking = !p.sneaking;
    this.msg(p.sneaking ? 'Você avança furtivamente (mais lento, quase silencioso).' : 'Você volta a andar normalmente.', 'info');
  }

  cmdRepair(it) {
    const p = this.player;
    const w = p.equip.main;
    if (!w || !['blades', 'axes', 'polearms'].includes(ITEMS[w.id].skill) || !ITEMS[w.id].durability) {
      this.msg('Equipe uma lâmina para amolar.', 'info');
      return;
    }
    this.command('amolar', () => this.startAction(p, {
      type: 'work', label: `amolando ${ITEMS[w.id].name}`, duration: ITEMS[it.id].time, interruptible: true,
      onCommit: () => {
        const def = ITEMS[w.id];
        if (w.cond <= 0) {
          this.msg('Está quebrada demais para amolar. Precisaria de uma forja.', 'warn');
          return;
        }
        w.cond = Math.min(def.durability, w.cond + def.durability * 0.4);
        it.charges--;
        if (it.charges <= 0) p.inv.splice(p.inv.indexOf(it), 1);
        this.emitNoise(p.x, p.y, 3, { source: p, label: 'metal raspando' });
        this.msg(`${def.name} amolada.`, 'good');
      },
    }));
  }

  cmdPlaceCandle(it) {
    const p = this.player;
    if (this.level.prop(p.x, p.y)) return this.msg('Não há espaço aqui.', 'info');
    this.command('acender vela', () => this.startAction(p, {
      type: 'work', label: 'acendendo uma vela', duration: 1200,
      onCommit: () => {
        if (!consumeOne(p, it)) return;
        placeProp(this.level, 'candle', p.x, p.y);
        this.level.version++;
        this.msg('Você acende uma vela. Uma pequena ilha de luz.', 'good');
      },
    }));
  }

  // Medicine.
  cmdTreatWith(it) {
    const p = this.player;
    const def = ITEMS[it.id];
    const med = p.skills.medicine.level;
    let target = null;
    let time = 0;
    let apply = null;
    if (def.use === 'bandage') {
      target = worstWound(p.body, (w) => !w.bandaged && !w.stitched && bleedRate(w) > 0) || worstWound(p.body, (w) => !w.bandaged && w.type !== 'bruise' && w.type !== 'fracture');
      time = 2500 * (1 - Math.min(0.5, med * 0.05));
      apply = (w) => {
        w.bandaged = def.clean ? 'clean' : 'dirty';
      };
    } else if (def.use === 'disinfect') {
      target = worstWound(p.body, (w) => w.dirty || w.infection > 0);
      time = def.time;
      apply = (w) => {
        w.dirty = false;
        if (w.infection < 0.4) w.infection = 0;
        else w.infection *= 0.6;
        p.needs.fear = Math.min(100, p.needs.fear + 3);
      };
    } else if (def.use === 'stitch') {
      target = worstWound(p.body, (w) => !w.stitched && ['laceration', 'deep_laceration', 'puncture', 'bite'].includes(w.type));
      time = def.time * (1 - Math.min(0.5, med * 0.06));
      apply = (w) => {
        if (this.rng.chance(0.35 + med * 0.12)) {
          w.stitched = true;
          this.msg('Você costura o ferimento.', 'good');
        } else {
          w.severity = Math.min(1, w.severity + 0.05);
          this.msg('Suas mãos tremem; os pontos não seguram. Tente de novo.', 'warn');
        }
      };
    } else if (def.use === 'splint') {
      target = worstWound(p.body, (w) => w.type === 'fracture' && !w.splinted);
      time = def.time;
      apply = (w) => {
        w.splinted = true;
      };
    }
    if (!target) {
      this.msg('Não há ferimento que precise disso agora.', 'info');
      return;
    }
    this.command('tratar', () => this.startAction(p, {
      type: 'treat', label: `${def.name}: ${target.part}`, duration: time, interruptible: true,
      onCommit: () => {
        if (!p.body.parts[target.part].wounds.includes(target.wound)) return;
        if (def.maxCharges) {
          it.charges--;
          if (it.charges <= 0) p.inv.splice(p.inv.indexOf(it), 1);
        } else if (!consumeOne(p, it)) return;
        apply(target.wound);
        this.train('medicine', 1);
        if (def.use !== 'stitch') this.msg(`Você trata: ${partName(target.part)} (${def.name}).`, 'good');
      },
    }));
  }

  // [B]: pick the most urgent treatment available.
  cmdTreat() {
    const p = this.player;
    const find = (id) => p.inv.find((it) => it.id === id);
    const bleeding = worstWound(p.body, (w) => !w.stitched && !w.bandaged && bleedRate(w) > 0);
    const deep = worstWound(p.body, (w) => !w.stitched && bleedRate(w) > 0.25);
    const fracture = worstWound(p.body, (w) => w.type === 'fracture' && !w.splinted);
    const dirty = worstWound(p.body, (w) => (w.dirty && w.type !== 'scratch') || w.infection > 0);
    if (deep && find('suture')) return this.cmdTreatWith(find('suture'));
    if (bleeding && (find('bandage') || find('rag'))) return this.cmdTreatWith(find('bandage') || find('rag'));
    if (fracture && find('splint')) return this.cmdTreatWith(find('splint'));
    if (dirty && find('alcohol')) return this.cmdTreatWith(find('alcohol'));
    if (bleeding) return this.msg('Você sangra e não tem bandagens. Trapos servem ([C]onstruir: 2 trapos = bandagem).', 'warn');
    if (fracture) return this.msg('Fratura sem tala. Faça uma: tábua + trapo.', 'warn');
    this.msg('Nada urgente para tratar.', 'info');
  }

  cmdBarricade() {
    const p = this.player;
    let target = null;
    for (const [dx, dy] of DIRS8) {
      const d = this.level.door(p.x + dx, p.y + dy);
      if (d && !d.broken) target = { d, x: p.x + dx, y: p.y + dy };
    }
    if (!target) return this.msg('Fique ao lado de uma porta para barricá-la.', 'info');
    if (!countItem(p, 'plank')) return this.msg('Você precisa de tábuas. Quebre móveis ou procure nos depósitos.', 'warn');
    if (target.d.barricade >= 3) return this.msg('A porta já está totalmente barricada.', 'info');
    if (target.d.open) {
      if (this.actorAt(target.x, target.y)) return this.msg('Há algo na porta.', 'warn');
      this.setDoor(target.x, target.y, false, p);
    }
    this.command('barricar', () => this.startAction(p, {
      type: 'work', label: 'pregando tábuas', duration: 3000 * statusMult(p), interruptible: true,
      onCommit: () => {
        if (!consumeItem(p, 'plank', 1)) return;
        target.d.barricade++;
        target.d.hp = 30 + target.d.barricade * 25;
        this.emitNoise(p.x, p.y, 10, { source: p, label: 'marteladas' });
        this.msg(`Porta barricada (${target.d.barricade}/3). O martelar ecoa pelo corredor.`, 'good');
        if (this.isSafeRoom()) this.msg('Sala segura: todas as portas estão fechadas e bloqueadas.', 'good');
      },
    }));
  }

  cmdCraft(recipeId) {
    const p = this.player;
    const r = RECIPES.find((x) => x.id === recipeId);
    if (!r) return;
    for (const [id, n] of Object.entries(r.needs)) {
      if (countItem(p, id) < n) return this.msg(`Faltam materiais para ${r.name}.`, 'warn');
    }
    let spot = null;
    if (r.place) {
      for (const [dx, dy] of DIRS8) {
        const x = p.x + dx;
        const y = p.y + dy;
        if (this.level.tile(x, y) === T.FLOOR && !this.level.prop(x, y) && !this.actorAt(x, y)) {
          spot = [x, y];
          break;
        }
      }
      if (!spot) return this.msg('Não há espaço livre ao lado para a fogueira.', 'warn');
    }
    this.command('construir', () => this.startAction(p, {
      type: 'craft', label: `fazendo ${r.name.toLowerCase()}`, duration: r.time * statusMult(p), interruptible: true,
      onCommit: () => {
        for (const [id, n] of Object.entries(r.needs)) if (countItem(p, id) < n) return;
        for (const [id, n] of Object.entries(r.needs)) consumeItem(p, id, n);
        if (r.place) {
          placeProp(this.level, r.place, spot[0], spot[1]);
          this.level.version++;
          if (r.noise) this.emitNoise(p.x, p.y, r.noise, { source: p });
          this.msg('A fogueira pega. Luz, calor — e fumaça.', 'good');
        } else {
          addToInventory(p, createItem(r.makes, r.qty));
          this.msg(`Você fez: ${r.name}.`, 'good');
        }
        this.train('survival', 1);
      },
    }));
  }

  cmdRest() {
    const p = this.player;
    if (this.danger || (this.visibleHostiles || []).some((m) => m.ai.state !== 'sleep')) {
      return this.msg('Não dá para descansar com inimigos por perto.', 'warn');
    }
    const sleep = p.needs.fatigue > 20;
    this.command('descansar', () => {
      this.startAction(p, {
        type: 'rest', label: sleep ? 'dormindo' : 'esperando', sleep, interruptible: true,
        duration: sleep ? 10 * 60000 : 30000,
        onFinish: () => this.msg(sleep ? 'Você acorda.' : 'Você espera.', 'info'),
      });
      this.msg(sleep ? (this.isSafeRoom() ? 'Você dorme na sala segura.' : 'Você dorme aqui, exposto...') : 'Você espera, escutando.', 'info');
    });
  }

  cmdStairs() {
    const p = this.player;
    const t = this.level.tile(p.x, p.y);
    if (t !== T.STAIRS_DOWN && t !== T.STAIRS_UP) return this.msg('Não há escadas aqui.', 'info');
    if (t === T.STAIRS_UP && this.depth === 1) return this.msg('A saída para a superfície. Ainda não — não sem algo para mostrar.', 'info');
    if (t === T.STAIRS_DOWN && this.level.gateSealed) return this.msg('O Portão do Profundo está selado. Algo neste andar o guarda.', 'warn');
    this.command('escadas', () => this.startAction(p, {
      type: 'stairs', label: t === T.STAIRS_DOWN ? 'descendo' : 'subindo', duration: 800,
      onCommit: () => {
        if (t === T.STAIRS_DOWN && this.depth === BRANCH.floors) {
          this.victory = {
            name: p.name, survived: this.survivedText(), kills: p.kills,
            relics: [...p.inv, ...Object.values(p.equip)].filter((it) => it && ITEMS[it.id].kind === 'relic').map((it) => ITEMS[it.id].name),
          };
          this.msg('Você atravessa o Portão do Profundo. Lá embaixo, a Cidade Perdida espera.', 'good');
          return;
        }
        this.enterLevel(t === T.STAIRS_DOWN ? this.depth + 1 : this.depth - 1, t === T.STAIRS_DOWN ? 'down' : 'up');
      },
    }));
  }

  cmdCast(spellId, tx, ty) {
    const p = this.player;
    const sp = SPELLS[spellId];
    if (!p.spells.includes(spellId)) return this.msg('Você não conhece esse feitiço.', 'info');
    if (p.mana < sp.mana) return this.msg(`Mana insuficiente (${sp.mana}).`, 'warn');
    if (Math.hypot(tx - p.x, ty - p.y) > sp.range + 0.5) return this.msg('Fora de alcance.', 'info');
    if (!lineOfSight(this.level, p.x, p.y, tx, ty)) return this.msg('Sem linha de visão.', 'info');
    this.command(sp.name, () => this.startAction(p, {
      type: 'cast', label: `conjurando ${sp.name}`, duration: sp.cast * statusMult(p), interruptible: true,
      target: { x: tx, y: ty },
      onCommit: () => {
        if (p.mana < sp.mana) return;
        p.mana -= sp.mana;
        p.facing = Math.atan2(ty - p.y, tx - p.x);
        castSpell(this, p, spellId, tx, ty);
      },
    }));
    this.events.push({ type: 'casting', spell: spellId });
  }

  cmdShoot(tx, ty) {
    const p = this.player;
    const { it, def } = weaponOf(p);
    if (!def.ranged) return this.msg('Você não empunha uma arma de fogo.', 'info');
    if (it.mag <= 0) return this.cmdReload();
    if (Math.hypot(tx - p.x, ty - p.y) > def.range) return this.msg('Fora de alcance.', 'info');
    this.command('atirar', () => this.startAction(p, {
      type: 'shoot', label: `mirando ${def.name}`, duration: def.aim * statusMult(p), target: { x: tx, y: ty },
      onCommit: () => {
        p.facing = Math.atan2(ty - p.y, tx - p.x);
        p.lastAttackAt = this.now;
        shoot(this, p, tx, ty);
      },
    }));
  }

  cmdReload() {
    const p = this.player;
    const { it, def } = weaponOf(p);
    if (!def.ranged) return;
    const ammo = countItem(p, def.ammo);
    if (!ammo) return this.msg('Sem munição.', 'danger');
    if (it.mag >= def.magazine) return this.msg('O pente está cheio.', 'info');
    this.command('recarregar', () => this.startAction(p, {
      type: 'reload', label: 'recarregando', duration: def.reload * (1 - Math.min(0.4, p.skills.firearms.level * 0.04)), interruptible: true,
      onCommit: () => {
        const n = Math.min(def.magazine - it.mag, countItem(p, def.ammo));
        consumeItem(p, def.ammo, n);
        it.mag += n;
        this.emitNoise(p.x, p.y, 2, { source: p, label: 'metal' });
        this.msg(`Recarregado: ${it.mag}/${def.magazine}. Restam ${countItem(p, def.ammo)} balas.`, 'info');
      },
    }));
  }

  cmdThrow(uid, tx, ty) {
    const p = this.player;
    const it = this.findInv(uid);
    if (!it) return;
    const def = ITEMS[it.id];
    if (Math.hypot(tx - p.x, ty - p.y) > def.range + 0.5) return this.msg('Longe demais.', 'info');
    this.command('arremessar', () => this.startAction(p, {
      type: 'throw', label: `arremessando ${def.name}`, duration: def.time * statusMult(p),
      onCommit: () => {
        if (!consumeOne(p, it)) return;
        p.facing = Math.atan2(ty - p.y, tx - p.x);
        throwItem(this, p, it, tx, ty);
      },
    }));
  }

  cmdIgnite(tx, ty) {
    const p = this.player;
    const torch = p.equip.off?.id === 'torch' && p.equip.off.fuel > 0;
    const fire = torch || this.nearWarmth(p);
    if (!fire) return this.msg('Você precisa de uma tocha acesa na mão secundária.', 'info');
    if (cheb(p, { x: tx, y: ty }) > 1) return this.msg('Chegue mais perto.', 'info');
    this.command('incendiar', () => this.startAction(p, {
      type: 'work', label: 'ateando fogo', duration: 900,
      onCommit: () => {
        if (igniteCell(this, tx, ty)) this.msg('As chamas pegam.', 'magic');
        else this.msg('Nada ali para queimar.', 'info');
      },
    }));
  }

  cmdFeed() {
    const p = this.player;
    if (!p.species.bloodDrinker) return this.msg('Você não é um vampiro.', 'info');
    for (const [dx, dy] of [[0, 0], ...DIRS8]) {
      const c = this.corpseAt(p.x + dx, p.y + dy, (k) => k.bleeds && !k.drained && !k.charred && this.now - k.time < 180000);
      if (!c) continue;
      return this.command('alimentar-se', () => this.startAction(p, {
        type: 'eat', label: 'alimentando-se', duration: 2500, interruptible: true,
        onCommit: () => {
          c.drained = true;
          p.needs.thirst = Math.max(0, p.needs.thirst - 45);
          p.body.blood = Math.min(100, p.body.blood + 20);
          this.emitNoise(p.x, p.y, 2, { source: p });
          this.msg(`Você bebe de ${c.name}. A sede recua.`, 'magic');
        },
      }));
    }
    this.msg('Nenhum cadáver fresco com sangue por perto.', 'info');
  }

  setSkillTraining(id, on) {
    this.player.skills[id].train = on;
  }
}

function consumeOne(p, it) {
  const def = ITEMS[it.id];
  const i = p.inv.indexOf(it);
  if (i < 0) return false;
  if (def.stack && it.qty > 1) it.qty--;
  else p.inv.splice(i, 1);
  return true;
}

function partName(part) {
  return {
    head: 'cabeça', torso: 'torso', armL: 'braço esquerdo', armR: 'braço direito', handL: 'mão esquerda',
    handR: 'mão direita', legL: 'perna esquerda', legR: 'perna direita', footL: 'pé esquerdo', footR: 'pé direito',
  }[part];
}

// Compass relative to the isometric screen: "norte" is up on the monitor.
export function direction(px, py, x, y) {
  const dx = x - px;
  const dy = y - py;
  const sx = dx - dy;
  const sy = dx + dy;
  if (Math.hypot(sx, sy) < 0.5) return 'aqui perto';
  const ang = Math.atan2(-sy, sx);
  const names = ['a leste', 'a nordeste', 'ao norte', 'a noroeste', 'a oeste', 'a sudoeste', 'ao sul', 'a sudeste'];
  const k = (Math.round(ang / (Math.PI / 4)) + 8) % 8;
  return names[k];
}

export { itemName, spellFailure, pain, SPELLS };
