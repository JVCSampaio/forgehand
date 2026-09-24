// Item definitions. Pure data: the simulation reads fields, never item ids.
// Damage ranges are [min, max] per damage type. Times are milliseconds of
// simulation time. Noise is a propagation radius in cells (1 cell = 1 m).
export const ITEMS = {
  // ---------------------------------------------------------------- weapons
  fists: {
    name: 'Punhos', kind: 'weapon', skill: 'unarmed', hands: 1, weight: 0, reach: 1,
    swing: 480, stamina: 4, noise: 2, dmg: { blunt: [1, 3] }, durability: 0, hidden: true,
  },
  dagger: {
    name: 'Adaga', kind: 'weapon', slot: 'main', skill: 'blades', hands: 1, light: true,
    weight: 0.5, reach: 1, swing: 420, stamina: 6, noise: 3,
    dmg: { pierce: [3, 7], slash: [1, 3] }, durability: 90, model: 'dagger',
  },
  short_sword: {
    name: 'Espada Curta', kind: 'weapon', slot: 'main', skill: 'blades', hands: 1,
    weight: 1.2, reach: 1, swing: 600, stamina: 10, noise: 4,
    dmg: { slash: [5, 10], pierce: [2, 5] }, durability: 60, model: 'sword',
  },
  long_sword: {
    name: 'Espada Longa', kind: 'weapon', slot: 'main', skill: 'blades', hands: 2,
    weight: 1.6, reach: 1, swing: 720, stamina: 13, noise: 8,
    dmg: { slash: [9, 18], pierce: [3, 8] }, durability: 80, model: 'longsword',
  },
  axe: {
    name: 'Machado', kind: 'weapon', slot: 'main', skill: 'axes', hands: 2,
    weight: 2.2, reach: 1, swing: 1050, stamina: 21, noise: 6,
    dmg: { slash: [12, 26] }, vsWood: 1.75, fracture: 0.2, durability: 85, model: 'axe',
  },
  mace: {
    name: 'Maça de Guerra', kind: 'weapon', slot: 'main', skill: 'maces', hands: 1,
    weight: 2.0, reach: 1, swing: 850, stamina: 15, noise: 6,
    dmg: { blunt: [7, 15] }, fracture: 0.25, durability: 120, model: 'mace',
  },
  spear: {
    name: 'Lança', kind: 'weapon', slot: 'main', skill: 'polearms', hands: 2,
    weight: 1.8, reach: 2, swing: 780, stamina: 12, noise: 4,
    dmg: { pierce: [6, 13] }, durability: 70, model: 'spear',
  },
  staff: {
    name: 'Cajado Rúnico', kind: 'weapon', slot: 'main', skill: 'maces', hands: 2,
    weight: 1.5, reach: 1, swing: 700, stamina: 9, noise: 3,
    dmg: { blunt: [3, 7] }, spellBonus: 8, durability: 100, model: 'staff',
  },
  pistol: {
    name: 'Colt M1911', kind: 'weapon', slot: 'main', skill: 'firearms', hands: 1, ranged: true,
    weight: 1.1, reach: 1, swing: 520, stamina: 5, noise: 30, aim: 480, reload: 2400,
    magazine: 7, ammo: 'ammo45', range: 12, dmg: { pierce: [16, 28] },
    meleeDmg: { blunt: [2, 5] }, durability: 200, model: 'pistol',
  },
  torch: {
    name: 'Tocha', kind: 'weapon', slot: 'off', skill: 'maces', hands: 1,
    weight: 0.6, reach: 1, swing: 650, stamina: 8, noise: 3,
    dmg: { blunt: [2, 4], fire: [2, 5] }, light: { radius: 5, intensity: 1.0, color: 0xff9a3c },
    burnTime: 1800, durability: 0, model: 'torch', flammable: true,
  },
  shield: {
    name: 'Escudo de Madeira', kind: 'armour', slot: 'off', weight: 3.0, block: 0.2,
    durability: 60, model: 'shield', flammable: true, encumbrance: 1,
  },

  // ------------------------------------------------------------------ ammo
  ammo45: { name: 'Munição .45 ACP', kind: 'ammo', weight: 0.02, stack: true },

  // --------------------------------------------------------------- armour
  gambeson: {
    name: 'Gambeson', kind: 'armour', slot: 'torso_outer', covers: ['torso', 'armL', 'armR'],
    prot: { slash: 3, pierce: 2, blunt: 2, bite: 3 }, weight: 3.5, encumbrance: 1,
    durability: 60, model: 'gambeson', color: 0x7a6a4f, flammable: true,
  },
  mail: {
    name: 'Cota de Malha', kind: 'armour', slot: 'torso_outer', covers: ['torso', 'armL', 'armR'],
    prot: { slash: 7, pierce: 4, blunt: 2, bite: 6 }, weight: 9, encumbrance: 5,
    durability: 110, model: 'mail', color: 0x8d949c,
  },
  tactical_vest: {
    name: 'Colete Tático (1994)', kind: 'armour', slot: 'torso_inner', covers: ['torso'],
    prot: { slash: 5, pierce: 9, blunt: 3, bite: 5 }, weight: 3, encumbrance: 1,
    durability: 80, model: 'vest', color: 0x3f4a36,
  },
  robe: {
    name: 'Manto Ritual', kind: 'armour', slot: 'torso_outer', covers: ['torso', 'legL', 'legR'],
    prot: { slash: 1, pierce: 0, blunt: 1, bite: 1 }, weight: 1.2, encumbrance: 0,
    spellBonus: 6, durability: 40, model: 'robe', color: 0x3b2d5c, flammable: true,
  },
  helmet: {
    name: 'Elmo de Ferro', kind: 'armour', slot: 'head', covers: ['head'],
    prot: { slash: 6, pierce: 4, blunt: 4, bite: 6 }, weight: 2, encumbrance: 1,
    durability: 90, model: 'helmet', color: 0x8d949c,
  },
  hood: {
    name: 'Capuz de Lã', kind: 'armour', slot: 'head', covers: ['head'],
    prot: { slash: 1, pierce: 0, blunt: 1, bite: 1 }, weight: 0.3, encumbrance: 0,
    durability: 30, model: 'hood', color: 0x40362e, flammable: true,
  },
  gas_mask: {
    name: 'Máscara Antigás', kind: 'armour', slot: 'face', covers: ['head'],
    prot: { slash: 1, pierce: 1, blunt: 1, bite: 2 }, weight: 0.8, encumbrance: 0,
    smokeProof: true, durability: 50, model: 'gasmask', color: 0x2e3328,
  },
  gloves: {
    name: 'Luvas de Couro', kind: 'armour', slot: 'hands', covers: ['handL', 'handR'],
    prot: { slash: 2, pierce: 1, blunt: 1, bite: 3 }, weight: 0.4, encumbrance: 0,
    durability: 40, model: 'gloves', color: 0x5a3d26,
  },
  padded_legs: {
    name: 'Calças Acolchoadas', kind: 'armour', slot: 'legs', covers: ['legL', 'legR'],
    prot: { slash: 2, pierce: 1, blunt: 2, bite: 3 }, weight: 1.5, encumbrance: 0,
    durability: 50, model: 'legs', color: 0x4a4038, flammable: true,
  },
  boots: {
    name: 'Botas de Couro', kind: 'armour', slot: 'feet', covers: ['footL', 'footR'],
    prot: { slash: 2, pierce: 1, blunt: 1, bite: 4 }, weight: 1.2, encumbrance: 0,
    durability: 60, model: 'boots', color: 0x3a2a1c,
  },
  backpack: {
    name: 'Mochila', kind: 'armour', slot: 'back', capacity: 12, weight: 0.8,
    durability: 0, model: 'backpack', color: 0x5b4a33,
  },
  lantern: {
    name: 'Lamparina', kind: 'light', slot: 'belt', weight: 0.8, model: 'lantern',
    light: { radius: 6.5, intensity: 1.15, color: 0xffc27a }, fuelMax: 5400, durability: 0,
  },

  // ------------------------------------------------------------ consumables
  ration: { name: 'Ração de Viagem', kind: 'food', weight: 0.4, hunger: -30, time: 1600 },
  bread: { name: 'Pão Duro', kind: 'food', weight: 0.3, hunger: -18, thirst: 4, time: 1200 },
  jerky: { name: 'Carne Seca', kind: 'food', weight: 0.25, hunger: -22, thirst: 6, time: 1400 },
  mushroom: {
    name: 'Cogumelo Pálido', kind: 'food', weight: 0.1, hunger: -10, time: 800, poison: 0.3,
  },
  waterskin: {
    name: 'Odre', kind: 'drink', weight: 0.3, chargeWeight: 0.25, maxCharges: 6, thirst: -25,
    time: 1000, refill: true,
  },
  wine: { name: 'Vinho Azedo', kind: 'drink', weight: 0.8, thirst: -15, fear: -20, time: 1200 },
  alcohol: {
    name: 'Álcool Destilado', kind: 'medical', use: 'disinfect', weight: 0.4, maxCharges: 3,
    time: 1200, flammable: true,
  },
  bandage: { name: 'Bandagem', kind: 'medical', use: 'bandage', clean: true, weight: 0.05, stack: true },
  rag: { name: 'Trapo', kind: 'material', use: 'bandage', clean: false, weight: 0.1, stack: true, flammable: true },
  suture: {
    name: 'Agulha e Linha', kind: 'medical', use: 'stitch', weight: 0.05, maxCharges: 3, time: 4500,
  },
  splint: { name: 'Tala', kind: 'medical', use: 'splint', weight: 0.5, time: 3500, flammable: true },
  heal_potion: {
    name: 'Poção de Cura', kind: 'potion', weight: 0.3, time: 1400, blood: 30, woundHeal: 0.6,
  },
  mana_potion: { name: 'Poção de Mana', kind: 'potion', weight: 0.3, time: 1400, mana: 25 },
  oil_flask: {
    name: 'Frasco de Óleo', kind: 'throwable', weight: 0.5, effect: 'oil', fuel: 2700,
    range: 6, time: 900, noise: 3, flammable: true,
  },
  firebomb: {
    name: 'Coquetel Incendiário', kind: 'throwable', weight: 0.6, effect: 'fire', range: 6,
    time: 1000, noise: 10, flammable: true,
  },
  plank: { name: 'Tábua', kind: 'material', weight: 1.0, stack: true, flammable: true },
  whetstone: { name: 'Pedra de Amolar', kind: 'tool', use: 'repair', weight: 0.3, maxCharges: 3, time: 3000 },
  candle: { name: 'Vela', kind: 'placeable', weight: 0.1, stack: true, flammable: true },

  // ------------------------------------------------------------ knowledge
  book_necro: {
    name: 'Livro de Necromancia', kind: 'book', teaches: 'raise_dead', weight: 1.2, time: 6000,
    flammable: true,
  },
  scroll_lightning: {
    name: 'Pergaminho do Arco Voltaico', kind: 'book', teaches: 'lightning', weight: 0.1,
    time: 3000, flammable: true,
  },
  scroll_fire: {
    name: 'Pergaminho da Bola de Fogo', kind: 'book', teaches: 'fireball', weight: 0.1,
    time: 3000, flammable: true,
  },

  // ------------------------------------------------------------- relics
  relic_idol: { name: 'Ídolo de Obsidiana', kind: 'relic', weight: 0.6, value: 40 },
  relic_coin: { name: 'Moeda do Império Afogado', kind: 'relic', weight: 0.05, value: 12, stack: true },
  relic_lens: { name: 'Lente de Latão (1887)', kind: 'relic', weight: 0.2, value: 25 },
  relic_crown: { name: 'Coroa do Castelão', kind: 'relic', weight: 1.0, value: 150 },
};

