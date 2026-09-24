// DOM HUD. Reads world state; sends commands through World cmd* methods only.
import { ITEMS, RECIPES } from '../content/items.js';
import { SPELLS, SKILLS, SPECIES, BACKGROUNDS, NAMES } from '../content/characters.js';
import { PROPS } from '../content/world.js';
import { PARTS, PART_NAMES, describeWound, health, pain, totalBleed, bleedRate } from '../sim/body.js';
import { itemName, itemWeight, carriedWeight, carryCapacity, countItem } from '../sim/entity.js';
import { spellFailure, weaponOf, encumbrance } from '../sim/combat.js';
import { intentLabel } from '../sim/ai.js';
import { T, S } from '../sim/level.js';

const $ = (sel, root = document) => root.querySelector(sel);
const h = (tag, cls, html) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (html !== undefined) e.innerHTML = html;
  return e;
};
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

const SLOT_NAMES = {
  main: 'Mão principal', off: 'Mão secundária', head: 'Cabeça', face: 'Rosto', torso_inner: 'Torso (interno)',
  torso_outer: 'Torso (externo)', hands: 'Mãos', legs: 'Pernas', feet: 'Pés', back: 'Costas', belt: 'Cinto',
};

// Body silhouette: [part, x, y, w, h]
const FIGURE = [
  ['head', 38, 4, 24, 24], ['torso', 32, 31, 36, 46], ['armL', 18, 32, 12, 38], ['armR', 70, 32, 12, 38],
  ['handL', 17, 72, 13, 12], ['handR', 70, 72, 13, 12], ['legL', 34, 80, 15, 50], ['legR', 51, 80, 15, 50],
  ['footL', 31, 132, 18, 10], ['footR', 51, 132, 18, 10],
];

export class UI {
  constructor(view) {
    this.view = view;
    this.world = null;
    this.modal = null;
    this.labels = new Map();
    this.floaters = [];
    this.lastPanel = 0;
    this.selectedUid = null;
    this.labelLayer = $('#labels');
    this.floatLayer = $('#floaters');
    this.buildFigure();
  }

  setWorld(world) {
    this.world = world;
    document.body.classList.toggle('menu', !world);
    this.hotKey = null;
    for (const el of this.labels.values()) el.remove();
    this.labels.clear();
    this.closeModal();
  }

  buildFigure() {
    const svg = FIGURE.map(([id, x, y, w, hh]) => `<rect data-part="${id}" x="${x}" y="${y}" width="${w}" height="${hh}" rx="${id === 'head' ? 10 : 3}"/>`).join('');
    $('#figure').innerHTML = `<svg viewBox="0 0 100 146" aria-label="Corpo">${svg}</svg>`;
  }

  // ---------------------------------------------------------- per frame
  update(world, now, dt = 1 / 60) {
    this.updateLabels(world);
    this.updateFloaters(dt);
    if (now - this.lastPanel > 120) {
      this.lastPanel = now;
      this.updatePanels(world);
      if (this.modal === 'inventory') this.renderInventory(false);
    }
  }

