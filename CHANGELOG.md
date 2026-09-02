# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento semântico.

## [1.1.0] — 2026-09-02

### Adicionado

- `pdf.js` 3.11.174 versionado em `vendor/` (`pdf.min.js`, `pdf.worker.min.js`, `LICENSE-pdfjs.txt`).
  A pasta estava documentada mas não existia no repositório: **sem ela a ferramenta não lia PDF nenhum.**
- Identidade **RitmoPatrimar — Estudo de Datas de Produção**, no mesmo sistema visual do
  RitmoPatrimar de estudo de tempos: lateral escura com a navegação, conteúdo claro,
  logotipo Patrimar embutido como data URI, escala tipográfica e de espaçamento compartilhadas.
- **Painel por setor**, no lugar da tabela isolada de aderência: um cartão por processo do
  roteiro, ordenado por gravidade, com operações vencidas, saldo parado, desvio médio, avanço
  e a ordem que está há mais tempo travada no setor. A tabela de aderência continua abaixo,
  como o número exato por trás dos cartões.
- Cartão de resposta no topo com os quatro números que decidem: ordens com achado crítico,
  em aberto e vencidas, aderência de prazo e saldo a produzir.
- Aviso de leitura no topo da tela quando algum arquivo diverge do rodapé do relatório ou
  tem linha não reconhecida. Antes o alerta só existia na última seção do menu.
- Estado vazio explicando de onde vem o relatório e o que fazer com ele.
- Histórico de versões acessível pelo número da versão, na lateral.
- Favicon próprio.

### Corrigido

- **Desalinhamento silencioso de colunas.** Quando a data em branco vinha como `/ /` com
  espaço entre as barras num único item de texto, o slot da data sumia e todas as colunas
  seguintes escorregavam uma posição — a tela exibia conclusão, quantidade e apontamento
  errados sem nenhum aviso.
- **Valor no tipo errado deixou de ser aceito calado.** Cada campo só aceita o valor cuja
  natureza corresponde à coluna (data em coluna de data, número em coluna de número);
  divergências viram contagem e aviso na aba Leitura dos arquivos.
- **Formatação de data derrubava a tela inteira** ao receber um número em vez de texto,
  deixando a seção anterior no lugar como se fosse a que o usuário abriu.
- **Cor enganosa na coluna de prazo.** Ordem em aberto com previsão futura aparecia em verde,
  como se fosse resultado bom. Nas concluídas a coluna mostra o desvio (conclusão − previsão);
  nas em aberto mostra o prazo, colorido só quando já venceu.
- **Painel e achados discordavam.** O painel por setor contava como vencida a operação isenta
  pela convenção do produto acabado e a operação pendente de ordem já concluída — casos que os
  achados, corretamente, não acusam como atraso de fila.
- Texto vindo do PDF passa a ser escapado antes de ir para a tela.
- Sem rolagem horizontal da página em tela estreita: a tabela larga rola dentro do próprio bloco.

### Validação

Testado no navegador de ponta a ponta contra um PDF sintético com o layout do relatório,
construído para disparar cada regra: 5 ordens, 10 operações, 10 achados, todas as 13 regras
exercitadas, exportação CSV conferida e nenhum erro de console.

Falta ainda o teste contra um lote real da fábrica antes de divulgar o link.

## [1.4.1] — 2026-09-02

### Corrigido

- **O app podia ficar sem ler PDF nenhum, e culpava a pasta `vendor` por palpite.**
  Quando a tag `<script>` do pdf.js não carregava — por uma falha de rede, uma cópia ruim
  guardada no aparelho ou um problema no servidor — o app ficava inútil e exibia sempre a
  mesma mensagem, que mandava conferir a publicação. Um chute, que não ajuda quem está com
  o app instalado.

  Agora:
  - O app **busca a biblioteca de novo por conta própria**, ignorando o que estiver guardado
    no cache do service worker e do navegador. Na maioria dos casos ele se recupera sozinho
    e o usuário não percebe nada. Se a segunda tentativa der certo, a cópia ruim é apagada
    para a próxima abertura não repetir o problema.
  - Quando não dá para recuperar, a tela mostra o **motivo real** — o código HTTP que o
    servidor respondeu, ou o tipo de conteúdo que veio no lugar do script — com os dois
    passos que resolvem.
  - A verificação passou a acontecer **ao abrir o app**, não só quando o usuário seleciona o
    primeiro PDF. Descobrir que o app não lê arquivo no meio de uma conferência é tarde.

