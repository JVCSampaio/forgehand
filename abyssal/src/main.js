// Boot, input and the frame loop. Input becomes World commands; the World
// advances on its own clock; the View and UI only read.
import { World } from './sim/world.js';
import { View } from './view/renderer.js';
import { UI } from './view/ui.js';
import { SPELLS } from './content/characters.js';
import { ITEMS } from './content/items.js';
import { weaponOf } from './sim/combat.js';
import { lineOfSight } from './sim/level.js';

const HALL_KEY = 'abyssal.hall.v1';
const params = new URLSearchParams(location.search);

function loadHall() {
  try {
    return JSON.parse(localStorage.getItem(HALL_KEY) || '[]');
  } catch {
    return [];
  }
}
function saveHall(hall) {
  try {
    localStorage.setItem(HALL_KEY, JSON.stringify(hall.slice(0, 30)));
  } catch {
    /* storage unavailable: the Hall of the Dead lives only for this session */
  }
}

const canvas = document.getElementById('game');
const view = new View(canvas);
const ui = new UI(view);
let world = null;
let hall = loadHall();
let targeting = null;
let endShown = false;
const held = new Set();

// Screen-relative WASD on an isometric grid.
const DIRS = {
  w: [-1, -1], arrowup: [-1, -1], s: [1, 1], arrowdown: [1, 1],
  a: [-1, 1], arrowleft: [-1, 1], d: [1, -1], arrowright: [1, -1],
};

function heldDir() {
  let dx = 0;
  let dy = 0;
  for (const k of held) {
    const d = DIRS[k];
    if (d) {
      dx += d[0];
      dy += d[1];
    }
  }
  dx = Math.sign(dx);
  dy = Math.sign(dy);
  return dx || dy ? [dx, dy] : null;
}

function start(opts) {
  hall = loadHall();
  const seed = params.get('seed') ? Number(params.get('seed')) >>> 0 : (Math.random() * 1e9) >>> 0;
  world = new World({
    seed, ...opts, hallOfDead: hall,
    onDeath: (rec) => {
      hall.unshift(rec);
      saveHall(hall);
      setTimeout(() => ui.showDeath(rec, showStart), 2200);
    },
    onLaidToRest: () => saveHall(hall),
  });
  endShown = false;
  targeting = null;
  view.targeting = null;
  ui.setWorld(world);
  view.buildLevel(world);
  window.game = { world, view, ui };
}

function showStart() {
  world = null;
  ui.showStart(loadHall(), start);
}

// ------------------------------------------------------------ targeting
function nearestHostile(range, pred = () => true) {
  const p = world.player;
  let best = null;
  for (const m of world.level.actors) {
    if (!m.alive || m.team !== 'hostile' || !world.isVisible(m.x, m.y) || !pred(m)) continue;
    const d = Math.hypot(m.x - p.x, m.y - p.y);
    if (d > range + 0.5 || !lineOfSight(world.level, p.x, p.y, m.x, m.y)) continue;
    if (!best || d < best.d) best = { m, d };
  }
  return best ? { x: best.m.x, y: best.m.y } : null;
}

function nearestCorpse(range) {
  const p = world.player;
  let best = null;
  for (const [i, list] of world.level.corpses) {
    if (!list.some((c) => c.monsterId && !c.charred && !c.raised)) continue;
    const x = i % world.level.w;
    const y = (i / world.level.w) | 0;
    if (!world.isVisible(x, y)) continue;
    const d = Math.hypot(x - p.x, y - p.y);
    if (d <= range && (!best || d < best.d)) best = { x, y, d };
  }
  return best;
}