  updatePanels(world) {
    const p = world.player;
    const t = world.gameTime();
    $('#who').textContent = `${p.name} · ${p.species.name} ${p.background.name}`;
    $('#where').textContent = `Profundidade ${world.depth} · Fortaleza Esquecida`;
    $('#clock').textContent = t.text;
    const scale = world.timeScale();
    const mode = $('#mode');
    let label;
    let cls;
    if (world.paused) {
      label = 'PAUSA TÁTICA';
      cls = 'paused';
    } else if (p.action?.type === 'rest') {
      label = p.action.sleep ? 'DORMINDO ×40' : 'ESPERANDO ×40';
      cls = 'rest';
    } else if (scale < 1) {
      label = 'CÂMERA LENTA 0,35×';
      cls = 'slow';
    } else {
      label = `${scale}×`;
      cls = '';
    }
    mode.textContent = label;
    mode.className = `mode ${cls}`;
    $('#autoslow').textContent = `[T] lentidão tática: ${world.autoSlow ? 'ligada' : 'desligada'}`;
    $('#safe').style.display = world.safe ? '' : 'none';

    // Body figure.
    for (const rect of document.querySelectorAll('#figure rect')) {
      const part = rect.dataset.part;
      const pr = p.body.parts[part];
      const r = pr.hp / pr.max;
      const sev = pr.wounds.reduce((s, w) => Math.max(s, w.severity), 0);
      const hue = Math.max(0, Math.min(110, (r - sev * 0.6) * 110));
      rect.setAttribute('fill', pr.hp <= 0 ? '#111' : `hsl(${hue} 55% ${pr.wounds.length ? 38 : 30}%)`);
      const bleeding = pr.wounds.some((w) => bleedRate(w) > 0.02);
      rect.setAttribute('class', `${bleeding ? 'bleeding' : ''} ${pr.wounds.some((w) => w.type === 'fracture') ? 'fracture' : ''}`);
    }
    const wounds = [];
    for (const part of PARTS) {
      for (const w of p.body.parts[part].wounds) {
        const bits = describeWound(w);
        wounds.push(`<div class="wound ${bleedRate(w) > 0.08 ? 'bad' : ''}"><b>${PART_NAMES[part].toUpperCase()}</b><span>${bits.map(esc).join('<br>')}</span></div>`);
      }
    }
    const armourNotes = Object.values(p.equip).filter((it) => it && ITEMS[it.id].covers && ITEMS[it.id].durability && it.cond / ITEMS[it.id].durability < 0.5)
      .map((it) => `<div class="wound"><b>${esc(ITEMS[it.id].name.toUpperCase())}</b><span>${it.cond <= 0 ? 'Destruída' : 'Danificada'}</span></div>`);
    $('#wounds').innerHTML = wounds.concat(armourNotes).join('') || '<div class="muted">Sem ferimentos.</div>';

    const bars = [
      ['Vida', health(p.body), false],
      ['Sangue', p.body.blood, false],
      ['Estamina', p.stamina, false],
      ['Mana', (p.mana / Math.max(1, p.maxMana)) * 100, false, `${Math.floor(p.mana)} / ${p.maxMana}`],
      ['Fome', p.needs.hunger, true, word(p.needs.hunger, ['Saciado', 'Leve', 'Faminto', 'Esfomeado'])],
      [p.species.bloodDrinker ? 'Sede de sangue' : 'Sede', p.needs.thirst, true, word(p.needs.thirst, p.species.bloodDrinker ? ['Saciado', 'Leve', 'Sedento', 'Voraz'] : ['Hidratado', 'Leve', 'Com sede', 'Desidratado'])],
      ['Fadiga', p.needs.fatigue, true, word(p.needs.fatigue, ['Descansado', 'Leve', 'Alta', 'Exausto'])],
      ['Medo', p.needs.fear, true, word(p.needs.fear, ['Calmo', 'Tenso', 'Assustado', 'Em pânico'])],
      ['Dor', pain(p.body), true, word(pain(p.body), ['Nenhuma', 'Leve', 'Forte', 'Agonia'])],
    ];
    $('#bars').innerHTML = bars.map(([name, v, bad, text]) => {
      const val = Math.max(0, Math.min(100, v));
      const color = bad ? (val > 70 ? 'var(--bad)' : val > 40 ? 'var(--warn)' : 'var(--ok-dim)') : val < 30 ? 'var(--bad)' : val < 60 ? 'var(--warn)' : 'var(--ok)';
      return `<div class="bar"><span class="bn">${name}</span><span class="bt">${text || Math.round(val)}</span><i style="width:${val}%;background:${color}"></i></div>`;
    }).join('');

    // Moodles.
    const m = [];
    const bleed = totalBleed(p.body);
    if (bleed > 0.02) m.push(['Sangrando', bleed > 0.25 ? 'bad' : 'warn']);
    if (p.effects.poison > 0) m.push(['Envenenado', 'bad']);
    if (PARTS.some((k) => p.body.parts[k].wounds.some((w) => w.infection > 0.25))) m.push(['Infecção', 'bad']);
    if (p.needs.hunger > 60) m.push(['Faminto', p.needs.hunger > 85 ? 'bad' : 'warn']);
    if (p.needs.thirst > 60) m.push([p.species.bloodDrinker ? 'Sedento de sangue' : 'Com sede', p.needs.thirst > 85 ? 'bad' : 'warn']);
    if (p.needs.fatigue > 70) m.push(['Exausto', 'warn']);
    if (p.needs.fear > 60) m.push(['Em pânico', 'bad']);
    if (carriedWeight(p) > carryCapacity(p)) m.push(['Sobrecarregado', 'warn']);
    if (p.sneaking) m.push(['Furtivo', 'ok']);
    if (world.level.light[world.level.idx(p.x, p.y)] < 0.12) m.push(['Na escuridão', 'ok']);
    if (world.level.smoke[world.level.idx(p.x, p.y)] > 0.35) m.push(['Fumaça', 'warn']);
    if (p.effects.stuckUntil > world.now) m.push(['Preso na teia', 'bad']);
    $('#moodles').innerHTML = m.map(([t2, c]) => `<span class="moodle ${c}">${t2}</span>`).join('');

    // Right panel: gear and spells.
    const { it: wi, def: wd } = weaponOf(p);
    const cond = wi && wd.durability ? wi.cond / wd.durability : 1;
    const lantern = p.equip.belt;
    let gear = `<div class="gear"><b>${esc(wd.name)}</b>${wi && wd.durability ? `<i class="cond"><i style="width:${cond * 100}%;background:${cond < 0.25 ? 'var(--bad)' : cond < 0.6 ? 'var(--warn)' : 'var(--ok)'}"></i></i>` : ''}`;
    if (wd.ranged) gear += `<div>Pente ${wi.mag}/${wd.magazine} · reserva ${countItem(p, wd.ammo)}</div>`;
    gear += '</div>';
    if (lantern) gear += `<div class="gear">Lamparina: ${p.lanternOn ? 'acesa' : 'apagada'} · ${Math.round(lantern.fuel / 60)} min de óleo</div>`;
    if (p.equip.off?.id === 'torch') gear += `<div class="gear">Tocha: ${Math.round(p.equip.off.fuel / 60)} min</div>`;
    gear += `<div class="gear">Carga ${carriedWeight(p).toFixed(1)} / ${carryCapacity(p)} kg · Abates ${p.kills}</div>`;
    if (p.spells.length) {
      gear += '<div class="spells">' + p.spells.map((id) => {
        const sp = SPELLS[id];
        return `<div class="spell ${p.mana < sp.mana ? 'dim' : ''}"><kbd>${sp.key}</kbd> ${esc(sp.name)} <span>${sp.mana} mp · falha ${spellFailure(p, id)}%</span></div>`;
      }).join('') + '</div>';
    }
    $('#gear').innerHTML = gear;

    // Log.
    const log = world.log.slice(-8);
    $('#log').innerHTML = log.map((l, i) => `<div class="msg ${l.cls}" style="opacity:${0.45 + (i / log.length) * 0.55}">${esc(l.text)}</div>`).join('');

    // Player intent.
    const act = p.action;
    let intent = '';
    if (act && act.type !== 'move' && act.t1 - act.t0 >= 300) {
      const pct = Math.min(100, ((world.now - act.t0) / (act.t1 - act.t0)) * 100);
      intent = `<div class="pi-label">Você → ${esc(act.label)}</div><i class="pi-bar"><i style="width:${pct}%"></i></i>`;
    }
    if (p.queuedLabel) intent += `<div class="pi-queued">em fila: ${esc(p.queuedLabel)}</div>`;
    $('#player-intent').innerHTML = intent;
    this.updateHotbar(world);
    this.drawMinimap(world);
  }

