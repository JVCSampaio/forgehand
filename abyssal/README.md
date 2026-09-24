# Abyssal Dungeon — fatia vertical jogável

> Project Zomboid dentro de um dungeon crawler de fantasia sistêmico como DCSS.
> Project Zomboid define como o mundo é vivido. DCSS define as decisões que o jogador toma.

Demo 3D isométrica que roda no navegador (Three.js, sem build), feita para validar os
sistemas do conceito antes de investir no pipeline Unity + assets. Branch **Fortaleza
Esquecida**, 5 andares procedurais, 8 inimigos + chefe, permadeath.

```bash
cd abyssal
npm start          # servidor estático em http://localhost:8080 (ES modules exigem http://, não file://)
npm test           # testes da simulação, headless (node --test)
```

Qualquer servidor estático serve (`python -m http.server` também). Three.js r170 está em
`vendor/`, então funciona offline. `?seed=123&autostart=1&bg=mage&species=vampire` pula a
tela inicial.

## Avaliação do conceito

A reformulação é muito mais forte que o Abyssus anterior, e a regra central
("Zomboid = como o mundo é vivido; DCSS = as decisões") se sustentou na implementação:
quase todo sistema se encaixou em uma das duas metades sem conflito. O que aprendi
construindo:

1. **Continuous Roguelike Time é o coração técnico, e funciona.** Um único relógio de
   simulação (ticks de 20 ms) com ações que têm duração e *ponto de efeito* (o golpe de um
   troll aterrissa aos 61% dos 1800 ms). Esse ponto de efeito é o que torna a pausa tática
   significativa: os rótulos mostram `Aranha → preparando bote 62%`,
   `Mago Cultista → conjurando Seta Sombria 40%`, e dá para reagir: sair do alcance
   (o golpe acerta o ar), interromper o conjurador (acertá-lo quebra a concentração) ou
   responder com magia.
2. **A tabela de tempos do documento precisa ser relativa, não absoluta.** "Andar uma
   célula 100 ms" é 10 m/s, corrida olímpica. Usei 300 ms andando, 540 ms furtivo,
   monstros de 210 ms (ratazana) a 450 ms (troll). O que importa é a razão entre
   velocidades e tempos de ataque.
3. **Câmera lenta automática cansa.** 0,35× sempre que há perigo é ótimo nos primeiros
   encontros e arrastado em lutas longas. Deixei ligada por padrão com `T` para desligar.
   Vale testar aplicar a lentidão só durante telegrafias (wind-ups inimigos).
4. **Som precisa atravessar pedra para "a pistola acorda o andar" ser verdade.** Com
   propagação só por corredores, um tiro alcançava pouca coisa. Agora pedra atenua forte
   mas transmite: passos (2) não atravessam parede, pistola (30) alcança ~metade de um
   andar 54×54, Bola de Fogo (35) ~dois terços. Portas fechadas e barricadas abafam.
5. **Anatomia localizada vira planilha se não for contida.** Golpes repetidos no mesmo
   membro agravam a mesma ferida em vez de empilhar; cortes rasos coagulam sozinhos;
   laceração profunda, mordida e perfuração exigem bandagem/sutura. Sem isso, o
   sangramento vira um cronômetro de morte e a UI vira uma lista.
6. **Magia sistêmica é onde o conceito brilha.** Bola de Fogo em uma sala com óleo e
   estantes é uma decisão de verdade: incendeia, gera fumaça que bloqueia visão e sufoca,
   destrói loot, faz barulho 35 e clarão. Gelo congela poças (escorregadias) e apaga
   fogo; o Arco Voltaico percorre a água, inclusive até você.
7. **Escopo continua sendo o risco principal.** Mesmo a lista do MVP é grande. O custo
   real no Unity vai ser animação e assets, e por isso o rig humanoide único + soquetes
   de equipamento é a decisão mais importante do plano visual. Aqui todos os humanoides
   (jogador, esqueletos, goblins, cavaleiros, chefe, Esvaziados) usam o mesmo rig.

**Por que web em vez de Unity nesta etapa:** roda sem instalar nada, sobe como link, e a
simulação é testável headless (`npm test`, bots). A arquitetura espelha a proposta do
documento, então portar é mecânico: `sim/` vira classes C# puras, `content/` vira
ScriptableObjects/JSON e `view/` vira MonoBehaviours. Nenhuma regra de jogo está na
camada de apresentação.

## O que está implementado

| Sistema do MVP | Estado | Onde |
|---|---|---|
| Movimento isométrico | ✅ WASD relativo à tela (desliza em paredes), clique para andar (A*) | `main.js`, `sim/world.js` |
| Scheduler em tempo real | ✅ ações com duração + ponto de efeito, mesmo relógio para todos | `sim/world.js` |
| Pausa / câmera lenta | ✅ `Espaço` pausa e enfileira ações; 0,35× automático em perigo | `sim/world.js` |
| Corpo a corpo | ✅ alcance, tempo de golpe, estamina, ruído, durabilidade, crítico em alvo dormindo | `sim/combat.js` |
| Armas de fogo | ✅ Colt M1911, pente de 7, recarga 2,4 s, ruído 30 | `sim/combat.js` |
| Magia | ✅ Bola de Fogo, Lança de Gelo, Arco Voltaico, Erguer Morto; falha % estilo DCSS | `sim/combat.js` |
| Inventário por peso | ✅ capacidade da espécie + mochila, sobrecarga deixa lento e cansa | `sim/entity.js` |
| Equipamento | ✅ 11 slots, visível no modelo 3D (elmo, máscara antigás, colete, mochila, lamparina…) | `view/models.js` |
| Fome / sede / fadiga | ✅ + medo; vampiro troca sede por sede de sangue | `sim/world.js` |
| Ferimentos | ✅ 10 partes, laceração/perfuração/mordida/fratura/queimadura, sangramento, infecção, dor | `sim/body.js` |
| Iluminação | ✅ luz simulada (FOV por fonte) decide visibilidade; lamparina com sombra e óleo finito | `sim/systems.js`, `view/renderer.js` |
| Propagação de som | ✅ Dijkstra atenuado; monstros investigam, você "ouve algo a nordeste" | `sim/systems.js` |
| Salas procedurais | ✅ salas temáticas + 8 vaults feitos à mão + corredores A* | `sim/dungeon.js`, `content/world.js` |
| Sala segura | ✅ portas fechadas e barricadas (tábuas) ou bloqueadas por móvel **arrastado** | `sim/world.js` |
| Permadeath | ✅ epitáfio; o morto volta como *Esvaziado* na profundidade em que caiu, com o equipamento | `sim/world.js`, `sim/dungeon.js` |

