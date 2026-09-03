# RitmoPatrimar — Estudo de Datas de Produção

Ferramenta que lê os relatórios **"Situação do Lote de Produção"** emitidos pelo ERP Industrial (Lógica)
e responde uma pergunta: **onde a produção não foi apontada.**

Lê vários PDFs de uma vez, consolida ordens e operações, e aponta cada fase sem registro — com a
quantidade de peças e o setor responsável. A conferência de previsão × conclusão continua inteira,
como o meio que sustenta essa resposta.

Área responsável: **PPCP**.

---

## 1. Problema que a ferramenta resolve

O relatório "Situação do Lote de Produção" traz, para cada ordem de fabricação, a **Previsão** e a
**Conclusão** da ordem, e para cada operação do roteiro a **Previsão do Processo** e a **Conclusão** da
operação. Conferir isso a olho, lote a lote, em PDFs de 10 a 20 páginas, é inviável e não escala.

A ferramenta faz três coisas:

1. **Lê o PDF por posição** e devolve os dados estruturados (ordem, produto, operação, datas, quantidades).
2. **Aponta onde falta apontamento**, separando o que é certeza do que é suspeita, e lista as demais
   inconsistências por severidade.
3. **Exporta CSV** de faltas de apontamento, achados, ordens e operações para Excel e Power BI.

### O achado central: apontamento esquecido

O relatório mostra ausência de **registro**. Ausência de registro tem duas causas — não produziu, ou
produziu e não apontou — e, olhando uma operação isolada, o relatório **não separa as duas**.

Existe um caso em que separa, e é o que dá valor a esta ferramenta: quando uma fase **posterior** do
roteiro já tem apontamento. A peça não pula fase — se foi lixada, foi cortada antes. Então o apontamento
da fase anterior foi **esquecido**, não é falta de produção. O mesmo vale quando a própria ordem foi dada
como concluída. Isso é prova lógica, e a ferramenta marca como `esquecido`.

Sem essa prova, a operação sem registro e com previsão vencida fica marcada como `pendente`: pode ser o
setor que não apontou ou o lote que não chegou lá. **Quem responde é o chão de fábrica, não o relatório.**

A separação entre as duas é deliberada. Tratar suspeita como certeza queima a confiança na ferramenta na
primeira cobrança errada.

### O que a ferramenta NÃO é

- Não substitui o ERP e não grava nada nele. É leitura e conferência.
- Não é fonte de dados para indicador oficial. É instrumento de auditoria pontual.
- Não corrige o roteiro. Aponta onde ele está inconsistente para correção na Engenharia/PPCP.

> **Recomendação técnica registrada:** ler PDF é um contorno, não a solução definitiva. O mesmo dado existe
> nas tabelas de lote, ordem e operação do ERP. Uma consulta direta ao banco (ou uma view publicada para o
> Power BI) elimina a dependência de layout de relatório e permite histórico. Esta ferramenta deve ser
> tratada como ponte até essa integração existir.

---

## 2. Como usar

1. No ERP, emita o relatório **Situação do Lote de Produção** com *Status das Ordens: Todas*.
2. Salve em PDF.
3. Abra a ferramenta e arraste um ou vários PDFs para a área de upload.
4. **Onde travou** abre por padrão: *por que* cada ordem ficou para trás — onde deveria estar
   hoje, onde está, e qual setor a está segurando (ver seção 5.2).
5. **Sem apontamento** é a segunda pergunta: fases sem registro, com peças e setor. O que estiver
   marcado como `esquecido` é cobrança direta; `a confirmar` é dúvida a esclarecer no setor.
6. **Detalhe** (fechado por padrão) traz a evidência: Ordens, Operações, Achados.
7. Antes de tirar conclusão, confira **Leitura dos arquivos** (ver seção 5).

Os arquivos são processados **dentro do navegador**. Nenhum dado é enviado para servidor.
Não há backend, não há banco, não há log de uso.

### Instalar no aparelho

