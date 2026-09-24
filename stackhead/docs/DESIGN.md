# Stackhead — Game Design

> **Empilhe tudo na cabeça. Quanto mais alto, mais vale. Se balançar demais, desaba.**

Este documento guarda as decisões de produto. O estado de implementação fica em
[`../PROJECT_STATE.md`](../PROJECT_STATE.md); a matemática da economia, em
[`ECONOMY.md`](ECONOMY.md).

---

## 1. Leitura de mercado (set/2026)

Fontes: buscas na web em 24/09/2026 (resumos de blogs e agregadores; não
tive acesso direto aos charts da Roblox). **Números são de terceiros e não
verificados; conclusões marcadas como _inferência_ são minhas.**

| Sinal | O que vi | Princípio extraído |
|---|---|---|
| **Grow a Garden** (2025) segue entre os maiores de 2026; bilhão de visitas mais rápido da história (33 dias) | loop idle de crescer + mutações raras + eventos de clima para o servidor inteiro | eventos síncronos no servidor criam "momentos"; raridades geram screenshots |
| **+1 Speed Keyboard Escape** (jan/2026): ~6 bi de visitas, pico de ~6,3 mi CCU num show em jul/2026 | uma regra só ("cada passo = +1 velocidade"), ASMR de teclado | **uma regra entendida em 1 segundo** + número subindo + som satisfatório |
| **99 Nights in the Forest**: pico ~442 mil CCU no início de 2026 | co-op de sobrevivência | social cooperativo sustenta sessões longas |
| **Steal a Brainrot / Steal An Egg** | base + roubar dos outros | tensão social leve gera drama e clipes |
| **Animal Hospital** (mai/2026), horror co-op | | horror/co-op segue quente |
| Blogs apontam luta/anime como gênero que mais cresce | | gênero saturado e caro de produzir para 1 dev |
| **"Be a Tornado"** já existe (~69 mi visitas) | | descartei meu primeiro conceito (ser um tornado) por isso |

**Saturado (_inferência_):** simulators de pet/rebirth genéricos, clones de
brainrot, obbies, anime fighters, tycoons de botão.

**Subexplorado (_inferência_):** jogos de **risco físico legível** (algo que
pode dar errado de forma engraçada) com progressão incremental. A maioria dos
incrementais não tem "falha"; a maioria dos jogos de física não tem economia.

---

## 2. Os 10 conceitos

1. **Stackhead** — Tudo que você pega vai pra cima da sua cabeça; quanto mais alta a pilha, mais vale — se balançar demais, desaba.
2. **Be the Storm** — Você é um tornado que cresce engolindo a cidade. *(já existe: "Be a Tornado")*
3. **Magnet Kid** — Todo metal que você toca gruda em você até você virar uma bola de carros.
4. **Balloon House** — Estoure os balões dos outros para sua casa subir para céus mais ricos.
5. **Domino Town** — Monte dominós pela cidade; quanto maior a reação em cadeia, mais cada peça paga.
6. **Snowball Hill** — Role uma bola de neve montanha abaixo que cresce com tudo que esmaga.
7. **Kaiju Egg** — Alimente um ovo com qualquer coisa da cidade até chocar um monstro feito do que ele comeu.
8. **Sky Tower** — O servidor inteiro empilha UMA torre bamba até a lua; seu bloco no topo te paga até ela cair.
9. **Tide Castle** — Construa seu castelo de areia antes da maré; cada onda sobrevivida paga mais.
10. **Lightning Jar** — Tempestades no servidor; capture raios em potes para alimentar máquinas.

## 3. Escolha: **Stackhead**

Por que este e não os outros:

- **Hook instantâneo.** Uma imagem de um avatar com uma torre de 100 objetos
  na cabeça se explica sozinha. Zero texto.
- **Fantasia dupla:** ganância (_só mais um item..._) e absurdo (carregar
  porcos, TVs e carros empilhados).
- **Progresso fisicamente visível.** A altura da pilha É o placar, visível
  do outro lado do mapa, para todos.
- **Risco/recompensa real.** O multiplicador cresce com a altura, e a chance
  de desabar também. Todo momento tem uma decisão: "banco agora ou vou mais alto?"
  É isso que falta nos incrementais saturados.
- **Social que nasce do loop.** Desabou? Seus itens caem no chão e qualquer um
  pega. Um jogador pequeno pode dar um *dash* num gigante e derrubá-lo
  (Davi vs. Golias). O banco é zona segura e ponto de encontro.
