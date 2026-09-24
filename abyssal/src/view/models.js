// Low/mid-poly procedural models. One humanoid rig for every humanoid (player,
// skeletons, goblins, knights, the boss); equipment attaches to sockets.
import * as THREE from '../../vendor/three.module.min.js';

const matCache = new Map();
export function mat(color, opts = {}) {
  const key = `${color}|${opts.metal || 0}|${opts.rough ?? 0.85}|${opts.emissive || 0}|${opts.ei || 0}|${opts.transparent ? opts.opacity : 1}`;
  if (!opts.unique && matCache.has(key)) return matCache.get(key);
  const m = new THREE.MeshStandardMaterial({
    color, metalness: opts.metal || 0, roughness: opts.rough ?? 0.85,
    emissive: opts.emissive || 0x000000, emissiveIntensity: opts.ei || 0,
    transparent: !!opts.transparent, opacity: opts.opacity ?? 1, flatShading: opts.flat ?? false,
  });
  if (!opts.unique) matCache.set(key, m);
  return m;
}

export function glow(color, intensity = 2.5) {
  return new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(intensity), toneMapped: false });
}

const geoCache = new Map();
function box(w, h, d) {
  const k = `b${w},${h},${d}`;
  if (!geoCache.has(k)) geoCache.set(k, new THREE.BoxGeometry(w, h, d));
  return geoCache.get(k);
}
function cyl(rt, rb, h, seg = 10) {
  const k = `c${rt},${rb},${h},${seg}`;
  if (!geoCache.has(k)) geoCache.set(k, new THREE.CylinderGeometry(rt, rb, h, seg));
  return geoCache.get(k);
}
function sph(r, seg = 10) {
  const k = `s${r},${seg}`;
  if (!geoCache.has(k)) geoCache.set(k, new THREE.SphereGeometry(r, seg, Math.max(6, seg - 2)));
  return geoCache.get(k);
}
function cone(r, h, seg = 8) {
  const k = `k${r},${h},${seg}`;
  if (!geoCache.has(k)) geoCache.set(k, new THREE.ConeGeometry(r, h, seg));
  return geoCache.get(k);
}

export function mesh(geo, material, x = 0, y = 0, z = 0, shadow = true) {
  const m = new THREE.Mesh(geo, material);
  m.position.set(x, y, z);
  m.castShadow = shadow;
  m.receiveShadow = true;
  return m;
}

const P = {
  wood: 0x5c4029, woodDark: 0x3b2819, iron: 0x70757c, stone: 0x6b675f, stoneDark: 0x4a4741,
  bone: 0xd9d1b9, cloth: 0x6d2a2a, gold: 0xc9a13a, leather: 0x4e3521, oil: 0x15110c,
};
export const PALETTE = P;

