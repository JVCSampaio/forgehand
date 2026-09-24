# Stackhead — Monetização

Regra de ouro: **o jogador gratuito joga tudo**. O Robux compra **status visível,
conveniência, aceleração e momentos sociais**, nunca o acesso ao conteúdo.
Tudo que é vendido e dá vantagem também pode ser ganho de graça (glue, moedas,
bases).

Toda compra nasce de um momento do loop:

| Momento do jogador | O que ele quer | Produto |
|---|---|---|
| "Minha torre de 150 vai cair!" | salvar a pilha | **Glue** (também ganha de graça) |
| "Quero que todo mundo veja minha torre" | status | **Bases de pilha**, **Rainbow Trail**, VIP |
| "Tô quase liberando o próximo mundo" | acelerar | **2x Coins** (15 min / permanente), **Coin Pouch** |
| "Tô com amigos no servidor" | ser o herói do servidor | **Item Rain**, **Golden Hour** (anunciam o nome do comprador) |
| "Acabei de entrar e gostei" | começar bem | **Starter Pack** (uma vez só) |

## Catálogo implementado

Os IDs ficam em `src/shared/Config/MonetizationConfig.luau`. Com ID `0` o item fica
escondido e o jogo continua funcionando.

### Game passes (permanentes)

| Pass | Preço inicial | Efeito | Categoria |
|---|---|---|---|
| Rainbow Trail | 49 | rastro colorido | cosmético |
| Magnet Hands | 99 | +3 de alcance | conveniência |
| UFO Saucer Base | 99 | base de pilha disco voador | cosmético (status) |
| Flame Ring Base | 149 | base de pilha em chamas | cosmético (status) |
| VIP | 199 | +20% moedas, Golden Tray, tag, +1 glue/dia | pacote |
| 2x Coins | 299 | moedas em dobro | aceleração |

### Developer products (repetíveis)

| Produto | Preço inicial | Efeito | Por que é saudável |
|---|---|---|---|
| 3 Glue | 25 | salva 3 desabamentos | impulso barato; também ganho em recordes/pedidos |
| Coin Pouch | 49 | moedas × escala do tier atual | nunca fica obsoleto |
| 2x Coins 15 min | 49 | boost temporário | acumula com o pass |
| 10 Glue | 79 | salva 10 desabamentos | melhor valor por unidade |
| **Starter Pack** | 99 | 10 glue + 30 min de 2x + base Starter Crate | oferta única e clara, some depois da compra |
| **Item Rain** | 99 | chuva de itens para o servidor inteiro | social: todos ganham, o comprador aparece |
| **Golden Hour** | 149 | 10 min de raros ×5 para o servidor | social + caça aos dourados |
| Coin Vault | 399 | moedas × escala do tier | para quem já está engajado |

### Private servers
Recomendado: **100 R$/mês**. Empilhar com amigos sem esbarrões de estranhos é um
motivo real para pagar.

### Premium
+10% de moedas e +1 glue por dia para assinantes Premium, que também geram
Premium Payouts pelo tempo de jogo.

## Escada de preços

```
25 ──── 49 ──── 99 ──── 149 ──── 199 ──── 299 ──── 399
glue    trail   starter golden   VIP      2x       vault
        boost   rain    flame             coins
        pouch   ufo
```

- **Impulso (25–49):** glue, boost, trail. Decisão de meio segundo, no momento do risco.
- **Pequena (79–99):** starter pack, item rain, bases. Status + social.
- **Média (149–199):** golden hour, VIP.
- **Premium (299–399):** 2x coins, vault. Para jogadores de muitas horas.

Os preços são hipóteses iniciais. Com dados: use o Price Optimization / regional
pricing da Roblox e compare receita por DAU, não só conversão.

## Onde as compras aparecem (e onde não aparecem)

- A loja **só abre quando o jogador toca em SHOP**. Não existe pop-up automático.
- O Starter Pack fica no topo da loja até ser comprado; depois some.
- Bases pagas aparecem junto com as ganhas, com o requisito sempre explícito
  ("Bank a 100 stack", "Unlock Frostpeak"). O jogador sabe o que dá para ganhar jogando.
- Item Rain e Golden Hour anunciam o nome do comprador para o servidor: status
  positivo, sem constranger quem não compra.

## O que não fazemos (de propósito)

- **Loot box paga / gacha.** Nada de odds pagas. Raridade só vem de jogar.
- **"Espere X horas ou pague."** Nenhum timer bloqueia progresso.
- **Vender progresso de mundo.** Strength e mundos só com moedas ganhas no jogo.
- **Falsa escassez / falsa promoção.** Sem "só hoje!" fabricado.
- **Vender títulos de recorde.** Títulos provam habilidade; comprar estragaria isso.
- **Trading.** Risco de golpe/dupe sem ganho real para o loop.

## Próximos passos (em ordem de impacto esperado)

1. **Stack Pass (temporada de 30 dias).** Trilha gratuita e trilha premium (produto
   por temporada, ~299 R$), avançada pelos pedidos diários e por itens bancados.
   Recompensas: bases, rastros, efeitos de desabamento e glue. É o maior motor de
   receita recorrente sem ser pay-to-win.
2. **Efeitos de desabamento** (confete, fogos, "PLOP" gigante): transforma a falha
   em show, que é o clipe viral do jogo. Pass de 79–149.
3. **Presentear** glue ou boost para um amigo do servidor (dev product com alvo
   guardado no servidor).
4. **Anúncios recompensados**, se a conta for elegível: vídeo opcional por 1 glue,
   no máximo 1 por dia.
5. **Pacotes de mundo** (cosméticos temáticos de Frostpeak, Candy e Neon) a cada
   atualização de conteúdo.

## Métricas para acompanhar

- Conversão por produto e onde o jogador estava quando comprou (tier, mundo, tamanho da pilha).
- `GlueSave` × compras de glue: se ninguém usa glue ganho, o risco está baixo demais.
- Receita por DAU nos dias de Item Rain / Golden Hour comprados (efeito social).
- Retenção D1/D7 de quem comprou o Starter Pack × quem não comprou (o pack não pode
  canibalizar o progresso).