  updateHotbar(world) {
    const p = world.player;
    const { def } = weaponOf(p);
    const t = world.level.tile(p.x, p.y);
    const buttons = [];
    for (const id of p.spells) {
      const sp = SPELLS[id];
      buttons.push([sp.key, sp.name, `spell:${id}`, p.mana >= sp.mana, 'magic']);
    }
    if (def.ranged) {
      buttons.push(['F', 'Atirar', 'shoot', true, 'gun']);
      buttons.push(['R', 'Recarregar', 'reload', countItem(p, def.ammo) > 0]);
    }
    if (p.inv.some((it) => ITEMS[it.id].kind === 'throwable')) buttons.push(['Q', 'Arremessar', 'throw', true]);
    buttons.push(['B', 'Tratar', 'treat', true]);
    buttons.push(['X', 'Barricar', 'barricade', countItem(p, 'plank') > 0]);
    buttons.push(['Z', p.needs.fatigue > 20 ? 'Dormir' : 'Esperar', 'rest', !world.danger]);
    buttons.push(['L', p.lanternOn ? 'Apagar luz' : 'Acender luz', 'lantern', !!p.equip.belt]);
    buttons.push(['V', p.sneaking ? 'Andar' : 'Furtivo', 'sneak', true]);
    if (p.species.bloodDrinker) buttons.push(['E', 'Alimentar-se', 'feed', true]);
    if (t === T.STAIRS_DOWN || t === T.STAIRS_UP) buttons.push(['Enter', t === T.STAIRS_DOWN ? 'Descer' : 'Subir', 'stairs', true, 'stairs']);
    buttons.push(['I', 'Inventário', 'inventory', true]);
    buttons.push(['C', 'Personagem', 'character', true]);
    buttons.push(['H', 'Ajuda', 'help', true]);
    const key = buttons.map((b) => b.join('|')).join(';');
    if (key === this.hotKey) return;
    this.hotKey = key;
    const bar = $('#hotbar');
    bar.innerHTML = buttons.map(([k, label, cmd, ok, cls]) => `<button class="hb ${cls || ''}" data-cmd="${cmd}" ${ok ? '' : 'disabled'}><kbd>${k}</kbd>${esc(label)}</button>`).join('');
    document.documentElement.style.setProperty('--hb', `${bar.offsetHeight}px`);
  }