// ------------------------------------------------------------ weapons
export function weaponModel(id, tint) {
  const g = new THREE.Group();
  const steel = mat(0xb8bec6, { metal: 0.8, rough: 0.35 });
  const grip = mat(P.leather);
  switch (id) {
    case 'dagger':
      g.add(mesh(box(0.05, 0.3, 0.02), steel, 0, -0.2, 0));
      g.add(mesh(box(0.12, 0.03, 0.04), mat(P.iron, { metal: 0.6 }), 0, -0.04, 0));
      break;
    case 'sword':
      g.add(mesh(box(0.06, 0.62, 0.02), steel, 0, -0.38, 0));
      g.add(mesh(box(0.2, 0.04, 0.05), mat(P.iron, { metal: 0.6 }), 0, -0.06, 0));
      g.add(mesh(box(0.04, 0.12, 0.04), grip, 0, 0.02, 0));
      break;
    case 'longsword':
      g.add(mesh(box(0.07, 0.95, 0.02), steel, 0, -0.55, 0));
      g.add(mesh(box(0.28, 0.05, 0.06), mat(P.iron, { metal: 0.6 }), 0, -0.07, 0));
      g.add(mesh(box(0.045, 0.22, 0.045), grip, 0, 0.06, 0));
      break;
    case 'axe':
      g.add(mesh(box(0.05, 0.85, 0.05), mat(P.wood), 0, -0.3, 0));
      g.add(mesh(box(0.28, 0.2, 0.03), steel, 0.12, -0.66, 0));
      break;
    case 'mace':
      g.add(mesh(box(0.05, 0.6, 0.05), mat(P.woodDark), 0, -0.25, 0));
      g.add(mesh(sph(0.1, 8), mat(P.iron, { metal: 0.7, rough: 0.4, flat: true }), 0, -0.58, 0));
      break;
    case 'spear':
      g.add(mesh(box(0.04, 1.6, 0.04), mat(P.wood), 0, -0.3, 0));
      g.add(mesh(cone(0.05, 0.22, 6), steel, 0, -1.2, 0)).rotation.x = Math.PI;
      break;
    case 'staff': {
      g.add(mesh(box(0.05, 1.5, 0.05), mat(P.woodDark), 0, -0.2, 0));
      const gem = mesh(sph(0.07, 8), glow(tint || 0x9c7bff, 2), 0, -0.98, 0, false);
      gem.name = 'gem';
      g.add(gem);
      break;
    }
    case 'pistol':
      g.add(mesh(box(0.05, 0.08, 0.26), mat(0x2b2d31, { metal: 0.7, rough: 0.4 }), 0, -0.06, 0.08));
      g.add(mesh(box(0.045, 0.14, 0.06), mat(0x3a2a1c), 0, -0.02, -0.02));
      break;
    case 'torch': {
      g.add(mesh(box(0.05, 0.5, 0.05), mat(P.woodDark), 0, -0.05, 0));
      const f = mesh(cone(0.08, 0.22, 6), glow(0xff8a2a, 3), 0, -0.38, 0, false);
      f.rotation.x = Math.PI;
      f.name = 'flame';
      g.add(f);
      break;
    }
    case 'shield':
      g.add(mesh(cyl(0.32, 0.32, 0.05, 12), mat(P.wood), 0, 0, 0)).rotation.z = Math.PI / 2;
      g.add(mesh(cyl(0.08, 0.08, 0.07, 8), mat(P.iron, { metal: 0.7 }), 0.02, 0, 0)).rotation.z = Math.PI / 2;
      break;
    default:
      break;
  }
  return g;
}