A ferramenta pode ser instalada no computador, tablet ou celular e passa a abrir pelo ícone,
como qualquer programa. Instalada, **funciona sem internet** — inclusive a leitura dos PDFs.

- **Chrome / Edge (Windows, Android):** o item **Instalar no aparelho** aparece na lateral.
- **iPhone / iPad:** o Safari não oferece o botão. Use **Compartilhar → Adicionar à Tela de
  Início**; a própria lateral mostra essa instrução no iOS.

Correções continuam chegando: o app busca a versão publicada sempre que há rede e só usa a
cópia local quando não há. Uma regra de conferência corrigida não fica presa no aparelho.

### Dias úteis

Todo prazo é contado em **dias úteis**: segunda a sexta, descontando feriados nacionais e do
estado de São Paulo — incluindo Carnaval, Sexta-feira Santa e Corpus Christi, calculados a
partir da Páscoa para qualquer ano.

A fábrica não produz no fim de semana. Contar dias corridos inflaria todo atraso que cruzasse
um sábado, sempre para cima: uma ordem prevista para sexta e concluída na segunda apareceria
com 3 dias de atraso quando a produção perdeu 1.

- Jornada: constante `DIAS_UTEIS` no `index.html`. Para incluir sábado, acrescente `6`.
- Feriado municipal e parada coletiva: `CFG.feriadosExtras`, no formato `'aaaa-mm-dd'`.

### Data de referência

O que conta como "vencido" é medido contra a **data de emissão do relatório**, lida do cabeçalho do próprio
PDF — não contra a data de hoje. Isso permite auditar um lote antigo sem que tudo apareça vencido.
O campo pode ser alterado manualmente na tela.

---

## 3. Regras de conferência

| ID | Severidade | O que verifica | Por que importa |
|---|---|---|---|
| `APONT_FURADO` | crítico | Fase sem apontamento com a fase seguinte já apontada, ou em ordem concluída | A peça passou por ali. O apontamento existe para ser feito — cobrança direta com o setor |
| `APONT_SEM_QTD` | crítico | Fase com data de conclusão e quantidade apontada zerada | O setor fechou a fase sem registrar o que produziu |
| `OP_SEM_APONTAMENTO` | atenção | Operação vencida sem nenhum registro, sem prova de que a peça passou | Pode ser falta de apontamento ou de produção; confirmar no setor |
| `OF_ABERTA_VENCIDA` | crítico | Ordem sem conclusão e previsão anterior à data de referência | Ordem parada no plano; impacta a data de corte do lote |
| `OF_SEM_OPERACOES` | crítico | Ordem sem nenhuma operação no relatório | Roteiro vazio ou fase órfã; a ordem não pode ser apontada |
| `OF_CONCL_SEM_APONTAR` | crítico | Ordem concluída e nenhuma operação apontada | Fechamento manual sem produção registrada |
| `OF_CONCL_OP_PENDENTE` | crítico | Ordem concluída com operação sem data de conclusão | O ERP diz pronto, o roteiro diz que não passou por todas as fases |
| `OF_CONCL_OP_SALDO` | crítico | Ordem concluída com `Já Pronto < Qtd. Total` em alguma operação | Saldo perdido; risco de faltar peça na montagem/embalagem |
| `OF_CONCL_ANTES_PREV` | crítico | Conclusão da ordem anterior à primeira previsão de processo do roteiro | Ordem fechada antes de existir programação — furo de dado |
| `APONTADO_MAIOR` | crítico | `Já Pronto > Qtd. Total` na ordem ou na operação | Apontamento acima do previsto; distorce estoque e eficiência |
| `OP_VENCIDA` | atenção | Operação começada e parada no meio, com previsão vencida | Localiza em qual processo o lote travou, com saldo já apontado |
| `OP_SEM_PREVISAO` | atenção | Operação sem previsão do processo | Fase existe no roteiro mas não foi programada |
| `QTD_OP_DIVERGENTE` | atenção | Quantidade da operação diferente da quantidade da ordem | Estrutura ou roteiro com multiplicador errado |
| `SEQ_FORA_ORDEM` | atenção | Operação concluída antes da operação anterior do roteiro | Sequência real diverge do roteiro cadastrado |
| `ROTEIRO_DIVERGENTE` | atenção | Mesmo produto com roteiros diferentes entre ordens (inclusive entre arquivos) | Cadastro inconsistente entre ordens do mesmo item |
| `OF_ATRASO` | info | Ordem concluída depois da previsão | Histórico de aderência; não exige ação imediata |

