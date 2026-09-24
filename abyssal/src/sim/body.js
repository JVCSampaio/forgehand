// Localised anatomy (Project Zomboid-style). The player has no single HP pool:
// each part has integrity and wounds; blood loss, infection and trauma kill.
export const PARTS = ['head', 'torso', 'armL', 'armR', 'handL', 'handR', 'legL', 'legR', 'footL', 'footR'];

export const PART_NAMES = {
  head: 'Cabeça', torso: 'Torso', armL: 'Braço E', armR: 'Braço D', handL: 'Mão E',
  handR: 'Mão D', legL: 'Perna E', legR: 'Perna D', footL: 'Pé E', footR: 'Pé D',
};

const PART_MAX = { head: 40, torso: 80, armL: 45, armR: 45, handL: 30, handR: 30, legL: 50, legR: 50, footL: 30, footR: 30 };
const LIMBS = new Set(['armL', 'armR', 'handL', 'handR', 'legL', 'legR', 'footL', 'footR']);

export const WOUND_NAMES = {
  scratch: 'Arranhão',
  laceration: 'Laceração',
  deep_laceration: 'Laceração profunda',
  puncture: 'Perfuração',
  bite: 'Mordida',
  bruise: 'Contusão',
  fracture: 'Fratura',
  burn: 'Queimadura',
};

export function createBody() {
  const parts = {};
  for (const p of PARTS) parts[p] = { hp: PART_MAX[p], max: PART_MAX[p], wounds: [] };
  return { parts, blood: 100 };
}

let WID = 1;

// dmg: { slash, pierce, blunt, bite, fire, cold, electric, arcane } after armour.
// Returns list of new wounds (for messages).
export function woundPart(body, part, dmg, info, rng) {
  const p = body.parts[part];
  const created = [];
  let total = 0;
  for (const v of Object.values(dmg)) total += v;
  if (total <= 0) return created;
  p.hp = Math.max(0, p.hp - total);
  const src = info.source || 'algo';
  const add = (type, severity, bleed, extra = {}) => {
    // Repeated trauma on the same spot worsens the existing wound instead of stacking.
    const family = type === 'deep_laceration' || type === 'laceration' || type === 'scratch' ? 'cut' : type;
    const same = p.wounds.find((w) => (w.type === 'deep_laceration' || w.type === 'laceration' || w.type === 'scratch' ? 'cut' : w.type) === family);
    if (same && family !== 'fracture') {
      same.severity = Math.min(1, same.severity + severity * 0.6);
      same.initial = Math.max(same.initial ?? 0, same.severity);
      same.bleed = Math.max(same.bleed, bleed) + bleed * 0.3;
      same.clot = 0;
      same.bandaged = null;
      same.stitched = false;
      if (family === 'cut') same.type = same.severity > 0.55 ? 'deep_laceration' : same.severity > 0.2 ? 'laceration' : 'scratch';
      if (extra.infection) same.infection = Math.max(same.infection, extra.infection);
      created.push(same);
      return same;
    }
    const w = {
      id: WID++, type, severity: Math.min(1, severity), bleed, bandaged: null, stitched: false,
      splinted: false, infection: 0, dirty: type !== 'burn' && type !== 'bruise' && type !== 'fracture',
      source: src, ...extra,
    };
    p.wounds.push(w);
    created.push(w);
    return w;
  };
  if (dmg.slash > 0.5) {
    const s = dmg.slash / 15;
    const type = s > 0.55 ? 'deep_laceration' : s > 0.2 ? 'laceration' : 'scratch';
    add(type, s, s * (type === 'scratch' ? 0.04 : type === 'deep_laceration' ? 0.6 : 0.35));
  }
  if (dmg.pierce > 0.5) {
    const s = dmg.pierce / 14;
    add('puncture', s, s * 0.3);
  }
  if (dmg.bite > 0.5) {
    const s = dmg.bite / 13;
    const w = add('bite', s, s * 0.28);
    if (rng.chance(info.infect || 0)) w.infection = 0.08;
  }
  if (dmg.blunt > 0.5) {
    const s = dmg.blunt / 20;
    if (LIMBS.has(part) && dmg.blunt >= 6 && rng.chance((info.fracture || 0) + dmg.blunt / 60)) {
      add('fracture', 0.6 + s * 0.4, 0, { dirty: false });
    } else add('bruise', s, 0);
  }
  if (dmg.fire > 0.5) add('burn', dmg.fire / 14, 0);
  if (info.fracture && !dmg.blunt && LIMBS.has(part) && total >= 8 && rng.chance(info.fracture)) {
    add('fracture', 0.7, 0, { dirty: false });
  }
  return created;
}

export function bleedRate(w) {
  if (w.stitched) return 0;
  const base = w.bleed * Math.max(0.2, w.severity / Math.max(0.01, w.initial ?? w.severity)) * (1 - (w.clot || 0));
  return w.bandaged ? base * 0.12 : base;
}

export function bleedWord(rate) {
  if (rate <= 0.001) return null;
  if (rate < 0.08) return 'Sangramento leve';
  if (rate < 0.25) return 'Sangramento moderado';
  return 'Sangramento intenso';
}

export function totalBleed(body) {
  let b = 0;
  for (const part of PARTS) for (const w of body.parts[part].wounds) b += bleedRate(w);
  return b;
}