// ------------------------------------------------------------ humanoid rig
// Returns { root, parts } where parts has pivots for animation and sockets.
export function humanoid(opts) {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  const skin = mat(opts.skin, { unique: true });
  const cloth = mat(opts.cloth ?? opts.skin, { unique: true, metal: opts.metal ? 0.6 : 0, rough: opts.metal ? 0.45 : 0.85 });
  const bone = opts.skeletal;
  const limbW = bone ? 0.08 : 0.15;
  const mats = [skin, cloth];

  const hipY = 0.74;
  const mkLeg = (side) => {
    const pivot = new THREE.Group();
    pivot.position.set(side * 0.12, hipY, 0);
    const leg = mesh(box(limbW, 0.72, limbW + 0.02), opts.legsMat || cloth, 0, -0.36, 0);
    pivot.add(leg);
    const foot = mesh(box(limbW + 0.02, 0.1, 0.26), opts.feetMat || skin, 0, -0.69, 0.05);
    pivot.add(foot);
    body.add(pivot);
    return pivot;
  };
  const legL = mkLeg(-1);
  const legR = mkLeg(1);

  const torso = new THREE.Group();
  torso.position.y = hipY;
  body.add(torso);
  const chest = mesh(box(bone ? 0.3 : 0.46, 0.62, bone ? 0.16 : 0.27), cloth, 0, 0.31, 0);
  torso.add(chest);
  if (bone) {
    for (let i = 0; i < 4; i++) torso.add(mesh(box(0.36, 0.035, 0.2), skin, 0, 0.18 + i * 0.1, 0));
  }
  if (opts.hunch) torso.rotation.x = opts.hunch;

  const head = new THREE.Group();
  head.position.y = 0.72;
  torso.add(head);
  const skull = mesh(box(0.27, 0.3, 0.28), skin, 0, 0.12, 0);
  head.add(skull);
  const eyeMat = glow(opts.eye || 0xffffff, 3);
  head.add(mesh(box(0.05, 0.035, 0.02), eyeMat, -0.06, 0.15, 0.145, false));
  head.add(mesh(box(0.05, 0.035, 0.02), eyeMat, 0.06, 0.15, 0.145, false));
  if (opts.ears) {
    head.add(mesh(cone(0.05, 0.2, 4), skin, -0.17, 0.16, 0)).rotation.z = Math.PI / 2;
    head.add(mesh(cone(0.05, 0.2, 4), skin, 0.17, 0.16, 0)).rotation.z = -Math.PI / 2;
  }

  const mkArm = (side) => {
    const pivot = new THREE.Group();
    pivot.position.set(side * (bone ? 0.22 : 0.3), 0.58, 0);
    torso.add(pivot);
    const arm = mesh(box(limbW * (opts.bigArms ? 1.7 : 1), 0.6, limbW * (opts.bigArms ? 1.6 : 1)), opts.armsMat || cloth, 0, -0.28, 0);
    pivot.add(arm);
    const hand = mesh(box(0.11 * (opts.bigArms ? 1.6 : 1), 0.12, 0.11), opts.handsMat || skin, 0, -0.62, 0);
    pivot.add(hand);
    const socket = new THREE.Group();
    socket.position.set(0, -0.64, 0.04);
    socket.rotation.x = Math.PI / 2;
    pivot.add(socket);
    return { pivot, socket };
  };
  const armL = mkArm(-1);
  const armR = mkArm(1);

  body.scale.setScalar(opts.scale || 1);
  root.userData.parts = {
    body, torso, head, legL, legR, armL: armL.pivot, armR: armR.pivot, handR: armR.socket, handL: armL.socket,
    chest, mats,
  };
  return root;
}

