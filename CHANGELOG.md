# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento semântico.

## [3.3.0] — 2026-09-03

### Adicionado

- **Tela "Conjunto incompleto"** — a terceira pergunta do PPCP: *o produto fecha?*

  O problema que ela mede: o ERP programa com **capacidade infinita**. Pega a data de
  entrega do lote, volta pelo roteiro e carimba a mesma data em todas as fases de todas as
  ordens. Num lote de 55 ordens, 55 vencem na COLAR BORDA no mesmo dia, independente de a
  COLAR BORDA fazer 55 num dia. Sem prioridade, o líder sequencia pelo que economiza setup
  — junta cor, junta chapa — o que é **racional**. O resultado é todo produto 70% pronto,
  nenhum conjunto fechado, e a EMBALAR sem o que embalar. Começar tudo é a consequência,
  não a causa.

- **O agrupamento vem do código da peça, não de BOM.** O relatório "Situação do Lote de
  Produção" não traz estrutura de produto — e não precisa. O 1º bloco do código é o
  produto (`387` SPACE, `778` SLEEP, `754` INTENSE), o 2º é a peça dentro dele
  (`387.010` = FRENTE GAV, e a descrição confirma com "MDP 10") e o 3º é a cor
  (`.116` CINAMOMO, `.006` OFF WHITE, `.001` BRANCO REAL). `prefixoProduto()` agrupa;
  `rotuloConjunto()` tira o nome legível da primeira palavra da descrição, porque "387"
  não diz nada numa reunião e "SPACE" diz.

- **Roda inteiro até** = a última fase que **todas** as ordens do conjunto passaram. O setor
  seguinte a ela pega o produto completo; daí para frente, não. **Trava em** = a primeira fase
  que não fechou, com quantas peças faltam e **quais ordens** — é a ação do dia. Uma ordem
  passou a fase quando **todas** as operações dela estão apontadas: dois passes de COLAR BORDA
  são um setor, e passar só o primeiro não é passar.

- **% pronto por conjunto**, com barra: avanço do roteiro medido em **peça-fase** — quanto das
  quantidades de todas as fases de todas as ordens já tem registro. Fase fechada sem quantidade
  lançada conta cheia, pela mesma regra do `apontada()`. No desempate da ordenação, o conjunto
  mais adiantado vem antes: é o que fecha antes.

  **Não é percentual de tempo**, e a nota da tela declara isso. Peça-fase trata corte e
  embalagem como esforços iguais, e não são. Sem tempo padrão por operação essa é a única conta
  possível com o que o relatório traz; ler "60% pronto" como "60% do tempo" erra a estimativa
  do que falta.

- **Correram na frente** = ordens que já passaram a fase que trava enquanto outras ficaram
  atrás. Aparece em vermelho porque **não é alívio**: são exatamente elas que criam produto
  incompleto nos setores seguintes. Zero aqui é o número bom. A primeira versão desta coluna
  se chamava "liberado p/ a frente" e sugeria o contrário — o que o setor seguinte pode rodar
  completo é o que está **até** `Roda inteiro até`, não o que correu além da trava.

- **Ordem das fases pela sequência média** do roteiro das ordens do conjunto. O roteiro
  varia de peça para peça (uma leva pintura, outra não), então "a 3ª linha" não serve como
  régua; a média ordena sem exigir que todas as ordens tenham as mesmas fases. Cada fase só
  conta as ordens que a **têm** no roteiro.

- **CSV de conjuntos** (`conjuntos.csv`): uma linha por conjunto × fase. Uma linha por
  conjunto perderia o roteiro, que é onde está a informação; com o grão fase dá para montar
  "% de conjuntos fechados por fase" ao longo dos lotes no Power BI.

### Notas de modelagem

- **Quebrado ≠ atrasado.** Conjunto inteiro parado na mesma fase é **junto**, não disperso:
  está atrasado ou não, mas não está espalhado, e junto é exatamente o que se quer. Só é
  **quebrado** quando parte do conjunto andou e parte não. O contador da lateral e o
  veredito alertam sobre o quebrado, não sobre o total de produtos em curso — cobrar o líder
  que está fazendo a coisa certa seria pior que não medir. Nos dados do lote 025139, o
  conjunto INTENSE aparece como **junto** (as 3 ordens passaram CORTAR e FURAR e pararam
  juntas na COLAR BORDA), e SPACE e SLEEP como **quebrados**.

- **Volume (5…) fica fora do agrupamento**, e a tela declara quantas ordens ficaram. Todo
  volume começa em `501`, então agrupá-las pelo 1º bloco juntaria os volumes de **todos** os
  produtos num grupo só — pior que não agrupar. E o volume é o resultado do conjunto, não
  peça dele: sua EMBALAR é isenta de apontamento (v3.2.0), logo não informa nada sobre kit
  completo.

