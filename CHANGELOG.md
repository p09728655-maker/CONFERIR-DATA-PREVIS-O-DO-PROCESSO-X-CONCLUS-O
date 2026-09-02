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