Todas as regras podem ser ligadas e desligadas na tela, em **Filtros e parâmetros → Regras de conferência ativas**.
A escolha vale só para a sessão; para mudar o padrão, edite `CFG.regras` no `index.html`.

### Setores que ainda não apontam no ERP

Alguns setores ainda não registram no ERP (hoje: PINTAR PU). Neles a ausência de apontamento não
é cobrança nem prova de que a peça está parada. Marcados em **Mais filtros** (guardado no
aparelho; padrão em `CFG.setoresSemApontamento`), saem das duas contas: falta de apontamento e
posição da ordem, que pula para a próxima fase que aponta. A tela declara o que ficou de fora —
aviso nas duas telas, "não aponta" na lateral, recorte na folha impressa. Quando o setor começar a
apontar, desmarque.

**A partir da 3.1.1 o recorte também vale para a lista.** A fase fora da conta **sem apontamento**
sai da tabela **Operações** e do contador da lateral: enquanto ela era listada — e listada como
`VENCIDA` — o filtro parecia não funcionar, e num lote grande essas linhas escondiam o que é de
fato cobrável. O corte é só o que os rótulos prometem: fase isenta que **tem** conclusão ou
quantidade apontada continua na lista, porque ali o registro existe. O cabeçalho da tabela diz
quantas linhas ficaram de fora e por quê, com **mostrar** para trazê-las de volta (aparecem com o
selo `fora da conta`, nunca como vencida). O `operacoes.csv` continua levando **todas** as fases,
com a coluna `ForaDaConta` (sim/não) para filtrar no Power BI.

### Convenção tratada como exceção

Em produto acabado (`1…`) e em volume (`5…`), a operação `EMBALAR` aparece sistematicamente sem
apontamento: a fase existe no roteiro dos dois e não recebe registro em nenhum dos dois. A ferramenta
trata isso como convenção e ignora esses casos por padrão.

> A versão anterior isentava só o acabado, sobre a hipótese de que o apontamento de embalagem
> acontecia na ordem do volume (`501.x`). Não acontece. Enquanto a isenção era só do acabado, toda
> ordem de volume virava falso **apontamento esquecido** no dia seguinte ao prazo da embalagem.

**Componente continua cobrável.** A isenção é por tipo de produto, não pela operação: `EMBALAR` no
roteiro de um código `7xx` entra na conta normalmente, porque ali a falta de apontamento é real.
É por isso que o caso não foi resolvido marcando `EMBALAR` em "setores que ainda não apontam no ERP" —
aquilo isentaria o componente junto.

O comportamento é controlado pela caixa **"Ignorar EMBALAR sem apontamento em produto acabado (1…) e
volume (5…)"** e pelas constantes `CFG.isentaEmbalagem`, `CFG.produtoAcabado`, `CFG.produtoVolume` e
`CFG.operacaoEmbalagem`.

> Se um dia o volume passar a apontar embalagem no ERP, desmarque a caixa para conferir e tire
> `'volume'` de `CFG.isentaEmbalagem` para valer por padrão.

---

## 4. Configuração

Todo o ajuste fica no bloco `CFG`, no topo do `<script>` do `index.html`:

```js
const CFG = {
  produtoAcabado:   /^1/,               // 1… = produto acabado
  produtoVolume:    /^5/,               // 5… = volume (501.x)
  operacaoEmbalagem:/^EMBAL/i,          // nome da operação de embalagem
  isentaEmbalagem: ['acabado','volume'],// tipos sem apontamento de EMBALAR no ERP
  setoresSemApontamento: ['PINTAR PU'], // padrão; ajustável na tela
  tolQtd: 0.001,                        // tolerância de quantidade, em peças
  feriadosExtras: [],                   // 'aaaa-mm-dd' — feriado municipal, parada coletiva
  regras: [ /* id, rótulo, severidade, ativa por padrão */ ]
};
```