- **Fase fora da conta não bloqueia conjunto.** Setor que ainda não aponta no ERP e EMBALAR
  isenta saem das fases do conjunto: sem registro ali, exigir que "todas passaram" travaria
  o produto para sempre. EMBALAR em **componente** continua contando e bloqueando, coerente
  com o v3.2.0.

### Limitação conhecida

- O conjunto é o **produto**, não a combinação de cores do volume. Um `VOL 1/1 PAINEL
  INTENSE FREIJO/OFF WHITE` mistura peças de duas cores; a tela fecha no nível do produto
  (754), não no do volume (501.113.001). É a granularidade da dor relatada — "3 produtos no
  mesmo dia" — e não exige inferência de texto. Fechar por combinação de cor exigiria a
  estrutura do produto vinda do ERP.

## [3.2.0] — 2026-09-03

### Alterado

- **A isenção de EMBALAR passa a valer para produto acabado (`1…`) e para volume (`5…`).**
  Até aqui valia só para o acabado, sobre a premissa — inferida dos dados, nunca confirmada —
  de que o apontamento real de embalagem acontecia na ordem do volume (`501.x`). O PPCP
  confirmou que não acontece: a fase EMBALAR existe no roteiro dos dois e não recebe registro
  em nenhum dos dois. Enquanto a isenção era só do acabado, toda ordem de volume aparecia
  como **apontamento esquecido** no dia seguinte ao prazo da embalagem — falso positivo em
  volume, e num lote de painéis são dezenas de linhas cobrando um setor que não tem o que
  apontar no ERP.
- **Componente segue cobrável.** A isenção é por tipo de produto (`CFG.isentaEmbalagem`),
  não pela operação: EMBALAR no roteiro de um código `7xx` continua entrando na conta,
  porque ali a falta de apontamento é falta de verdade.
- Rótulo da caixa, motivo declarado no cabeçalho da tabela **Operações**, nota de rodapé e
  cabeçalho da folha impressa passam de "produto acabado (código 1…)" para
  "acabado (1…) e volume (5…)". O recorte continua declarado; nada sai em silêncio.
- `tipoProduto()` virou declaração de função e subiu para junto de `ignoraEmbalagem()`, que
  agora depende dela. Era `const` definido depois no arquivo.

### Notas

- A premissa continua **reversível pela tela**: desmarcar "Ignorar EMBALAR sem apontamento"
  traz as fases de volta como achado. Se um dia o volume passar a apontar embalagem no ERP,
  a caixa é o interruptor — e o caminho definitivo é tirar `'volume'` de `CFG.isentaEmbalagem`.
- Alternativa avaliada e descartada: marcar EMBALAR em "setores que ainda não apontam no ERP".
  Resolveria acabado e volume com um clique, mas isentaria **também os componentes**, apagando
  a única falta de apontamento de embalagem que é real hoje.

## [3.1.1] — 2026-09-03

### Corrigido

- **O recorte "fora da conta" não chegava à tabela Operações.** A isenção de EMBALAR em
  produto acabado (`fEmb`) e os setores marcados como "ainda não apontam no ERP" já saíam
  das duas contas (falta de apontamento e posição da ordem) e das regras de conferência,
  mas `opsFiltradas()` continuava devolvendo essas fases — e a tabela as exibia com o selo
  **VENCIDA**. Com "Ignorar EMBALAR" marcado, EMBALAR aparecia em vermelho na tela; com
  PINTAR PU marcado como setor sem apontamento, o mesmo. O usuário concluía, com razão,
  que o filtro não funcionava, e num lote grande essas linhas dominavam a lista e escondiam
  o que é de fato cobrável.
- O corte aplicado é exatamente o que os dois rótulos prometem: a fase **sem apontamento**.
  Fase isenta que tem conclusão ou quantidade apontada permanece na lista — ali o registro
  existe, e removê-la seria apagar produção real da evidência.
- Fase fora da conta deixou de ser julgada por prazo: quando exibida, recebe o selo neutro
  **fora da conta** em vez de VENCIDA/PENDENTE. Chamar de vencida o que a própria tela
  declarou fora da conta era a contradição que fazia o filtro parecer quebrado.

### Adicionado

- Cabeçalho da tabela **Operações** declara quantas fases ficaram de fora e por qual motivo
  (EMBALAR em acabado; setores que não apontam), com **mostrar/ocultar** para conferi-las.
  Filtro que esconde sem dizer o que escondeu é pior que filtro nenhum.