// Equipment visuals on the humanoid rig.
export function dressHumanoid(root, equip, itemDefs) {
  const parts = root.userData.parts;
  const old = root.userData.gear || [];
  for (const g of old) g.parent?.remove(g);
  const gear = [];
  const add = (parent, obj) => {
    parent.add(obj);
    gear.push(obj);
  };
  const def = (slot) => (equip[slot] ? itemDefs[equip[slot].id] : null);
  const outer = def('torso_outer');
  if (outer) {
    const m = mat(outer.color || 0x6b5a45, { metal: outer.model === 'mail' ? 0.65 : 0, rough: outer.model === 'mail' ? 0.4 : 0.9, flat: outer.model === 'mail' });
    add(parts.torso, mesh(box(0.52, 0.56, 0.32), m, 0, 0.32, 0));
    if (outer.model === 'robe') add(parts.torso, mesh(cyl(0.26, 0.36, 0.75, 8), m, 0, -0.3, 0));
    add(parts.armL, mesh(box(0.19, 0.36, 0.19), m, 0, -0.14, 0));
    add(parts.armR, mesh(box(0.19, 0.36, 0.19), m, 0, -0.14, 0));
  }
  const inner = def('torso_inner');
  if (inner) {
    add(parts.torso, mesh(box(0.5, 0.42, 0.33), mat(inner.color || 0x3f4a36), 0, 0.36, 0.01));
    add(parts.torso, mesh(box(0.14, 0.1, 0.05), mat(0x2b3325), -0.12, 0.44, 0.18));
    add(parts.torso, mesh(box(0.14, 0.1, 0.05), mat(0x2b3325), 0.12, 0.44, 0.18));
  }
  const head = def('head');
  if (head) {
    if (head.model === 'helmet') {
      const m = mat(head.color, { metal: 0.7, rough: 0.35 });
      add(parts.head, mesh(cyl(0.17, 0.18, 0.2, 10), m, 0, 0.23, 0));
      add(parts.head, mesh(box(0.04, 0.16, 0.04), m, 0, 0.12, 0.16));
    } else {
      add(parts.head, mesh(cone(0.22, 0.42, 8), mat(head.color), 0, 0.3, -0.03));
    }
  }
  const face = def('face');
  if (face) {
    add(parts.head, mesh(box(0.24, 0.18, 0.06), mat(face.color), 0, 0.08, 0.15));
    add(parts.head, mesh(cyl(0.05, 0.05, 0.07, 8), mat(0x1c1f19), -0.08, 0.02, 0.2)).rotation.x = Math.PI / 2;
    add(parts.head, mesh(cyl(0.05, 0.05, 0.07, 8), mat(0x1c1f19), 0.08, 0.02, 0.2)).rotation.x = Math.PI / 2;
  }
  const back = def('back');
  if (back) {
    add(parts.torso, mesh(box(0.4, 0.46, 0.2), mat(back.color || 0x5b4a33), 0, 0.34, -0.23));
    add(parts.torso, mesh(box(0.3, 0.12, 0.12), mat(0x3e3122), 0, 0.64, -0.22));
  }
  const belt = def('belt');
  if (belt) {
    add(parts.torso, mesh(box(0.1, 0.14, 0.1), mat(P.iron, { metal: 0.5 }), -0.27, 0.02, 0.1));
    const flame = mesh(box(0.06, 0.08, 0.06), glow(0xffc27a, 2.5), -0.27, 0.02, 0.1, false);
    flame.name = 'lanternFlame';
    add(parts.torso, flame);
  }
  const legs = def('legs');
  if (legs) {
    add(parts.legL, mesh(box(0.19, 0.5, 0.2), mat(legs.color), 0, -0.26, 0));
    add(parts.legR, mesh(box(0.19, 0.5, 0.2), mat(legs.color), 0, -0.26, 0));
  }
  const feet = def('feet');
  if (feet) {
    add(parts.legL, mesh(box(0.19, 0.22, 0.3), mat(feet.color), 0, -0.63, 0.05));
    add(parts.legR, mesh(box(0.19, 0.22, 0.3), mat(feet.color), 0, -0.63, 0.05));
  }
  const hands = def('hands');
  if (hands) {
    add(parts.armL, mesh(box(0.14, 0.15, 0.14), mat(hands.color), 0, -0.6, 0));
    add(parts.armR, mesh(box(0.14, 0.15, 0.14), mat(hands.color), 0, -0.6, 0));
  }
  const main = def('main');
  if (main) add(parts.handR, weaponModel(main.model));
  const off = def('off');
  if (off) {
    const w = weaponModel(off.model);
    if (off.model === 'shield') {
      w.rotation.set(-Math.PI / 2, 0, 0);
      w.position.set(-0.08, 0, -0.1);
    }
    add(parts.handL, w);
  }
  root.userData.gear = gear;
}