- **Clipe de 10 segundos pronto:** a torre de 200 itens oscilando, um
  esbarrão, e tudo chovendo sobre o servidor.
- **Barato de produzir.** Itens são primitivas (5–20 linhas de config cada),
  o mapa é gerado por código, sem animações nem NPCs.
- **Conteúdo novo é trivial:** um item = uma entrada de tabela; uma zona = um
  anel na config.

Tornado e Magnet têm hooks parecidos mas já existem ou exigem física pesada.
Domino e Sky Tower são ótimos para clipes, mas construção no mobile é chata.
Kaiju exige arte modular cara.

## 4. Elevator pitch

Em **Stackhead**, tudo em que você encosta vai parar em cima da sua cabeça.
Leve sua torre bamba até o banco no centro da cidade: quanto mais alta, maior
o multiplicador. Mas curvas, pulos e esbarrões de outros jogadores fazem a
pilha balançar, e se ela cair, qualquer um pode pegar o que caiu.

## 5. Core loop

```
ANDAR ENCOSTANDO EM ITENS      (ação, 0–5 s: primeiro item na mão)
        ↓
A PILHA CRESCE + SOM SOBE      (recompensa imediata, pitch sobe a cada item)
        ↓
MULTIPLICADOR SOBE ↔ WOBBLE SOBE   (decisão: continuar ou bancar?)
        ↓
BANCAR NO CENTRO → CHUVA DE MOEDAS  (recompensa grande, primeira em ~30 s)
        ↓
UPGRADE (Speed / Reach / Balance / Strength)
        ↓
PILHAS MAIS ALTAS + ZONA NOVA COM ITENS MAIS PESADOS E VALIOSOS
        ↓
DESAFIO MAIOR: mais longe do banco, pilhas mais altas, outros jogadores
```

Compreensível em < 20 s: "pega → empilha → leva pro centro → $$$".

## 6. O hook ("a coisa daquele jogo")

**A pilha bamba na cabeça que pode desabar.** Ela aparece no segundo 3.
O wobble é simulado no servidor a partir do movimento real (aceleração,
curvas, pulos, esbarrões), escalado pela altura. O cliente mostra a pilha
envergando como macarrão, um medidor e um vento que sobe de volume. O
jogador *sente* o perigo antes de ler qualquer coisa.

Pequenos sistemas emergentes que saem daí sem conteúdo extra:
- **Caixas de pizza são planas**: pilhas de 300 pizzas batem recordes de contagem. Jogadores vão descobrir isso.
- **Itens altos valem mais, mas desestabilizam**: carregar 3 carros é uma decisão.
- **Zona mais valiosa = mais longe do banco = mais tempo exposto.**

## 7. Retenção

| Escala | O que puxa |
|---|---|
| **Micro (segundos)** | cada item: som com pitch subindo, número na cabeça, multiplicador |
| **Sessão (5–30 min)** | upgrades; Strength 2 desbloqueia a 2ª zona (~2 min bot / ~5 min humano); Strength 3 (~9 / ~20 min) |
| **Meta (horas/dias)** | Strength 4 / Docks (~35 min bot, meta de 2ª sessão); Balance tem 20 níveis caros; coleção de 60 descobertas (20 itens × normal/shiny/golden) |
| **Aspiracional (semanas)** | recordes de pilha com títulos (10 → 500), leaderboard global "Tallest Stacks", itens golden (0,6%) |

**Por que voltar amanhã:** sequência de login de 7 dias (moedas escaladas
pela tier + glue grátis), um recorde que ficou *quase* lá, a zona seguinte
que custa um pouco mais do que deu para juntar, e a coleção incompleta.
Nenhum timer do tipo "espere 8 h ou pague".

## 8. Monetização

Princípio: **o jogador gratuito joga tudo.** Robux compra conveniência,
aceleração, cosméticos e momentos sociais. Nada de loot box paga, pop-up
automático, preço falso ou timer de espera. A loja só abre quando o jogador
toca no botão.