- Nota de rodapé da tabela explicando o estado **fora da conta**.
- O recorte também é declarado no cabeçalho da folha impressa da seção Operações.
- Coluna **ForaDaConta** (sim/não) no `operacoes.csv`. O CSV passa a levar **todas** as fases
  do recorte, inclusive as fora da conta: no Power BI o que se quer é o roteiro inteiro com
  um campo para filtrar, e sumir com a fase deixaria um buraco no roteiro sem aviso.

### Alterado

- O contador **Operações** da lateral segue a lista da tela (não conta mais as fases fora
  da conta enquanto elas estiverem ocultas).

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

## [3.1.0] — 2026-09-03

### Setores que ainda não apontam no ERP

No LT 162/26, PINTAR PU tinha 198 operações e nenhum apontamento: o setor ainda não aponta no
ERP. Com isso "Onde travou" dizia que a PU segurava 60 ordens e "Sem apontamento" cobrava 198
registros de quem não tem como registrar. Os dois números eram lixo, e lixo com cara de gargalo.

- `CFG.setoresSemApontamento` (padrão `['PINTAR PU']`) e a lista em **Mais filtros**, guardada em
  `localStorage`. `foraDaConta(of, op, flagEmb)` = isenção da EMBALAR **ou** setor marcado; é ela
  que `faltasApontamento`, `posicaoOrdem` e as regras de ordem concluída consultam.
- Efeito: as operações do setor saem das faltas de apontamento e da posição da ordem, que pula
  para a **próxima fase que aponta**. No LT 162/26 a abertura passa a ser "PINTAR UV segura 63
  ordens, a mais antiga há 2 dias úteis" — a leitura honesta: a peça saiu da usinagem e ainda não
  chegou ao registro do UV; onde ela está entre os dois, o relatório não sabe.
- **Declarado, não escondido:** aviso "Fora da conta" nas duas telas com a quantidade de operações
  retiradas; "não aponta" na lateral; tela do setor explica o estado; o recorte impresso na folha
  dos líderes cita o setor; "Mais filtros" conta o setor como filtro ativo.

Verificação: lotes de teste sem PINTAR PU ficam idênticos ao snapshot da 3.0.0; suíte completa
passando.

## [3.0.0] — 2026-09-03

### Duas telas, duas perguntas

O app tinha crescido por acréscimo: 7 seções, uma tela por setor, veredito, ranking, quatro
cartões, nove números de contexto e oito filtros sempre abertos. Três telas respondiam a mesma
pergunta com números diferentes (Sem apontamento, Painel por setor, Onde travou), todos certos, e
o leitor não sabia qual valia. Esta versão **apaga** em vez de acrescentar.

O PPCP faz duas perguntas por dia, nesta ordem. Cada uma tem uma tela, e o resto é evidência:

| Pergunta | Tela |
|---|---|
| Onde o lote está travado, e por quê? | **Onde travou** — abre por padrão |
| Quem não apontou? | **Sem apontamento** — veredito, ranking e lista |
| Evidência | **Detalhe** (fechado): Ordens, Operações, Achados, Leitura |

### Removido por redundância

- **Painel por setor.** Dizia o mesmo que "Onde travou" com outra conta (operações vencidas em vez de
  ordens paradas). `painelPorSetor`/`desenharPainel` apagados.
- **Os quatro cartões e a linha de contexto** do topo. Aderência e demais números continuam no
  Detalhe, onde são consultados quando alguém pergunta.
- Na **tela do setor**: "Parado no setor", "Já concluído", desvio médio e saldo. Ficam dois blocos,
  os mesmos das duas perguntas: **Parado aqui** (ordens que o setor está segurando, da mesma conta
  de "Onde travou") e **Cobrar apontamento**.

### Alterado — vocabulário

Dez estados viraram três palavras que o líder entende sem manual:

- **parado** — a ordem está atrás do programado e a próxima fase a apontar é deste setor. Se a
  fase começou (parcial) ou nada foi apontado ainda, é texto de apoio ao lado, não selo.
- **esquecido** — a fase seguinte já tem apontamento, ou a ordem foi fechada, ou a fase foi fechada
  sem lançar quantidade. A peça passou; faltou o registro.
- **a confirmar** — nada apontado e a previsão venceu, sem prova de que a peça passou.

A folha dos líderes e o CSV de faltas seguem as mesmas palavras (`Esquecido`,
`Esquecido (sem quantidade)`, `A confirmar`; `Parado - nada apontado / parcial / aguardando`).

### Alterado — filtros

Lote e data de referência ficam à vista. Produto, setor, tipo, reposição, severidade e a isenção
da EMBALAR ficam em "Mais filtros", cujo título diz quantos estão ativos — para um recorte
esquecido nunca fazer a tela mentir em silêncio.

### Verificação

