# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento semântico.

## [1.0.0] — 2026-09-02

### Adicionado

- Leitura posicional de PDFs do relatório "Situação do Lote de Produção" (ERP Lógica),
  com suporte a múltiplos arquivos na mesma sessão.
- Reconhecimento de ordens cujo cabeçalho cai na quebra de página.
- Auto-verificação da leitura: soma de M³ das ordens conferida contra o `Total M3` do rodapé
  do próprio relatório; contagem de linhas não reconhecidas.
- Motor com 13 regras de conferência (5 níveis de dado inconsistente, prazo e roteiro),
  ligáveis e desligáveis na tela.
- Exceção configurável para `EMBALAR` sem apontamento em produto acabado de prefixo `103.`.
- Data de referência baseada na data de emissão do relatório, não na data do sistema.
- Abas: Achados, Ordens, Operações, Aderência por processo, Leitura dos arquivos.
- Indicadores de topo: ordens com achado crítico, em aberto e vencidas, aderência de prazo,
  saldo a produzir.
- Exportação CSV de achados, ordens e operações (`;`, decimal vírgula, data `dd/mm/aaaa`, UTF-8 com BOM).
- `pdf.js` 3.11.174 versionado em `vendor/`, eliminando dependência de CDN.

### Validação

Testado contra o lote `025121` — LT 159/26 MESA CABECEIRA SLEEP (13 páginas):
51 ordens e 206 operações lidas, zero linhas ignoradas, M³ conferindo com o rodapé (83,397).

### Pendências conhecidas

- Confirmar com a Engenharia se `EMBALAR` sem apontamento em produto `103.` é convenção
  (premissa inferida dos dados, ainda não validada).
- Avaliar substituição da leitura de PDF por consulta direta ao ERP.