export function quadruped(opts) {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  const m = mat(opts.color, { unique: true });
  const torso = mesh(sph(0.3, 10), m, 0, 0.3, 0);
  torso.scale.set(0.8, 0.7, 1.4);
  body.add(torso);
  const head = new THREE.Group();
  head.position.set(0, 0.36, 0.42);
  body.add(head);
  head.add(mesh(cone(0.16, 0.34, 8), m, 0, 0, 0.12)).rotation.x = Math.PI / 2;
  const eye = glow(opts.eye, 3);
  head.add(mesh(box(0.04, 0.04, 0.04), eye, -0.08, 0.06, 0.05, false));
  head.add(mesh(box(0.04, 0.04, 0.04), eye, 0.08, 0.06, 0.05, false));
  head.add(mesh(cone(0.06, 0.12, 4), m, -0.1, 0.14, -0.02));
  head.add(mesh(cone(0.06, 0.12, 4), m, 0.1, 0.14, -0.02));
  const tail = mesh(cyl(0.02, 0.035, 0.7, 5), mat(0x8a6a5a), 0, 0.22, -0.7);
  tail.rotation.x = Math.PI / 2.4;
  body.add(tail);
  const legs = [];
  for (const [x, z] of [[-0.15, 0.25], [0.15, 0.25], [-0.15, -0.25], [0.15, -0.25]]) {
    const leg = mesh(box(0.07, 0.22, 0.07), m, x, 0.1, z);
    body.add(leg);
    legs.push(leg);
  }
  body.scale.setScalar(opts.scale || 1);
  root.userData.parts = { body, head, legs, mats: [m] };
  return root;
}

export function crawler(opts) {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  const m = mat(opts.color, { unique: true, rough: 0.55 });
  const thorax = mesh(sph(0.22, 10), m, 0, 0.35, 0.15);
  body.add(thorax);
  const abdomen = mesh(sph(0.34, 10), m, 0, 0.42, -0.3);
  abdomen.scale.set(1, 0.85, 1.2);
  body.add(abdomen);
  body.add(mesh(box(0.12, 0.02, 0.2), mat(0x8a1c1c, { emissive: 0x5a0000, ei: 0.4 }), 0, 0.72, -0.3));
  const eye = glow(opts.eye, 3);
  for (let i = 0; i < 4; i++) body.add(mesh(box(0.035, 0.035, 0.03), eye, -0.075 + i * 0.05, 0.42, 0.36, false));
  const legs = [];
  for (let i = 0; i < 4; i++) {
    for (const side of [-1, 1]) {
      const pivot = new THREE.Group();
      pivot.position.set(side * 0.16, 0.38, 0.25 - i * 0.14);
      pivot.rotation.y = side * (0.9 - i * 0.35) + (side < 0 ? Math.PI : 0);
      const seg = mesh(box(0.5, 0.04, 0.04), m, 0.25, 0.08, 0);
      seg.rotation.z = 0.5;
      pivot.add(seg);
      const seg2 = mesh(box(0.4, 0.035, 0.035), m, 0.55, -0.1, 0);
      seg2.rotation.z = -0.9;
      pivot.add(seg2);
      body.add(pivot);
      legs.push(pivot);
    }
  }
  body.scale.setScalar(opts.scale || 1);
  root.userData.parts = { body, legs, mats: [m] };
  return root;
}

// Monster model from data (family + palette + attachments).
export function monsterModel(def, itemDefs, extra = {}) {
  if (def.family === 'quadruped') return quadruped({ color: def.color, eye: def.eye, scale: def.scale });
  if (def.family === 'crawler') return crawler({ color: def.color, eye: def.eye, scale: def.scale });
  const skeletal = def.name === 'Esqueleto';
  const root = humanoid({
    skin: def.color, cloth: def.robe || (def.armored ? def.color : shade(def.color, 0.75)), eye: def.eye,
    scale: def.scale, hunch: def.hunch || (def.family === 'brute' ? 0.3 : 0), ears: def.name === 'Goblin',
    metal: def.armored, skeletal, bigArms: def.family === 'brute',
  });
  const parts = root.userData.parts;
  if (def.robe) parts.torso.add(mesh(cyl(0.24, 0.38, 0.8, 8), mat(def.robe), 0, -0.3, 0));
  if (def.armored) {
    const m = mat(shade(def.color, 1.2), { metal: 0.7, rough: 0.4 });
    parts.head.add(mesh(cyl(0.18, 0.19, 0.3, 10), m, 0, 0.16, 0));
    parts.torso.add(mesh(box(0.62, 0.14, 0.34), m, 0, 0.62, 0));
  }
  if (def.crown) {
    const g = mat(0xc9a13a, { metal: 0.9, rough: 0.3, emissive: 0x4a3000, ei: 0.3 });
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2;
      parts.head.add(mesh(cone(0.04, 0.14, 4), g, Math.cos(a) * 0.15, 0.38, Math.sin(a) * 0.15));
    }
    parts.head.add(mesh(cyl(0.19, 0.19, 0.06, 10), g, 0, 0.32, 0));
  }
  if (extra.equip) dressHumanoid(root, extra.equip, itemDefs);
  else if (def.weapon) parts.handR.add(weaponModel(def.weapon));
  if (def.hollowed) {
    for (const m of parts.mats) {
      m.transparent = true;
      m.opacity = 0.8;
      m.emissive = new THREE.Color(0x1f5a50);
      m.emissiveIntensity = 0.4;
    }
  }
  return root;
}

