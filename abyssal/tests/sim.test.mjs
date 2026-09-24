// Headless simulation tests: node --test abyssal/tests
import test from 'node:test';
import assert from 'node:assert/strict';
import { generateLevel } from '../src/sim/dungeon.js';
import { Level, T, S, findPath } from '../src/sim/level.js';
import { propagateNoise, igniteCell, freezeCell } from '../src/sim/systems.js';
import { createBody, woundPart, totalBleed, bleedRate, tickBody } from '../src/sim/body.js';
import { handPenalty } from '../src/sim/combat.js';
import { createMonster, createItem } from '../src/sim/entity.js';
import { World, TICK } from '../src/sim/world.js';
import { Rng } from '../src/sim/rng.js';
import { ITEMS } from '../src/content/items.js';
import { MONSTERS } from '../src/content/monsters.js';
import { BRANCH } from '../src/content/world.js';

function newWorld(extra = {}) {
  return new World({ seed: 1234, name: 'Teste', species: 'human', background: 'relic_hunter', ...extra });
}

function run(world, ms) {
  for (let t = 0; t < ms; t += TICK) world.tick(TICK);
}

// Clear a 5x5 patch in the middle of the biggest room and put the player there.
function arena(world) {
  const level = world.level;
  level.actors = [];
  const room = [...level.rooms].filter((r) => !r.vault).sort((a, b) => b.w * b.h - a.w * a.h)[0];
  const x = room.x + Math.floor(room.w / 2);
  const y = room.y + Math.floor(room.h / 2);
  for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) {
      const i = level.idx(x + dx, y + dy);
      level.tiles[i] = T.FLOOR;
      level.props.delete(i);
      level.items.delete(i);
      level.surface[i] = S.NONE;
    }
  }
  const p = world.player;
  p.x = p.px = x;
  p.y = p.py = y;
  return { x, y };
}

test('floors are deterministic, connected and complete', () => {
  for (const seed of [1, 7, 42, 999, 31337]) {
    for (let depth = 1; depth <= BRANCH.floors; depth++) {
      const opts = { needsNecroBook: depth === BRANCH.necroBookFloor };
      const a = generateLevel(depth, seed * 100 + depth, opts);
      const b = generateLevel(depth, seed * 100 + depth, opts);
      assert.deepEqual(Array.from(a.tiles), Array.from(b.tiles), 'same seed, same map');
      assert.ok(a.up, 'has up stairs');
      assert.ok(a.down, 'has a way down');
      const path = findPath(a, a.up.x, a.up.y, a.down.x, a.down.y, { canOpenDoors: true, bashes: true, maxNodes: 20000 });
      assert.ok(path && path.length > 5, `stairs connected (seed ${seed}, depth ${depth})`);
      if (depth === BRANCH.floors) {
        assert.ok(a.gateSealed, 'boss floor gate starts sealed');
        assert.ok(a.actors.some((m) => m.defId === 'castellan'), 'boss present');
      }
      if (depth === BRANCH.necroBookFloor) {
        const hasBook = [...a.items.values()].flat().some((it) => it.id === 'book_necro');
        assert.ok(hasBook, 'necromancy book placed on its floor');
      }
    }
  }
});

test('content is data-driven and consistent', () => {
  for (const [id, m] of Object.entries(MONSTERS)) {
    assert.ok(m.attacks?.length, `${id} has attacks`);
    assert.ok(m.senses && m.senses.vision > 0, `${id} has senses`);
  }
  for (const [id, it] of Object.entries(ITEMS)) {
    assert.ok(it.name && it.kind, `${id} named and typed`);
    if (it.kind === 'weapon' && !it.hidden) assert.ok(it.swing > 0 && it.dmg, `${id} has timing and damage`);
  }
});

test('noise flows through open doors and is muffled by closed ones and walls', () => {
  const lv = new Level(1, 20, 5);
  for (let x = 1; x < 19; x++) lv.tiles[lv.idx(x, 2)] = T.FLOOR;
  for (let x = 0; x < 20; x++) {
    lv.tiles[lv.idx(x, 1)] = T.WALL;
    lv.tiles[lv.idx(x, 3)] = T.WALL;
  }
  lv.tiles[lv.idx(10, 2)] = T.DOOR;
  lv.doors.set(lv.idx(10, 2), { open: true, barricade: 0, hp: 30, broken: false });
  const open = propagateNoise(lv, 2, 2, 18).get(lv.idx(15, 2)) || 0;
  lv.doors.get(lv.idx(10, 2)).open = false;
  const closed = propagateNoise(lv, 2, 2, 18).get(lv.idx(15, 2)) || 0;
  assert.ok(open > closed, 'closed door muffles');
  assert.ok(closed > 0, 'but sound still passes');
  const behindWall = propagateNoise(lv, 2, 2, 4).get(lv.idx(2, 0)) || 0;
  assert.equal(behindWall, 0, 'quiet sounds do not pass walls');
});

