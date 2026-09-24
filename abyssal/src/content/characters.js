// Species, backgrounds, skills and spells. Pure data.

export const SKILLS = {
  blades: { name: 'Lâminas', group: 'combate' },
  axes: { name: 'Machados', group: 'combate' },
  maces: { name: 'Maças e Cajados', group: 'combate' },
  polearms: { name: 'Armas de Haste', group: 'combate' },
  unarmed: { name: 'Desarmado', group: 'combate' },
  firearms: { name: 'Armas de Fogo', group: 'combate' },
  throwing: { name: 'Arremesso', group: 'combate' },
  dodging: { name: 'Esquiva', group: 'defesa' },
  armour: { name: 'Armadura', group: 'defesa' },
  shields: { name: 'Escudos', group: 'defesa' },
  stealth: { name: 'Furtividade', group: 'sobrevivência' },
  medicine: { name: 'Medicina', group: 'sobrevivência' },
  survival: { name: 'Sobrevivência', group: 'sobrevivência' },
  spellcasting: { name: 'Conjuração', group: 'magia' },
  fire: { name: 'Magia de Fogo', group: 'magia' },
  ice: { name: 'Magia de Gelo', group: 'magia' },
  air: { name: 'Magia do Ar', group: 'magia' },
  necromancy: { name: 'Necromancia', group: 'magia' },
};

export const SPECIES = {
  human: {
    name: 'Humano',
    desc: 'Versátil. Precisa comer, beber e dormir. Aprende tudo na mesma velocidade.',
    carry: 10, darkvision: 0, skin: 0xc9a383,
    needs: { hunger: 1, thirst: 1, fatigue: 1 },
    aptitudes: {},
  },
  vampire: {
    name: 'Vampiro',
    desc: 'Vê no escuro (4 m). Quase não sente fome, mas sente Sede de Sangue: água não resolve, cadáveres frescos sim. Fogo o fere 50% mais. Regenera quando saciado.',
    carry: 10, darkvision: 4, skin: 0xb9b6c8, fireVuln: 1.5, bloodDrinker: true, regen: 0.02,
    needs: { hunger: 0.15, thirst: 1.1, fatigue: 0.8 },
    aptitudes: { necromancy: 2, stealth: 2, dodging: 1, fire: -2, medicine: -1, ice: 1 },
  },
};

// Starting kits reproduce the opening of the design doc: gambeson, boots, backpack,
// short sword, lantern, 2 bandages, waterskin, food for two days.
export const BACKGROUNDS = {
  relic_hunter: {
    name: 'Caçador de Relíquias',
    desc: 'Espada curta, gambeson, lamparina, 2 bandagens, odre e comida para dois dias. Furtivo e cauteloso.',
    skills: { blades: 2.5, dodging: 3, stealth: 2.5, survival: 2, medicine: 1.5, armour: 1 },
    equip: ['short_sword', 'gambeson', 'boots', 'backpack', 'lantern', 'padded_legs'],
    items: [['bandage', 2], ['waterskin', 1], ['ration', 4], ['whetstone', 1], ['rag', 2]],
    spells: [],
  },
  fighter: {
    name: 'Guerreiro',
    desc: 'Espada longa de duas mãos, cota de malha e elmo. Aguenta pancadas, mas faz barulho e cansa.',
    skills: { blades: 4, armour: 3.5, dodging: 1.5, shields: 1, survival: 1 },
    equip: ['long_sword', 'mail', 'helmet', 'boots', 'backpack', 'lantern', 'padded_legs'],
    items: [['bandage', 2], ['waterskin', 1], ['ration', 3], ['whetstone', 1]],
    spells: [],
  },
  survivor: {
    name: 'Sobrevivente',
    desc: 'Um Colt M1911 com 7 balas e mais 7 soltas. Colete tático, adaga, kit médico. Cada tiro acorda o andar.',
    skills: { firearms: 3.5, medicine: 3.5, stealth: 2, blades: 1.5, survival: 2.5, dodging: 1.5 },
    equip: ['pistol', 'tactical_vest', 'gloves', 'boots', 'backpack', 'lantern', 'padded_legs'],
    items: [['dagger', 1], ['ammo45', 7], ['bandage', 3], ['alcohol', 1], ['suture', 1],
      ['waterskin', 1], ['jerky', 4], ['gas_mask', 1]],
    spells: [],
  },
  mage: {
    name: 'Mago',
    desc: 'Bola de Fogo e Lança de Gelo. Cajado rúnico, manto ritual. Magia forte, mas barulhenta e luminosa.',
    skills: { spellcasting: 3.5, fire: 3.5, ice: 2.5, dodging: 2, maces: 1, air: 1 },
    equip: ['staff', 'robe', 'hood', 'boots', 'backpack', 'lantern'],
    items: [['bandage', 1], ['mana_potion', 1], ['waterskin', 1], ['ration', 3], ['rag', 2]],
    spells: ['fireball', 'frost'],
  },
};

// Spells are simulation participants: noise, light, fire, ice, conduction, corpses.
export const SPELLS = {
  fireball: {
    name: 'Bola de Fogo', school: 'fire', level: 3, mana: 9, cast: 1800, range: 8,
    noise: 35, radius: 1, dmg: { fire: [8, 16] }, projectile: { speed: 14, color: 0xff7a1a },
    key: '1', desc: 'Explode em 3×3. Incendeia óleo, madeira, teias e cadáveres. Ruído 35, clarão.',
  },
  frost: {
    name: 'Lança de Gelo', school: 'ice', level: 2, mana: 5, cast: 1100, range: 7,
    noise: 6, radius: 1, dmg: { cold: [5, 10] }, projectile: { speed: 16, color: 0x9fe6ff },
    key: '2', desc: 'Congela água (piso escorregadio), apaga fogo e retarda o alvo. Silenciosa.',
  },
  lightning: {
    name: 'Arco Voltaico', school: 'air', level: 3, mana: 7, cast: 900, range: 8,
    noise: 18, dmg: { electric: [6, 14] }, key: '3',
    desc: 'Instantâneo. Se o alvo estiver na água, a descarga percorre toda a poça — inclusive você.',
  },
  raise_dead: {
    name: 'Erguer Morto', school: 'necromancy', level: 3, mana: 8, cast: 2200, range: 6,
    noise: 4, target: 'corpse', key: '4',
    desc: 'Um cadáver vira um servo por algumas horas. Cadáver não é decoração: é recurso.',
  },
};

export const NAMES = [
  'Edmund Black', 'Isolde Varga', 'Tomas Reed', 'Mara Quill', 'Aldo Ferreira', 'Brina Holt',
  'Cassius Vey', 'Joana Brasil', 'Oskar Lind', 'Wren Ashby', 'Ilse Moreau', 'Dario Kest',
];
