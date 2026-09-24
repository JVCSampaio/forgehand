# Stackhead — Economia

Todos os números vivem em `src/shared/Config/*`. A matemática vive em
`src/shared/Economy.luau`, `Wobble.luau` e `Orders.luau` (puros, testados).
Para rebalancear: edite a config e rode `lune run tools/economy_sim.luau`.

## Fórmulas

**Pagamento ao bancar**

```
payout = Σ(valor_item × raridade) × altura(n) × multiplicador_moedas
altura(n) = min(1 + 0.05·n, 16)            -- 20 itens = ×2, 100 = ×6, teto em 300
raridade: normal ×1, shiny ×5 (3,5%), golden ×25 (0,6%)   (Golden Hour: chances ×5)
multiplicador_moedas = 2x pass × VIP 1.2 × Premium 1.1 × boost 2
```

Como o valor da pilha já cresce com n, o total cresce ~n²: **ir mais alto é
sempre tentador**. O que segura é o wobble.

**Wobble (risco)**, a cada tick de 0,1 s no servidor:

```
fator(h) = ((h − 8) / 29) ^ 1.5            -- h = altura da pilha em studs; 0 abaixo de 8
ganho    = (|Δv|·0.0045 + velocidade·0.002·dt + pulo·0.16) × fator(h) / balance
perda    = (parado ? 0.34 : 0.07) × balance × dt
balance  = 1 + 0.15 · nível_Balance         -- nível 40 = ×7
wobble ≥ 1 → desaba (fica a metade de baixo; glue salva uma vez)
esbarrão = 0.55 × fator(h_alvo) / balance_alvo
```

| altura (studs) | fator |
|---|---|
| 20 | 0.27 |
| 36 | 0.95 |
| 72 | 3.28 |
| 135 | 9.16 |

Até ~20 itens é seguro; 40 pede cuidado; 80+ pede paradas e Balance.
Itens baixos (caixas de pizza, esquis, pranchas, cartuchos) rendem as maiores
pilhas em contagem: é uma estratégia emergente de propósito.

## Mundos e tiers

Cada mundo tem 4 anéis (26–85, 85–150, 150–220, 220–290 studs do banco). O tier
N exige Strength N; os níveis 5, 9 e 13 abrem um mundo novo.

| tier | mundo | zona | valor médio | altura média | custo do Strength |
|---|---|---|---|---|---|
| 1 | Stackville | Market Street | 2 | 0.91 | — |
| 2 | Stackville | Yard Sale | 8 | 1.84 | 690 |
| 3 | Stackville | Old Farm | 21 | 1.75 | 4.1K |
| 4 | Stackville | The Docks | 82 | 2.52 | 18K |
| 5 | Frostpeak | Snowy Village | 213 | 1.13 | 99K |
| 6 | Frostpeak | Ski Lodge | 605 | 1.24 | 1.4M |
| 7 | Frostpeak | Ice Caves | 1.5K | 1.54 | 5.8M |
| 8 | Frostpeak | The Summit | 4.3K | 2.02 | 8.4M |
| 9 | Candy Coast | Sweet Street | 9.3K | 1.39 | 17M |
| 10 | Candy Coast | Bakery Row | 25K | 1.72 | 91M |
| 11 | Candy Coast | Sugar Beach | 67K | 1.34 | 270M |
| 12 | Candy Coast | Candy Pier | 187K | 2.26 | 640M |
| 13 | Neon City | Arcade Street | 433K | 0.96 | 900M |
| 14 | Neon City | Tech Mall | 1.2M | 1.55 | 5.6B |
| 15 | Neon City | Robot Factory | 3.1M | 2.37 | 21B |
| 16 | Neon City | Skyline | 8.6M | 1.47 | 41B |

Os valores sobem ~2,6× por tier. Ao abrir um mundo, a renda salta (momento de
"uau"), e os custos seguintes foram calibrados para cada anel durar o tempo alvo.

## Outros sinks e fontes

| | Detalhe |
|---|---|
| Speed (12 níveis) | 40 · 1.75^n, 16 → 31 walk speed |
| Reach (12 níveis) | 30 · 1.7^n, 5 → 14.6 studs |
| **Balance (40 níveis)** | 60 · 1.6^n, último nível 5.5B, total 14.6B: o sink de longo prazo |
| Pedidos diários | 3/dia; recompensa = 120/200/350 × escala do tier (+1 glue no terceiro) |
| Recompensa diária | 7 dias em ciclo, moedas × escala do tier |
| Recordes | 10, 25, 50, 100, 200, 350, 500, 750, 999 itens → título + glue |
| Coleção | 68 itens × 3 raridades = 204 descobertas, bônus de 3× o valor na primeira |

## Ritmo simulado

`tools/economy_sim.luau`: um bot joga o código real, escolhe o tamanho de pilha
ótimo para os stats que tem, anda com curvas e para quando o wobble passa de 0,6.
Os custos de Strength foram calibrados automaticamente contra estes alvos (minutos
de bot em cada tier): 2, 7, 15, 30 | 12, 15, 20, 30 | 15, 18, 22, 35 | 18, 22, 28.
**O bot é um otimizador perfeito; humanos devem levar ~2–3× mais.**

```
   0.2 min  First bank: 6 items, +58 coins
   1.9 min  Strength 2 -> Yard Sale
   9.1 min  Strength 3 -> Old Farm
  25.5 min  Strength 4 -> The Docks
  53.9 min  Strength 5 -> NEW WORLD Frostpeak
  90.0 min  Strength 8 -> The Summit
 133.3 min  Strength 9 -> NEW WORLD Candy Coast
 221.1 min  Strength 13 -> NEW WORLD Neon City
 289.9 min  Strength 16 -> Skyline
```

| marco | bot | humano estimado |
|---|---|---|
| 1ª recompensa | 12 s | ~30 s |
| zona nova (Yard Sale) | 2 min | ~5 min |
| 2º mundo (Frostpeak) | 54 min | ~2 h (sessão 2–3, dia 2) |
| 3º mundo (Candy Coast) | 2,2 h | ~5 h (dias 3–5) |
| 4º mundo (Neon City) | 3,7 h | ~9 h (semana 1–2) |
| todos os anéis | 4,8 h | ~12 h |
| Balance 40, recorde 999, coleção 204 | muito além | semanas |

Suposições do modelo: zonas perto do teto de itens; taxa de coleta limitada a
1,5 item/s; sem outros jogadores competindo e sem esbarrões.

## Riscos a monitorar com dados reais

- Se `Stack5 → FirstBank` cair: o guia/feixe até o banco não está claro.
- Se `Collapse` antes do 1º banco for comum: aumentar `SafeHeight`.
- Se muitos param logo antes de um mundo novo: baixar o custo do nível 5/9/13.
- A renda cresce ~×40 por mundo; se números enormes confundirem, trocar a
  formatação para sufixos maiores (já suportado até Qi).
