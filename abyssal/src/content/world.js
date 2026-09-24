// Props (furniture), room themes, hand-made vaults and branch/floor setup.

export const PROPS = {
  shelf: {
    name: 'Estante', blocks: true, opaque: true, movable: true, flammable: true, wood: true,
    hp: 30, fuel: 26000, container: 'common', height: 1.9, pushTime: 900, pushNoise: 5,
  },
  bookshelf: {
    name: 'Estante de Livros', blocks: true, opaque: true, movable: true, flammable: true, wood: true,
    hp: 30, fuel: 30000, container: 'books', height: 1.9, pushTime: 1000, pushNoise: 5,
  },
  table: {
    name: 'Mesa', blocks: true, movable: true, flammable: true, wood: true, hp: 22, fuel: 18000,
    height: 0.8, pushTime: 700, pushNoise: 4, container: 'common',
  },
  chair: {
    name: 'Cadeira', blocks: true, movable: true, flammable: true, wood: true, hp: 8, fuel: 9000,
    height: 0.9, pushTime: 350, pushNoise: 2,
  },
  crate: {
    name: 'Caixote', blocks: true, movable: true, flammable: true, wood: true, hp: 12, fuel: 14000,
    container: 'common', height: 0.8, pushTime: 650, pushNoise: 4,
  },
  barrel_oil: {
    name: 'Barril de Óleo', blocks: true, movable: true, flammable: true, wood: true, hp: 10,
    fuel: 6000, spills: 'oil', height: 1.0, pushTime: 1100, pushNoise: 6, explosive: true,
  },
  bed: {
    name: 'Catre', blocks: false, movable: false, flammable: true, wood: true, hp: 15, fuel: 15000,
    height: 0.45, rest: 1.5,
  },
  altar: { name: 'Altar', blocks: true, movable: false, hp: 999, height: 1.0, container: 'rare', stone: true },
  sarcophagus: {
    name: 'Sarcófago', blocks: true, movable: false, hp: 999, height: 0.9, container: 'crypt', stone: true,
  },
  weapon_rack: {
    name: 'Armeiro', blocks: true, movable: false, flammable: true, wood: true, hp: 20, fuel: 12000,
    height: 1.6, container: 'gear', opaque: false,
  },
  pillar: { name: 'Pilar', blocks: true, opaque: true, movable: false, hp: 999, height: 2.6, stone: true },
  wall_torch: {
    name: 'Tocha de Parede', blocks: false, hp: 999, height: 1.6, onWall: true,
    light: { radius: 5.5, intensity: 1.0, color: 0xff8f3a },
  },
  brazier: {
    name: 'Braseiro', blocks: true, hp: 999, height: 1.0, stone: true,
    light: { radius: 6, intensity: 1.2, color: 0xff7a2a },
  },
  campfire: {
    name: 'Fogueira', blocks: true, hp: 999, height: 0.5, burns: 600,
    light: { radius: 6.5, intensity: 1.3, color: 0xff8a33 }, warm: true,
  },
  candle: {
    name: 'Vela', blocks: false, hp: 1, height: 0.3, burns: 360,
    light: { radius: 3.2, intensity: 0.7, color: 0xffd08a },
  },
  gate: { name: 'Portão do Profundo', blocks: false, hp: 999, height: 0.1 },
};