function beginTargeting(mode, data) {
  if (!world?.player.alive) return;
  const p = world.player;
  let spec;
  if (mode === 'spell') {
    const sp = SPELLS[data];
    if (p.mana < sp.mana) return world.msg(`Mana insuficiente para ${sp.name} (${sp.mana}).`, 'warn');
    if (targeting?.mode === 'spell' && targeting.spellId === data) return confirmTarget(view.hover);
    const colors = { fireball: 0xff7a1a, frost: 0x9fe6ff, lightning: 0xcfeaff, raise_dead: 0x7aff5a };
    spec = { mode, spellId: data, range: sp.range, radius: sp.radius || 0, color: colors[data], corpse: sp.target === 'corpse', name: sp.name };
  } else if (mode === 'shoot') {
    const { def } = weaponOf(p);
    if (!def.ranged) return world.msg('Você não empunha uma arma de fogo.', 'info');
    if (targeting?.mode === 'shoot') return confirmTarget(view.hover);
    spec = { mode, range: def.range, color: 0xffd08a, name: def.name };
  } else if (mode === 'throw') {
    const it = data ? p.inv.find((i) => i.uid === data) : p.inv.find((i) => ITEMS[i.id].kind === 'throwable');
    if (!it) return world.msg('Nada para arremessar.', 'info');
    if (targeting?.mode === 'throw') return confirmTarget(view.hover);
    spec = { mode, uid: it.uid, range: ITEMS[it.id].range, radius: 1, arc: true, color: 0xff9a3c, name: ITEMS[it.id].name };
  } else if (mode === 'ignite') {
    spec = { mode, range: 1.5, color: 0xff7a1a, name: 'atear fogo' };
  }
  targeting = spec;
  const auto = spec.corpse ? nearestCorpse(spec.range) : spec.mode === 'ignite' ? null : nearestHostile(spec.range);
  if (auto) view.hover = { x: auto.x, y: auto.y };
  refreshTargeting();
  world.msg(`Mirando: ${spec.name}. Clique no alvo · [Enter] ou a mesma tecla confirma · [Esc] cancela.`, 'magic');
}

function validTarget(cell) {
  if (!targeting || !cell) return false;
  const p = world.player;
  const level = world.level;
  if (!level.inBounds(cell.x, cell.y) || !level.explored[level.idx(cell.x, cell.y)]) return false;
  if (Math.hypot(cell.x - p.x, cell.y - p.y) > targeting.range + 0.5) return false;
  if (targeting.mode !== 'throw' && !lineOfSight(level, p.x, p.y, cell.x, cell.y)) return false;
  if (targeting.corpse) return !!world.corpseAt(cell.x, cell.y, (c) => c.monsterId && !c.charred);
  return true;
}

function refreshTargeting() {
  view.targeting = targeting ? { valid: validTarget(view.hover), color: targeting.color, radius: targeting.radius, arc: targeting.arc } : null;
}

function cancelTargeting() {
  targeting = null;
  view.targeting = null;
}

function confirmTarget(cell) {
  if (!targeting || !cell) return;
  if (!validTarget(cell)) {
    world.msg('Alvo inválido: fora de alcance ou sem linha de visão.', 'warn');
    return;
  }
  const t = targeting;
  cancelTargeting();
  if (t.mode === 'spell') world.cmdCast(t.spellId, cell.x, cell.y);
  else if (t.mode === 'shoot') world.cmdShoot(cell.x, cell.y);
  else if (t.mode === 'throw') world.cmdThrow(t.uid, cell.x, cell.y);
  else if (t.mode === 'ignite') world.cmdIgnite(cell.x, cell.y);
}

ui.onTarget = (e) => beginTargeting(e.mode, e.uid);

// ---------------------------------------------------------- commands
function run(cmd) {
  if (!world) return;
  const p = world.player;
  if (cmd.startsWith('spell:')) return beginTargeting('spell', cmd.slice(6));
  switch (cmd) {
    case 'shoot': return beginTargeting('shoot');
    case 'reload': return world.cmdReload();
    case 'throw': return beginTargeting('throw');
    case 'treat': return world.cmdTreat();
    case 'barricade': return world.cmdBarricade();
    case 'rest': return world.cmdRest();
    case 'lantern': return world.cmdToggleLantern();
    case 'sneak': return world.cmdToggleSneak();
    case 'feed': return world.cmdFeed();
    case 'stairs': return world.cmdStairs();
    case 'pickup': return world.cmdInteract(p.x, p.y);
    case 'door': return world.cmdToggleNearestDoor();
    case 'inventory': return toggleModal('inventory');
    case 'character': return toggleModal('character');
    case 'help': return toggleModal('help');
    default:
  }
}

function toggleModal(kind) {
  if (ui.modal === kind) ui.closeModal();
  else ui.openModal(kind);
}

const KEYMAP = {
  f: 'shoot', r: 'reload', q: 'throw', b: 'treat', x: 'barricade', z: 'rest', l: 'lantern', v: 'sneak',
  e: 'feed', g: 'pickup', o: 'door', i: 'inventory', c: 'character', h: 'help', '?': 'help', k: 'inventory',
};