export function shade(hex, k) {
  const c = new THREE.Color(hex);
  c.multiplyScalar(k);
  return c.getHex();
}

// ------------------------------------------------------------- props
export function propModel(id, wallDir) {
  const g = new THREE.Group();
  const wood = mat(P.wood);
  const woodDark = mat(P.woodDark);
  const stone = mat(P.stone, { flat: true });
  switch (id) {
    case 'shelf':
    case 'bookshelf': {
      g.add(mesh(box(0.9, 1.9, 0.08), woodDark, 0, 0.95, -0.17));
      g.add(mesh(box(0.06, 1.9, 0.42), wood, -0.42, 0.95, 0));
      g.add(mesh(box(0.06, 1.9, 0.42), wood, 0.42, 0.95, 0));
      for (let i = 0; i < 4; i++) g.add(mesh(box(0.84, 0.05, 0.4), wood, 0, 0.1 + i * 0.55, 0, false));
      const colors = id === 'bookshelf' ? [0x6b2323, 0x2c4a2a, 0x2a3558, 0x6b5a24, 0x4a2a55] : [0x6b5a45, 0x3f3a33, 0x7a6a50];
      for (let i = 0; i < 3; i++) {
        let x = -0.36;
        while (x < 0.34) {
          const w = id === 'bookshelf' ? 0.06 + ((x * 97) % 0.04 + 0.04) * 0.5 : 0.18;
          const h = id === 'bookshelf' ? 0.34 + ((x * 31 + i) % 0.1) : 0.2;
          g.add(mesh(box(w, h, 0.26), mat(colors[Math.abs(Math.floor(x * 50 + i)) % colors.length]), x + w / 2, 0.13 + i * 0.55 + h / 2, 0, false));
          x += w + (id === 'bookshelf' ? 0.01 : 0.12);
        }
      }
      orient(g, wallDir);
      break;
    }
    case 'table':
      g.add(mesh(box(0.92, 0.08, 0.8), wood, 0, 0.76, 0));
      for (const [x, z] of [[-0.38, -0.32], [0.38, -0.32], [-0.38, 0.32], [0.38, 0.32]]) g.add(mesh(box(0.07, 0.72, 0.07), woodDark, x, 0.36, z));
      g.add(mesh(box(0.12, 0.1, 0.12), mat(0x9a8a6a), 0.15, 0.85, 0.1, false));
      break;
    case 'chair':
      g.add(mesh(box(0.44, 0.06, 0.44), wood, 0, 0.45, 0));
      g.add(mesh(box(0.44, 0.5, 0.06), wood, 0, 0.72, -0.2));
      for (const [x, z] of [[-0.18, -0.18], [0.18, -0.18], [-0.18, 0.18], [0.18, 0.18]]) g.add(mesh(box(0.05, 0.45, 0.05), woodDark, x, 0.22, z));
      g.rotation.y = Math.random() * Math.PI * 2;
      break;
    case 'crate':
      g.add(mesh(box(0.76, 0.72, 0.76), wood, 0, 0.36, 0));
      g.add(mesh(box(0.8, 0.08, 0.8), woodDark, 0, 0.7, 0));
      g.add(mesh(box(0.8, 0.08, 0.8), woodDark, 0, 0.04, 0));
      g.rotation.y = (Math.random() - 0.5) * 0.4;
      break;
    case 'barrel_oil':
      g.add(mesh(cyl(0.33, 0.3, 0.95, 12), wood, 0, 0.47, 0));
      g.add(mesh(cyl(0.345, 0.345, 0.06, 12), mat(P.iron, { metal: 0.6 }), 0, 0.2, 0));
      g.add(mesh(cyl(0.345, 0.345, 0.06, 12), mat(P.iron, { metal: 0.6 }), 0, 0.75, 0));
      g.add(mesh(cyl(0.3, 0.3, 0.02, 12), mat(P.oil, { rough: 0.15 }), 0, 0.95, 0, false));
      break;
    case 'bed':
      g.add(mesh(box(0.86, 0.3, 0.96), woodDark, 0, 0.15, 0));
      g.add(mesh(box(0.8, 0.1, 0.9), mat(0x5a4f45), 0, 0.34, 0));
      g.add(mesh(box(0.8, 0.06, 0.55), mat(0x5c2b2b), 0, 0.41, 0.15));
      g.add(mesh(box(0.4, 0.1, 0.22), mat(0x8a8070), 0, 0.42, -0.3));
      orient(g, wallDir);
      break;
    case 'altar':
      g.add(mesh(box(0.9, 0.9, 0.62), stone, 0, 0.45, 0));
      g.add(mesh(box(0.3, 0.92, 0.64), mat(0x6b1f1f), 0, 0.46, 0));
      for (const x of [-0.3, 0.3]) {
        g.add(mesh(cyl(0.035, 0.035, 0.18, 6), mat(0xe8dcc0), x, 0.99, 0.1, false));
        const f = mesh(cone(0.03, 0.07, 5), glow(0xffc070, 3), x, 1.12, 0.1, false);
        f.name = 'flame';
        g.add(f);
      }
      break;
    case 'sarcophagus':
      g.add(mesh(box(0.78, 0.75, 0.96), stone, 0, 0.37, 0));
      g.add(mesh(box(0.86, 0.1, 1.0), mat(P.stoneDark, { flat: true }), 0, 0.8, 0));
      g.add(mesh(box(0.3, 0.06, 0.5), mat(0x77736b), 0, 0.88, 0));
      break;
    case 'weapon_rack':
      g.add(mesh(box(0.9, 0.08, 0.3), woodDark, 0, 0.3, 0));
      g.add(mesh(box(0.9, 0.08, 0.3), woodDark, 0, 1.2, 0));
      for (const [x, w] of [[-0.28, 'spear'], [0, 'sword'], [0.28, 'axe']]) {
        const m = weaponModel(w);
        m.position.set(x, 1.5, 0.05);
        g.add(m);
      }
      orient(g, wallDir);
      break;
    case 'pillar':
      g.add(mesh(box(0.8, 0.2, 0.8), stone, 0, 0.1, 0));
      g.add(mesh(cyl(0.3, 0.33, 2.4, 10), stone, 0, 1.3, 0));
      g.add(mesh(box(0.74, 0.18, 0.74), stone, 0, 2.5, 0));
      break;
    case 'wall_torch': {
      const [dx, dy] = wallDir || [0, -1];
      const t = new THREE.Group();
      t.position.set(dx * 0.42, 0, dy * 0.42);
      t.add(mesh(box(0.08, 0.35, 0.08), woodDark, 0, 1.45, 0));
      t.add(mesh(box(0.14, 0.05, 0.14), mat(P.iron, { metal: 0.6 }), 0, 1.3, 0));
      const f = mesh(cone(0.1, 0.3, 6), glow(0xff8a2a, 3), 0, 1.75, 0, false);
      f.name = 'flame';
      t.add(f);
      g.add(t);
      break;
    }
    case 'brazier': {
      for (let i = 0; i < 3; i++) {
        const a = (i / 3) * Math.PI * 2;
        const leg = mesh(box(0.05, 0.7, 0.05), mat(P.iron, { metal: 0.6 }), Math.cos(a) * 0.2, 0.35, Math.sin(a) * 0.2);
        leg.rotation.z = Math.cos(a) * 0.2;
        g.add(leg);
      }
      g.add(mesh(cyl(0.34, 0.2, 0.25, 10), mat(0x3a3a3c, { metal: 0.6 }), 0, 0.78, 0));
      g.add(mesh(cyl(0.3, 0.3, 0.04, 10), glow(0xff5a10, 1.8), 0, 0.9, 0, false));
      const f = mesh(cone(0.22, 0.5, 7), glow(0xff8a2a, 2.6), 0, 1.15, 0, false);
      f.name = 'flame';
      g.add(f);
      break;
    }
    case 'campfire': {
      for (let i = 0; i < 7; i++) {
        const a = (i / 7) * Math.PI * 2;
        g.add(mesh(box(0.14, 0.1, 0.12), stone, Math.cos(a) * 0.3, 0.05, Math.sin(a) * 0.3));
      }
      for (let i = 0; i < 3; i++) {
        const log = mesh(box(0.08, 0.08, 0.5), woodDark, 0, 0.08, 0);
        log.rotation.y = (i / 3) * Math.PI;
        g.add(log);
      }
      const f = mesh(cone(0.18, 0.45, 7), glow(0xff8a2a, 2.8), 0, 0.3, 0, false);
      f.name = 'flame';
      g.add(f);
      break;
    }
    case 'candle': {
      g.add(mesh(cyl(0.04, 0.045, 0.2, 6), mat(0xe8dcc0), 0, 0.1, 0));
      const f = mesh(cone(0.03, 0.08, 5), glow(0xffc070, 3), 0, 0.25, 0, false);
      f.name = 'flame';
      g.add(f);
      break;
    }
    default:
      g.add(mesh(box(0.5, 0.5, 0.5), wood, 0, 0.25, 0));
  }
  return g;
}

