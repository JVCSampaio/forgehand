// Monster definitions. Everything a monster does is described here; the AI and
// combat code only interpret these fields.
//
// senses: vision (cells), hearing (multiplier on received volume), smell (cells to
// track blood), magic (cells at which spellcasting is sensed).
// targets: hit-location profile used against anatomical bodies.
// abilities: special actions with telegraphed wind-ups (shown in tactical pause).

export const HIT_PROFILES = {
  low: { footL: 3, footR: 3, legL: 4, legR: 4, handL: 1, handR: 1, torso: 1 },
  mid: { head: 1.2, torso: 4, armL: 1.5, armR: 1.5, handL: 1, handR: 1.2, legL: 1.5, legR: 1.5, footL: 0.5, footR: 0.5 },
  high: { head: 2.5, torso: 4, armL: 2, armR: 2, handL: 1.2, handR: 1.5, legL: 0.6, legR: 0.6 },
};

export const MONSTERS = {
  rat: {
    name: 'Ratazana', family: 'quadruped', scale: 0.55, color: 0x4d3f36, eye: 0xff4433,
    hp: 5, ac: { slash: 0, pierce: 0, blunt: 0 }, evasion: 6, move: 210,
    attacks: [{ name: 'mordida', dmg: { bite: [1, 3] }, windup: 380, recover: 250, infect: 0.12 }],
    targets: 'low', senses: { vision: 5, hearing: 1.4, smell: 8, magic: 0 },
    behavior: { pack: [3, 5], cowardice: 0.2, wanders: true }, stepNoise: 1,
    xp: 2, depth: [1, 3], weight: 5, corpse: 'Carcaça de Ratazana', bleeds: true,
  },
  skeleton: {
    name: 'Esqueleto', family: 'humanoid', scale: 0.95, color: 0xd8d0b8, eye: 0x88ccff,
    hp: 16, ac: { slash: 2, pierce: 6, blunt: -2 }, evasion: 2, move: 380, undead: true,
    attacks: [{ name: 'espada enferrujada', dmg: { slash: [3, 8] }, windup: 650, recover: 450 }],
    targets: 'mid', senses: { vision: 7, hearing: 1.0, smell: 0, magic: 4 },
    behavior: { canOpenDoors: true, sleeps: 0.6 }, stepNoise: 2, weapon: 'sword',
    xp: 6, depth: [1, 5], weight: 5, corpse: 'Ossada', bleeds: false, resists: { cold: 0.5 },
  },
  goblin: {
    name: 'Goblin', family: 'humanoid', scale: 0.72, color: 0x5d7a3a, eye: 0xffd24a,
    hp: 11, ac: { slash: 1, pierce: 1, blunt: 0 }, evasion: 7, move: 260,
    attacks: [{ name: 'faca serrilhada', dmg: { slash: [2, 6] }, windup: 480, recover: 300 }],
    abilities: [{ type: 'shout', name: 'grito de alerta', windup: 450, cooldown: 20000, noise: 12 }],
    targets: 'mid', senses: { vision: 8, hearing: 1.2, smell: 0, magic: 0 },
    behavior: { pack: [2, 4], cowardice: 0.35, canOpenDoors: true, wanders: true },
    stepNoise: 1, weapon: 'dagger', loot: 0.45,
    xp: 5, depth: [1, 4], weight: 6, corpse: 'Cadáver de Goblin', bleeds: true,
  },
  ghoul: {
    name: 'Carniçal', family: 'humanoid', scale: 1.0, color: 0x6f7d6a, eye: 0xc8ff5a, hunch: 0.35,
    hp: 24, ac: { slash: 1, pierce: 2, blunt: 1 }, evasion: 4, move: 300, undead: true,
    attacks: [
      { name: 'garras', dmg: { slash: [3, 7] }, windup: 520, recover: 350 },
      { name: 'mordida', dmg: { bite: [4, 9] }, windup: 800, recover: 400, infect: 0.35, weight: 0.5 },
    ],
    targets: 'mid', senses: { vision: 6, hearing: 1.1, smell: 14, magic: 0 },
    behavior: { canOpenDoors: false, bashes: true, sleeps: 0.3 }, stepNoise: 2,
    xp: 10, depth: [2, 5], weight: 4, corpse: 'Carcaça de Carniçal', bleeds: true,
    desc: 'Segue o cheiro de sangue por corredores inteiros.',
  },
  cultist: {
    name: 'Mago Cultista', family: 'humanoid', scale: 0.95, color: 0x3a2346, eye: 0xb45cff,
    hp: 14, ac: { slash: 0, pierce: 0, blunt: 0 }, evasion: 5, move: 320, robe: 0x2a1a36,
    attacks: [{ name: 'adaga ritual', dmg: { pierce: [2, 5] }, windup: 550, recover: 350 }],
    abilities: [{
      type: 'bolt', name: 'Seta Sombria', windup: 1600, cooldown: 3500, range: 7,
      dmg: { arcane: [5, 11] }, noise: 12, interruptible: true, color: 0xb45cff, keepDistance: 4,
    }],
    targets: 'mid', senses: { vision: 8, hearing: 1.0, smell: 0, magic: 12 },
    behavior: { canOpenDoors: true, caster: true }, stepNoise: 1, light: { radius: 2.5, color: 0xb45cff, intensity: 0.6 },
    loot: 0.8, lootTable: 'rare',
    xp: 12, depth: [2, 5], weight: 4, corpse: 'Cadáver de Cultista', bleeds: true,
  },
  spider: {
    name: 'Aranha das Criptas', family: 'crawler', scale: 0.8, color: 0x2b2420, eye: 0xff2b2b,
    hp: 15, ac: { slash: 2, pierce: 1, blunt: 1 }, evasion: 9, move: 230,
    attacks: [{ name: 'quelíceras', dmg: { bite: [3, 7] }, windup: 450, recover: 350, poison: 6 }],
    abilities: [{
      type: 'pounce', name: 'bote', windup: 900, cooldown: 6000, range: 3,
      dmg: { bite: [5, 10] }, poison: 8,
    }],
    targets: 'low', senses: { vision: 6, hearing: 1.3, smell: 0, magic: 0 },
    behavior: { ambush: true, sleeps: 0.5 }, stepNoise: 0,
    xp: 9, depth: [2, 5], weight: 3, corpse: 'Carapaça de Aranha', bleeds: true, webs: true,
  },
  knight: {
    name: 'Cavaleiro Caído', family: 'humanoid', scale: 1.08, color: 0x6d7076, eye: 0xff6a3d,
    hp: 34, ac: { slash: 7, pierce: 5, blunt: 3 }, evasion: 2, move: 420, undead: true,
    block: 0.25, armored: true,
    attacks: [{ name: 'montante', dmg: { slash: [6, 14] }, windup: 900, recover: 600, fracture: 0.12 }],
    targets: 'mid', senses: { vision: 7, hearing: 0.9, smell: 0, magic: 0 },
    behavior: { canOpenDoors: true, bashes: true, guard: true }, stepNoise: 4, weapon: 'longsword',
    loot: 0.6, lootTable: 'gear',
    xp: 18, depth: [3, 5], weight: 3, corpse: 'Armadura Vazia', bleeds: false,
  },
  troll: {
    name: 'Troll das Profundezas', family: 'brute', scale: 1.55, color: 0x5e6b52, eye: 0xffe14a,
    hp: 60, ac: { slash: 2, pierce: 2, blunt: 2 }, evasion: 1, move: 450, regen: 0.6,
    attacks: [{ name: 'punho', dmg: { blunt: [8, 17] }, windup: 1100, recover: 700, fracture: 0.35 }],
    targets: 'high', senses: { vision: 6, hearing: 1.0, smell: 8, magic: 0 },
    behavior: { bashes: true, sleeps: 0.7, doorBreaker: true }, stepNoise: 5,
    xp: 30, depth: [4, 5], weight: 1.5, corpse: 'Carcaça de Troll', bleeds: true,
    desc: 'Regenera. Fogo interrompe a regeneração.',
  },
  castellan: {
    name: 'O Castelão Oco', family: 'humanoid', scale: 1.45, color: 0x55504a, eye: 0xff3b1f,
    hp: 130, ac: { slash: 8, pierce: 6, blunt: 4 }, evasion: 2, move: 440, undead: true,
    block: 0.2, armored: true, boss: true, crown: true,
    attacks: [{ name: 'lâmina do castelo', dmg: { slash: [9, 19] }, windup: 950, recover: 550, fracture: 0.15 }],
    abilities: [
      { type: 'sweep', name: 'varredura', windup: 1400, cooldown: 7000, dmg: { slash: [8, 16] } },
      { type: 'summon', name: '"Levantem-se!"', windup: 1600, cooldown: 25000, summon: 'skeleton', count: 2, hpBelow: 0.7, noise: 20 },
    ],
    targets: 'high', senses: { vision: 9, hearing: 1.0, smell: 0, magic: 6 },
    behavior: { canOpenDoors: true, bashes: true, guard: true, sleeps: 1 }, stepNoise: 5, weapon: 'longsword',
    xp: 80, depth: [5, 5], weight: 0, corpse: 'Restos do Castelão', bleeds: false,
    drops: ['relic_crown', 'heal_potion'],
  },
  hollowed: {
    // A previous character, found again below. Name and gear come from the Hall of the Dead.
    name: 'Esvaziado', family: 'humanoid', scale: 1.0, color: 0x8a8f96, eye: 0x7fffd4, hollowed: true,
    hp: 38, ac: { slash: 3, pierce: 3, blunt: 2 }, evasion: 5, move: 330, undead: true,
    attacks: [{ name: 'golpe', dmg: { slash: [5, 12] }, windup: 700, recover: 450 }],
    targets: 'mid', senses: { vision: 8, hearing: 1.1, smell: 6, magic: 6 },
    behavior: { canOpenDoors: true, bashes: true, wanders: true }, stepNoise: 2,
    xp: 25, depth: [99, 99], weight: 0, corpse: 'Restos de', bleeds: false,
  },
};

// Raised dead keep the corpse's monster def but fight for the necromancer.
export const RAISED_PREFIX = 'Servo';