  drawMinimap(world) {
    const c = $('#minimap');
    if (!c) return;
    const level = world.level;
    const s = 3;
    if (c.width !== level.w * s) {
      c.width = level.w * s;
      c.height = level.h * s;
    }
    const ctx = c.getContext('2d');
    ctx.clearRect(0, 0, c.width, c.height);
    for (let y = 0; y < level.h; y++) {
      for (let x = 0; x < level.w; x++) {
        const i = level.idx(x, y);
        if (!level.explored[i]) continue;
        const t = level.tiles[i];
        let col = null;
        if (t === T.WALL) col = '#4a4640';
        else if (t === T.WATER) col = '#2a4a58';
        else if (t === T.DOOR) col = '#8a5a2a';
        else if (t === T.STAIRS_DOWN || t === T.STAIRS_UP) col = '#e8d8a0';
        else if (t !== T.ROCK) col = level.visible[i] ? '#6a655d' : '#34322f';
        if (level.fire[i] > 0) col = '#ff7a1a';
        if (col) {
          ctx.fillStyle = col;
          ctx.fillRect(x * s, y * s, s, s);
        }
      }
    }
    for (const m of level.actors) {
      if (!m.alive || !world.isVisible(m.x, m.y)) continue;
      ctx.fillStyle = m.team === 'player' ? '#7aff5a' : '#ff4a3a';
      ctx.fillRect(m.x * s - 1, m.y * s - 1, s + 1, s + 1);
    }
    const p = world.player;
    ctx.fillStyle = '#fff';
    ctx.fillRect(p.x * s - 1, p.y * s - 1, s + 2, s + 2);
  }

  // ---------------------------------------------------------- labels
  updateLabels(world) {
    const show = world.paused || world.danger || world.timeScale() < 1;
    const live = new Set();
    const hov = this.view.hover;
    const placed = [];
    for (const m of world.level.actors) {
      if (!m.alive || !world.isVisible(m.x, m.y)) continue;
      const hovered = hov && hov.x === m.x && hov.y === m.y;
      const sleeping = m.ai.state === 'sleep';
      if (!show && !hovered && !sleeping && m.team === 'hostile') continue;
      live.add(m.id);
      let el = this.labels.get(m.id);
      if (!el) {
        el = h('div', 'intent');
        this.labelLayer.appendChild(el);
        this.labels.set(m.id, el);
      }
      const pos = this.view.actorScreen(m);
      // Stack labels of crowded monsters instead of overlapping them.
      let y = pos.y;
      for (let guard = 0; guard < 6; guard++) {
        const hit = placed.find((q) => Math.abs(q.x - pos.x) < 90 && Math.abs(q.y - y) < 34);
        if (!hit) break;
        y = hit.y - 36;
      }
      placed.push({ x: pos.x, y });
      el.style.transform = `translate(${pos.x}px, ${y}px) translate(-50%, -100%)`;
      const intent = intentLabel(world, m);
      const act = m.action;
      const telegraph = act && (act.type === 'cast' || act.type === 'ability' || act.type === 'attack');
      const pct = act ? Math.min(100, ((world.now - act.t0) / Math.max(1, act.t1 - act.t0)) * 100) : 0;
      const hpPct = Math.max(0, (m.hp / m.maxHp) * 100);
      const cls = `intent ${m.team === 'player' ? 'ally' : ''} ${telegraph ? 'tele' : ''} ${sleeping ? 'sleep' : ''}`;
      if (el.className !== cls) el.className = cls;
      el.innerHTML = sleeping && !hovered && !show
        ? '<span class="zz">z z z</span>'
        : `<b>${esc(m.name)}</b><span>${esc(intent)}</span>${telegraph ? `<i class="tb"><i style="width:${pct}%"></i></i>` : ''}<i class="hp"><i style="width:${hpPct}%"></i></i>`;
    }
    for (const [id, el] of this.labels) {
      if (!live.has(id)) {
        el.remove();
        this.labels.delete(id);
      }
    }
  }