Snapshot antes × depois nos dois lotes de teste: Ordens, Operações, Achados, Leitura, os cinco CSVs
e a impressão da lista **idênticos**; a folha dos líderes só muda as palavras. Testes de
apontamento, impressão, volume, "Onde travou", responsividade e PWA offline passando. Lote real
LT 162/26: abre em "81 de 88 ordens em aberto estão atrás do programado — comece por PINTAR PU".

## [2.3.0] — 2026-09-03

Primeiro lote real (LT 162/26, 45 páginas, 137 ordens, 832 operações). O que ele ensinou:

### Corrigido — um PDF pode trazer vários lotes

O ERP emite a Situação do Lote **por LT**, e um LT tem um lote por produto: o arquivo veio com o
lote 025136 (mesa cabeceira) nas páginas 1–12 e o 025137 (penteadeira) nas 13–45, cada um com
cabeçalho, previsão e rodapé próprios. O leitor assumia um lote por arquivo: rotulava toda ordem
com o último lote lido, usava a previsão dele para detectar reposição e comparava a soma dos
dois lotes com o rodapé de um — daí os avisos "M³ diverge" e "71 linhas não reconhecidas".

Agora `parseDoc` mantém `doc.lotes[]`; o cabeçalho se repete em toda página e só um **número de
lote diferente** abre um lote novo. Ordem carrega `lote`, `lt` e `previsaoLote` do lote em que
foi lida. Conferência de leitura por lote. Filtro de lote, contexto, folha e Leitura dos arquivos
passaram a ler de `doc.lotes`.

### Adicionado — "Qtd. Concluída na Fase"

As 71 linhas "não reconhecidas" eram esta linha, que o ERP imprime por ordem: a última **fase**
(grupo de operações: CORTE, FURACAO, USINAGEM, COLAGEM BORDA) que a peça completou e quantas
peças. É a posição da ordem segundo o próprio ERP. Lida em `of.faseConcluida` e mostrada em
"Onde travou" como **Fase concluída (ERP)**, contraprova do "Está em" calculado pelo roteiro. No
lote real as duas concordaram em todas as ordens conferidas.

### Alterado — "Onde travou" conta setores, não linhas

Um roteiro real tem três passes de PINTAR PU seguidos de PINTAR UV. Contar linhas dizia "4 fases
atrás" para o que o líder chama de um setor atrás. A distância passa a ser em **setores distintos**
entre onde está e onde deveria estar. Coluna e CSV renomeados (`SetoresAtras`).

### Alterado — "Inconsistente" exige falta de produção, não só a data

A regra "concluída antes da primeira previsão de processo" pegou uma ordem cortada e fechada um
dia antes do programado, com as 975 peças apontadas no mesmo dia. Isso é adiantamento. Agora só é
inconsistente quando **não há apontamento que sustente o fechamento** (nenhuma operação apontada)
ou quando uma operação foi concluída **depois** de a ordem já estar fechada. `OF_CONCL_ANTES_PREV`
segue a mesma definição, para achado e aderência nunca discordarem.

### Alterado — M³ sai da tela

O PPCP não decide nada por M³. Ele continua sendo lido só para a conferência silenciosa de que o
arquivo foi lido inteiro (soma das ordens × rodapé do lote), que aparece como "leitura conferida"
ou "leitura incompleta". A coluna `M3` do CSV de ordens fica, para não quebrar consulta existente.

## [2.2.0] — 2026-09-03

### Onde travou — por que a ordem ficou para trás

A aba Ordens já dizia *se* a ordem estava atrasada. Não dizia *por quê*, nem *onde ir buscá-la*.
A pergunta do PPCP é a segunda: "o produto estava previsto para embalar hoje e ainda tem peça na
coladeira" — a ordem está travada na coladeira, e é lá que a conversa acontece.

- **Deveria estar em** = a última fase do roteiro com previsão do processo até a data de
  referência. É o que o PPCP programou a ordem alcançar até hoje.
- **Está em** = a fase seguinte à última com apontamento. Se a última apontada ainda tem saldo e
  não foi fechada, é ela mesma (**parcial**). Ordem sem nenhuma fase apontada: **não começou**.
- Fase anterior em branco com uma posterior apontada **não** é posição: é apontamento esquecido
  (seção "Sem apontamento"), e a peça já passou dali. As duas seções não se contradizem — uma
  cobra registro, a outra localiza a peça.
- **Fases atrás**, **parada há** (dias úteis desde a previsão da fase atual) e **peças na fase**
  (saldo ainda não apontado ali).
- Cartões por **setor que está segurando** as ordens, com a que está parada há mais tempo.
- **Roteiro concluído, ordem não fechada** em lista à parte: todas as fases apontadas e a ordem
  em aberto não é atraso de produção — é ordem por encerrar.