Para acrescentar uma regra: inclua a linha em `CFG.regras` e o `add('ID', of, op, detalhe)`
correspondente dentro de `analisar()`. Nada mais precisa ser alterado — filtros, contadores,
tela e CSV se ajustam sozinhos.

---

## 5. Como a ferramenta se protege de ler errado

A extração linear de texto do PDF embaralha as colunas do relatório. Por isso o parser **não** trabalha com
texto sequencial: ele agrupa os itens por coordenada Y (linha), ordena por X e classifica cada valor pelo
tipo (data, data em branco `/ /`, número). A ordem das colunas na tabela de operações é:

```
Descrição | Previsão do Processo | Conclusão | Qtd. Total | Já Pronto | Faltam
```

Consequências práticas do desenho:

- Ordens cujo cabeçalho cai na quebra de página são lidas corretamente.
- `Faltam` só é impresso pelo ERP quando não há data de conclusão; a ferramenta sempre recalcula o saldo.
- Operações repetidas no roteiro (duas fases `PINTAR UV`, por exemplo) são preservadas, não deduplicadas.

- **Um PDF pode trazer vários lotes.** O ERP emite a Situação do Lote por LT, e um LT tem um lote por
  produto, cada um com cabeçalho, previsão e rodapé próprios. Cada lote é lido e conferido separadamente;
  o cabeçalho se repete em toda página e só um número de lote diferente abre um lote novo.
- A linha `Qtd. Concluída na Fase: <FASE> <qtd>` é lida em `of.faseConcluida`: a última fase que o ERP dá
  como completa. É mostrada em "Onde travou" como contraprova.

**Auto-verificação ("leitura conferida"):** a soma de M³ das ordens lidas é comparada com o `Total M3` do
rodapé de cada lote no próprio relatório. O M³ não é usado para mais nada — o PPCP não decide por ele; é só
a prova de que nenhuma ordem ou página ficou de fora. Se divergir, ou se alguma linha não for reconhecida,
a aba **Leitura dos arquivos** exibe alerta.

> Se aparecer aviso nessa aba, **não use os números da tela** antes de revisar o PDF. O layout do relatório
> pode ter mudado.

---

## 5.1 Painel por setor (removido na 3.0.0)

Existiu até a 2.3.0. Dizia o mesmo que "Onde travou" com outra conta (operações vencidas em vez de
ordens paradas) e foi removido por redundância. O texto abaixo fica como registro do critério.


Setor, aqui, é o **processo do roteiro** — o centro de trabalho onde a operação é apontada
(CORTAR, FURAR, PINTAR UV, COLAR FITA, EMBALAR). A seção existe para responder a pergunta do
começo do dia: **onde o lote está travado agora.**

Cada setor é um cartão, ordenado por gravidade (atrasado antes de em andamento, e dentro disso
por operações vencidas e saldo). O cartão traz:

| Campo | O que significa | Como usar |
|---|---|---|
| Vencidas | Operações sem conclusão, previsão anterior à data de referência, **em ordem ainda em aberto** | É a fila real do setor. Só este número define "atrasado" |
| Pendentes | Operações sem conclusão, qualquer que seja a situação da ordem | Carga que ainda vai passar pelo setor |
| Saldo pç | Peças ainda não apontadas nas operações do setor | Quanto de produto está preso ali |
| Desvio médio | Média de (conclusão − previsão do processo) nas operações já concluídas | Positivo = o setor entrega depois do programado. É o sinal de gargalo estrutural, não pontual |
| Avanço | Operações concluídas sobre o total | Leitura rápida de progresso |
| Mais parada | A ordem que está há mais tempo vencida naquele setor | É por ela que se começa a puxar |

