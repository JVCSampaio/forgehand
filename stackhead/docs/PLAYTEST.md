# Stackhead — Playtest e lançamento

O jogo **ainda não rodou no Roblox Studio**. Tudo até aqui foi verificado fora
do motor (typecheck, testes Lune, simulação de economia, build, verificador de
place e renderizações Three.js). Este roteiro é o que falta antes de qualquer
divulgação paga, na ordem.

## 1. Primeira execução no Studio (solo, ~20 min)

```
rojo build default.project.json -o build/Stackhead.rbxl   # ou rojo serve + plugin
```

Abrir `build/Stackhead.rbxl`, **Test > Play**. Na janela Output não pode haver
erro vermelho. Conferir:

- [ ] Nasce ao lado de itens em Stackville; o guia aparece; pegar item é automático.
- [ ] Pilha cresce com som subindo; o número aparece em cima da cabeça.
- [ ] Feixe até o banco; bancar paga, mostra o popup e zera a pilha.
- [ ] Wobble sobe andando rápido com pilha alta; parar reduz; desaba e metade cai como loot.
- [ ] Upgrades compram e aplicam (Speed muda WalkSpeed, Reach pega de mais longe).
- [ ] WORLDS: mundo liberado viaja; mundo bloqueado aparece como **👀 VISIT** e ao
      visitar nada pode ser levantado (aviso "Items here need 💪 Strength N").
- [ ] Sair e voltar: moedas, upgrades e coleção persistem (ativar *Enable Studio
      Access to API Services* para testar DataStore).

### Torres altas e grandes quedas (sem farmar)

Na **Command Bar** com a visão *Server* ativa:

```lua
game.ServerStorage.StackheadDebug.Fill:Invoke(game.Players:GetPlayers()[1], 400)
```

(Só existe no Studio.) Conferir:

- [ ] Acima de 320 itens a torre continua subindo com segmentos simples coloridos
      (a altura visual acompanha o número).
- [ ] Ao desabar, os 40 itens de baixo viram loot coletável e o resto da torre cai
      como destroços que ficam ~2 s no chão. A cena tem que parecer grande.
- [ ] FPS com a pilha de 400 (View > Performance / MicroProfiler).

## 2. Anti-exploit: depósito por teleporte (obrigatório)

Antes, o servidor pagava se o personagem aparecesse dentro do banco, mesmo por
teleporte. Agora `src/server/Util/MoveGuard.luau` mantém a última posição aceita e
um orçamento de distância; o banco, as coletas e os esbarrões usam só posições
aceitas. Testes: `tests/movement.spec.luau`.

Reproduzir no Studio (Play, visão *Client*, Command Bar):

```lua
local c = game.Players.LocalPlayer.Character
c:PivotTo(CFrame.new(0, 5, 0))      -- centro do banco de Stackville
```

- [ ] Com pilha: o personagem **volta** para onde estava, a pilha leva um tranco e
      **nada é pago**.
- [ ] Repetir o teleporte por 3 s seguidos: o servidor desiste de puxar de volta,
      mas **derruba a pilha inteira** (pagamento 0).
- [ ] Viajar pelo WORLDS e renascer **não** disparam o puxão (movimentos do próprio servidor).
- [ ] Andar, pular, dash e cair de altura normalmente nunca puxam de volta.
- [ ] Com lag simulado (*Studio Settings > Network > Incoming Replication Lag* 0,5 s)
      andar continua sem puxões.

## 3. Multiplayer (2–3 jogadores)

**Test > Clients and Servers**, 3 players.

- [ ] Cada um vê as pilhas dos outros (até 160 itens detalhados + segmentos).
- [ ] Dash + esbarrão sacode/derruba a pilha do outro; os dois recebem o aviso; 3 s de imunidade.
- [ ] Loot caído: o dono espera 1,5 s, outros pegam na hora.
- [ ] Item Rain e Golden Hour aparecem para todos.
- [ ] Desempenho no servidor com os 4 mundos (~12 mil peças de mapa): memória e
      *Heartbeat* no MicroProfiler.

## 4. Celular

Studio **Device Emulator** (iPhone SE e um Android médio) e depois um telefone real
via *Team Test* / publicação privada.

- [ ] Botões Dash/Glue/menus alcançáveis com o polegar; nada cortado pela notch.
- [ ] Texto legível; toasts não cobrem o banco.
- [ ] FPS estável em Stackville e Neon City com outra pessoa por perto.

## 5. Dez minutos com alguém novo (o teste mais importante)

Chamar 3–5 pessoas que nunca viram o jogo. **Não explicar nada.** Observar e anotar:

| Minuto | O que deveria acontecer | Anotar |
|---|---|---|
| 0–1 | pega o 1º item sem ajuda | segundos até o 1º item |
| 1–2 | leva a pilha ao banco | segundos até o 1º banco; se se perdeu |
| 2–5 | compra o 1º upgrade; empilha mais alto | rosto/reação na 1ª queda |
| 5–10 | torre engraçada (20–40 itens), abre Yard Sale, espia outro mundo | quer continuar? |

Perguntas no fim: *"O que você fazia no jogo?"*, *"O que foi mais engraçado?"*,
*"O que te irritou?"*, *"Voltaria amanhã?"*.

### Sinal a observar: "andar e esperar"

A recuperação do wobble depende de ficar parado (`Wobble.RecoverStill` 0,34/s
contra `RecoverMoving` 0,07/s andando). Se as pessoas passam muito tempo **paradas esperando a barra
baixar** em vez de **se sentindo no controle**, o experimento previsto é um
*contrapeso*: andar na direção oposta à inclinação da torre reduz o wobble
(como equilibrar um cabo de vassoura). Só implementar se o teste mostrar tédio;
hoje a tensão de parar pode ser justamente a graça.

## 6. Antes de lançar

```
lune run tools/launch_check.luau          # lista o que falta
lune run tools/launch_check.luau --strict # falha se faltar algo (para CI no dia do lançamento)
```

1. **Monetização:** criar no Creator Dashboard os 6 passes e 8 produtos de
   `docs/MONETIZATION.md` com os preços iniciais e colar os IDs em
   `src/shared/Config/MonetizationConfig.luau`. Com ID 0 o item fica escondido.
2. **Sons:** trocar os 12 placeholders de `SoundConfig.luau` por áudio da Creator
   Store (prioridade: coleta, quase-queda/vento, depósito e desabamento; o meme pede
   um "quack" de pato de borracha).
3. **Página do jogo:** ícone `marketing/icon-512.png`; thumbnails na ordem
   `thumbnail-crash.png` (principal), `thumbnail-tower.png`, `thumbnail-worlds.png`.
   Testar as duas primeiras em A/B de thumbnails assim que houver tráfego.
4. Publicar privado, repetir 1–4 no servidor real, abrir para amigos, só então anúncios.
