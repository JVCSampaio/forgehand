# Ajustes após a gravação — Playtest 02

Implementação baseada na gravação de 44 segundos enviada em 25/09/2026.

- Câmera de jogo limitada a 34 studs, foco com elevação suave limitada a 3 studs.
  C / R3 / VIEW TOWER alterna a visão da torre; andar, morrer, depositar ou
  renascer devolve a visão de jogo. Mantém a câmera padrão e sua oclusão.
- Quantidade/valor/multiplicador centralizados; canto da lista de jogadores livre.
  FALL RISK separado do STABILIZE ON/OFF; mensagem antiga de queda corrigida.
- Um aviso por vez, memes espaçados e resumo único do depósito. Descobertas não
  geram uma pilha de avisos. Recompensa de marco aparece depois do depósito.
- Seis contornos locais no máximo, apenas em itens próximos e coletáveis.
  Itens caídos recebem destaque verde por oito segundos; bloqueados mostram a
  força necessária e achados especiais indicam a chance de raridade.
- Rotas de itens comuns próximas dos eixos das ruas e tentativas de agrupamentos
  fora delas (20% das gerações, chance de raridade dobrada). Mantém espaçamento,
  obstáculos e limite de itens; usa posição aleatória como fallback se necessário.
- Próxima área mostra moedas faltantes; clicar no objetivo abre upgrades.
- Oscilação visual cresce com o risco e respeita movimento reduzido. Postes
  sem material Neon, placas menores, grama e iluminação menos saturadas.
- Câmera próxima permite ver as bases cosméticas; visão da torre é opcional.

Validação: 68 testes passaram; luau-lsp sem erros; Rojo compilou o arquivo
build/Stackhead-Playtest-02.rbxl; verificação de 164 requires sem falhas.

Não foi feita validação interativa desta versão no Studio. Testar:
1. Caminhar/coletar com 0, 10, 50 e 100+ itens; C e retorno ao andar/depositar.
2. Girar a câmera perto de casas/postes, respawn, touch e R3 no controle.
3. Lista de jogadores aberta; telas 1920x1080, 390x844 e 844x390.
4. Estabilização ligada/desligada, queda, recuperação e movimento reduzido.
5. Depósito com várias descobertas, marco e recompensa cosmética simultâneos.
6. Rotas e desvios: conferir se a coleta permanece fluida e o bônus não acelera
   demais a economia. A simulação antiga não mede este novo padrão espacial.

Abra o arquivo Playtest-02, pois o arquivo anterior foi preservado. Mudanças
locais feitas diretamente em um place do Studio não foram importadas nem
sobrescritas por esta edição do repositório.