**O critério de "vencida" é o mesmo do achado `OP_VENCIDA`**, de propósito: operação isenta pela
convenção de embalagem e operação pendente em ordem já concluída não entram na conta. A primeira
não é atraso; a segunda é inconsistência de apontamento, e aparece nos Achados como tal. Painel e
Achados que discordam do mesmo dado destroem a confiança nos dois.

Abaixo dos cartões fica a tabela **Aderência por setor**, com o número exato por trás de cada um.

### O que o painel não é

Não é medição de capacidade nem de eficiência do setor. Ele lê **datas de um relatório**, não
apontamento de hora, ritmo ou parada. Um setor com desvio médio alto pode estar sem capacidade,
sem material, sem programação — ou apenas sem apontar. O painel diz onde olhar; a causa se
investiga no chão de fábrica.

## 5.2 Onde travou

A aba Ordens diz *se* a ordem está atrasada. Esta seção diz **por quê e onde ir buscá-la**: "o
produto estava previsto para embalar hoje e ainda tem peça na coladeira" — a ordem está travada
na coladeira, e é lá que a conversa acontece.

Para cada ordem **em aberto**:

| Campo | O que significa |
|---|---|
| Deveria estar em | A última fase do roteiro com previsão do processo até a data de referência: o que o PPCP programou a ordem alcançar até hoje |
| Está em | A fase seguinte à última com apontamento. Se a última apontada ainda tem saldo e não foi fechada, é ela mesma (`parcial`). Nenhuma fase apontada: `não começou` |
| Setores atrás | Quantos setores distintos separam onde está de onde deveria estar (três passes de pintura no mesmo setor contam um). `—` com dias parada = atrasada dentro da própria fase |
| Fase concluída (ERP) | A linha "Qtd. Concluída na Fase" do próprio relatório: a última fase que o ERP dá como completa. Contraprova do "Está em" |
| Parada há | Dias úteis desde a previsão da fase onde está |
| Peças na fase | Saldo ainda não apontado na fase onde está |

Os cartões agrupam pelo **setor que está segurando** as ordens — quantas, quantas peças, e a que
está há mais tempo parada. É a ordem de visita ao chão de fábrica.

Regras que evitam leitura errada:

- **Fase anterior em branco com uma posterior apontada não é posição.** É apontamento esquecido
  (seção "Sem apontamento"), e a peça já passou dali. As duas seções não se contradizem: uma
  cobra registro, a outra localiza a peça.
- A EMBALAR isenta por convenção não conta como posição (não é apontada nesta ordem), mas conta
  como programação: "prevista para embalar hoje" continua sendo a régua.
- **Roteiro concluído, ordem não fechada** fica em lista à parte: todas as fases apontadas e a
  ordem em aberto não é atraso de produção, é ordem por encerrar.
- Com filtro de operação, a seção mostra as ordens travadas **naquele** setor.

---

## 6. Exportação

### Levar para a reunião com os líderes

**Imprimir para os líderes** gera uma folha A4 agrupada **por setor** — cada líder responde pelo
processo dele. Cada linha traz a situação, a ordem, o produto, a previsão, as peças, o motivo, e
uma **coluna em branco para a tratativa**: o que a reunião decidir é escrito ali, e a folha vira o
registro em vez de uma lista que se perde. Tem campo de assinatura do PPCP, do responsável pelo
setor e a data.

No topo vem o **quadro de responsabilidade por setor**: quem deixou de apontar, quantas
operações e quantas peças, do pior para o menor. É a resposta consolidada antes do detalhe.

Feita para impressora preto e branco: a situação é dita por palavra, e o que é certeza
(`ESQUECIDO`) leva tarja preta que sobrevive à fotocópia.

**Imprimir a lista da tela** leva a tabela que está sendo vista (Operações, Ordens, Achados)
deitada no papel — para quando alguém questiona o resumo e é preciso mostrar a evidência bruta.

Os dois documentos **declaram o recorte impresso** no cabeçalho: qual filtro estava aplicado,
ou que não havia nenhum. Uma folha que mostra 12 linhas de um lote com 195 operações, sem
dizer que estava filtrada, faz o problema parecer menor do que é.