test('wounds bleed, bandages slow bleeding, fractures cripple two-handed weapons', () => {
  const rng = new Rng(5);
  const body = createBody();
  woundPart(body, 'handR', { slash: 14 }, { source: 'teste' }, rng);
  const w = body.parts.handR.wounds[0];
  assert.equal(w.type, 'deep_laceration');
  const before = totalBleed(body);
  assert.ok(before > 0.2, 'deep laceration bleeds');
  w.bandaged = 'clean';
  assert.ok(bleedRate(w) < before * 0.2, 'bandage slows bleeding');
  tickBody(body, 10000, { rng });
  assert.ok(body.blood < 100 && body.blood > 90);
  woundPart(body, 'armL', { blunt: 30 }, { source: 'troll', fracture: 1 }, rng);
  assert.ok(body.parts.armL.wounds.some((x) => x.type === 'fracture'), 'heavy blunt hit fractures');
  const pen = handPenalty({ body }, ITEMS.long_sword);
  assert.ok(pen.bad && pen.time > 1.5, 'two-handed sword is nearly useless');
  const dagger = handPenalty({ body }, ITEMS.dagger);
  assert.ok(dagger.time < pen.time, 'a dagger is the better choice');
});

test('continuous time: every action takes simulated time on one clock', () => {
  const w = newWorld();
  arena(w);
  const p = w.player;
  const x0 = p.x;
  w.stepPlayer(1, 0, false);
  assert.equal(p.x, x0 + 1, 'cell is claimed immediately');
  assert.equal(p.action.type, 'move');
  const dur = p.action.t1 - p.action.t0;
  assert.ok(dur >= 250 && dur <= 400, `walking takes ~300ms (${dur})`);
  run(w, dur + TICK);
  assert.equal(p.action, null);
  w.paused = true;
  const now = w.now;
  w.update(1000);
  assert.equal(w.now, now, 'pause freezes the clock');
  w.paused = false;
});

test('fire spreads across oil, frost puts it out, lightning conducts through water', () => {
  const w = newWorld();
  const c = arena(w);
  const lv = w.level;
  for (let x = c.x - 2; x <= c.x + 2; x++) lv.setSurface(x, c.y + 2, S.OIL, 25000);
  igniteCell(w, c.x - 2, c.y + 2);
  run(w, 3000);
  const burning = [...lv.burning].filter((i) => ((i / lv.w) | 0) === c.y + 2).length;
  assert.ok(burning >= 3, `oil fire spreads (${burning})`);
  for (let x = c.x - 2; x <= c.x + 2; x++) freezeCell(w, x, c.y + 2);
  assert.equal([...lv.burning].filter((i) => ((i / lv.w) | 0) === c.y + 2).length, 0, 'frost extinguishes');

  const w2 = newWorld({ background: 'mage' });
  const c2 = arena(w2);
  const lv2 = w2.level;
  for (let x = c2.x - 2; x <= c2.x + 2; x++) lv2.tiles[lv2.idx(x, c2.y - 2)] = T.WATER;
  const a = createMonster('goblin', c2.x - 2, c2.y - 2, w2.rng, { awake: true });
  const b = createMonster('goblin', c2.x + 2, c2.y - 2, w2.rng, { awake: true });
  lv2.actors.push(a, b);
  w2.player.spells.push('lightning');
  w2.player.skills.air.level = 10;
  w2.player.skills.spellcasting.level = 10;
  w2.player.mana = 50;
  w2.cmdCast('lightning', a.x, a.y);
  run(w2, 1500);
  assert.ok(b.hp < b.maxHp || !b.alive, 'the other goblin in the puddle is shocked');
});

