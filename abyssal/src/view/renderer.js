// Presentation: reads the simulation, never writes to it.
// Orthographic isometric camera, instanced modular tiles, room cutaway,
// pooled point lights, lantern shadows, particles and telegraphs.
import * as THREE from '../../vendor/three.module.min.js';
import { T, S } from '../sim/level.js';
import { wallDirection } from '../sim/dungeon.js';
import { ITEMS } from '../content/items.js';
import { MONSTERS } from '../content/monsters.js';
import { PROPS } from '../content/world.js';
import { humanoid, dressHumanoid, monsterModel, propModel, itemModel, mat, glow, mesh, shade } from './models.js';

const WALL_H = 2.3;
const CUT_H = 0.28;
const LIGHT_POOL = 8;

function hash(x, y) {
  let h = (x * 374761393 + y * 668265263) >>> 0;
  h = ((h ^ (h >>> 13)) * 1274126177) >>> 0;
  return (h & 0xffff) / 0xffff;
}

export class View {
  constructor(canvas) {
    this.canvas = canvas;
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.15;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap;
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x000000);
    this.zoom = 15;
    this.camera = new THREE.OrthographicCamera(-10, 10, 10, -10, 0.1, 200);
    this.camOffset = new THREE.Vector3(1, 1.08, 1).normalize().multiplyScalar(60);
    this.camTarget = new THREE.Vector3();
    this.hemi = new THREE.HemisphereLight(0x5a6a90, 0x120e0c, 0.55);
    this.scene.add(this.hemi);
    this.moon = new THREE.DirectionalLight(0x6a7aa8, 0.25);
    this.moon.position.set(-20, 40, 10);
    this.scene.add(this.moon);
    this.lantern = new THREE.PointLight(0xffc27a, 0, 12, 1.4);
    this.lantern.castShadow = true;
    this.shadowsOn = true;
    this.lantern.shadow.mapSize.set(512, 512);
    this.lantern.shadow.bias = -0.004;
    this.lantern.shadow.radius = 3;
    this.lantern.shadow.camera.near = 0.2;
    this.lantern.shadow.camera.far = 14;
    this.scene.add(this.lantern);
    // Soft key light from the camera side so the player never reads as a silhouette.
    this.keyLight = new THREE.PointLight(0xd8c8b0, 1.6, 4.5, 1.2);
    this.scene.add(this.keyLight);
    this.pool = [];
    for (let i = 0; i < LIGHT_POOL; i++) {
      const l = new THREE.PointLight(0xffffff, 0, 8, 1.5);
      this.scene.add(l);
      this.pool.push(l);
    }
    this.levelGroup = new THREE.Group();
    this.propGroup = new THREE.Group();
    this.dynGroup = new THREE.Group();
    this.scene.add(this.levelGroup, this.propGroup, this.dynGroup);
    this.actorViews = new Map();
    this.fx = [];
    this.projViews = new Map();
    this.builtLevel = null;
    this.hover = null;
    this.targeting = null;
    this.raycaster = new THREE.Raycaster();
    this.groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
    this.initParticles();
    this.initMarkers();
    this.resize();
  }

  resize() {
    const w = this.canvas.clientWidth || window.innerWidth;
    const h = this.canvas.clientHeight || window.innerHeight;
    this.renderer.setSize(w, h, false);
    this.aspect = w / h;
    this.applyZoom();
  }

  applyZoom() {
    const h = this.zoom;
    this.camera.left = (-h * this.aspect) / 2;
    this.camera.right = (h * this.aspect) / 2;
    this.camera.top = h / 2;
    this.camera.bottom = -h / 2;
    this.camera.updateProjectionMatrix();
  }

  setShadows(on) {
    this.lantern.castShadow = on;
    this.shadowsOn = on;
  }

  zoomBy(delta) {
    this.zoom = Math.max(8, Math.min(30, this.zoom * (delta > 0 ? 1.1 : 0.9)));
    this.applyZoom();
  }

  // ------------------------------------------------------ level building
  buildLevel(world) {
    const level = world.level;
    this.world = world;
    this.level = level;
    for (const g of [this.levelGroup, this.propGroup]) {
      while (g.children.length) g.remove(g.children[0]);
    }
    for (const v of this.actorViews.values()) this.dynGroup.remove(v.root);
    this.actorViews.clear();
    for (const v of this.projViews.values()) this.dynGroup.remove(v);
    this.projViews.clear();
    const floors = [];
    const walls = [];
    const waters = [];
    for (let y = 0; y < level.h; y++) {
      for (let x = 0; x < level.w; x++) {
        const t = level.tile(x, y);
        if (t === T.WALL) walls.push([x, y]);
        else if (t === T.WATER) waters.push([x, y]);
        else if (t !== T.ROCK) floors.push([x, y, t]);
      }
    }
    const floorMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.93, metalness: 0 });
    this.floorMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(0.965, 0.2, 0.965), floorMat, floors.length + waters.length);
    this.floorMesh.receiveShadow = true;
    this.floorCells = [];
    const m4 = new THREE.Matrix4();
    const col = new THREE.Color();
    floors.concat(waters.map(([x, y]) => [x, y, T.WATER])).forEach(([x, y, t], i) => {
      m4.makeTranslation(x, t === T.WATER ? -0.28 : -0.1, y);
      this.floorMesh.setMatrixAt(i, m4);
      const room = level.roomId[level.idx(x, y)] >= 0;
      const v = hash(x, y);
      const base = room ? new THREE.Color(0x57524b) : new THREE.Color(0x3f3c38);
      base.offsetHSL(0, 0, (v - 0.5) * 0.06);
      if (t === T.WATER) base.set(0x1c2322);
      this.floorCells.push({ i: level.idx(x, y), base });
      this.floorMesh.setColorAt(i, col.setRGB(0, 0, 0));
    });
    this.levelGroup.add(this.floorMesh);

    const waterMat = new THREE.MeshStandardMaterial({ color: 0x2a4a58, roughness: 0.08, metalness: 0.2, transparent: true, opacity: 0.78 });
    this.waterMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 0.06, 1), waterMat, Math.max(1, waters.length));
    this.waterMesh.count = waters.length;
    this.waterCells = [];
    waters.forEach(([x, y], i) => {
      m4.makeTranslation(x, -0.12, y);
      this.waterMesh.setMatrixAt(i, m4);
      this.waterCells.push(level.idx(x, y));
      this.waterMesh.setColorAt(i, col.setRGB(0, 0, 0));
    });
    this.waterMesh.receiveShadow = true;
    this.levelGroup.add(this.waterMesh);

    const side = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.9 });
    const top = new THREE.MeshStandardMaterial({ color: 0x1b1a1e, roughness: 1 });
    const wallGeo = new THREE.BoxGeometry(1, 1, 1);
    wallGeo.translate(0, 0.5, 0);
    this.wallMesh = new THREE.InstancedMesh(wallGeo, [side, side, top, side, side, side], walls.length);
    this.wallMesh.castShadow = true;
    this.wallMesh.receiveShadow = true;
    this.wallCells = walls.map(([x, y]) => {
      const v = hash(x * 3, y * 7);
      const base = new THREE.Color(0x6a655d).offsetHSL(0, -0.02, (v - 0.5) * 0.08);
      return { x, y, i: level.idx(x, y), base, cut: false };
    });
    this.wallMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.levelGroup.add(this.wallMesh);
    this.lastCutKey = null;

    // Doors and stairs (dynamic per frame).
    this.doorViews = [];
    for (const [i, d] of level.doors) {
      const x = i % level.w;
      const y = (i / level.w) | 0;
      const horiz = level.tile(x - 1, y) === T.WALL || level.tile(x + 1, y) === T.WALL;
      const g = new THREE.Group();
      g.position.set(x, 0, y);
      const frameMat = mat(0x3b2819);
      const posts = new THREE.Group();
      const pw = 0.14;
      posts.add(mesh(new THREE.BoxGeometry(pw, WALL_H, pw), frameMat, -0.5 + pw / 2, WALL_H / 2, 0));
      posts.add(mesh(new THREE.BoxGeometry(pw, WALL_H, pw), frameMat, 0.5 - pw / 2, WALL_H / 2, 0));
      posts.add(mesh(new THREE.BoxGeometry(1, 0.2, 0.2), frameMat, 0, WALL_H - 0.1, 0));
      const hinge = new THREE.Group();
      hinge.position.set(-0.43, 0, 0);
      const panel = mesh(new THREE.BoxGeometry(0.86, 2.0, 0.09), mat(d.anomaly ? 0x4a3040 : 0x5a3c22), 0.43, 1.0, 0);
      hinge.add(panel);
      const planks = new THREE.Group();
      hinge.add(planks);
      g.add(posts, hinge);
      if (!horiz) g.rotation.y = Math.PI / 2;
      this.levelGroup.add(g);
      this.doorViews.push({ d, g, hinge, posts, planks, x, y, i, shownBarricade: -1, angle: d.open ? -1.45 : 0 });
    }
    this.stairViews = [];
    for (const s of [level.up, level.down]) {
      if (!s) continue;
      const g = new THREE.Group();
      g.position.set(s.x, 0, s.y);
      const down = s === level.down;
      const stone = mat(0x77726a, { flat: true });
      if (down) {
        g.add(mesh(new THREE.BoxGeometry(0.9, 0.02, 0.9), glow(0x000000, 0), 0, 0.005, 0, false));
        for (let k = 0; k < 4; k++) g.add(mesh(new THREE.BoxGeometry(0.9, 0.12, 0.22), stone, 0, -0.1 - k * 0.2, -0.33 + k * 0.22));
        const hole = mesh(new THREE.BoxGeometry(0.92, 0.02, 0.92), new THREE.MeshBasicMaterial({ color: 0x000000 }), 0, -0.9, 0, false);
        g.add(hole);
        if (level.gateSealed) {
          const bars = new THREE.Group();
          for (let k = -3; k <= 3; k++) bars.add(mesh(new THREE.BoxGeometry(0.05, 0.05, 0.95), mat(0x4a4a50, { metal: 0.7 }), k * 0.13, 0.08, 0));
          bars.add(mesh(new THREE.BoxGeometry(0.95, 0.06, 0.06), glow(0xff3b1f, 1.6), 0, 0.1, 0, false));
          bars.name = 'seal';
          g.add(bars);
        }
      } else {
        for (let k = 0; k < 4; k++) g.add(mesh(new THREE.BoxGeometry(0.9, 0.2 + k * 0.25, 0.22), stone, 0, (0.2 + k * 0.25) / 2, 0.33 - k * 0.22));
      }
      this.levelGroup.add(g);
      this.stairViews.push({ g, x: s.x, y: s.y, down });
    }
    this.buildProps();
    this.buildSurfaces();
    this.builtLevel = level;
    this.builtVersion = level.version;
    this.builtTiles = level.tiles.slice();
    this.visKey = -1;
  }

  buildProps() {
    const level = this.level;
    while (this.propGroup.children.length) this.propGroup.remove(this.propGroup.children[0]);
    this.propViews = [];
    for (const p of level.props.values()) {
      const def = PROPS[p.id];
      const wd = def.onWall || ['shelf', 'bookshelf', 'bed', 'weapon_rack'].includes(p.id) ? p.wallDir || wallDirection(level, p.x, p.y) : null;
      const g = propModel(p.id, wd);
      g.position.x += p.x;
      g.position.z += p.y;
      if (!def.opaque && def.height < 1.7) g.traverse((o) => { o.castShadow = def.height > 0.7; });
      this.propGroup.add(g);
      const flames = [];
      g.traverse((o) => {
        if (o.name === 'flame') flames.push(o);
      });
      this.propViews.push({ p, g, flames, i: level.idx(p.x, p.y) });
    }
    // Items and corpses.
    this.itemViews = [];
    for (const [i, list] of level.items) {
      if (!list.length) continue;
      const it = list[list.length - 1];
      const def = ITEMS[it.id];
      const g = itemModel(def.kind, def.color || (def.kind === 'potion' ? (it.id === 'mana_potion' ? 0x3a5aff : 0xc02a2a) : null));
      const x = i % level.w;
      const y = (i / level.w) | 0;
      g.position.set(x + (hash(x, y) - 0.5) * 0.3, 0, y + (hash(y, x) - 0.5) * 0.3);
      if (list.length > 1) {
        const extra = itemModel('misc', 0x6a5a45);
        extra.position.set(0.18, 0, 0.1);
        g.add(extra);
      }
      this.propGroup.add(g);
      this.itemViews.push({ g, i });
    }
    for (const [i, list] of level.corpses) {
      for (const c of list) {
        const x = i % level.w;
        const y = (i / level.w) | 0;
        const def = c.monsterId ? MONSTERS[c.monsterId] : null;
        const color = c.charred ? 0x151210 : shade(def?.color || 0x6a6055, 0.7);
        const g = new THREE.Group();
        const s = (def?.scale || 1) * (def?.family === 'quadruped' ? 0.6 : 1);
        g.add(mesh(new THREE.BoxGeometry(0.42 * s, 0.14, 0.95 * s), mat(color), 0, 0.07, 0, false));
        g.add(mesh(new THREE.BoxGeometry(0.26 * s, 0.16, 0.26 * s), mat(color), 0, 0.08, -0.55 * s, false));
        g.position.set(x, 0, y);
        g.rotation.y = hash(x + 5, y) * Math.PI * 2;
        this.propGroup.add(g);
        this.itemViews.push({ g, i });
      }
    }
    this.builtVersion = level.version;
    this.builtItemsKey = this.itemsKey();
  }

  itemsKey() {
    const level = this.level;
    let k = 0;
    for (const [i, list] of level.items) k = (k * 31 + i * 7 + list.length * 13 + (list[list.length - 1]?.uid || 0)) | 0;
    for (const [i, list] of level.corpses) for (const c of list) k = (k * 17 + i + (c.charred ? 3 : 1)) | 0;
    return k;
  }

  buildSurfaces() {
    const level = this.level;
    if (this.surfaceMesh) this.levelGroup.remove(this.surfaceMesh);
    const cells = [];
    for (let i = 0; i < level.surface.length; i++) if (level.surface[i]) cells.push(i);
    const geo = new THREE.PlaneGeometry(0.98, 0.98);
    geo.rotateX(-Math.PI / 2);
    const m = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.2, metalness: 0.1, transparent: true, opacity: 0.85, depthWrite: false });
    this.surfaceMesh = new THREE.InstancedMesh(geo, m, Math.max(1, cells.length));
    this.surfaceMesh.count = cells.length;
    this.surfaceMesh.receiveShadow = true;
    const m4 = new THREE.Matrix4();
    const col = new THREE.Color();
    this.surfaceCells = cells;
    cells.forEach((i, k) => {
      const x = i % level.w;
      const y = (i / level.w) | 0;
      const s = level.surface[i];
      const sc = s === S.BLOOD ? 0.45 + hash(x, y) * 0.4 : 1;
      const yy = level.tile(x, y) === T.WATER ? -0.08 : 0.012;
      m4.compose(new THREE.Vector3(x + (s === S.BLOOD ? (hash(y, x) - 0.5) * 0.3 : 0), yy + k * 0.00001, y), new THREE.Quaternion().setFromEuler(new THREE.Euler(0, hash(x, y) * 6, 0)), new THREE.Vector3(sc, 1, sc));
      this.surfaceMesh.setMatrixAt(k, m4);
      const c = s === S.OIL ? 0x120d07 : s === S.BLOOD ? 0x4a0808 : s === S.ICE ? 0xbfe8ff : 0xd8d8d0;
      this.surfaceMesh.setColorAt(k, col.set(c));
    });
    if (this.surfaceMesh.instanceColor) this.surfaceMesh.instanceColor.needsUpdate = true;
    this.levelGroup.add(this.surfaceMesh);
    this.builtSurface = level.surfaceVersion;
  }

  // ------------------------------------------------------- per-frame update
  update(world, dt, ui) {
    if (world.level !== this.builtLevel) this.buildLevel(world);
    const level = world.level;
    if (level.version !== this.builtVersion || this.itemsKey() !== this.builtItemsKey) {
      if (this.tilesChanged(level)) this.buildLevel(world);
      else this.buildProps();
    }
    if (level.surfaceVersion !== this.builtSurface) this.buildSurfaces();
    const now = world.now;
    const p = world.player;
    const pp = this.actorPos(p, now);
    this.camTarget.lerp(new THREE.Vector3(pp.x, 0, pp.z), Math.min(1, dt * 8));
    this.camera.position.copy(this.camTarget).add(this.camOffset);
    this.camera.lookAt(this.camTarget);
    this.updateVisibility(world);
    this.updateCutaway(world);
    this.updateDoors(world, dt);
    this.updateActors(world, dt, now);
    this.updateLights(world, now);
    this.updateFire(world, now);
    this.updateProjectiles(world);
    this.consumeEvents(world, ui);
    this.updateFx(dt);
    this.updateParticles(dt);
    this.updateMarkers(world, now);
    this.renderer.render(this.scene, this.camera);
  }

  tilesChanged(level) {
    const a = this.builtTiles;
    if (!a || a.length !== level.tiles.length) return true;
    for (let i = 0; i < a.length; i++) if (a[i] !== level.tiles[i]) return true;
    return false;
  }

  updateVisibility(world) {
    const level = world.level;
    const key = world.tickCount - (world.tickCount % 5);
    if (key === this.visKey) return;
    this.visKey = key;
    const col = new THREE.Color();
    const memory = new THREE.Color(0x3a4458);
    const shadeCell = (i, base) => {
      if (level.visible[i]) return col.copy(base);
      if (level.explored[i]) return col.copy(base).multiplyScalar(0.3).lerp(memory, 0.25);
      return col.setRGB(0, 0, 0);
    };
    this.floorCells.forEach((c, k) => this.floorMesh.setColorAt(k, shadeCell(c.i, c.base)));
    this.floorMesh.instanceColor.needsUpdate = true;
    const wbase = new THREE.Color(0x2a4a58);
    this.waterCells.forEach((i, k) => this.waterMesh.setColorAt(k, shadeCell(i, level.surface[i] === S.ICE ? new THREE.Color(0xbfe8ff) : wbase)));
    if (this.waterMesh.instanceColor) this.waterMesh.instanceColor.needsUpdate = true;
    // A wall is known when it borders any explored cell.
    this.wallCells.forEach((c, k) => {
      let seen = level.explored[c.i];
      let vis = level.visible[c.i];
      if (!seen) {
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const j = level.idx(c.x + dx, c.y + dy);
          if (level.inBounds(c.x + dx, c.y + dy) && level.explored[j] && level.tile(c.x + dx, c.y + dy) !== T.WALL) seen = 1;
        }
      }
      if (!seen) col.setRGB(0, 0, 0);
      else if (vis) col.copy(c.base);
      else col.copy(c.base).multiplyScalar(0.3).lerp(memory, 0.25);
      this.wallMesh.setColorAt(k, col);
      c.seen = seen;
    });
    this.wallMesh.instanceColor.needsUpdate = true;
    for (const v of this.propViews) v.g.visible = !!level.explored[v.i];
    for (const v of this.itemViews) v.g.visible = !!level.visible[v.i];
    for (const d of this.doorViews) d.g.visible = !!level.explored[d.i];
    for (const s of this.stairViews) s.g.visible = !!level.explored[level.idx(s.x, s.y)];
    if (this.surfaceMesh) this.surfaceMesh.visible = true;
    this.cutKey = null;
  }

  // Walls between the camera and the player drop to stubs (Zomboid cutaway).
  updateCutaway(world) {
    const p = world.player;
    const key = `${p.x},${p.y},${this.visKey}`;
    if (key === this.lastCutKey) return;
    this.lastCutKey = key;
    const m4 = new THREE.Matrix4();
    const pos = new THREE.Vector3();
    const q = new THREE.Quaternion();
    const scl = new THREE.Vector3();
    this.wallCells.forEach((c, k) => {
      const depth = c.x + c.y - (p.x + p.y);
      const lateral = Math.abs(c.x - c.y - (p.x - p.y));
      const cut = depth > 0 && depth <= 16 && lateral <= depth * 1.2 + 5;
      c.cut = cut;
      pos.set(c.x, 0, c.y);
      scl.set(1, c.seen ? (cut ? CUT_H : WALL_H) : 0.001, 1);
      m4.compose(pos, q, scl);
      this.wallMesh.setMatrixAt(k, m4);
    });
    this.wallMesh.instanceMatrix.needsUpdate = true;
    for (const d of this.doorViews) {
      const depth = d.x + d.y - (p.x + p.y);
      const lateral = Math.abs(d.x - d.y - (p.x - p.y));
      d.cut = depth > 0 && depth <= 16 && lateral <= depth * 1.2 + 5;
      d.g.scale.y = d.cut ? 0.14 : 1;
    }
    for (const v of this.propViews) {
      const def = PROPS[v.p.id];
      const depth = v.p.x + v.p.y - (p.x + p.y);
      const lateral = Math.abs(v.p.x - v.p.y - (p.x - p.y));
      const cut = def.height > 1.5 && depth > 0 && depth <= 5 && lateral <= 4;
      v.g.scale.y = cut ? 0.25 : 1;
    }
  }

  updateDoors(world, dt) {
    for (const v of this.doorViews) {
      const target = v.d.open || v.d.broken ? -1.45 : 0;
      v.angle += (target - v.angle) * Math.min(1, dt * 10);
      v.hinge.rotation.y = v.angle;
      v.hinge.visible = !v.d.broken;
      if (v.shownBarricade !== v.d.barricade) {
        v.shownBarricade = v.d.barricade;
        while (v.planks.children.length) v.planks.remove(v.planks.children[0]);
        for (let k = 0; k < v.d.barricade; k++) {
          const pl = mesh(new THREE.BoxGeometry(1.1, 0.16, 0.06), mat(0x7a5a38), 0.43, 0.6 + k * 0.45, 0.1);
          pl.rotation.z = k % 2 ? 0.25 : -0.25;
          v.planks.add(pl);
        }
      }
    }
    for (const s of this.stairViews) {
      const seal = s.g.getObjectByName('seal');
      if (seal) seal.visible = world.level.gateSealed;
    }
  }

  // --------------------------------------------------------------- actors
  actorPos(a, now) {
    const t = a.moveT1 > a.moveT0 ? Math.min(1, Math.max(0, (now - a.moveT0) / (a.moveT1 - a.moveT0))) : 1;
    const e = t;
    const x = a.px + (a.x - a.px) * e;
    const z = a.py + (a.y - a.py) * e;
    const y = a.leap ? Math.sin(t * Math.PI) * 0.6 : 0;
    return { x, y, z, t };
  }

  ensureActorView(a) {
    let v = this.actorViews.get(a.id);
    if (v) return v;
    let root;
    if (a.isPlayer) {
      root = humanoid({ skin: a.species.skin, cloth: 0x4a4540, eye: a.speciesId === 'vampire' ? 0xff3030 : 0xf0e8d8, scale: 1 });
    } else {
      root = monsterModel(a.def, ITEMS, a.hollowed ? { equip: gearToEquip(a.hollowed.gear) } : {});
    }
    root.traverse((o) => {
      if (o.isMesh && a.isPlayer) o.castShadow = false;
    });
    this.dynGroup.add(root);
    const mats = [];
    root.traverse((o) => {
      if (o.isMesh && o.material?.isMeshStandardMaterial && !mats.includes(o.material)) mats.push(o.material);
    });
    v = { root, parts: root.userData.parts, mats, flash: 0, gearKey: '', dying: 0, yaw: 0 };
    if (a.raised) {
      for (const m of v.mats) {
        m.emissive = new THREE.Color(0x3aff7a);
        m.emissiveIntensity = 0.25;
      }
    }
    this.actorViews.set(a.id, v);
    return v;
  }

  updateActors(world, dt, now) {
    const level = world.level;
    const all = [world.player, ...level.actors];
    const seen = new Set();
    for (const a of all) {
      const v = this.ensureActorView(a);
      seen.add(a.id);
      const pos = this.actorPos(a, now);
      v.root.position.set(pos.x, pos.y, pos.z);
      const visible = a.isPlayer || (a.alive && world.isVisible(a.x, a.y)) || (!a.alive && v.dying > 0 && world.isVisible(a.x, a.y));
      v.root.visible = visible;
      if (a.isPlayer) {
        const key = Object.values(a.equip).map((it) => it?.id || '-').join(',');
        if (key !== v.gearKey) {
          v.gearKey = key;
          dressHumanoid(v.root, a.equip, ITEMS);
          v.root.traverse((o) => {
            if (o.isMesh) o.castShadow = false;
          });
        }
        const flame = v.root.getObjectByName('lanternFlame');
        if (flame) flame.visible = a.lanternOn && a.equip.belt?.fuel > 0;
      }
      // Facing (grid atan2 -> world yaw).
      const f = a.facing ?? 0;
      const yaw = Math.atan2(Math.cos(f), Math.sin(f));
      let d = yaw - v.yaw;
      while (d > Math.PI) d -= Math.PI * 2;
      while (d < -Math.PI) d += Math.PI * 2;
      v.yaw += d * Math.min(1, dt * 14);
      v.root.rotation.y = v.yaw;
      this.animate(a, v, pos, now, dt);
      if (v.flash > 0) {
        v.flash -= dt;
        for (const m of v.mats) {
          m.emissive.setRGB(0.9, 0.1, 0.05);
          m.emissiveIntensity = Math.max(0, v.flash * 5);
        }
        if (v.flash <= 0) {
          for (const m of v.mats) {
            m.emissive.set(a.raised ? 0x3aff7a : a.hollowed ? 0x1f5a50 : 0x000000);
            m.emissiveIntensity = a.raised ? 0.25 : a.hollowed ? 0.4 : 0;
          }
        }
      }
      if (!a.alive) {
        v.dying = v.dying || 0.6;
        v.dying -= dt;
        v.parts.body.rotation.x = -Math.PI / 2 * Math.min(1, (0.6 - v.dying) / 0.4);
        v.parts.body.position.y = 0.15;
        if (v.dying <= 0) {
          this.dynGroup.remove(v.root);
          this.actorViews.delete(a.id);
        }
      }
    }
    for (const [id, v] of this.actorViews) {
      if (!seen.has(id)) {
        this.dynGroup.remove(v.root);
        this.actorViews.delete(id);
      }
    }
  }

  animate(a, v, pos, now, dt) {
    const parts = v.parts;
    const act = a.action;
    const moving = now < a.moveT1;
    const phase = now / 110;
    const sleeping = a.ai?.state === 'sleep';
    parts.body.position.y = sleeping ? -0.15 : 0;
    if (parts.legL) {
      const swing = moving ? Math.sin(phase) * 0.7 : 0;
      parts.legL.rotation.x = swing;
      parts.legR.rotation.x = -swing;
      parts.armL.rotation.x = -swing * 0.6;
      parts.armR.rotation.x = swing * 0.6;
      parts.armR.rotation.z = 0;
      parts.armL.rotation.z = 0;
      if (a.isPlayer && a.sneaking) parts.body.position.y = -0.12;
      if (act && (act.type === 'attack' || act.type === 'ability' || act.type === 'bash')) {
        const t = (now - act.t0) / Math.max(1, act.t1 - act.t0);
        const c = act.commitAt ?? 0.6;
        const k = t < c ? -2.6 * (t / c) : -2.6 + 3.4 * Math.min(1, (t - c) / 0.25);
        parts.armR.rotation.x = k;
        if (act.type === 'ability') parts.armL.rotation.x = k * 0.8;
      } else if (act && (act.type === 'cast' || act.type === 'shoot' || act.type === 'throw')) {
        const t = (now - act.t0) / Math.max(1, act.t1 - act.t0);
        parts.armR.rotation.x = -1.5;
        parts.armL.rotation.x = act.type === 'cast' ? -1.4 - Math.sin(now / 80) * 0.1 : 0;
        if (act.type === 'cast' && Math.random() < dt * 30) {
          const hx = pos.x + Math.sin(v.yaw) * 0.5;
          const hz = pos.z + Math.cos(v.yaw) * 0.5;
          this.emit(hx, 1.3, hz, castColor(a, act), 1, 0.6, 1.2);
        }
        void t;
      } else if (act && ['treat', 'eat', 'drink', 'work', 'craft', 'read', 'search', 'pickup', 'push'].includes(act.type)) {
        parts.armR.rotation.x = -0.9 + Math.sin(now / 120) * 0.2;
        parts.armL.rotation.x = -0.9 - Math.sin(now / 120) * 0.2;
        if (act.type === 'push') {
          parts.armR.rotation.x = -1.5;
          parts.armL.rotation.x = -1.5;
        }
      } else if (act?.type === 'rest') {
        parts.body.position.y = -0.3;
        parts.legL.rotation.x = -1.4;
        parts.legR.rotation.x = -1.4;
      }
      if (a.effects?.fallenUntil > now) parts.body.rotation.z = 1.2;
      else if (a.alive) parts.body.rotation.z = 0;
      const gem = parts.handR.getObjectByName?.('gem');
      if (gem) gem.scale.setScalar(1 + Math.sin(now / 200) * 0.15);
      const tflame = parts.handL.getObjectByName?.('flame');
      if (tflame) tflame.scale.y = 1 + Math.sin(now / 60) * 0.2;
    } else if (parts.legs) {
      const w = moving ? Math.sin(phase * 1.6) * 0.4 : 0;
      parts.legs.forEach((l, i) => {
        l.rotation.x = (i % 2 ? w : -w) * (a.def.family === 'crawler' ? 0.5 : 1);
      });
      if (act && (act.type === 'attack' || act.type === 'ability')) {
        const t = (now - act.t0) / Math.max(1, act.t1 - act.t0);
        const c = act.commitAt ?? 1;
        parts.body.rotation.x = t < c ? 0.25 * (t / c) : -0.35;
        parts.body.position.z = t < c ? -0.15 * (t / c) : 0.2;
      } else {
        parts.body.rotation.x = 0;
        parts.body.position.z = 0;
      }
    }
  }

  // --------------------------------------------------------------- lights
  updateLights(world, now) {
    const p = world.player;
    const pp = this.actorPos(p, now);
    const lanternOn = p.lanternOn && p.equip.belt?.fuel > 0;
    const torch = p.equip.off?.id === 'torch' && p.equip.off.fuel > 0;
    const flick = 1 + Math.sin(now / 90) * 0.04 + Math.sin(now / 37) * 0.03;
    this.keyLight.position.set(pp.x + 1.1, 2.6, pp.z + 1.1);
    if (lanternOn || torch) {
      this.lantern.visible = true;
      this.lantern.position.set(pp.x, 1.35, pp.z);
      this.lantern.color.set(torch && !lanternOn ? 0xff9a3c : 0xffc27a);
      this.lantern.intensity = (lanternOn ? 9 : 7) * flick * (p.equip.belt?.fuel < 600 && lanternOn ? 0.6 : 1);
      this.lantern.distance = lanternOn ? 11 : 9;
    } else {
      this.lantern.intensity = 0;
    }
    // Rank remaining lights by distance to the player.
    const sources = (world.lights || []).filter((L) => L.kind !== 'lantern' && L.kind !== 'torch' && world.level.explored[world.level.idx(L.x, L.y)]);
    sources.sort((a, b) => Math.hypot(a.x - p.x, a.y - p.y) - Math.hypot(b.x - p.x, b.y - p.y));
    const fires = new Set();
    let n = 0;
    for (const L of sources) {
      if (n >= LIGHT_POOL) break;
      if (L.kind === 'fire') {
        const key = `${L.x >> 1},${L.y >> 1}`;
        if (fires.has(key)) continue;
        fires.add(key);
      }
      const l = this.pool[n++];
      let x = L.x;
      let z = L.y;
      if (L.actor) {
        const ap = this.actorPos(L.actor, now);
        x = ap.x;
        z = ap.z;
      }
      const f = L.flicker ? 1 + Math.sin(now / 70 + L.x * 3) * 0.08 + Math.sin(now / 23 + L.y) * 0.05 : 1;
      l.position.set(x, L.kind === 'fire' ? 0.8 : L.kind === 'wall_torch' ? 1.7 : 1.2, z);
      l.color.set(L.color);
      l.intensity = L.intensity * (L.kind === 'flash' ? 14 : 7) * f;
      l.distance = L.radius * 1.7;
    }
    for (; n < LIGHT_POOL; n++) this.pool[n].intensity = 0;
  }

  updateFire(world, now) {
    const level = world.level;
    if (!this.fireMesh) {
      const geo = new THREE.ConeGeometry(0.28, 0.9, 6);
      geo.translate(0, 0.45, 0);
      this.fireMesh = new THREE.InstancedMesh(geo, new THREE.MeshBasicMaterial({ color: new THREE.Color(0xff7a1a).multiplyScalar(2.2), transparent: true, opacity: 0.85, toneMapped: false, depthWrite: false, blending: THREE.AdditiveBlending }), 400);
      this.fireMesh.frustumCulled = false;
      this.scene.add(this.fireMesh);
      const sgeo = new THREE.SphereGeometry(0.55, 7, 5);
      this.smokeMesh = new THREE.InstancedMesh(sgeo, new THREE.MeshStandardMaterial({ color: 0x3a3a3c, transparent: true, opacity: 0.32, depthWrite: false, roughness: 1 }), 600);
      this.smokeMesh.frustumCulled = false;
      this.scene.add(this.smokeMesh);
    }
    const m4 = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    let n = 0;
    for (const i of level.burning) {
      if (n >= 400) break;
      if (!level.explored[i]) continue;
      const x = i % level.w;
      const y = (i / level.w) | 0;
      const s = 0.8 + Math.sin(now / 60 + x * 7 + y * 3) * 0.25;
      q.setFromEuler(new THREE.Euler(0, now / 300 + x, 0));
      m4.compose(new THREE.Vector3(x + (hash(x, y) - 0.5) * 0.2, 0, y), q, new THREE.Vector3(1, s, 1));
      this.fireMesh.setMatrixAt(n++, m4);
      if (Math.random() < 0.15) this.emit(x + Math.random() - 0.5, 0.4, y + Math.random() - 0.5, 0xff8a2a, 1, 0.8, 1.6);
    }
    this.fireMesh.count = n;
    this.fireMesh.instanceMatrix.needsUpdate = true;
    let k = 0;
    if (world.smokeActive) {
      for (let i = 0; i < level.smoke.length && k < 600; i++) {
        const s = level.smoke[i];
        if (s < 0.08 || !level.explored[i]) continue;
        const x = i % level.w;
        const y = (i / level.w) | 0;
        const sc = Math.min(1.5, 0.4 + s * 1.3);
        m4.compose(new THREE.Vector3(x, 0.9 + Math.sin(now / 900 + i) * 0.15, y), q.identity(), new THREE.Vector3(sc, sc * 0.6, sc));
        this.smokeMesh.setMatrixAt(k++, m4);
      }
    }
    this.smokeMesh.count = k;
    this.smokeMesh.instanceMatrix.needsUpdate = true;
    for (const v of this.propViews || []) {
      for (const f of v.flames) {
        f.scale.y = 1 + Math.sin(now / 70 + v.p.x * 5) * 0.2;
        f.visible = v.p.fuel === undefined || v.p.fuel > 0;
      }
    }
  }

  updateProjectiles(world) {
    const live = new Set();
    for (const pr of world.projectiles) {
      live.add(pr.id);
      let m = this.projViews.get(pr.id);
      if (!m) {
        m = new THREE.Group();
        m.add(mesh(new THREE.SphereGeometry(pr.kind === 'throw' ? 0.09 : 0.18, 10, 8), glow(pr.color, pr.kind === 'throw' ? 1 : 3), 0, 0, 0, false));
        this.dynGroup.add(m);
        this.projViews.set(pr.id, m);
      }
      const arc = pr.arc ? Math.sin(Math.min(1, pr.progress / pr.cells.length) * Math.PI) * 1.2 : 0;
      m.position.set(pr.fx, 1.2 + arc, pr.fy);
      if (pr.kind !== 'throw') this.emit(pr.fx, 1.2, pr.fy, pr.color, 2, 0.4, 0.4);
    }
    for (const [id, m] of this.projViews) {
      if (!live.has(id)) {
        this.dynGroup.remove(m);
        this.projViews.delete(id);
      }
    }
  }

  // ------------------------------------------------------------ events/fx
  consumeEvents(world, ui) {
    const events = world.events;
    world.events = [];
    for (const e of events) {
      switch (e.type) {
        case 'hit': {
          const v = this.actorViews.get(e.target.id);
          if (v) v.flash = 0.18;
          if (world.isVisible(e.x, e.y)) {
            const blood = e.target.isPlayer || e.target.def?.bleeds;
            if (e.amount > 0) this.emit(e.x, 1.0, e.y, blood ? 0x8a0a0a : 0xd8d0b8, 10, 0.5, 2.2, false);
            ui?.floatText(e.x, e.y, e.amount > 0 ? Math.round(e.amount * 10) / 10 : 'bloqueado', e.target.isPlayer ? 'hurt' : e.crit ? 'crit' : 'dmg');
          }
          break;
        }
        case 'miss':
          ui?.floatText(e.x, e.y, 'errou', 'miss');
          break;
        case 'noise':
          // Loud noises draw a capped ring; the log and the monsters carry the rest.
          if (e.volume >= 2) this.ring(e.x, e.y, Math.min(e.volume, 9), e.own ? 0xd8c8a0 : 0xff5040, e.volume > 15 ? 1.2 : 0.8, false, e.volume > 15 ? 0.8 : 0.45);
          break;
        case 'heard':
          this.ring(e.x, e.y, 1.5, 0xff5040, 1.2, true);
          break;
        case 'explosion':
          this.burst(e.x, e.y, e.color || 0xff6a10, 1.8);
          for (let i = 0; i < 40; i++) this.emit(e.x, 0.8, e.y, i % 3 ? 0xff8a2a : 0xffd070, 1, 1.2, 4.5);
          this.shake = 0.35;
          break;
        case 'frost':
          this.burst(e.x, e.y, 0x9fe6ff, 1.3);
          for (let i = 0; i < 30; i++) this.emit(e.x, 0.6, e.y, 0xcff4ff, 1, 1.0, 3);
          break;
        case 'burst':
          this.burst(e.x, e.y, e.color, 0.7);
          break;
        case 'tracer':
          this.line([[e.x0, 1.2, e.y0], [e.x1, 1.2, e.y1]], 0xffe0a0, 0.12);
          this.emit(e.x1, 1.1, e.y1, 0xffd08a, 8, 0.3, 2);
          this.shake = Math.max(this.shake || 0, 0.12);
          break;
        case 'lightning': {
          const pts = [];
          const n = 10;
          for (let i = 0; i <= n; i++) {
            const t = i / n;
            const j = i === 0 || i === n ? 0 : 0.35;
            pts.push([e.x0 + (e.x1 - e.x0) * t + (Math.random() - 0.5) * j, 1.2 + (Math.random() - 0.5) * j, e.y0 + (e.y1 - e.y0) * t + (Math.random() - 0.5) * j]);
          }
          this.line(pts, 0xcfeaff, 0.25);
          break;
        }
        case 'spark':
          this.emit(e.x, 0.1, e.y, 0xcfeaff, 6, 0.4, 2.5);
          break;
        case 'raise':
          for (let i = 0; i < 24; i++) this.emit(e.x, 0.2, e.y, 0x7aff5a, 1, 1.2, 1.5);
          break;
        case 'fizzle':
          this.emit(world.player.x, 1.2, world.player.y, e.color, 14, 0.5, 2);
          break;
        case 'sweep':
          this.ring(e.x, e.y, 1.6, 0xff6040, 0.4);
          break;
        case 'bash':
          this.emit(e.x, 1, e.y, 0x8a6a4a, 6, 0.5, 2.5, false);
          this.shake = Math.max(this.shake || 0, world.isVisible(e.x, e.y) ? 0.08 : 0);
          break;
        case 'death':
          if (world.isVisible(e.x, e.y) && e.actor.def?.bleeds) this.emit(e.x, 0.6, e.y, 0x7a0808, 18, 0.7, 2.5, false);
          break;
        default:
          ui?.onEvent?.(e);
      }
    }
  }

  ring(x, y, radius, color, life, pulse = false, alpha = 0.55) {
    const geo = new THREE.RingGeometry(0.9, 1, 48);
    geo.rotateX(-Math.PI / 2);
    const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.6, depthWrite: false, toneMapped: false }));
    m.position.set(x, 0.05, y);
    this.scene.add(m);
    this.fx.push({ obj: m, life, max: life, update: (k) => {
      const s = pulse ? radius * (0.5 + (1 - k) * 0.8) : 0.3 + radius * (1 - k);
      m.scale.setScalar(s);
      m.material.opacity = alpha * k;
    } });
  }

  burst(x, y, color, radius) {
    const m = new THREE.Mesh(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(2), transparent: true, opacity: 0.8, toneMapped: false, depthWrite: false, blending: THREE.AdditiveBlending }));
    m.position.set(x, 0.7, y);
    this.scene.add(m);
    this.fx.push({ obj: m, life: 0.45, max: 0.45, update: (k) => {
      m.scale.setScalar(radius * (1.2 - k));
      m.material.opacity = 0.8 * k;
    } });
  }

  line(points, color, life) {
    const geo = new THREE.BufferGeometry().setFromPoints(points.map(([x, y, z]) => new THREE.Vector3(x, y, z)));
    const m = new THREE.Line(geo, new THREE.LineBasicMaterial({ color: new THREE.Color(color).multiplyScalar(3), transparent: true, toneMapped: false }));
    this.scene.add(m);
    this.fx.push({ obj: m, life, max: life, update: (k) => {
      m.material.opacity = k;
    } });
  }

  updateFx(dt) {
    for (let i = this.fx.length - 1; i >= 0; i--) {
      const f = this.fx[i];
      f.life -= dt;
      const k = Math.max(0, f.life / f.max);
      f.update(k);
      if (f.life <= 0) {
        this.scene.remove(f.obj);
        f.obj.geometry.dispose();
        f.obj.material.dispose();
        this.fx.splice(i, 1);
      }
    }
    if (this.shake > 0) {
      this.shake = Math.max(0, this.shake - dt);
      const s = this.shake * 0.35;
      this.camera.position.x += (Math.random() - 0.5) * s;
      this.camera.position.z += (Math.random() - 0.5) * s;
    }
  }

  // ---------------------------------------------------------- particles
  initParticles() {
    const N = 1500;
    this.pN = N;
    const make = (blending) => {
      const geo = new THREE.BufferGeometry();
      const pos = new Float32Array(N * 3);
      const colr = new Float32Array(N * 3);
      geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
      geo.setAttribute('color', new THREE.BufferAttribute(colr, 3));
      const pts = new THREE.Points(geo, new THREE.PointsMaterial({ size: 5, sizeAttenuation: false, vertexColors: true, transparent: true, depthWrite: false, blending, toneMapped: false }));
      pts.frustumCulled = false;
      this.scene.add(pts);
      return { pts, pos, colr, data: [], next: 0 };
    };
    this.addP = make(THREE.AdditiveBlending);
    this.normP = make(THREE.NormalBlending);
  }

  emit(x, y, z, color, count, life, speed, additive = true) {
    const sys = additive ? this.addP : this.normP;
    const c = new THREE.Color(color);
    if (additive) c.multiplyScalar(1.6);
    for (let i = 0; i < count; i++) {
      const k = sys.next;
      sys.next = (sys.next + 1) % this.pN;
      sys.data[k] = {
        x, y, z, vx: (Math.random() - 0.5) * speed, vy: Math.random() * speed * (additive ? 0.9 : 0.6), vz: (Math.random() - 0.5) * speed,
        life: life * (0.6 + Math.random() * 0.6), max: life, r: c.r, g: c.g, b: c.b, grav: additive ? -0.4 : 6,
      };
    }
  }

  updateParticles(dt) {
    for (const sys of [this.addP, this.normP]) {
      for (let k = 0; k < this.pN; k++) {
        const p = sys.data[k];
        if (!p || p.life <= 0) {
          sys.pos[k * 3 + 1] = -100;
          continue;
        }
        p.life -= dt;
        p.vy -= p.grav * dt;
        p.x += p.vx * dt;
        p.y = Math.max(0.02, p.y + p.vy * dt);
        p.z += p.vz * dt;
        const a = Math.max(0, p.life / p.max);
        sys.pos[k * 3] = p.x;
        sys.pos[k * 3 + 1] = p.y;
        sys.pos[k * 3 + 2] = p.z;
        sys.colr[k * 3] = p.r * a;
        sys.colr[k * 3 + 1] = p.g * a;
        sys.colr[k * 3 + 2] = p.b * a;
      }
      sys.pts.geometry.attributes.position.needsUpdate = true;
      sys.pts.geometry.attributes.color.needsUpdate = true;
    }
  }

  // ------------------------------------------------------------ markers
  initMarkers() {
    const geo = new THREE.PlaneGeometry(1, 1);
    geo.rotateX(-Math.PI / 2);
    this.hoverMark = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: 0xe8d8b0, transparent: true, opacity: 0.18, depthWrite: false, toneMapped: false }));
    this.hoverMark.position.y = 0.02;
    this.scene.add(this.hoverMark);
    const edges = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(1, 0.01, 1)), new THREE.LineBasicMaterial({ color: 0xe8d8b0, transparent: true, opacity: 0.7, toneMapped: false }));
    this.hoverMark.add(edges);
    this.areaMarks = [];
    for (let i = 0; i < 9; i++) {
      const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: 0xff7a1a, transparent: true, opacity: 0.22, depthWrite: false, toneMapped: false }));
      m.position.y = 0.03;
      m.visible = false;
      this.scene.add(m);
      this.areaMarks.push(m);
    }
    this.pathDots = [];
    const dg = new THREE.CircleGeometry(0.08, 8);
    dg.rotateX(-Math.PI / 2);
    for (let i = 0; i < 16; i++) {
      const d = new THREE.Mesh(dg, new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.6, toneMapped: false }));
      d.visible = false;
      this.scene.add(d);
      this.pathDots.push(d);
    }
  }

  updateMarkers(world, now) {
    const h = this.hover;
    this.hoverMark.visible = !!h && world.level.inBounds(h.x, h.y) && !!world.level.explored[world.level.idx(h.x, h.y)];
    if (h) this.hoverMark.position.set(h.x, 0.03, h.y);
    const tg = this.targeting;
    for (const m of this.areaMarks) m.visible = false;
    for (const d of this.pathDots) d.visible = false;
    if (!tg || !h) {
      this.hoverMark.material.color.set(0xe8d8b0);
      return;
    }
    const color = tg.valid ? tg.color : 0x888888;
    this.hoverMark.material.color.set(color);
    this.hoverMark.material.opacity = 0.3 + Math.sin(now / 120) * 0.08;
    if (tg.radius) {
      let k = 0;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const m = this.areaMarks[k++];
          m.visible = true;
          m.position.set(h.x + dx, 0.03, h.y + dy);
          m.material.color.set(color);
        }
      }
    }
    const p = world.player;
    const n = Math.max(1, Math.hypot(h.x - p.x, h.y - p.y));
    const count = Math.min(this.pathDots.length, Math.ceil(n * 1.5));
    for (let i = 0; i < count; i++) {
      const t = (i + 1) / (count + 1);
      const d = this.pathDots[i];
      d.visible = true;
      d.position.set(p.x + (h.x - p.x) * t, 0.05 + (tg.arc ? Math.sin(t * Math.PI) * 1.0 : 0), p.y + (h.y - p.y) * t);
      d.material.color.set(color);
    }
  }

  // --------------------------------------------------------- picking
  pickCell(clientX, clientY) {
    const rect = this.canvas.getBoundingClientRect();
    const ndc = new THREE.Vector2(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    // Actors first: clicking a body selects its cell.
    const targets = [];
    for (const v of this.actorViews.values()) if (v.root.visible) targets.push(v.root);
    const hits = this.raycaster.intersectObjects(targets, true);
    if (hits.length) {
      let o = hits[0].object;
      while (o.parent && !targets.includes(o)) o = o.parent;
      for (const [id, v] of this.actorViews) {
        if (v.root === o) {
          const a = id === this.world.player.id ? this.world.player : this.world.level.actors.find((m) => m.id === id);
          if (a && !a.isPlayer) return { x: a.x, y: a.y };
        }
      }
    }
    const pt = new THREE.Vector3();
    if (!this.raycaster.ray.intersectPlane(this.groundPlane, pt)) return null;
    return { x: Math.round(pt.x), y: Math.round(pt.z) };
  }

  project(x, y, h) {
    const v = new THREE.Vector3(x, h, y).project(this.camera);
    const rect = this.canvas.getBoundingClientRect();
    return { x: rect.left + ((v.x + 1) / 2) * rect.width, y: rect.top + ((1 - v.y) / 2) * rect.height };
  }

  actorScreen(a, h = 2.1) {
    const pos = this.actorPos(a, this.world.now);
    const s = (a.def?.scale || 1) * (a.def?.family === 'quadruped' || a.def?.family === 'crawler' ? 0.5 : 1);
    return this.project(pos.x, pos.z, h * s + pos.y);
  }
}

function gearToEquip(ids) {
  const equip = {};
  for (const id of ids || []) {
    const def = ITEMS[id];
    if (def?.slot && !equip[def.slot]) equip[def.slot] = { id };
  }
  return equip;
}

function castColor(a, act) {
  if (!a.isPlayer) return 0xb45cff;
  const l = act.label || '';
  if (l.includes('Fogo')) return 0xff7a1a;
  if (l.includes('Gelo')) return 0x9fe6ff;
  if (l.includes('Arco')) return 0xcfeaff;
  return 0x7aff5a;
}