- A EMBALAR isenta por convenção (produto acabado) não conta como posição, mas continua contando
  como programação: "prevista para embalar hoje" segue sendo a régua.
- Só ordens em aberto. Reposição entra, marcada. Com filtro de operação, a seção mostra as ordens
  travadas **naquele** setor.
- Contador no menu, CSV `onde-travou.csv` e impressão pela "lista da tela".

Verificado com um lote sintético que reproduz o exemplo (prevista para EMBALAR, peça na COLAR
BORDA), mais os casos de ordem não começada, parcial, adiantada, apontamento esquecido no meio e
roteiro concluído sem fechar. As demais seções continuam idênticas ao snapshot da 2.1.1.

## [2.1.1] — 2026-09-03

### Refatoração — sem mudança de comportamento

O código tinha crescido por acréscimo: a mesma agregação de faltas por setor estava escrita
seis vezes (veredito, ranking, lateral, painel, folha impressa duas vezes), a função que
desenha a tela tinha 312 linhas com todas as seções dentro, e havia código morto da folha
antiga (`quadroSetores`, `resumo` e o CSS deles). Seis cópias da mesma conta são seis lugares
onde tela e papel podem divergir — e a divergência seria descoberta na reunião.

- `agregarPorSetor` / `rankSetores`: a conta por setor existe em um lugar só, e todos os usos
  leem dela. `tituloVeredito`, `marcaSetor`, `rotuloFalta` e `motivoFalta` fazem o mesmo com
  os textos repetidos entre tela, papel e CSV.
- `resumoGeral` calcula tudo do topo da tela uma vez; `renderVeredito`, `renderRanking`,
  `renderCartoes`, `renderContexto`, `renderListaSetores` e `renderContadores` só desenham.
- Uma função por seção (`desenharSetor`, `desenharApont`, `desenharAchados`, `desenharOrdens`,
  `desenharOperacoes`, `desenharPainel`, `desenharLeitura`), escolhida por uma tabela. O
  painel por setor separou cálculo (`painelPorSetor`) de desenho.
- CSV das faltas em `csvFaltas`, usada pelo botão geral e pelo botão da tela do setor.
- Removidos `quadroSetores`, `resumo`, o CSS `.doc-resumo` e um cabeçalho de seção duplicado.

**Verificação:** um script fotografa o HTML de todas as seções, de cada tela de setor, de cada
filtro isolado, das três folhas impressas e dos cinco CSVs, em dois lotes de teste (um sintético
e um com o layout real do relatório). Antes e depois da refatoração o resultado é idêntico
byte a byte (484.989 bytes), sem erro de console. A regressão de impressão, volume, PWA e
recuperação do pdf.js também passou.

## [2.1.0] — 2026-09-03

### Ordens de reposição

Quando uma peça é perdida ou refugada, o ERP abre uma ordem nova para repor. Ela nasce depois
do lote e traz previsão posterior à dele, porque a contagem começa na criação da ordem.

Isso tornava dois julgamentos inválidos para ela:

- comparar o prazo dela com o do lote não diz nada, e
- **"concluída antes da primeira previsão de processo" deixava de ser furo de dado**: na
  reposição a peça costuma ser feita antes de a programação formal existir, e isso é o fluxo
  normal dela, não inconsistência.

Agora a reposição é reconhecida, ganha situação própria na aba Ordens e fica **fora do cálculo
de aderência**. O que não muda: a falta de apontamento continua valendo, porque reposição é
produção real e precisa de registro como qualquer outra. Filtro novo para incluir, isolar ou
ocultar.

**O critério é a previsão do lote, lida do cabeçalho do relatório** — a data-limite do lote.
Uma ordem com previsão além dela nasceu fora do planejamento original.

Tentei antes usar a data mais repetida entre as ordens, imaginando que o cabeçalho pudesse vir
contaminado pela própria reposição. **O teste desmentiu:** num lote normal cada ordem tem a sua
data escalonada, a mais repetida não representa o prazo do lote, e **6 de 7 ordens legítimas
eram acusadas de reposição**. O cabeçalho erra menos.

### Texto de "Esquecido" reescrito

A explicação anterior — *"a peça passou por aqui, logo o apontamento existe para ser feito"* —
gastava duas frases no que é óbvio para quem conhece o roteiro, e não dizia a conclusão que
importa. Agora:

> **Esquecido** = a fase seguinte já tem apontamento, ou a ordem foi fechada. Como a peça não
> pula fase, faltou o **registro**, não a produção.

A distinção entre faltar registro e faltar produção é o que a folha precisa deixar claro numa
reunião. Aplicado na tela, na tela do setor, no detalhe do achado e nos dois documentos
impressos.

### Verificado