test('barricaded rooms become safe rooms; furniture can be pushed', () => {
  const w = newWorld();
  const lv = w.level;
  const p = w.player;
  const room = lv.rooms.find((r) => !r.vault && r.doorCells.length && r.doorCells.every(([x, y]) => lv.tile(x, y) === T.DOOR));
  assert.ok(room, 'a room with only doors exists');
  lv.actors = lv.actors.filter((m) => lv.roomId[lv.idx(m.x, m.y)] !== room.id);
  const cells = [];
  for (let y = room.y + 1; y < room.y + room.h - 1; y++) {
    for (let x = room.x + 1; x < room.x + room.w - 1; x++) if (lv.tile(x, y) === T.FLOOR && !lv.prop(x, y)) cells.push([x, y]);
  }
  p.x = p.px = cells[0][0];
  p.y = p.py = cells[0][1];
  for (const [x, y] of room.doorCells) {
    const d = lv.door(x, y);
    d.open = false;
    d.barricade = 1;
  }
  assert.equal(w.isSafeRoom(), true);
  lv.door(...room.doorCells[0]).barricade = 0;
  assert.equal(w.isSafeRoom(), false, 'an unblocked door breaks safety');

  const w2 = newWorld();
  const c = arena(w2);
  const crate = { id: 'crate', x: c.x + 1, y: c.y, hp: 12, items: [], searched: true };
  w2.level.props.set(w2.level.idx(c.x + 1, c.y), crate);
  w2.stepPlayer(1, 0, false);
  assert.equal(w2.player.action.type, 'push');
  run(w2, 1500);
  assert.equal(crate.x, c.x + 2, 'crate dragged one cell');
  assert.equal(w2.player.x, c.x + 1, 'player follows');
});

test('monsters hear gunshots and come to investigate', () => {
  const w = newWorld({ background: 'survivor' });
  const c = arena(w);
  const far = createMonster('goblin', c.x, c.y, w.rng, { awake: true });
  // Somewhere the shot carries to, out of sight.
  const field = propagateNoise(w.level, c.x, c.y, 30);
  let spot = null;
  for (const [i, rem] of field) {
    const x = i % w.level.w;
    const y = (i / w.level.w) | 0;
    if (rem > 3 && rem < 12 && w.level.isPassable(x, y) && !w.isVisible(x, y) && Math.hypot(x - c.x, y - c.y) > 8) {
      spot = [x, y];
      break;
    }
  }
  assert.ok(spot, 'found a spot in earshot');
  far.x = far.px = spot[0];
  far.y = far.py = spot[1];
  w.level.actors.push(far);
  w.cmdShoot(c.x + 2, c.y);
  run(w, 800);
  assert.ok(['investigate', 'hunt'].includes(far.ai.state), `goblin reacts to the shot (${far.ai.state})`);
});

test('corpses are a resource: raise dead creates a temporary servant', () => {
  const w = newWorld({ background: 'mage' });
  const c = arena(w);
  const g = createMonster('goblin', c.x + 2, c.y, w.rng, { awake: true });
  w.level.actors.push(g);
  w.kill(g, w.player);
  assert.ok(w.corpseAt(c.x + 2, c.y), 'corpse left behind');
  w.player.spells.push('raise_dead');
  w.player.skills.necromancy.level = 12;
  w.player.skills.spellcasting.level = 12;
  w.player.mana = 40;
  w.cmdCast('raise_dead', c.x + 2, c.y);
  run(w, 3000);
  const servant = w.level.actors.find((m) => m.alive && m.team === 'player');
  assert.ok(servant, 'a servant rises');
  assert.ok(servant.expires > w.now, 'servant is temporary');
});

test('permadeath produces an epitaph and the dead return as the Hollowed', () => {
  let record = null;
  const w = newWorld({ onDeath: (r) => (record = r) });
  w.player.body.blood = 1;
  woundPart(w.player.body, 'handR', { bite: 12 }, { source: 'mordida de Carniçal' }, w.rng);
  w.player.lastBleedSource = 'mordida de Carniçal';
  run(w, 60000);
  assert.ok(record, 'death recorded');
  assert.match(record.cause, /exsanguinação após mordida de Carniçal/);
  assert.equal(record.depth, 1);

  const hall = [{ ...record, depth: 2, name: 'Edmund Black', gear: ['long_sword', 'mail'], laidToRest: false }];
  const w2 = new World({ seed: 99, name: 'Nova', species: 'human', background: 'fighter', hallOfDead: hall });
  w2.enterLevel(2, 'down');
  const hollow = w2.level.actors.find((m) => m.hollowed);
  assert.ok(hollow, 'the previous character waits below');
  assert.match(hollow.name, /Edmund, o Esvaziado/);
  assert.ok(hollow.loot.some((it) => it.id === 'long_sword'), 'wearing the old gear');
});

test('needs rise over time and food answers hunger', () => {
  const w = newWorld();
  arena(w);
  const p = w.player;
  const h0 = p.needs.hunger;
  run(w, 600000);
  assert.ok(p.needs.hunger > h0 + 20, 'hunger rises with game time');
  const ration = p.inv.find((it) => it.id === 'ration');
  const hungry = p.needs.hunger;
  w.cmdUse(ration.uid);
  run(w, 2500);
  assert.ok(p.needs.hunger < hungry - 20, 'eating helps');
  assert.ok(createItem('waterskin').charges > 0);
});