// Field crafting. Workstation crafting (forge, alchemy) is deliberately out of the slice.
export const RECIPES = [
  { id: 'bandage', name: 'Bandagem', needs: { rag: 2 }, makes: 'bandage', qty: 1, time: 1500 },
  { id: 'torch', name: 'Tocha', needs: { plank: 1, rag: 1 }, makes: 'torch', qty: 1, time: 2000 },
  { id: 'splint', name: 'Tala', needs: { plank: 1, rag: 1 }, makes: 'splint', qty: 1, time: 2000 },
  { id: 'firebomb', name: 'Coquetel Incendiário', needs: { oil_flask: 1, rag: 1 }, makes: 'firebomb', qty: 1, time: 1800 },
  { id: 'campfire', name: 'Fogueira', needs: { plank: 2 }, place: 'campfire', time: 4000, noise: 4 },
];

export const LOOT_TABLES = {
  common: [
    ['ration', 6], ['bread', 6], ['jerky', 4], ['mushroom', 3], ['rag', 8], ['plank', 7],
    ['bandage', 5], ['oil_flask', 4], ['candle', 3], ['wine', 2], ['alcohol', 2],
    ['waterskin', 1], ['relic_coin', 4],
  ],
  gear: [
    ['dagger', 3], ['short_sword', 3], ['mace', 3], ['axe', 2], ['spear', 2], ['long_sword', 1],
    ['shield', 2], ['helmet', 2], ['gloves', 3], ['padded_legs', 3], ['boots', 2], ['hood', 2],
    ['gambeson', 2], ['mail', 1], ['tactical_vest', 1], ['gas_mask', 1],
  ],
  rare: [
    ['heal_potion', 5], ['mana_potion', 4], ['suture', 3], ['whetstone', 3], ['ammo45', 3],
    ['splint', 2], ['firebomb', 2], ['scroll_lightning', 1], ['scroll_fire', 1],
    ['relic_idol', 2], ['relic_lens', 2], ['pistol', 0.4],
  ],
};