  floatText(x, y, text, cls) {
    const el = h('div', `floater ${cls}`, esc(text));
    this.floatLayer.appendChild(el);
    this.floaters.push({ el, x, y, t: 0 });
  }

  updateFloaters(dt) {
    for (let i = this.floaters.length - 1; i >= 0; i--) {
      const f = this.floaters[i];
      f.t += dt;
      const pos = this.view.project(f.x, f.y, 2 + f.t * 1.2);
      f.el.style.transform = `translate(${pos.x}px, ${pos.y}px) translate(-50%, -50%)`;
      f.el.style.opacity = String(Math.max(0, 1 - f.t / 1.1));
      if (f.t > 1.1) {
        f.el.remove();
        this.floaters.splice(i, 1);
      }
    }
  }

  onEvent(e) {
    if (e.type === 'target' && this.onTarget) this.onTarget(e);
  }

  // ---------------------------------------------------------- modals
  openModal(kind) {
    this.modal = kind;
    const el = $('#modal');
    el.style.display = 'flex';
    if (kind === 'inventory') this.renderInventory(true);
    if (kind === 'character') this.renderCharacter();
    if (kind === 'help') this.renderHelp();
  }

  closeModal() {
    this.modal = null;
    const el = $('#modal');
    if (el) el.style.display = 'none';
  }

  renderInventory(force) {
    const world = this.world;
    const p = world.player;
    const sig = JSON.stringify([p.inv.map((i) => [i.uid, i.qty, i.charges, i.cond, i.mag]), Object.values(p.equip).map((i) => i && [i.uid, i.cond, i.fuel > 0]), world.lootSources().map((s) => s.items.map((i) => i.uid)), this.selectedUid, p.x, p.y]);
    if (!force && sig === this.invSig) return;
    this.invSig = sig;
    const box = $('#modal-body');
    const eq = Object.keys(SLOT_NAMES).map((slot) => {
      const it = p.equip[slot];
      return `<div class="row"><span class="slot">${SLOT_NAMES[slot]}</span><span class="nm">${it ? esc(itemName(it)) : '<i class="muted">—</i>'}</span>${it ? `<button data-act="unequip" data-slot="${slot}">Remover</button>` : ''}${it && ITEMS[it.id].kind === 'light' ? `<button data-act="use" data-uid="${it.uid}">Óleo</button>` : ''}${it?.id === 'torch' ? `<button data-act="use" data-uid="${it.uid}">Atear fogo</button>` : ''}</div>`;
    }).join('');
    const inv = p.inv.map((it) => {
      const def = ITEMS[it.id];
      const sel = it.uid === this.selectedUid;
      const acts = [];
      if (def.slot) acts.push(['equip', 'Equipar']);
      if (['food', 'drink', 'medical', 'potion', 'book', 'tool', 'placeable', 'relic'].includes(def.kind) || (def.kind === 'material' && def.use)) acts.push(['use', useLabel(def)]);
      if (def.kind === 'throwable') acts.push(['throw', 'Arremessar']);
      acts.push(['drop', 'Largar']);
      return `<div class="row item ${sel ? 'sel' : ''}" data-uid="${it.uid}"><span class="nm">${esc(itemName(it))}</span><span class="wt">${itemWeight(it).toFixed(2)} kg</span>${acts.map(([a, l]) => `<button data-act="${a}" data-uid="${it.uid}">${l}</button>`).join('')}</div>`;
    }).join('') || '<div class="muted">Mochila vazia.</div>';
    const sources = world.lootSources();
    const loot = sources.map((s, si) => `<h4>${esc(s.label)}</h4>` + s.items.map((it) => `<div class="row"><span class="nm">${esc(itemName(it))}</span><span class="wt">${itemWeight(it).toFixed(2)} kg</span><button data-act="take" data-src="${si}" data-uid="${it.uid}">Pegar</button></div>`).join('')).join('');
    const unsearched = world.unsearchedNearby();
    const craft = RECIPES.map((r) => {
      const ok = Object.entries(r.needs).every(([id, n]) => countItem(p, id) >= n);
      const needs = Object.entries(r.needs).map(([id, n]) => `${n}× ${ITEMS[id].name}`).join(' + ');
      return `<div class="row ${ok ? '' : 'dim'}"><span class="nm">${esc(r.name)}</span><span class="wt">${esc(needs)}</span><button data-act="craft" data-rid="${r.id}" ${ok ? '' : 'disabled'}>Fazer</button></div>`;
    }).join('');
    box.innerHTML = `
      <div class="cols">
        <section><h3>Equipamento</h3>${eq}
          <p class="muted small">Carga ${carriedWeight(p).toFixed(1)} / ${carryCapacity(p)} kg · Estorvo da armadura ${encumbrance(p).toFixed(1)}</p></section>
        <section><h3>Mochila</h3>${inv}</section>
        <section><h3>Ao alcance</h3>${loot || '<div class="muted">Nada no chão aqui.</div>'}
          ${unsearched ? `<button class="wide" data-act="search">Vasculhar ${esc(PROPS[unsearched.id].name.toLowerCase())}</button>` : ''}
          <h3>Construir (campo)</h3>${craft}
          <p class="muted small">Oficinas (forja, alquimia) ficam fora desta fatia vertical.</p></section>
      </div>`;
    this.lootCache = sources;
  }

