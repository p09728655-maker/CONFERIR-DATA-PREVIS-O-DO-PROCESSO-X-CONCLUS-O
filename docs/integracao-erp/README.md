# Integração direta com o banco do ERP — plano de execução

O RitmoPatrimar lê o PDF do relatório **Situação do Lote de Produção**. O próprio
README registra, desde a primeira versão, que isso é ponte e não solução: *"o mesmo
dado existe nas tabelas de lote, ordem e operação do ERP"*. Este documento é o
detalhe que faltava lá — o que precisa existir para atravessar a ponte, na ordem em
que precisa existir.

> **Nada aqui foi executado contra o banco da Lógica.** Os scripts foram rodados
> ponta a ponta num PostgreSQL 16 limpo, com schema e dados simulados: o DDL cria,
> a descoberta encontra as tabelas e as chaves estrangeiras do schema falso, o
> comparativo classifica corretamente fase fechada, avanço parcial, estorno, ordem
> nova e parada, e o teste de aceite passa contra um `operacoes.csv` que replica o
> formato do exportador (BOM, `;`, CRLF, `dd/mm/aaaa`, decimal com vírgula) — e
> acusa as três divergências quando esse CSV é adulterado de propósito.
>
> Isso valida a sintaxe e a lógica, **não o mapeamento**. A consulta de extração do
> job (`04`) está com o `SELECT` em branco, porque os nomes reais das tabelas da
> Lógica ainda não são conhecidos. Tratar como roteiro de trabalho, não como
> integração pronta.

---

## 1. O que a integração resolve

Uma coisa só, e não é a que parece: **histórico**.

A ferramenta responde "como o lote está agora". Não responde "o que mudou de ontem
para hoje", e não responde por decisão de projeto — ela guarda uma foto por lote, e
abrir o mesmo lote duas vezes substitui a leitura anterior em vez de somar
(`index.html`, `trocarLoteRepetido`). Somar duas fotos do mesmo objeto dobraria
ordens e peças mantendo os percentuais certos, que é o tipo de erro que não parece
erro.

Consulta direta ao banco **não resolve isso sozinha**. O banco do ERP também é foto
do agora: ele sobrescreve. O que resolve é gravar a foto todo dia, em tabela própria,
e comparar as fotos. É por isso que o centro deste plano é a tabela de snapshot, e
não a consulta.

O que se ganha junto, de graça, uma vez que a série exista:

- avanço diário real por setor, em peças, sem depender de alguém ter salvado o PDF;
- aderência ao plano ao longo do tempo, não por lote isolado;
- lead time medido, em vez de estimado;
- detecção de **estorno de apontamento** — fase que tinha conclusão ontem e não tem
  hoje. Hoje isso é invisível.

---

## 2. O ambiente

| | |
|---|---|
| ERP | Lógica |
| SGBD | PostgreSQL |
| Onde roda | servidor na Patrimar (on-premise) |
| Consumidor | Power BI |

On-premise decide a arquitetura inteira: **tudo roda dentro da rede**, sem VPN, sem
túnel, sem dado saindo da empresa. Elimina a discussão de segurança que uma
hospedagem externa exigiria, e elimina a hospedagem externa junto — se o consumidor
é Power BI, ela não tem função aqui.

Ainda falta levantar:

- versão do PostgreSQL (`SELECT version()`) — muda o nome das colunas do
  `pg_stat_statements` e pouco mais;
- sistema operacional do servidor, para escolher entre cron e Agendador de Tarefas;
- se os relatórios do Power BI ficarão publicados no serviço com atualização
  automática. Se sim, é preciso **On-premises Data Gateway** instalado e com dono
  definido. Se for Power BI Desktop com atualização manual, não precisa.

---

## 3. A regra inegociável

**Nada é criado dentro do banco do ERP.** Nem tabela, nem view, nem índice, nem
procedure.

Não é preciosismo. No dia em que o ERP apresentar lentidão, erro ou corrupção e o
suporte da Lógica encontrar objeto estranho no banco deles, a causa vira a
integração — esteja ela certa ou errada — e a discussão de suporte acaba ali. O
`02-usuario-leitura.sql` cria um *role*, que é objeto de instância, não de banco: não
há nada nosso convivendo com as tabelas da Lógica.

Isso também facilita a conversa com a TI. Você não está pedindo para alterar o ERP.
Está pedindo para ler.

---

## 4. Arquitetura

```
banco do ERP (Lógica)        job diário 05:00        banco ppcp_bi          Power BI
somente leitura        ─────────────────────▶   snapshot_operacao   ─────▶  comparativo,
statement_timeout 60s        extrai e grava         só INSERT               aderência,
                                                                            lead time
```

Banco separado, e não schema dentro do banco do ERP. No PostgreSQL isso custa não
poder consultar um banco a partir do outro sem `postgres_fdw` ou `dblink` — custo que
o job resolve com arquivo intermediário, sem instalar extensão e sem tocar no lado do
ERP.