window.addEventListener('keydown', (e) => {
  if (!world || e.target.tagName === 'INPUT') return;
  const k = e.key.toLowerCase();
  if (k === ' ') {
    e.preventDefault();
    if (!world.gameOver) world.paused = !world.paused;
    return;
  }
  if (k === 'escape') {
    if (targeting) cancelTargeting();
    else ui.closeModal();
    return;
  }
  if (k === 'enter') {
    e.preventDefault();
    if (targeting) confirmTarget(view.hover);
    else world.cmdStairs();
    return;
  }
  if (k === 't') {
    world.autoSlow = !world.autoSlow;
    world.msg(`Câmera lenta tática ${world.autoSlow ? 'ligada' : 'desligada'}.`, 'info');
    return;
  }
  if (DIRS[k]) {
    e.preventDefault();
    if (ui.modal === 'inventory') return;
    if (!held.has(k)) {
      world.player.path = null;
      world.player.attackTarget = null;
      if (world.paused) world.cmdMoveDir(...DIRS[k]);
    }
    held.add(k);
    return;
  }
  if (/^[1-4]$/.test(k)) {
    const id = world.player.spells.find((s) => SPELLS[s].key === k);
    if (id) beginTargeting('spell', id);
    return;
  }
  if (k === 'p') {
    view.setShadows(!view.shadowsOn);
    world.msg(`Sombras da lamparina ${view.shadowsOn ? 'ligadas' : 'desligadas'} (qualidade).`, 'info');
    return;
  }
  if (KEYMAP[k]) run(KEYMAP[k]);
});
window.addEventListener('keyup', (e) => held.delete(e.key.toLowerCase()));
window.addEventListener('blur', () => held.clear());

canvas.addEventListener('pointermove', (e) => {
  if (!world) return;
  view.hover = view.pickCell(e.clientX, e.clientY);
  refreshTargeting();
});
canvas.addEventListener('pointerdown', (e) => {
  if (!world) return;
  const cell = view.pickCell(e.clientX, e.clientY);
  view.hover = cell;
  if (e.button === 2) {
    if (targeting) cancelTargeting();
    else if (cell) ui.examine(world, cell.x, cell.y);
    return;
  }
  if (targeting) return confirmTarget(cell);
  if (cell) world.cmdInteract(cell.x, cell.y);
});
canvas.addEventListener('contextmenu', (e) => e.preventDefault());
canvas.addEventListener('wheel', (e) => {
  e.preventDefault();
  view.zoomBy(e.deltaY);
}, { passive: false });
window.addEventListener('resize', () => view.resize());

document.getElementById('hotbar').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-cmd]');
  if (b) run(b.dataset.cmd);
});
document.getElementById('modal-close').addEventListener('click', () => ui.closeModal());
document.getElementById('modal').addEventListener('pointerdown', (e) => {
  if (e.target.id === 'modal') ui.closeModal();
});
document.getElementById('modal-body').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-act]');
  if (!b || !world) return;
  const uid = b.dataset.uid ? Number(b.dataset.uid) : null;
  switch (b.dataset.act) {
    case 'equip': world.cmdEquip(uid); break;
    case 'unequip': world.cmdUnequip(b.dataset.slot); break;
    case 'use': world.cmdUse(uid); break;
    case 'drop': world.cmdDrop(uid); break;
    case 'throw':
      ui.closeModal();
      beginTargeting('throw', uid);
      break;
    case 'take': world.cmdTake(ui.lootCache[Number(b.dataset.src)].list, uid); break;
    case 'craft': world.cmdCraft(b.dataset.rid); break;
    case 'search': {
      const prop = world.unsearchedNearby();
      if (prop) world.cmdSearch(prop);
      break;
    }
    default:
  }
  setTimeout(() => ui.modal === 'inventory' && ui.renderInventory(true), 50);
});
document.getElementById('modal-body').addEventListener('change', (e) => {
  const cb = e.target.closest('input[data-skill]');
  if (cb && world) {
    world.setSkillTraining(cb.dataset.skill, cb.checked);
    ui.renderCharacter();
  }
});
document.getElementById('pause-btn').addEventListener('click', () => {
  if (world && !world.gameOver) world.paused = !world.paused;
});

// ------------------------------------------------------------- loop
let last = performance.now();
function frame(t) {
  const dt = Math.min(0.1, (t - last) / 1000);
  last = t;
  if (world) {
    world.input.heldDir = ui.modal === 'inventory' ? null : heldDir();
    world.update(dt * 1000);
    view.update(world, dt, ui);
    ui.update(world, t, dt);
    if (world.victory && !endShown) {
      endShown = true;
      setTimeout(() => ui.showVictory(world.victory, showStart), 1500);
    }
  } else {
    view.renderer.render(view.scene, view.camera);
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

if (params.get('autostart')) {
  start({
    name: params.get('name') || 'Edmund Black',
    species: params.get('species') || 'human',
    background: params.get('bg') || 'relic_hunter',
  });
} else {
  showStart();
}