- **Service worker: uma cópia ruim não fica presa para sempre.**
  - Só entra no cache o que veio íntegro (`ok` e sem redirecionamento). Meia cópia é pior que
    nenhuma, porque a estratégia cache-first a serviria indefinidamente sem tentar a rede.
  - Uma resposta guardada só é servida se estiver íntegra; um erro que tenha entrado no cache
    por engano deixa de bloquear o app.
  - Falha de rede sem cópia local passou a devolver `Response.error()` em vez de um `504`
    vazio. Um 504 vazio para um `<script>` é tratado pelo navegador como script vazio: a
    biblioteca sumia sem nenhum sinal, e era exatamente isso que escondia o problema.

### Verificado

Quatro cenários, com perfis de navegador limpos: falha só na primeira tentativa (recupera
sozinho), arquivo ausente com 404 (diz o código), tipo de conteúdo errado (diz o tipo), e
tudo certo (nenhum aviso). Mais a regressão completa — regras, impressão, PWA, uso offline e
atualização de versão do service worker.

## [1.4.0] — 2026-09-02

### Adicionado

- **Imprimir para os líderes** — o documento que faltava para a conferência sair do
  computador e virar conversa. Não é a tela levada ao papel: é outro documento.
  - **Agrupado por setor**, porque é assim que a reunião acontece: cada líder responde
    pelo processo dele. Uma lista corrida por ordem obrigaria cada um a garimpar as
    próprias linhas.
  - Resumo no topo: apontamentos esquecidos, peças com registro esquecido, operações sem
    registro, peças no total e setores envolvidos.
  - Uma **coluna em branco para a tratativa** em cada linha. O que a reunião decidir é
    escrito ali, e a folha vira o registro em vez de uma lista que se perde.
  - Campos de assinatura: PPCP, responsável pelo setor e data da tratativa.
  - Rodapé com a legenda das três situações e a ressalva de origem do dado.
  - Respeita os filtros da tela.

### Decisões de impressão

- **Preto e branco.** A impressora da fábrica é P&B: nada depende de cor. A situação é dita
  por palavra, e o que é certeza (`ESQUECIDO`) leva tarja preta, que sobrevive à fotocópia.
- **O setor flui entre páginas** em vez de pular inteiro para a próxima. Forçar cada setor a
  caber numa folha gastava uma página por setor — 12 folhas para 124 linhas. Protege-se o
  essencial: título nunca órfão, linha nunca partida ao meio, cabeçalho da tabela repetido
  no alto de cada página.
- Colunas de largura fixa, iguais em todos os setores. Sem isso cada tabela calculava a
  própria largura e as colunas dançavam de bloco em bloco na mesma folha.
- `venc.` desce para a linha de baixo em vez de alargar a coluna de previsão: transbordando,
  ele invadia a coluna de peças e o número ficava ambíguo no papel.

### Verificado

PDF gerado em A4 retrato via Chromium, no lote de teste e num volume de 12 setores e 124
linhas: 9 páginas, nenhuma colisão de coluna, nenhum setor maior que uma página, cabeçalho
repetido a cada página.

## [1.3.0] — 2026-09-02

### Adicionado

- **Instalação no aparelho (PWA)**: `manifest.webmanifest`, ícones 192/512 e um ícone
  *maskable* com margem de segurança para o recorte circular do Android. O botão
  **Instalar no aparelho** aparece na lateral só quando o navegador realmente oferece a
  instalação; no iPhone e iPad, onde o Safari não expõe esse evento, a lateral mostra o
  caminho manual (Compartilhar → Adicionar à Tela de Início) em vez de um botão que não
  funcionaria. Instalado, o app se identifica no rodapé e para de oferecer instalação.
- **Uso offline** via service worker: `index.html`, `vendor/pdf.min.js`,
  `vendor/pdf.worker.min.js` e os ícones ficam disponíveis sem rede. Como os PDFs já eram
  lidos dentro do navegador, o app passa a funcionar inteiro sem internet — que é o estado
  normal em boa parte do chão de fábrica.

### Estratégia de cache, e por quê

