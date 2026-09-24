# Stackhead — Economia

Todos os números vivem em `src/shared/Config/*`. A matemática vive em
`src/shared/Economy.luau` e `src/shared/Wobble.luau` (puros, testados).
Para rebalancear: edite a config e rode `lune run tools/economy_sim.luau`.

## Fórmulas

**Pagamento ao bancar**

```
payout = Σ(valor_item × raridade) × altura(n) × multiplicador_moedas
altura(n) = min(1 + 0.05·n, 11)            -- 20 itens = ×2, 100 = ×6, teto em 200
raridade: normal ×1, shiny ×5 (3,5%), golden ×25 (0,6%)
multiplicador_moedas = 2x pass × VIP 1.2 × Premium 1.1 × boost 2
```

Como o valor da pilha já cresce com n, o total cresce ~n² → **ir mais alto é
sempre tentador**. O que segura é o wobble.

**Wobble (risco)**, a cada tick de 0,1 s no servidor:

```
fator(h) = ((h − 8) / 29) ^ 1.5            -- h = altura da pilha em studs; 0 abaixo de 8
ganho    = (|Δv|·0.0045 + velocidade·0.002·dt + pulo·0.16) × fator(h) / balance
perda    = (parado ? 0.34 : 0.07) × balance × dt
balance  = 1 + 0.22 · nível_Balance         -- nível 20 = ×5.4
wobble ≥ 1 → desaba (fica a metade de baixo; glue salva uma vez)
esbarrão = 0.55 × fator(h_alvo) / balance_alvo
```

| altura (studs) | ≈ itens do Market | fator |
|---|---|---|
| 10 | 11 | 0.02 |
| 20 | 22 | 0.27 |
| 36 | 40 | 0.95 |
| 50 | 55 | 1.74 |
| 72 | 80 | 3.28 |
| 100 | 110 | 5.65 |
| 135 | 150 | 9.16 |

Intenção: até ~20 itens é seguro; 40 pede cuidado; 80+ pede paradas
frequentes e Balance; 150+ é para quem domina o jogo (ou usa itens planos).

## Tiers

| tier | zona | valor médio | altura média | valor/stud |
|---|---|---|---|---|
| 1 | Market Street | 1.8 | 0.91 | 2.0 |
| 2 | Yard Sale | 7.6 | 1.84 | 4.1 |
| 3 | Old Farm | 20.9 | 1.75 | 11.9 |
| 4 | The Docks | 82.0 | 2.52 | 32.6 |

Zonas mais valiosas ficam mais longe do banco (anéis 26–85, 85–150, 150–220,
220–290 studs): mais tempo carregando a pilha, mais exposição a esbarrões.

## Custos

`custo(nível) = Base × Crescimento^nível`

| upgrade | primeiros níveis | último nível | total | efeito |
|---|---|---|---|---|
| Speed (12) | 40, 70, 123 | 18.857 | 43.948 | 16 → 31 walk speed |
| Reach (12) | 30, 51, 87 | 10.282 | 24.928 | 5 → 14.6 studs |
| Balance (20) | 60, 93, 144 | 248.001 | 698.803 | ×1 → ×5.4 |
| Strength (3) | 400 | 60.000 | 65.400 | zonas 2, 3, 4 |

Balance é o sink de longo prazo: é o que permite pilhas recorde.

## Ritmo simulado

`tools/economy_sim.luau`: um bot joga o código real. Ele escolhe o tamanho
de pilha ótimo para seus stats, anda com curvas a cada ~1,5 s e para quando
o wobble passa de 0,6. As duas primeiras viagens seguem o guia (6, depois 12
itens). **O bot é um otimizador perfeito; humanos devem levar ~2–3× mais.**

```
   0.2 min  First bank: 6 items, +58 coins
   0.2 min  First upgrade: Reach
   0.5 min  Record 10 stack (Stacker)
   1.9 min  Record 25 / 50 stack
   1.9 min  Strength 2 -> unlocks Yard Sale
   9.1 min  Strength 3 -> unlocks Old Farm
  20.1 min  Record 100 stack (Skyscraper)
  33.5 min  Strength 4 -> unlocks The Docks
  60   min  ~13k coins/min, Balance 18/20
```

| meta do brief | bot | humano estimado |
|---|---|---|
| 1ª recompensa < 30 s | 12 s | ~30 s |
| 1º upgrade relevante 2–5 min | 0,2 min (Reach), 1,9 min (zona nova) | ~1 min / ~5 min |
| grande mudança perceptível 10–15 min | 9 min (Farm) | ~20 min |
| meta de 2ª sessão | Docks aos 33 min | ~1–1,5 h |

Suposições do modelo: zonas perto do teto de itens; taxa de coleta =
densidade × largura do alcance × velocidade, com teto de 1,5 item/s; sem
outros jogadores competindo; sem esbarrões.

## Riscos a monitorar com dados reais

- Se `Stack5 → FirstBank` cair: o guia/feixe até o banco não está claro.
- Se `Collapse` antes do 1º banco for comum: aumentar `SafeHeight`.
- Se pouca gente comprar Strength 3: baixar `Costs[2]` ou subir o valor do tier 3.
- A renda do late game (~13k/min) é financiada principalmente por Balance; quando
  alguém maxar tudo, o próximo sink é conteúdo (zona 5) ou prestígio.