| Faixa | Produto | Tipo | Preço inicial (R$) | Por que alguém compra |
|---|---|---|---|---|
| Impulso | **3 Glue** | Dev Product | 25 | salvar uma pilha recorde *agora* (glue também é ganha de graça) |
| Pequena | **Rainbow Trail** | Pass | 49 | cosmético visível |
| Pequena | **2x Coins 15 min** | Dev Product | 49 | acelerar uma sessão |
| Pequena | **Coin Pouch** | Dev Product | 49 | moedas escaladas pela tier atual |
| Média | **Item Rain** | Dev Product | 99 | **produto social**: chove item para o servidor inteiro, com o nome do comprador anunciado |
| Média | **Magnet Hands** | Pass | 99 | +3 de alcance (conveniência) |
| Média | **10 Glue** | Dev Product | 79 | consumível em quantidade |
| Premium | **VIP** | Pass | 199 | +20% moedas, tag, glue diária extra |
| Premium | **2x Coins** | Pass | 299 | aceleração permanente |
| Alto valor | **Coin Vault** | Dev Product | 399 | para quem já está engajado |
| Futuro | skins de "base da pilha", efeitos de desabamento, emotes | Pass/Product | 49–199 | expressão |

- **Private servers:** baratos (sugestão 100 R$/mês) para empilhar com amigos sem esbarrões de estranhos.
- **Premium:** +10% moedas e +1 glue diária (incentiva Premium Payouts por engajamento).
- Preços iniciais seguem a faixa de 25–75 R$ recomendada por guias de 2026 para jogos novos; subir só depois de dados. Ativar a precificação gerenciada/regional da Roblox quando disponível.

## 9. MVP (o que está construído)

- 1 mapa circular gerado por código: banco no centro + 4 anéis (Market, Yard Sale, Old Farm, Docks)
- 20 itens em 4 tiers, com variantes Shiny (5×) e Golden (25×)
- Loop completo: pegar → empilhar → wobble → bancar / desabar
- 4 upgrades (Speed, Reach, Balance, Strength)
- Social: dash + esbarrão, itens caídos viram loot livre, anúncio de pilhas grandes, leaderboard global, Item Rain para o servidor
- Save com session lock, autosave, BindToClose, migração, sanitização
- Recompensa diária, recordes com títulos, coleção
- Loja (passes + produtos) com recibos idempotentes
- Funil de analytics
- UI mobile-first, guia contextual sem parede de texto

## 10. Primeiros minutos (FTUE)

1. Spawn **ao lado** de itens, olhando para fora do centro. Nenhum menu.
2. Guia: *"Walk into items to stack them on your head!"* + highlight no item mais próximo.
3. 5 itens → *"Carry your stack to the BANK in the middle!"* + feixe dourado até o banco.
4. Primeiro banco: popup contando moedas + bônus de primeira entrega (paga o 1º upgrade).
5. *"Open UPGRADE and buy your first upgrade!"* (badge vermelho no botão).
6. Primeira vez que o wobble passa de 65%: *"STAND STILL to steady your stack!"*
7. Strength disponível → *"Buy Strength to unlock Yard Sale!"*

## 11. Social

- **Dash + esbarrão:** empurrão com cooldown; o alvo recebe wobble proporcional à *própria* altura. Pequenos derrubam gigantes; gigantes que dão dash se desestabilizam.
- **Proteções:** banco é zona segura, imunidade de 3 s após ser atingido, nenhum esbarrão logo após teleporte, Balance e glue.
- **Loot caído:** os itens de uma pilha desabada ficam 25 s no chão para qualquer um (o dono espera 1,5 s).
- **Show-off:** número acima de cada pilha, título do recorde, anúncio para o servidor de bancos ≥ 40.
- **Item Rain:** evento coletivo a cada 9 min ou comprado por alguém.
- **Trading:** fora do MVP de propósito (risco de dupe/scam sem benefício ao loop).

## 12. Viralidade: os clipes

- A torre de 150 itens envergando, a trilha sonora do vento subindo… **CRASH** e tudo chovendo.
- Um noob dando dash num gigante perto do banco.
- "Carreguei 3 carros e um porco dourado na cabeça."
- Time-lapse de 0 → 300 caixas de pizza.
- Item Rain com 12 jogadores correndo.

## 13. Arte

Low-poly de primitivas, cores saturadas, contorno de UI grosso, fonte
FredokaOne. Cada tier tem uma cor de chão. Raridade é legível (shiny =
vidro brilhante, golden = folha dourada + partículas). Nada de realismo.

## 14. Thumbnail / ícone