**`pg_cron` está descartado**: exige entrar em `shared_preload_libraries`, o que exige
reiniciar o servidor, o que significa parar o ERP. Não vale por um agendamento que o
sistema operacional já faz de graça.

---

## 5. Ordem de execução

### Passo 0 — em paralelo, antes de tudo

Dois pedidos, ao mesmo tempo. Não espere um para começar o outro.

**Para a Lógica:**

1. Existe dicionário de dados das tabelas de lote, ordem de fabricação e operação?
2. Vocês fornecem views de integração ou módulo de BI para leitura?
3. Acesso somente leitura ao banco fere contrato ou suporte?

A primeira pergunta é a que mais importa, e a razão é de manutenção, não de
educação: **uma view fornecida pelo fornecedor é mantida por contrato; uma consulta
obtida por engenharia reversa quebra em silêncio na próxima atualização do ERP.**
Renomearam uma coluna, o job continua rodando, e o snapshot passa a gravar dado
errado sem erro nenhum. Esse custo é permanente, não é de uma vez só. Se a Lógica
cobrar pela view, compare com o custo de manter engenharia reversa viva por anos.

**Para a TI:** o pedido está no [Anexo A](#anexo-a--pedido-para-a-ti).

### Passo 1 — descoberta · [`01-descoberta.sql`](01-descoberta.sql)

Numa **cópia de backup restaurada**, nunca em produção. Peça a restauração de um
backup que a TI já tem; não peça `pg_dump` novo em horário de expediente.

Restaurar cópia para estudo é infinitamente mais fácil de aprovar do que acesso ao
banco de produção. Comece pela porta que abre.

Comece pelo item 2 do script — o `pg_stat_statements`. Se a extensão estiver
instalada, você emite o relatório no ERP e lê **o SQL que a própria Lógica executa**,
com as regras de negócio embutidas. São cinco minutos que podem economizar duas
semanas.

### Passo 2 — acesso · [`02-usuario-leitura.sql`](02-usuario-leitura.sql)

Usuário dedicado, somente leitura, com `statement_timeout` de 60s. O timeout é o
argumento que derruba o "BI vai travar o ERP" — inclua no pedido, não espere
perguntarem.

Terminado o mapeamento, feche o `GRANT` amplo e deixe só as tabelas identificadas.
O script tem o bloco pronto no fim.

### Passo 3 — histórico · [`03-ppcp-bi-ddl.sql`](03-ppcp-bi-ddl.sql)

Cria `ppcp_bi`, a tabela `snapshot_operacao`, a tabela `snapshot_execucao` e os dois
usuários (carga e leitura).

Duas decisões que valem explicação:

- **`seq` está na chave primária.** O roteiro repete a mesma operação — três passes
  de PINTAR UV na mesma ordem — e o parser preserva essa repetição justamente por
  isso. Chave sem `seq` funde fases distintas e o histórico passa a mentir sem dar
  erro.
- **`saldo` não é gravado.** É `qtd_total - ja_pronto`, derivado. A ferramenta atual
  também recalcula sempre, em vez de confiar no "Faltam" impresso pelo ERP.
- **`ppcp_carga` não tem `UPDATE` nem `DELETE` em `snapshot_operacao`.** A regra "só
  INSERT" fica no banco, não só na disciplina de quem escreve o script.

### Passo 4 — job · [`04-snapshot-job.sh`](04-snapshot-job.sh)

Agende às 05:00, antes do primeiro turno. Consulta pesada em banco de ERP no meio do
expediente concorre com o terminal de apontamento do chão de fábrica.

O `SELECT` de extração é o **único** ponto do plano que depende do schema da Lógica.
Tudo o mais já está escrito.

O script extrai para arquivo antes de carregar, e não em pipe direto. Pipe é mais
curto e está errado: se a origem falhar no meio, ela já emitiu CSV parcial, o destino
carrega e comita esse pedaço, e o dia fica gravado pela metade sem ninguém saber.

Ele termina com uma checagem de sanidade: variação de mais de 30% no número de linhas
contra a coleta anterior marca a execução como `suspeito`. Isso não reprova o dado —
chama alguém para olhar. **Sem essa checagem, uma atualização do ERP que renomeie
coluna transforma o job num gerador silencioso de dado errado, e você descobre meses
depois.**

### Passo 5 — teste de aceite · [`06-validacao.sql`](06-validacao.sql)

**Este passo não pode ser pulado.**

O PDF não é a tabela crua. O relatório aplica regra — "Faltam" só é impresso quando
não há conclusão, "Qtd. Concluída na Fase" é derivada — e uma consulta que lê as
tabelas e supõe que dá no mesmo está errada até prova em contrário.

O teste compara, linha a linha, a saída da consulta contra o `operacoes.csv` que o
RitmoPatrimar exporta do PDF do **mesmo lote e da mesma data de emissão**. As três
consultas de divergência têm que voltar vazias.

Você já tem os dois lados prontos, o que torna esse teste barato. Rode antes de
agendar o job, e de novo a cada atualização do ERP.

Se voltar linha, o mapa das tabelas está errado. Não ajuste o teste.

### Passo 6 — a resposta · [`05-diff-lote.sql`](05-diff-lote.sql)

Com duas coletas na mesa, "o que mudou de ontem para hoje no 163/26" vira uma
consulta. `sem movimento` é a linha que interessa: fase que fechou é informação boa;
fase parada dois dias seguidos é a visita ao chão de fábrica.

---

## 6. Piloto de uma semana

Não peça o projeto inteiro. Peça o piloto.

| Dia | O quê |
|---|---|
| 1–2 | Backup restaurado em teste; mapear as tabelas de um lote conhecido |
| 3 | Escrever a consulta e rodar o teste de aceite. **Tem que bater 100%** |
| 4 | Tabela de snapshot e job rodando, só para lotes abertos |
| 5+ | Deixar acumular |

Na primeira semana você já tem o comparativo que originou a demanda, e o lote de
teste vira o caso de demonstração. Com uma semana de dado rodando, você tem prova
para pedir o resto. Sem ela, é promessa.

**Estimativa honesta:** com dicionário ou view da Lógica, 2 a 3 dias de trabalho
efetivo. Por engenharia reversa, 1 a 3 semanas — e a variação inteira está no
mapeamento. Construir o job e o painel é a parte fácil e previsível.

---

## 7. Riscos

| Risco | Consequência | Mitigação |
|---|---|---|
| Atualização do ERP renomeia tabela ou coluna | Job continua rodando e grava dado errado, sem erro | Checagem de sanidade no job; refazer o teste de aceite a cada atualização |
| Consulta pesada em horário de pico | Concorre com apontamento no chão de fábrica | Janela 05:00 + `statement_timeout` no role |
| Consulta diverge do relatório oficial | A ferramenta perde credibilidade numa reunião, esteja certa ou errada | Teste de aceite obrigatório antes de publicar qualquer número |
| Job para e ninguém percebe | Lote sem coleta parece lote sem movimento | `snapshot_execucao` + a consulta de buracos na série (`05`, item 3) |
| Acesso direto negado por contrato | Plano inteiro cai | Perguntar à Lógica **antes** de construir; alternativas na seção 8 |

---

## 8. Se o acesso direto for negado

Em ordem de preferência:

1. **API ou webservice do ERP**, se existir — pergunte, muitos têm.
2. **Exportação agendada pelo próprio ERP** para uma pasta. Mais feio, funciona, não
   fere contrato.
3. **PDF automatizado**: pasta monitorada e o parser que já existe rodando no
   servidor. O código de leitura já está pronto e validado em campo; seria portar de
   navegador para Node.

---

## 9. O que isto NÃO muda

**O RitmoPatrimar continua como está.** Client-side, sem backend, sem banco, offline,
instalável no tablet. Isso não é limitação a ser superada — é vantagem real: roda sem
depender de TI, sem rede, e sem servidor para manter.

Fazer o app ler o banco exigiria backend, autenticação e servidor, e trocaria essa
vantagem por uma dependência. O snapshot alimenta o **Power BI**; o app segue sendo
leitura de PDF e auditoria pontual de lote, inclusive de lote antigo e inclusive
quando o banco estiver fora do ar.

Os dois convivem. O parser continua sendo o plano B, e continua sendo o outro lado do
teste de aceite.

---

## Anexo A — pedido para a TI

> **Assunto: acesso somente leitura ao banco do ERP Lógica — histórico de produção (PPCP)**
>
> Preciso construir um histórico diário da situação dos lotes de produção, que hoje
> não existe: o relatório do ERP mostra apenas a situação atual e não permite comparar
> como o lote estava ontem. Sem isso não é possível medir avanço real, aderência ao
> plano nem lead time por setor.
>
> Solicito:
>
> 1. **Usuário de banco somente leitura**, dedicado ao PPCP, com `SELECT` limitado às
>    tabelas de lote, ordem de fabricação, operação/roteiro e apontamento, e
>    `statement_timeout` de 60 segundos — consulta que passar disso morre sozinha, em
>    vez de segurar o banco que atende o apontamento.
> 2. **Cópia de backup restaurada em instância de teste**, para mapear as tabelas sem
>    tocar em produção.
> 3. **Banco separado** (`ppcp_bi`) na infraestrutura existente, para gravar o
>    histórico. **Nenhum objeto será criado dentro do banco do ERP.**
> 4. **Tarefa agendada às 05:00**, antes do primeiro turno.
> 5. Versão do PostgreSQL e sistema operacional do servidor.
> 6. Se possível, a permissão `pg_read_all_stats` temporária para o usuário de
>    leitura, ou a informação de que a extensão `pg_stat_statements` está ativa — isso
>    encurta bastante o mapeamento.
>
> Volume estimado: cerca de 26 mil linhas por dia, 6,6 milhões por ano — desprezível
> para o servidor.
>
> Estou consultando a Lógica em paralelo sobre dicionário de dados ou views de
> integração, que seria o caminho preferencial por ser mantido em contrato.