  renderCharacter() {
    const world = this.world;
    const p = world.player;
    const groups = {};
    for (const [id, s] of Object.entries(SKILLS)) (groups[s.group] ||= []).push(id);
    const skills = Object.entries(groups).map(([g, ids]) => `<h4>${g}</h4>` + ids.map((id) => {
      const s = p.skills[id];
      const apt = p.species.aptitudes[id] || 0;
      return `<label class="row skill ${s.train ? 'on' : ''}"><input type="checkbox" data-skill="${id}" ${s.train ? 'checked' : ''}><span class="nm">${SKILLS[id].name}</span><span class="lv">${s.level.toFixed(1)}</span><span class="apt">${apt > 0 ? '+' + apt : apt < 0 ? apt : ''}</span></label>`;
    }).join('')).join('');
    const spells = p.spells.map((id) => {
      const sp = SPELLS[id];
      return `<div class="row"><span class="nm"><kbd>${sp.key}</kbd> ${esc(sp.name)}</span><span class="wt">${sp.mana} mp · falha ${spellFailure(p, id)}%</span></div><p class="muted small">${esc(sp.desc)}</p>`;
    }).join('') || '<p class="muted">Nenhum feitiço. Livros e pergaminhos ensinam magia a qualquer um — mas armadura pesada e falta de treino aumentam a falha.</p>';
    $('#modal-body').innerHTML = `
      <div class="cols">
        <section><h3>${esc(p.name)}</h3>
          <p>${esc(p.species.name)} · ${esc(p.background.name)}</p>
          <p class="muted small">${esc(p.species.desc)}</p>
          <p class="small">Tempo sobrevivido: ${world.survivedText()} · Abates: ${p.kills}</p>
          <h3>Feitiços</h3>${spells}</section>
        <section class="wide2"><h3>Perícias</h3>
          <p class="muted small">Como no DCSS: a experiência de cada abate é dividida entre as perícias marcadas. Você decide onde investir — nada de treino repetitivo. Aptidões da espécie tornam algumas mais baratas.</p>
          <div class="skills">${skills}</div></section>
      </div>`;
  }

  renderHelp() {
    $('#modal-body').innerHTML = `
      <div class="cols help">
        <section><h3>Tempo contínuo</h3>
          <p>O mundo se move continuamente, mas cada ação tem uma duração e todos os atores seguem o mesmo relógio. Quando há perigo, o tempo desacelera para 0,35×. <kbd>Espaço</kbd> pausa: escolha uma ação, ela entra na fila e acontece ao despausar. Os rótulos mostram o que cada inimigo está preparando.</p>
          <h3>Movimento</h3>
          <p><kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> / setas movem em relação à tela. Clique para andar, clique num inimigo para atacar, numa porta para abrir/fechar, num baú para vasculhar. Andar contra um móvel <b>o arrasta</b>. Botão direito examina.</p>
          <h3>Sobrevivência</h3>
          <p><kbd>B</kbd> trata o ferimento mais urgente (bandagem, sutura, tala, álcool). <kbd>Z</kbd> dorme ou espera. <kbd>X</kbd> barrica uma porta com tábuas. Uma sala com todas as portas fechadas e bloqueadas (tábuas ou um móvel arrastado) é uma <b>sala segura</b>.</p></section>
        <section><h3>Ações</h3>
          <p><kbd>1</kbd>–<kbd>4</kbd> feitiços · <kbd>F</kbd> atirar · <kbd>R</kbd> recarregar · <kbd>Q</kbd> arremessar · <kbd>G</kbd> pegar/vasculhar · <kbd>O</kbd> porta · <kbd>Enter</kbd> escadas · <kbd>L</kbd> lamparina · <kbd>V</kbd> furtividade · <kbd>E</kbd> alimentar-se (vampiro) · <kbd>I</kbd> inventário · <kbd>C</kbd> personagem · <kbd>T</kbd> lentidão tática · roda do mouse: zoom · <kbd>Esc</kbd> cancela.</p>
          <p>Aperte a tecla de um feitiço duas vezes (ou <kbd>Enter</kbd>) para mirar no inimigo mais próximo.</p>
          <h3>Sistemas</h3>
          <p><b>Som</b>: cada ação tem um raio. Passos 2, porta 3, espada 4–8, grito 12, pistola 30, Bola de Fogo 35. Monstros ouvem através de portas; paredes abafam. <b>Luz</b>: sua lamparina revela você. Apagá-la esconde — mas você também fica cego.</p>
          <p><b>Fogo</b> se espalha por óleo, madeira, teias e cadáveres, gera fumaça e destrói itens. <b>Gelo</b> congela água e apaga fogo. <b>Relâmpago</b> percorre a água. <b>Cadáveres</b> são recurso para necromancia.</p>
          <p><b>Morte é permanente.</b> Quem morre continua lá embaixo.</p></section>
      </div>`;
  }