export function pain(body) {
  let p = 0;
  for (const part of PARTS) {
    for (const w of body.parts[part].wounds) {
      let k = 22;
      if (w.type === 'fracture') k = w.splinted ? 20 : 45;
      if (w.type === 'burn') k = 30;
      if (w.type === 'scratch') k = 8;
      p += w.severity * k;
    }
    const pr = body.parts[part];
    p += (1 - pr.hp / pr.max) * 10;
  }
  return Math.min(100, p);
}

export function hasFracture(body, part) {
  return body.parts[part].wounds.some((w) => w.type === 'fracture');
}

export function limbOk(body, part) {
  const pr = body.parts[part];
  if (pr.hp <= 0) return false;
  return !body.parts[part].wounds.some((w) => w.type === 'fracture' && !w.splinted);
}

// Overall health, 0..100, for the HUD.
export function health(body) {
  let sum = 0;
  let wsum = 0;
  for (const part of PARTS) {
    const pr = body.parts[part];
    const wgt = part === 'torso' || part === 'head' ? 3 : 1;
    sum += (pr.hp / pr.max) * wgt;
    wsum += wgt;
  }
  return Math.round(Math.min(sum / wsum, body.blood / 100) * 100);
}

// Movement multiplier from leg/foot trauma.
export function legPenalty(body) {
  let m = 1;
  for (const part of ['legL', 'legR', 'footL', 'footR']) {
    const pr = body.parts[part];
    for (const w of pr.wounds) {
      if (w.type === 'fracture') m += w.splinted ? 0.35 : 0.9;
      else m += w.severity * 0.25;
    }
    if (pr.hp <= 0) m += 0.6;
  }
  return m;
}

export function worstWound(body, predicate = () => true) {
  let best = null;
  for (const part of PARTS) {
    for (const w of body.parts[part].wounds) {
      if (!predicate(w, part)) continue;
      const score = bleedRate(w) * 10 + w.severity + (w.infection > 0 ? 0.5 : 0);
      if (!best || score > best.score) best = { part, wound: w, score };
    }
  }
  return best;
}

// Per-simulated-second update. Returns a death cause string or null.
export function tickBody(body, dt, ctx) {
  const sec = dt / 1000;
  let bleeding = 0;
  let infectionLoad = 0;
  for (const part of PARTS) {
    const pr = body.parts[part];
    for (let i = pr.wounds.length - 1; i >= 0; i--) {
      const w = pr.wounds[i];
      if (w.initial === undefined) w.initial = w.severity;
      // Shallow wounds clot on their own; deep ones need a bandage or stitches.
      if (w.bleed > 0 && (w.clot || 0) < 1) {
        const deep = w.type === 'deep_laceration' || w.severity > 0.5;
        w.clot = Math.min(1, (w.clot || 0) + sec * (deep ? 0.0015 : w.bandaged ? 0.03 : 0.012));
      }
      bleeding += bleedRate(w);
      // Infection: dirty, untreated wounds can fester; established infections grow.
      if (w.infection > 0) {
        w.infection = Math.min(1, w.infection + sec * (w.bandaged === 'clean' ? 0.002 : 0.004));
        infectionLoad += w.infection;
      } else if (w.dirty && w.type !== 'scratch' && !w.bandaged) {
        if (ctx.rng.chance(sec * 0.0012)) w.infection = 0.05;
      } else if (w.dirty && w.bandaged === 'dirty' && ctx.rng.chance(sec * 0.0008)) {
        w.infection = 0.05;
      }
      // Healing.
      let heal = 0.0009;
      if (w.bandaged === 'clean') heal = 0.0022;
      if (w.stitched) heal = 0.004;
      if (w.type === 'fracture') heal = w.splinted ? 0.0006 : 0.00012;
      if (w.infection > 0.3) heal = 0;
      if (ctx.starving) heal *= 0.3;
      heal *= ctx.healMult || 1;
      w.severity -= heal * sec;
      if (w.severity <= 0) pr.wounds.splice(i, 1);
    }
    if (!ctx.starving && pr.hp < pr.max && pr.wounds.length === 0) {
      pr.hp = Math.min(pr.max, pr.hp + sec * 0.05 * (ctx.healMult || 1));
    }
  }
  body.blood -= bleeding * sec;
  if (bleeding < 0.01 && !ctx.dehydrated) body.blood = Math.min(100, body.blood + sec * 0.03);
  if (infectionLoad > 0.6) {
    body.parts.torso.hp -= sec * infectionLoad * 0.06;
  }
  return deathCheck(body, ctx);
}

export function deathCheck(body, ctx = {}) {
  if (body.blood <= 0) {
    const src = ctx.lastBleedSource;
    return src ? `exsanguinação após ${src}` : 'exsanguinação';
  }
  if (body.parts.head.hp <= 0) return `traumatismo craniano (${ctx.lastHit || 'golpe'})`;
  if (body.parts.torso.hp <= 0) {
    if (ctx.lastTorsoCause) return ctx.lastTorsoCause;
    return `ferimentos no torso (${ctx.lastHit || 'golpe'})`;
  }
  return null;
}

export function describeWound(w) {
  const parts = [WOUND_NAMES[w.type]];
  const b = bleedWord(bleedRate(w));
  if (b) parts.push(b);
  if (w.bandaged === 'clean') parts.push('enfaixado');
  if (w.bandaged === 'dirty') parts.push('trapo sujo');
  if (w.stitched) parts.push('suturado');
  if (w.splinted) parts.push('imobilizado');
  if (w.infection > 0.25) parts.push('INFECCIONADO');
  else if (w.infection > 0) parts.push('inflamado');
  return parts;
}