Lote normal: **zero** ordens marcadas como reposição. Lote com reposição: as duas ordens de
quantidade pequena e previsão posterior reconhecidas, saindo de "Inconsistente" para
"Reposição" e da base da aderência (0/3 em vez de 0/1).

## [2.0.0] — 2026-09-03

### Uma tela por setor

Os setores viraram **navegação**: a lateral lista cada processo do roteiro com um ponto de
estado e as peças pendentes ao lado — o ponto nunca informa sozinho, a quantidade diz o mesmo
em número. Clicar abre a tela daquele setor.

A tela traz três blocos, **em ordem de ação**:

1. **Cobrar apontamento** — o que tem prova de que a peça passou. É o bloco que abre a conversa
   com o líder, e tem os botões de imprimir a folha do setor e exportar o CSV dele.
2. **Parado no setor** — vencido, começado e travado no meio. Aqui pode ser falta de produção,
   não de registro: é outra conversa.
3. **Já concluído** — recolhido, porque não pede ação. Existe para o líder ver o histórico dele
   no lote, não só a cobrança.

O veredito geral e o ranking somem na tela do setor: eles falam do lote inteiro enquanto o
cabeçalho fala do setor, e dois títulos com números diferentes fazem o leitor parar para
descobrir qual vale.

`dadosDoSetor()` alimenta os três lugares que precisam concordar sobre o mesmo processo — a
tela, a lista da lateral e a folha impressa. Calcula sobre os filtros da tela, mas ignora o
filtro de operação: abrir o setor do líder não pode reescrever o recorte que o usuário montou.

### Corrigido — a isenção do EMBALAR reconhecia menos produtos do que devia

`CFG.produtoAcabado` era `/^103\./`, que só casa com os códigos começados exatamente em
`103.`. Na convenção da Patrimar o que define o tipo é o **primeiro dígito**: um produto
acabado `104.` ou `102.` ficava de fora da isenção e virava **falso apontamento esquecido**.

Agora `1` é produto acabado e `5` é volume.

### Adicionado — filtro Tipo de produto

Acabado (1…), Volume (5…) ou Componentes (demais). Entra na declaração de recorte da folha
impressa, como os outros filtros.

### Verificado

Classificação por primeiro dígito, filtro por tipo em quatro estados, lista da lateral
ordenada por gravidade, navegação entre setor e conferência (o veredito geral aparece e some
na hora certa), folha e CSV de um setor só — sem alterar o filtro da tela —, mais a regressão
completa em desktop, 1600px e celular.

## [1.9.1] — 2026-09-03

### Nome da peça

A aba **Operações** mostrava só o código do produto. `479.006.001` não diz nada numa reunião —
só vira informação com `MADERO LAT DIR 350X320X12 MDP 3` ao lado. A coluna **Peça** entrou
entre Produto e Seq, e acompanha a impressão da lista, que clona a tabela da tela.

O cartão do **Painel por setor** também passa a nomear a peça da ordem mais parada, em vez de
citar só o número da ordem.

As demais telas já traziam a descrição: Ordens, Achados, Sem apontamento, a folha da reunião e
os três CSV.

### A tela aproveita a largura do monitor

O conteúdo tinha teto de 1400px. Em monitor grande sobrava um vazio à direita enquanto as
colunas da tabela apertavam — o limite existe para texto corrido, não para tabela densa, onde
cada pixel a mais é uma coluna que deixa de espremer.

O teto saiu; o respiro fica por conta do padding. Texto corrido — o veredito, as notas e o
rodapé impresso — ganhou limite próprio de 120 caracteres, porque linha longa demais cansa a
leitura mesmo havendo espaço.

## [1.9.0] — 2026-09-03

### A conclusão escrita, não o número solto

A tela mostrava quatro números de peso igual e deixava a conclusão por conta do leitor. Agora
uma frase responde as três perguntas de uma vez — **tem problema, onde e quanto**:

> **3 apontamentos esquecidos em 2 setores**
> 62 peças sem registro. Comece por CORTAR, com 42 peças — há prova de que a peça passou por lá.

### Ranking por setor, com barra

O olho compara **comprimento** em milissegundos; comparar números exige ler, alinhar e
subtrair. O ranking vem logo abaixo do veredito, do pior para o menor, e existe nas duas
saídas — tela e papel.

Na folha impressa, barra **preenchida** é apontamento esquecido e **hachurada** é pendente. A
distinção sobrevive à fotocópia, e o número vem ao lado porque barra sozinha não se lê com
precisão.

### Menos, mas melhor

A folha trazia a mesma conclusão **quatro vezes**: veredito, ranking, resumo de cinco números
e quadro por setor. Informação repetida não reforça — faz o leitor procurar qual das quatro é
a certa, que é o oposto de entender em dois segundos. Ficaram o veredito (a conclusão), o
ranking (a comparação) e o detalhe por setor (a ação).