// Weighted room themes: props placed along walls, in the centre, loot and extras.
export const ROOM_THEMES = {
  hall: { name: 'Salão', weight: 4, wall: [['pillar', 1]], center: [], torches: 0.5, pillars: true },
  barracks: { name: 'Alojamento', weight: 3, wall: [['bed', 4], ['crate', 1], ['shelf', 1]], center: [['table', 1]], torches: 0.4 },
  library: { name: 'Biblioteca', weight: 2, wall: [['bookshelf', 5]], center: [['table', 1], ['chair', 1]], torches: 0.3 },
  storeroom: { name: 'Depósito', weight: 3, wall: [['crate', 3], ['barrel_oil', 2], ['shelf', 2]], center: [['crate', 1]], torches: 0.2, oil: 0.4 },
  kitchen: { name: 'Cozinha', weight: 2, wall: [['shelf', 2], ['barrel_oil', 1], ['crate', 1]], center: [['table', 2]], torches: 0.6 },
  chapel: { name: 'Capela', weight: 1.5, wall: [['bookshelf', 1]], center: [['altar', 1]], torches: 0.2, braziers: true },
  flooded: { name: 'Cisterna Alagada', weight: 2, wall: [], center: [], torches: 0.1, water: true },
  guardroom: { name: 'Sala da Guarda', weight: 2, wall: [['weapon_rack', 1], ['shelf', 1], ['crate', 1]], center: [['table', 1], ['chair', 2]], torches: 0.7 },
  crypt: { name: 'Cripta', weight: 1.5, wall: [['sarcophagus', 3]], center: [], torches: 0.1 },
};

// Hand-made vaults stamped into the procedural layout (DCSS principle).
// Legend: # wall . floor + exit/door ~ water o oil % web
// b oil barrel c crate s bookshelf t table h chair B bed A altar S sarcophagus
// r weapon rack T wall torch F brazier P pillar C corpse-with-loot D sealed gate
// Monsters: g goblin k knight x spider z skeleton m cultist R troll 1 boss
// Loot: $ rare * gear ? knowledge (necromancy book when due)
export const VAULTS = [
  {
    id: 'oil_store', depth: [1, 5], weight: 3,
    map: [
      '#########',
      '#b.o.o.b#',
      '#..ooo..#',
      '+.o.g.o.+',
      '#c..*..c#',
      '#########',
    ],
  },
  {
    id: 'flooded_shrine', depth: [1, 5], weight: 3,
    map: [
      '###########',
      '#~~~~~~~~~#',
      '#~~.....~~#',
      '+~..tA$..~#',
      '#~~.....~~+',
      '#~~~~~~~~~#',
      '###########',
    ],
  },
  {
    id: 'armory', depth: [2, 5], weight: 2,
    map: [
      '#######',
      '#r.*.r#',
      '#.....#',
      '#r.k.r#',
      '###+###',
    ],
  },
  {
    id: 'spider_nest', depth: [2, 5], weight: 2,
    map: [
      '##########',
      '#%%..%%%.#',
      '#%C%..x%%#',
      '+..%%...%#',
      '#%..$%%x.#',
      '##########',
    ],
  },
  {
    id: 'forbidden_library', depth: [2, 3], weight: 4, unique: true,
    map: [
      '#########',
      '#sssssss#',
      '#.......#',
      '+..t?t..+',
      '#...m...#',
      '#sssssss#',
      '#########',
    ],
  },
  {
    id: 'crypt_row', depth: [3, 5], weight: 2,
    map: [
      '###########',
      '#S.S.S.S.S#',
      '#.........#',
      '+....z....+',
      '#.........#',
      '#S.S.S.S.S#',
      '###########',
    ],
  },
  {
    id: 'troll_den', depth: [4, 5], weight: 2,
    map: [
      '##########',
      '#C...o..c#',
      '#..R.....#',
      '+....ooo.#',
      '#c..$...C#',
      '####+#####',
    ],
  },
  {
    id: 'castellan_hall', depth: [5, 5], weight: 0, boss: true,
    map: [
      '###############',
      '#P..F..D..F..P#',
      '#.............#',
      '#..P.......P..#',
      '#......1......#',
      '#..P.......P..#',
      '#.............#',
      '#P..F.....F..P#',
      '#######+#######',
    ],
  },
];

export const BRANCH = {
  id: 'forgotten_fortress',
  name: 'Fortaleza Esquecida',
  floors: 5,
  size: 54,
  // Monster budget per floor (xp-weighted) and a guaranteed pool of survival supplies.
  budget: [26, 40, 56, 70, 80],
  loot: [16, 16, 17, 17, 16],
  necroBookFloor: 2,
};