  // ------------------------------------------------------------ screens
  showStart(hall, onStart) {
    document.body.classList.add('menu');
    const el = $('#screen-start');
    el.style.display = 'flex';
    const speciesCards = Object.entries(SPECIES).map(([id, s], i) => `<label class="card"><input type="radio" name="species" value="${id}" ${i === 0 ? 'checked' : ''}><b>${esc(s.name)}</b><span>${esc(s.desc)}</span></label>`).join('');
    const bgCards = Object.entries(BACKGROUNDS).map(([id, b], i) => `<label class="card"><input type="radio" name="bg" value="${id}" ${i === 0 ? 'checked' : ''}><b>${esc(b.name)}</b><span>${esc(b.desc)}</span></label>`).join('');
    const waiting = hall.find((x) => !x.laidToRest && x.depth <= 5);
    const dead = hall.slice(0, 6).map((d) => `<div class="epitaph-mini"><b>${esc(d.name)}</b> — ${esc(d.species)} ${esc(d.background)}, prof. ${d.depth}<br><span>${esc(d.cause)} · ${esc(d.survived)}${d.laidToRest ? ' · descansa' : ''}</span></div>`).join('');
    el.querySelector('.start-body').innerHTML = `
      <div class="form">
        <label class="name">Nome <input id="pc-name" maxlength="28" value="${esc(NAMES[Math.floor(Math.random() * NAMES.length)])}"><button id="pc-rand" type="button" title="Nome aleatório">↻</button></label>
        <h3>Espécie</h3><div class="cards">${speciesCards}</div>
        <h3>Origem</h3><div class="cards">${bgCards}</div>
        <button id="pc-go" class="go">Descer à Fortaleza Esquecida</button>
      </div>
      <aside>
        <h3>Salão dos Mortos</h3>
        ${dead || '<p class="muted">Ninguém ainda. Seja o primeiro.</p>'}
        ${waiting ? `<p class="hollow">Algo com o rosto de <b>${esc(waiting.name)}</b> ainda anda na profundidade ${waiting.depth}.</p>` : ''}
      </aside>`;
    $('#pc-rand').onclick = () => {
      $('#pc-name').value = NAMES[Math.floor(Math.random() * NAMES.length)];
    };
    $('#pc-go').onclick = () => {
      const name = $('#pc-name').value.trim() || 'Sem Nome';
      const species = el.querySelector('input[name=species]:checked').value;
      const bg = el.querySelector('input[name=bg]:checked').value;
      el.style.display = 'none';
      onStart({ name, species, background: bg });
    };
  }

  showDeath(rec, onAgain) {
    const el = $('#screen-death');
    el.style.display = 'flex';
    el.querySelector('.epitaph').innerHTML = `
      <div class="day">DIA ${rec.day}</div>
      <h2>${esc(rec.name)}</h2>
      <div>${esc(rec.species)} / ${esc(rec.background)}</div>
      <dl>
        <dt>Profundidade</dt><dd>${rec.depth}</dd>
        <dt>Causa da morte</dt><dd>${esc(rec.cause)}</dd>
        <dt>Tempo sobrevivido</dt><dd>${esc(rec.survived)}</dd>
        <dt>Abates</dt><dd>${rec.kills}</dd>
      </dl>
      <p class="muted">A masmorra guarda o que você carregava. O próximo a descer à profundidade ${rec.depth} pode encontrar você — não necessariamente morto.</p>
      <button class="go" id="again">Novo personagem</button>`;
    $('#again').onclick = () => {
      el.style.display = 'none';
      onAgain();
    };
  }