function orient(g, wallDir) {
  if (!wallDir) return;
  const [dx, dy] = wallDir;
  // Back of the model (-z) faces the wall.
  g.rotation.y = Math.atan2(-dx, -dy);
  g.position.x += dx * 0.28;
  g.position.z += dy * 0.28;
}

export function itemModel(kind, color) {
  const g = new THREE.Group();
  const c = color || 0x9a8a6a;
  switch (kind) {
    case 'weapon':
      g.add(mesh(box(0.08, 0.04, 0.55), mat(0xaab0b8, { metal: 0.7, rough: 0.35 }), 0, 0.03, 0, false));
      g.rotation.y = Math.random() * Math.PI;
      break;
    case 'armour':
      g.add(mesh(box(0.4, 0.08, 0.35), mat(c), 0, 0.04, 0, false));
      break;
    case 'potion':
      g.add(mesh(cyl(0.06, 0.08, 0.18, 8), mat(c, { emissive: c, ei: 0.6, rough: 0.2 }), 0, 0.09, 0, false));
      break;
    case 'book':
      g.add(mesh(box(0.25, 0.06, 0.32), mat(0x4a2a55, { emissive: 0x2a0a40, ei: 0.5 }), 0, 0.03, 0, false));
      break;
    case 'relic':
      g.add(mesh(sph(0.09, 8), mat(0xc9a13a, { metal: 0.9, rough: 0.25, emissive: 0x3a2800, ei: 0.5 }), 0, 0.09, 0, false));
      break;
    default:
      g.add(mesh(box(0.22, 0.12, 0.18), mat(c), 0, 0.06, 0, false));
  }
  return g;
}
