# Conferência de Lotes de Produção — Patrimar Móveis

Ferramenta de conferência dos relatórios **"Situação do Lote de Produção"** emitidos pelo ERP Industrial (Lógica).
Lê vários PDFs de uma vez, consolida ordens e operações, e aplica um conjunto de regras que aponta
inconsistências de apontamento, quebras de roteiro e desvios de prazo.

Área responsável: **PPCP**.

---

## 1. Problema que a ferramenta resolve

O relatório "Situação do Lote de Produção" traz, para cada ordem de fabricação, a **Previsão** e a
**Conclusão** da ordem, e para cada operação do roteiro a **Previsão do Processo** e a **Conclusão** da
operação. Conferir isso a olho, lote a lote, em PDFs de 10 a 20 páginas, é inviável e não escala.

A ferramenta faz três coisas:

1. **Lê o PDF por posição** e devolve os dados estruturados (ordem, produto, operação, datas, quantidades).
2. **Aplica regras de conferência** e lista o que exige atenção, priorizado por severidade.
3. **Exporta CSV** de achados, ordens e operações para Excel e Power BI.

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
4. Comece pela aba **Achados**. Depois use **Ordens**, **Operações** e **Aderência por processo**.
5. Antes de tirar conclusão, confira a aba **Leitura dos arquivos** (ver seção 5).

Os arquivos são processados **dentro do navegador**. Nenhum dado é enviado para servidor.
Não há backend, não há banco, não há log de uso.

### Data de referência

O que conta como "vencido" é medido contra a **data de emissão do relatório**, lida do cabeçalho do próprio
PDF — não contra a data de hoje. Isso permite auditar um lote antigo sem que tudo apareça vencido.
O campo pode ser alterado manualmente na tela.

---

## 3. Regras de conferência

| ID | Severidade | O que verifica | Por que importa |
|---|---|---|---|
| `OF_ABERTA_VENCIDA` | crítico | Ordem sem conclusão e previsão anterior à data de referência | Ordem parada no plano; impacta a data de corte do lote |
| `OF_SEM_OPERACOES` | crítico | Ordem sem nenhuma operação no relatório | Roteiro vazio ou fase órfã; a ordem não pode ser apontada |
| `OF_CONCL_SEM_APONTAR` | crítico | Ordem concluída e nenhuma operação apontada | Fechamento manual sem produção registrada |
| `OF_CONCL_OP_PENDENTE` | crítico | Ordem concluída com operação sem data de conclusão | O ERP diz pronto, o roteiro diz que não passou por todas as fases |
| `OF_CONCL_OP_SALDO` | crítico | Ordem concluída com `Já Pronto < Qtd. Total` em alguma operação | Saldo perdido; risco de faltar peça na montagem/embalagem |
| `OF_CONCL_ANTES_PREV` | crítico | Conclusão da ordem anterior à primeira previsão de processo do roteiro | Ordem fechada antes de existir programação — furo de dado |
| `APONTADO_MAIOR` | crítico | `Já Pronto > Qtd. Total` na ordem ou na operação | Apontamento acima do previsto; distorce estoque e eficiência |
| `OP_VENCIDA` | atenção | Operação sem conclusão com previsão vencida (em ordem aberta) | Localiza em qual processo o lote travou |
| `OP_SEM_PREVISAO` | atenção | Operação sem previsão do processo | Fase existe no roteiro mas não foi programada |
| `QTD_OP_DIVERGENTE` | atenção | Quantidade da operação diferente da quantidade da ordem | Estrutura ou roteiro com multiplicador errado |
| `SEQ_FORA_ORDEM` | atenção | Operação concluída antes da operação anterior do roteiro | Sequência real diverge do roteiro cadastrado |
| `ROTEIRO_DIVERGENTE` | atenção | Mesmo produto com roteiros diferentes entre ordens (inclusive entre arquivos) | Cadastro inconsistente entre ordens do mesmo item |
| `OF_ATRASO` | info | Ordem concluída depois da previsão | Histórico de aderência; não exige ação imediata |