Conteúdo: Humano e Vampiro; Caçador de Relíquias (o kit do documento), Guerreiro,
Sobrevivente e Mago; Ratazana, Esqueleto, Goblin, Carniçal, Mago Cultista, Aranha,
Cavaleiro Caído, Troll e o chefe **Castelão Oco**. O Livro de Necromancia fica no andar 2.
Construção de campo: bandagem, tocha, tala, coquetel incendiário, fogueira.

Também entraram, por serem baratos e sistêmicos: a masmorra que lembra (voltar a um andar
depois de horas pode revelar uma porta que "não estava ali"), a masmorra que se
reabastece, portas arrombadas por trolls, monstros que seguem você pela escada e
perícias alocadas por XP como no DCSS (sem grind).

Fora da fatia, de propósito: patronos/deuses, oficinas (forja, alquimia), temperatura,
cultivo de fungos, ward mágico e save no meio da partida.

## Arquitetura

```
src/
├── sim/                 SIMULAÇÃO — não conhece Three.js nem DOM
│   ├── world.js         SimulationClock, scheduler de ações, comandos do jogador, necessidades
│   ├── level.js         SpatialGrid (tiles, superfícies, portas, props), FOV, A*
│   ├── systems.js       NoiseSystem, LightingSystem, EnvironmentSystem (fogo, fumaça, gelo, água)
│   ├── dungeon.js       gerador procedural + vaults
│   ├── entity.js        fábricas de itens, monstros e jogador (componentes em objetos simples)
│   ├── body.js          anatomia, ferimentos, sangramento, infecção
│   ├── combat.js        Melee, Projectile, Magic, DamageResolver
│   ├── ai.js            percepção (visão, audição, olfato, sentido mágico) e decisões
│   └── rng.js           RNG determinístico por seed
├── content/             CONTEÚDO — dados puros
│   ├── items.js         armas, armaduras, consumíveis, receitas, tabelas de loot
│   ├── monsters.js      monstros, perfis de acerto, habilidades telegrafadas
│   ├── characters.js    espécies, origens, perícias, feitiços
│   └── world.js         móveis, temas de sala, vaults ASCII, branch
├── view/                APRESENTAÇÃO — só lê a simulação
│   ├── renderer.js      câmera ortográfica 35°/45°, tiles instanciados, cutaway, luzes, partículas
│   ├── models.js        modelos low-poly procedurais: um rig humanoide + famílias
│   └── ui.js            HUD, corpo, rótulos de intenção, inventário, telas
└── main.js              entrada → comandos, loop de frame
```

Nenhum `if (enemyType == "Goblin")`: o goblin grita porque tem a habilidade `shout` nos
dados; a aranha dá bote porque tem `pounce`; o troll regenera porque tem `regen`, e fogo
suspende a regeneração porque o DamageResolver marca `burnedAt`.

## Controles

| Tecla | Ação |
|---|---|
| `WASD` / setas | mover (relativo à tela) · andar contra um móvel o arrasta |
| clique esquerdo | andar · atacar · abrir/fechar porta · vasculhar |
| clique direito | examinar (óleo, gelo, teia, luz, estado do inimigo…) |
| `Espaço` | pausa tática: escolha a ação, ela acontece ao despausar |
| `T` | liga/desliga câmera lenta automática |
| `1`–`4` | feitiços (tecla duas vezes ou `Enter` mira no inimigo mais próximo) |
| `F` / `R` | atirar / recarregar |
| `Q` | arremessar (óleo, coquetel) |
| `B` | tratar o ferimento mais urgente |
| `X` | barricar porta com tábua |
| `Z` | dormir / esperar (40×) |
| `L` / `V` | lamparina / furtividade |
| `G` / `O` | pegar ou vasculhar / porta mais próxima |
| `Enter` | escadas |
| `E` | alimentar-se de cadáver fresco (vampiro) |
| `I` / `C` / `H` | inventário e construção / personagem e perícias / ajuda |
| `P` | liga/desliga sombras da lamparina (desempenho) |
| roda do mouse | zoom |

## Próximos passos sugeridos

1. Jogar 10 partidas e ajustar: velocidade do sangramento, dano do troll na cabeça
   (hoje 2–3 golpes matam), custo das perícias.
2. Patronos (Carrion Saint, The Lantern, The Maw): conectam sobrevivência e religião e
   cabem nos sistemas já existentes (cadáveres, exploração, fome).
3. Portar `sim/` para C# e começar o pipeline Unity pelo passo 6 do plano visual: um
   preset de iluminação que já faça este greybox ficar bonito.