Na tela, os números detalhados foram para um bloco recolhido.

### Corrigido — as barras do ranking mentiam

Dois defeitos somados faziam a barra do pior setor sair menor que a de um setor com menos da
metade das peças:

1. **Cada linha era o próprio grid.** A coluna da barra media diferente em cada uma, porque
   `2 ESQUECIDOS` é mais largo que `1 A APONTAR`. O grid passou para o container, com as
   linhas em `display:contents` — todas compartilham a mesma régua.
2. **Colisão de classe.** A barra usava `.f`, que já existia para os campos de filtro com
   `max-width:320px`. A barra de 100% era cortada nesse limite. As classes viraram `.esq` e
   `.pend`.

Uma barra que engana é pior que barra nenhuma: o olho acredita nela antes de ler o número.
Verificado medindo a largura renderizada em pixels contra o valor — 100%/48%/71% para
42/20/30 peças, na tela e no celular.

## [1.8.0] — 2026-09-02

### Prazo em dias úteis, não em dias corridos

A fábrica não produz sábado, domingo nem feriado. Contar dias corridos inflava **todo** atraso
que cruzasse um fim de semana, e sempre para cima — o indicador acusava a fábrica de um atraso
que não houve.

| Previsão | Conclusão | Corridos | Úteis |
|---|---|---|---|
| sexta 11/09 | segunda 14/09 | 3 | **1** |
| sexta 28/08 | quarta 02/09 | 5 | **3** |
| sexta 14/08 | quarta 02/09 | 19 | **13** |

Numa semana com feriado a diferença chega a 3 dias numa única comparação.

### Como ficou

- **Jornada:** segunda a sexta (`DIAS_UTEIS`). Se a fábrica passar a produzir aos sábados,
  basta incluir `6` na constante.
- **Feriados:** nacionais e do estado de **São Paulo** (09/07, Revolução Constitucionalista).
  Os móveis saem da Páscoa, calculada pelo algoritmo de Meeus/Jones/Butcher e conferida
  contra 2024–2027. Carnaval e Corpus Christi são ponto facultativo em lei, mas a fábrica
  para — por isso entram.
- **Feriado municipal e parada coletiva:** `CFG.feriadosExtras`, no formato `aaaa-mm-dd`.
- A conta é feita uma vez por ano consultado e guardada: um lote tem centenas de comparações
  de data, e recalcular a Páscoa em cada uma seria desperdício.
- O sinal se mantém: negativo continua sendo adiantamento.

### Na tela

As colunas passam a dizer `(d.ú.)`, as notas explicam a regra, o rodapé dos dois documentos
impressos registra a base de contagem, e a coluna do CSV virou `DesvioDiasUteis` — quem abrir
no Power BI precisa saber o que está somando.

### Verificado

Onze casos: fim de semana no meio, mesmo dia, adiantamento com sinal negativo, feriado
nacional, feriado de São Paulo, Natal, Carnaval e um intervalo de três semanas. Dois deles
acusaram falha e **a expectativa do teste é que estava errada** — 07/09/2026 cai numa
segunda-feira, e de 14/08 a 02/09 há 13 dias úteis, não 12. O cálculo estava correto nos onze.

## [1.7.0] — 2026-09-02

### Corrigido — o total de peças contava a mesma peça várias vezes

Cada item da lista de faltas é **uma fase** sem registro, e traz a quantidade prevista daquela
fase. Somar tudo conta a mesma peça uma vez por fase: uma ordem de 100 peças com corte,
furação e lixamento sem apontar virava **300 peças**.

Num lote real o efeito foi: **18.394 peças sem registro** contra um **saldo de 3.933** no lote
inteiro — quase cinco vezes mais peças do que existem para produzir. Levado a uma reunião, o
primeiro cruzamento derruba o número, e junto com ele o achado verdadeiro, que são os
apontamentos esquecidos.

**A conta agora é por ordem**, tomando a maior quantidade entre as fases sem registro dela.
Maior, e não a quantidade da ordem, porque a operação pode ter multiplicador — duas peças por
unidade — e é a quantidade da fase que diz quantas peças de fato ficaram sem apontamento.

Verificado contra verdade conhecida: duas ordens de 100 e 50 peças, com 5 fases sem
apontamento no total. Soma ingênua: 400. Peças distintas: **150**, que é o número real.

### O que continua somando por fase, de propósito

- **Dentro de um setor** a soma está certa: cada peça passa uma vez por lá. O quadro de
  responsabilidade por setor mantém o total do setor, e passou a avisar no título que a soma
  das colunas ultrapassa o lote porque a mesma peça passa por vários setores.