  showVictory(v, onAgain) {
    const el = $('#screen-death');
    el.style.display = 'flex';
    el.querySelector('.epitaph').innerHTML = `
      <div class="day">FIM DA DEMO</div>
      <h2>${esc(v.name)} atravessa o Portão do Profundo</h2>
      <dl>
        <dt>Tempo na fortaleza</dt><dd>${esc(v.survived)}</dd>
        <dt>Abates</dt><dd>${v.kills}</dd>
        <dt>Relíquias</dt><dd>${esc(v.relics.join(', ') || 'nenhuma')}</dd>
      </dl>
      <p class="muted">Abaixo: Profundo, Cidade Perdida, Zona Abissal. Esta fatia vertical termina aqui.</p>
      <button class="go" id="again">Nova descida</button>`;
    $('#again').onclick = () => {
      el.style.display = 'none';
      onAgain();
    };
  }

  // Right-click examine.
  examine(world, x, y) {
    const level = world.level;
    if (!level.inBounds(x, y) || !level.explored[level.idx(x, y)]) return world.msg('Você não conhece esse lugar.', 'info');
    const bits = [];
    const a = world.actorAt(x, y);
    if (a && world.isVisible(x, y)) {
      if (a.isPlayer) bits.push('Você.');
      else {
        const hp = a.hp / a.maxHp;
        bits.push(`${a.name}: ${intentLabel(world, a)}, ${hp > 0.8 ? 'ileso' : hp > 0.5 ? 'ferido' : hp > 0.2 ? 'muito ferido' : 'quase morto'}.`);
        if (a.def.desc) bits.push(a.def.desc);
        if (a.def.resists || a.def.ac?.blunt < 0) bits.push(a.def.ac?.blunt < 0 ? 'Vulnerável a impacto; resistente a perfuração.' : '');
      }
    }
    const prop = level.prop(x, y);
    if (prop) bits.push(`${PROPS[prop.id].name}${PROPS[prop.id].flammable ? ' (inflamável)' : ''}${PROPS[prop.id].movable ? ', pode ser arrastado' : ''}${PROPS[prop.id].container ? (prop.searched ? ', já vasculhado' : ', pode ser vasculhado') : ''}.`);
    const d = level.door(x, y);
    if (d) bits.push(`Porta ${d.broken ? 'arrombada' : d.open ? 'aberta' : 'fechada'}${d.barricade ? `, ${d.barricade} tábua(s)` : ''}.`);
    const s = level.surface[level.idx(x, y)];
    if (s === S.OIL) bits.push('Óleo no chão — inflamável.');
    if (s === S.BLOOD) bits.push('Sangue. Carniçais sentem o cheiro.');
    if (s === S.ICE) bits.push('Gelo — escorregadio.');
    if (s === S.WEB) bits.push('Teia — prende quem pisa. Queima rápido.');
    if (level.tile(x, y) === T.WATER) bits.push('Água parada — conduz eletricidade; congela.');
    if (level.fire[level.idx(x, y)] > 0) bits.push('Em chamas!');
    const corpses = level.corpses.get(level.idx(x, y));
    if (corpses) bits.push(corpses.map((c) => `${c.name}${c.charred ? ' (carbonizado)' : c.monsterId ? ' — pode ser erguido' : ''}`).join(', ') + '.');
    const items = level.itemsAt(x, y);
    if (items.length && world.isVisible(x, y)) bits.push(`Itens: ${items.map(itemName).join(', ')}.`);
    const light = level.light[level.idx(x, y)];
    bits.push(light > 0.5 ? 'Bem iluminado.' : light > 0.1 ? 'Penumbra.' : 'Escuro.');
    world.msg(bits.filter(Boolean).join(' '), 'info');
  }
}

function word(v, words) {
  if (v < 25) return words[0];
  if (v < 50) return words[1];
  if (v < 80) return words[2];
  return words[3];
}

function useLabel(def) {
  switch (def.kind) {
    case 'food': return 'Comer';
    case 'drink': return 'Beber';
    case 'potion': return 'Beber';
    case 'book': return 'Ler';
    case 'tool': return 'Amolar';
    case 'placeable': return 'Acender';
    case 'relic': return 'Examinar';
    default: return 'Usar';
  }
}