## 6.1 Exportação

| Botão | Arquivo | Conteúdo |
|---|---|---|
| CSV sem apontamento | `sem-apontamento.csv` | Uma linha por fase sem registro, com situação, setor e peças |
| CSV achados | `achados.csv` | Uma linha por achado, com severidade, regra e detalhe |
| CSV ordens | `ordens.csv` | Uma linha por ordem de fabricação |
| CSV operações | `operacoes.csv` | Uma linha por operação de roteiro, **inclusive as fora da conta**, com a coluna `ForaDaConta` (sim/não) |

Todos respeitam os filtros ativos na tela (lote, produto, setor, tipo, reposição, severidade). O
recorte de "fora da conta" é a única exceção no `operacoes.csv`: em vez de sumir com a fase, ele
vira a coluna `ForaDaConta` — no Power BI o que se quer é o roteiro inteiro com um campo para
filtrar, e a fase ausente deixaria um buraco no roteiro sem nenhum aviso do outro lado.

Formato: separador `;`, decimal com vírgula, datas `dd/mm/aaaa`, codificação UTF-8 com BOM.
Abre direto no Excel pt-BR e é lido pelo Power BI com locale pt-BR.

---

## 7. Stack e estrutura

Arquivo único, sem etapa de build, sem framework, sem backend.

```
.
├── index.html                 # aplicação inteira (HTML + CSS + JS)
├── sw.js                      # service worker: uso offline
├── manifest.webmanifest       # instalação no aparelho
├── icone-192.png              # ícones do app instalado
├── icone-512.png
├── icone-maskable.png         # com margem para o recorte circular do Android
├── favicon.svg
├── vendor/
│   ├── pdf.min.js             # pdf.js 3.11.174 (Apache-2.0)
│   ├── pdf.worker.min.js
│   └── LICENSE-pdfjs.txt
├── vercel.json                # headers de segurança e cache
├── .gitignore
├── CHANGELOG.md
└── README.md
```

O `pdf.js` é **versionado no repositório**, não carregado de CDN. Isso mantém a ferramenta funcionando com
rede instável ou bloqueio de domínio externo, cenário real na fábrica.

### Identidade visual

Segue o sistema visual do **RitmoPatrimar** (repositório `crono-analise`), com os mesmos tokens:

- Marca: vermelho `#DB2126`, bordeaux `#A8140F`, areia `#F7ECC0`, grafite `#1F2328`.
- Status: verde `#15803D`, âmbar `#B45309`, laranja queimado `#C2410C`, neutro `#64748B`.
- Tipografia Calibri no texto; `Roboto Mono` tabular em todo número, data e código.
- Escala de espaçamento 4/8/12/16/24/32/48/64 e escala tipográfica de razão ~1,2.

Duas decisões herdadas, com o motivo:

**O vermelho da marca é identidade, nunca status.** Se `#DB2126` também sinalizasse erro, o usuário
perderia a capacidade de distinguir "isto é da Patrimar" de "isto está com problema". Estado crítico
usa laranja queimado, sempre acompanhado de texto — a cor nunca informa sozinha.

**Lateral escura, conteúdo claro.** A navegação nunca vai para a impressora nem para o Excel;
o conteúdo, sim. Escurecer o menu separa navegação de conteúdo com a coisa mais barata que existe,
a cor do fundo, e devolve o branco inteiro para o trabalho.

### Compatibilidade

Chrome, Edge e Firefox atuais. Uso previsto em desktop — a tela é densa, com tabelas de até doze
colunas. Em tela estreita o layout se reorganiza (lateral acima, conteúdo abaixo) e as tabelas rolam
dentro do próprio bloco, mas conferir um lote no celular continua sendo trabalho ruim.

---

## 8. Deploy

### 8.1 Repositório

Organização GitHub: `p09728655-maker`.
Repositório: `CONFERIR-DATA-PREVIS-O-DO-PROCESSO-X-CONCLUS-O`.

### 8.2 Vercel

Conta: `p09728655-1429`.