- **"Apontamentos a fazer"** é o número de fases, e mede o esforço de regularização — outra
  pergunta, com outro número.

### Rótulos

- "Peças esquecidas" sugeria peça perdida ou com defeito. O que foi esquecido é o
  **apontamento**, não a peça: virou "Peças sem apontamento" e "Peças que passaram sem registro".
- A nota da seção avisa que somar a coluna Peças à mão dá um número maior que o total do
  cabeçalho, e por quê.

## [1.6.0] — 2026-09-02

### O prazo da ordem passa a ser julgado pelo roteiro

A ordem tem uma previsão própria — a data de entrega, na capa — e cada operação tem a sua
**Previsão do Processo**, que é o que o PPCP de fato programou por fase. As duas divergem, e
julgar pela capa produzia número falso.

O caso que expôs o problema, num lote real: a ordem **803963** foi fechada em **02/09**, seis
dias **antes** de a primeira fase do roteiro estar prevista (08/09), com **0 de 6 operações
apontadas**. O app exibia **−12 d** — como se tivesse sido entregue adiantada — e a contava
como cumprida. Não é adiantamento: é fechamento antes de a produção existir.

Era isso que levava a **Aderência de prazo a 100%** num lote com 52 apontamentos esquecidos.

### Alterado

- `prazoOrdem()` é agora a **única fonte** do critério de prazo, usada pela tela, pelo
  indicador e pelos achados — para os três nunca discordarem do mesmo dado.
  - Referência de prazo: a **última** Previsão do Processo, porque a ordem termina quando a
    última fase termina. Sem roteiro programado, cai para a previsão da ordem (e a tela diz).
  - **Inconsistente**: concluída antes da **primeira** Previsão do Processo.
- `OF_ABERTA_VENCIDA` e `OF_ATRASO` passam a medir contra a previsão do processo, e informam
  no detalhe qual das duas datas foi usada.
- `OF_ATRASO` não dispara em ordem inconsistente — esse caso já é reportado por
  `OF_CONCL_ANTES_PREV`, e dois achados sobre o mesmo fato viram ruído.
- A aba **Ordens** mostra `Prev. processo` e `Prev. ordem` lado a lado, e substitui o desvio
  por *"fechada antes do roteiro"* nas inconsistentes.
- A **aderência** exclui as inconsistentes e declara a base: `0% · 0/1`, com as excluídas
  contadas à parte. Um indicador que não diz sobre quantos foi calculado não é auditável.

### Verificado

No caso reproduzido do relatório real (layout de 5 colunas, sem "Faltam"): o parser lê as
datas corretamente — o defeito era de julgamento, não de leitura. Depois da correção, as duas
ordens fechadas antes do roteiro saem de "−12 d adiantada / no prazo" para "Inconsistente /
fora da conta", e uma ordem que parecia no prazo pela capa (0 d) aparece como **+1 d** pelo
roteiro. Aderência caiu de 100% para 0% de 1 ordem julgável — que é o número verdadeiro.

## [1.5.0] — 2026-09-02

### Adicionado

- **Quadro de responsabilidade por setor**, no topo da folha da reunião. O corpo do documento
  já separava as pendências por setor, mas quem abre a folha precisa ver a responsabilidade
  consolidada antes do detalhe: qual setor concentra o problema e qual é só respingo.
  Ordenado por apontamento esquecido, que é o que tem prova.
- **Imprimir a lista da tela** — leva a tabela que está sendo vista (Operações, Ordens,
  Achados) para o papel, deitada em A4 paisagem. Serve quando alguém questiona o resumo e é
  preciso mostrar a evidência bruta, do jeito que o app leu o relatório.

### O papel passa a declarar o recorte

O cabeçalho impresso diz qual filtro estava aplicado — e, quando não havia nenhum, diz isso
também. Uma folha que mostra 12 linhas de um lote com 195 operações, sem declarar que estava
filtrada, faz o líder concluir que o problema é pequeno.

Só é declarado o filtro que **de fato vale** para aquela lista: severidade filtra Achados,
não Operações nem Ordens. Anunciar um filtro que não foi aplicado faria o leitor descontar
linhas que nunca foram descartadas — engana tanto quanto omitir.

### Decisões de impressão

- A orientação do papel muda com o documento: o da reunião cabe em retrato; a lista bruta tem
  colunas demais e só fica legível deitada. `@page` não aceita condicional, então a regra é
  trocada antes de chamar a impressão.
- Na lista, as colunas têm largura automática: a tabela vem clonada da tela, e deixar o
  navegador distribuí-la pelo conteúdo é melhor que impor uma grade que não conhece os dados.
- Tudo preto, sem realce de linha e sem selo colorido. A tela usa cinza para hierarquia; em
  P&B o cinza quase desaparece e o realce só suja.

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