- `index.html` usa **rede primeiro**, cache como reserva. É onde moram as regras de
  conferência: servir do cache primeiro faria a correção de uma regra demorar dias para
  chegar, e o usuário estaria conferindo lote com regra velha sem saber.
- `vendor/` e ícones usam **cache primeiro**: são grandes e imutáveis.
- O cache é nomeado pela versão; ao publicar, os caches de versões anteriores são apagados.
- `sw.js` e `manifest.webmanifest` respondem com `must-revalidate` no `vercel.json`.
  Service worker cacheado é aplicativo congelado.

### Corrigido

- O contador de **Painel por setor** ficava em `0` até a seção ser aberta pela primeira vez.

### Verificado

Com servidor HTTP local e Chromium: service worker ativo, manifest válido com 3 ícones,
9 arquivos em cache, app abrindo e **lendo PDF com a rede cortada**, e o teste de
atualização — publicada uma versão nova, o usuário já instalado a recebe ao reabrir.

## [1.2.0] — 2026-09-02

### O que mudou de propósito

A pergunta que a ferramenta responde passou a ser **onde a produção não foi apontada**.
A conferência de datas continua inteira, mas deixou de ser o eixo: virou o meio.

### Adicionado

- Seção **Sem apontamento**, primeira do menu e aberta por padrão. Uma linha por operação
  sem registro, com a quantidade de peças, o setor e o motivo.
- Regra `APONT_FURADO` (crítico) — **apontamento esquecido**. Dispara quando uma fase
  posterior do roteiro já tem apontamento, ou quando a ordem foi dada como concluída.
  A peça não pula fase: se a seguinte foi apontada, a anterior foi executada. É prova
  lógica de apontamento esquecido, não suspeita de falta de produção.
- Regra `APONT_SEM_QTD` (crítico) — fase com data de conclusão e quantidade zerada.
- Regra `OP_SEM_APONTAMENTO` (atenção) — operação vencida sem nenhum registro, sem prova
  de que a peça passou. Pode ser falta de apontamento ou de produção; só o setor responde.
- Painel por setor com **Sem apontar**, **Esquecidos** e **Pç sem registro**, saindo da
  mesma função da seção nova — painel e lista nunca discordam do mesmo dado.
- Exportação **CSV sem apontamento**, para a cobrança por setor.

### Alterado

- Cartão do topo lidera com apontamento esquecido e peças sem registro. Saldo e aderência
  de prazo desceram para a linha de contexto.
- `OP_VENCIDA` passou a significar operação **começada e parada no meio**: quando não há
  nenhum apontamento, o achado é `OP_SEM_APONTAMENTO` ou `APONT_FURADO`. Os três são
  mutuamente exclusivos, para não gerar dois achados sobre a mesma operação.

### Corrigido

- Nome do setor quebrava letra a letra no cartão quando o selo era longo.
- `pdf.min.js`, `pdf.worker.min.js` e `LICENSE-pdfjs.txt` estavam duplicados na raiz do
  repositório, além da pasta `vendor/` que o app realmente usa. Removidos da raiz.

### Limitação que continua valendo

O relatório mostra ausência de **registro**. Sem a prova do furo de roteiro, ausência de
registro não distingue "não produziu" de "produziu e não apontou" — quem responde é o
chão de fábrica.

## [1.0.0] — 2026-09-02

### Adicionado

- Leitura posicional de PDFs do relatório "Situação do Lote de Produção" (ERP Lógica),
  com suporte a múltiplos arquivos na mesma sessão.
- Reconhecimento de ordens cujo cabeçalho cai na quebra de página.
- Auto-verificação da leitura: soma de M³ das ordens conferida contra o `Total M3` do rodapé
  do próprio relatório; contagem de linhas não reconhecidas.
- Motor com 13 regras de conferência, ligáveis e desligáveis na tela.
- Exceção configurável para `EMBALAR` sem apontamento em produto acabado de prefixo `103.`.
- Data de referência baseada na data de emissão do relatório, não na data do sistema.
- Exportação CSV de achados, ordens e operações (`;`, decimal vírgula, data `dd/mm/aaaa`, UTF-8 com BOM).

### Pendências conhecidas

- Confirmar com a Engenharia se `EMBALAR` sem apontamento em produto `103.` é convenção
  (premissa inferida dos dados, ainda não validada).
- Avaliar substituição da leitura de PDF por consulta direta ao ERP.