1. **Add New → Project → Import Git Repository** e selecione o repositório.
2. Framework Preset: **Other**.
3. Build Command: **deixar vazio**.
4. Output Directory: **deixar vazio** (a raiz é servida como estático).
5. Install Command: **deixar vazio**.
6. Deploy.

Não há variável de ambiente. Não há secret. Não há chave de API.

### 8.3 Após o deploy

- **Confirme que `https://<projeto>.vercel.app/vendor/pdf.min.js` responde 200.**
  Sem a pasta `vendor` a ferramenta não lê PDF nenhum — foi exatamente o que aconteceu no primeiro
  deploy, quando o repositório subiu só com o `index.html`. A tela exibe a mensagem de erro
  correspondente, mas o problema é de publicação, não de arquivo.
- Faça um teste de ponta a ponta com um lote já conhecido antes de divulgar o link.

### 8.4 Acesso

O projeto é público por padrão no Vercel. Ele **não contém dado de produção** — os PDFs são abertos
localmente pelo usuário e nunca trafegam. Ainda assim, se a política interna exigir, ative
**Vercel Authentication** ou **Password Protection** em *Project Settings → Deployment Protection*.

---

## 9. Segurança e LGPD

- Processamento 100% no navegador. Nenhum upload, nenhum armazenamento, nenhum log de conteúdo.
- O repositório não contém dado de produção. O `.gitignore` bloqueia `*.pdf`, `*.csv` e `*.xlsx`
  justamente para evitar commit acidental de relatório com dado da fábrica.
- Os CSVs exportados **contêm dado operacional da Patrimar**. Tratar com o mesmo cuidado de qualquer
  relatório interno: não subir em repositório, não anexar em ferramenta externa.

---

## 10. Limitações conhecidas

1. **Depende do layout do relatório.** Mudança de layout no ERP quebra a leitura. A auto-verificação avisa,
   mas a correção exige ajuste no parser.
2. **Não há histórico.** Cada sessão parte do zero. Para tendência de aderência ao longo do tempo, exporte
   os CSVs e acumule no Power BI, ou resolva na origem com consulta ao ERP.
3. **A regra `SEQ_FORA_ORDEM` compara pela ordem de impressão do roteiro**, que assume ser a sequência
   cadastrada. Se o relatório imprimir fora de sequência, gera falso positivo.
4. **Sem verificação de estrutura de produto.** A ferramenta confere roteiro e apontamento, não a árvore
   de componentes.
5. **A ferramenta lê o relatório, não a realidade.** Se o apontamento não foi feito no ERP, o achado aponta
   falta de apontamento — não necessariamente falta de produção. Vale igualmente para o Painel por setor:
   ele mede datas, não capacidade.
6. **O parser depende da posição das colunas.** A partir da v1.1.0 um valor só é aceito na coluna cujo
   tipo ele tem, e divergência vira aviso — mas a defesa é contra ler errado em silêncio, não contra
   uma mudança de layout, que continua exigindo ajuste no código.

---

## 11. Manutenção

Ao alterar qualquer regra de conferência ou o parser:

1. Rode um lote **já encerrado e conhecido** e confira se os achados batem com o que se sabe do chão de fábrica.
2. Rode um lote **em andamento** e verifique se não há falso positivo.
3. Confirme na aba **Leitura dos arquivos** que cada lote está "leitura conferida" e que não há linha ignorada.
4. Atualize a constante `VERSAO` no `index.html`, acrescente a entrada no diálogo de histórico
   (`#dlgVersao`, no próprio `index.html`) e registre a mudança no `CHANGELOG.md`.

### Teste de ponta a ponta

Não há suíte automatizada no repositório. O teste da v1.1.0 foi feito no navegador com um PDF
sintético que reproduz o layout do relatório e dispara cada uma das 13 regras. Ao mexer no parser,
o mínimo é: abrir um lote conhecido, ver "leitura conferida" em cada lote, e verificar que nenhuma coluna
escorregou (data onde deveria haver data, número onde deveria haver número).
