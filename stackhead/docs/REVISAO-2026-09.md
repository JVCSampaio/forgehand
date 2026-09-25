# Revisão do Stackhead — 25/09/2026

## O que mudou

- Gameplay: modo STEADY (E, L1 e botão touch) reduz velocidade em troca de
  recuperação do equilíbrio. Dash permanece uma decisão separada; colisões
  continuam perigosas. Tutorial e HUD explicam o controle de risco.
- Progressão: primeiros níveis de Strength mais acessíveis; bandeja de pizza
  grátis ao bater recorde de 10 itens. Primeiro evento de chuva aos 75 segundos,
  recorrência de quatro minutos e contagem regressiva no HUD.
- Loja: prévias 3D das bases, benefícios descritos com clareza e preço consultado
  no Roblox; se a consulta falhar, a interface convida a ver o preço oficial.
  Produtos sem ID não são oferecidos. Nenhuma compra é forçada pelo tutorial.
- Interface: layouts compactos para celular, navegação por controle e menu de
  música, efeitos, sons cômicos e movimento reduzido, com preferências salvas.
- Som: 13 WAVs originais, incluindo buzina de pato, queda, boing, coleta e música.
  Barramentos separados, limite de vozes simultâneas, cooldown e redução da
  música durante efeitos. Arquivos e gerador em assets/audio e tools/audio.
- Visual: partículas na queda, brilho mais controlado, compensação de altura de
  acessórios, novo ícone e três thumbnails. As artes usam os modelos do projeto
  em cenas promocionais Three.js; não são capturas do Roblox Studio.
- Desempenho: mundos construídos conforme o primeiro uso; torre renderizada com
  detalhes nas extremidades e segmentos simplificados no meio, preservando a
  altura total mesmo com 999 itens.
- Integridade: movimentação horizontal implausível é revertida antes de coleta,
  banco ou colisão. Viagens legítimas reiniciam a referência no servidor.
  Repetição de recibo só confirma compra após salvar o perfil com sucesso.

## Verificação feita no PC

- 66 testes Lune aprovados: economia, persistência, cosméticos, equilíbrio,
  movimentos inválidos e altura/limite de objetos na simplificação das torres.
- Análise luau-lsp com definições Roblox e sourcemap: saída 0, sem erros.
- Rojo gerou build/Stackhead.rbxl; verificador resolveu 157 requires sem falhas.
- Simulação determinística de uma hora: Frostpeak em cerca de 18 minutos,
  contra aproximadamente 54 minutos na configuração anterior. Trata-se de um
  bot, não de retenção medida nem de garantia de ritmo para jogadores reais.
- Ícone e thumbnails renderizados e inspecionados visualmente.

## O que depende da experiência Roblox

Roblox Studio não foi localizado neste PC durante a revisão. Portanto não foi
possível validar execução, áudio, interação mobile, compras nem desempenho no
motor. A ausência de erros na análise não prova ausência de bugs em execução.

Os 13 sons originais estão prontos para upload, mas seus IDs continuam em zero.
Até que sejam enviados e autorizados para a experiência, efeitos usam fallback
interno e a música original não toca. Passes/produtos também precisam de IDs reais.
O link da experiência ou Universe ID permite identificar o destino correto;
nenhum asset ou preço foi publicado em uma experiência presumida.

Antes de publicar: executar a sequência de teste em PROJECT_STATE.md, testar
compras/recibos num ambiente publicado de teste, importar os áudios e subir
marketing/icon-512.png e as três thumbnails de 1920×1080.

Não há garantia de viralização ou ganhos. O próximo ajuste de economia deve usar
observação de jogadores, tempo até primeiro depósito, quedas/abandono e retorno.