Todas as regras podem ser ligadas e desligadas na tela, em **Filtros e parâmetros → Regras de conferência ativas**.
A escolha vale só para a sessão; para mudar o padrão, edite `CFG.regras` no `index.html`.

### Convenção tratada como exceção

Nos produtos acabados de prefixo `103.`, a operação `EMBALAR` aparece sistematicamente sem apontamento —
o apontamento real acontece na ordem do volume correspondente (`501.`). A ferramenta trata isso como
convenção e ignora esses casos por padrão.

O comportamento é controlado pela caixa **"Ignorar EMBALAR sem apontamento em produto acabado"** e pelas
constantes `CFG.produtoAcabado` e `CFG.operacaoEmbalagem`.

> Esta premissa foi inferida dos dados, **não confirmada pela Engenharia**. Se estiver errada, desmarque a
> caixa e os casos voltam a aparecer como achado.

---

## 4. Configuração

Todo o ajuste fica no bloco `CFG`, no topo do `<script>` do `index.html`:

```js
const CFG = {
  produtoAcabado:   /^103\./,   // prefixo de produto acabado
  operacaoEmbalagem:/^EMBAL/i,  // nome da operação de embalagem
  tolQtd: 0.001,                // tolerância de quantidade, em peças
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

**Auto-verificação:** a soma de M³ das ordens lidas é comparada com o `Total M3` do rodapé do próprio
relatório. Se divergir, ou se alguma linha não for reconhecida, a aba **Leitura dos arquivos** exibe alerta.

> Se aparecer aviso nessa aba, **não use os números da tela** antes de revisar o PDF. O layout do relatório
> pode ter mudado.

---

## 6. Exportação

| Botão | Arquivo | Conteúdo |
|---|---|---|
| CSV achados | `achados.csv` | Uma linha por achado, com severidade, regra e detalhe |
| CSV ordens | `ordens.csv` | Uma linha por ordem de fabricação |
| CSV operações | `operacoes.csv` | Uma linha por operação de roteiro |

Os três respeitam os filtros ativos na tela.

Formato: separador `;`, decimal com vírgula, datas `dd/mm/aaaa`, codificação UTF-8 com BOM.
Abre direto no Excel pt-BR e é lido pelo Power BI com locale pt-BR.

---

## 7. Stack e estrutura

Arquivo único, sem etapa de build, sem framework, sem backend.

```
.
├── index.html                 # aplicação inteira (HTML + CSS + JS)
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

Segue o padrão Patrimar: vermelho `#DB2126`, bordeaux `#A8140F`, grafite `#1F2328`, tipografia Calibri.
As cores de status são **deliberadamente distintas do vermelho de marca**, para que "identidade" e
"problema" não se confundam na tela.

### Compatibilidade

Chrome, Edge e Firefox atuais. Uso previsto em desktop — a tela é densa e não foi projetada para celular.

---

## 8. Deploy

### 8.1 Repositório

Organização GitHub: `p09728655-maker`. Repositório sugerido: `conferencia-lotes-patrimar`.

```bash
git init
git add .
git commit -m "feat: conferencia de lotes de producao v1.0.0"
git branch -M main
git remote add origin https://github.com/p09728655-maker/conferencia-lotes-patrimar.git
git push -u origin main
```

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

- Confirme que `https://<projeto>.vercel.app/vendor/pdf.min.js` responde 200.
  Se a pasta `vendor` não subir, a ferramenta não lê PDF nenhum e exibe a mensagem de erro correspondente.
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
   falta de apontamento — não necessariamente falta de produção.

---

## 11. Manutenção

Ao alterar qualquer regra de conferência ou o parser:

1. Rode um lote **já encerrado e conhecido** e confira se os achados batem com o que se sabe do chão de fábrica.
2. Rode um lote **em andamento** e verifique se não há falso positivo.
3. Confirme na aba **Leitura dos arquivos** que o M³ confere e que não há linha ignorada.
4. Atualize a constante `VERSAO` no `index.html` e registre a mudança no `CHANGELOG.md`.