- **Ícone:** close do avatar olhando pra cima, com uma torre de itens coloridos saindo do quadro; um porco dourado no meio.
- **Thumbnail 1:** avatar pequeno no chão ↔ torre enorme (seta "1 → 200"), pilha curvada, moedas explodindo.
- **Thumbnail 2 (A/B):** a torre desabando sobre outros jogadores, "💥 CRASH!".
- Texto máximo de 2 palavras: **"STACK IT"**, **"DON'T DROP IT"**.

## 15. Nome e descoberta

- **Nome:** *Stackhead* (curto, pronunciável, busca "stack"). "Tall Order" foi descartado (jogo de VR na Steam).
- **Título na Roblox:** `Stackhead 📦 Stack Everything!`
- **Descrição (vende a fantasia):** "Everything you touch goes on your head. The taller your stack, the more it's worth… if it doesn't fall! Stack pizzas, pigs, TVs and even cars, bank your tower in the middle of town, and watch out for other players trying to knock you over!"
- **Keywords:** stack, tower, balance, wobble, simulator, carry, funny, physics.
- **Trailer de 15 s:** 0–3 s pega o 1º item; 3–8 s time-lapse até 100; 8–12 s esbarrão + desabamento; 12–15 s "+12,480" e logo.
- **Vídeos verticais:** fails de desabamento; recordes; "tier list" de itens.

## 16. Analytics (funil)

Onboarding (`AnalyticsService:LogOnboardingFunnelStepEvent`, só na 1ª sessão):
`Joined → FirstPickup → Stack5 → FirstBank → FirstUpgrade → Played5Min → UnlockedYard → Played10Min → Stack25 → UnlockedFarm`

Outros eventos: economia (fontes: Bank, Daily, IAP; sinks: cada upgrade), progressão (Strength N),
custom: `Collapse` (tamanho), `BankStack`, `Bump`, `GlueSave`, `ReturnSession` (dias desde a 1ª visita),
`SessionMinutes`, `DailyStreak`, `Purchase_*`, `PassPurchase_*`.

Não coletamos chat, texto livre nem dados pessoais.

**Gargalos a observar:** queda entre `Stack5` e `FirstBank` (jogador não acha o banco);
`Collapse` antes do 1º banco (wobble cedo demais); tempo entre `FirstUpgrade` e `UnlockedYard`.

## 17. Áudio

| Evento | Som |
|---|---|
| Pegar item | ping com pitch subindo conforme a pilha cresce |
| Raro | ping agudo + toast |
| Bancar | ping grave + contagem de moedas |
| Upgrade | switch com pitch por nível |
| Wobble | vento em loop, volume = perigo |
| Desabar | impacto 3D audível para quem está perto |
| Dash / esbarrão | swoosh / hit + tremor de câmera |
| Glue | splat |
| Erro | clique grave |

Placeholders usam sons embutidos do engine (`rbxasset://sounds/...`); trocar por
áudio licenciado da Creator Store antes do lançamento (só em `SoundConfig`).

## 18. Live ops: primeiros 30 dias

| Quando | O quê | Decide com |
|---|---|---|
| **Launch** | MVP + 3 produtos (Glue, Item Rain, 2x Coins) + VIP | — |
| **Dia 1** | hotfix: erros de console, gargalos de FTUE, ajuste de `Wobble` | funil `Stack5→FirstBank`, `Collapse` |
| **Semana 1** | 6 itens novos (1 por tier + 2 raros); códigos de resgate | tempo de sessão |
| **Semana 2** | **experimento**: `HeightBonus.PerItem` 0,05 vs 0,06; preço do Glue 25 vs 15 | receita/DAU, retenção D1 |
| **Semana 3** | zona 5 ("Downtown": geladeiras, motos, cofres) + Strength 5 | quantos chegam em Docks |
| **Semana 4** | "Stack Party" (evento de fim de semana 2× Item Rain), cosméticos de base de pilha, prestígio ("Deliver the tower") se o late game estiver vazio | D7, sessões/usuário |

Sistemas ruins saem mesmo que estejam no roadmap.

## 19. A/B testing

Com `ExperimentService`/atributos de servidor quando disponíveis: texto do guia,
`FirstBankBonus`, `HeightBonus.PerItem`, curva do wobble, preço do Glue, thumbnails
e ícone (via ferramentas da Roblox). Nunca esconder informação relevante (odds,
preços) para ganhar métrica.
