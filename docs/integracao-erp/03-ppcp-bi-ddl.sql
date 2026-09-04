-- =============================================================================
-- 03 — BANCO DO HISTORICO (ppcp_bi) E A TABELA DE SNAPSHOT
-- =============================================================================
-- Rode com psql: o arquivo usa \c para trocar de banco no meio.
--
--   psql -h SERVIDOR -U postgres -f 03-ppcp-bi-ddl.sql
--
-- Banco SEPARADO, nao schema dentro do banco do ERP. No PostgreSQL isso custa
-- nao poder consultar um banco a partir do outro sem postgres_fdw ou dblink —
-- custo que o job do passo 04 resolve com um pipe de COPY, sem instalar
-- extensao nenhuma e sem criar nada do lado do ERP.
-- =============================================================================

CREATE DATABASE ppcp_bi;

\c ppcp_bi

-- -----------------------------------------------------------------------------
-- Grao: uma linha por dia x lote x ordem x sequencia da operacao
-- -----------------------------------------------------------------------------
-- `seq` esta na chave de proposito. O roteiro repete a mesma operacao — tres
-- passes de PINTAR UV na mesma ordem —, e o parser do RitmoPatrimar preserva
-- essas repeticoes justamente por isso. Chave sem `seq` funde fases distintas e
-- o historico passa a mentir sem dar erro.
--
-- `saldo` NAO e gravado: e qtd_total - ja_pronto, derivado. A ferramenta atual
-- tambem sempre recalcula, em vez de confiar no "Faltam" impresso. Campo
-- calculado guardado e o lugar classico onde um valor fica errado sozinho.
CREATE TABLE snapshot_operacao (
  data_snapshot     date          NOT NULL,
  lote              text          NOT NULL,
  lt                text,
  ordem             text          NOT NULL,
  seq               smallint      NOT NULL,
  produto           text,
  descricao_produto text,
  operacao          text,
  previsao_lote     date,
  previsao_processo date,
  conclusao         date,
  qtd_total         numeric(14,3),
  ja_pronto         numeric(14,3),
  ordem_previsao    date,
  ordem_conclusao   date,
  extraido_em       timestamptz   NOT NULL DEFAULT now(),
  PRIMARY KEY (data_snapshot, lote, ordem, seq)
);

COMMENT ON TABLE  snapshot_operacao                   IS 'Foto diaria da situacao das operacoes. Somente INSERT: o valor esta na serie, e UPDATE destroi exatamente o que se quer medir.';
COMMENT ON COLUMN snapshot_operacao.data_snapshot     IS 'Dia da extracao. Nao e data do ERP — e quando a foto foi tirada.';
COMMENT ON COLUMN snapshot_operacao.seq               IS 'Sequencia da operacao no roteiro. Na chave porque o roteiro repete operacoes.';
COMMENT ON COLUMN snapshot_operacao.previsao_processo IS 'Previsao do Processo da operacao, no relatorio Situacao do Lote.';
COMMENT ON COLUMN snapshot_operacao.conclusao         IS 'Conclusao da operacao. NULL = sem apontamento.';
COMMENT ON COLUMN snapshot_operacao.ja_pronto         IS 'Quantidade ja apontada na operacao.';
COMMENT ON COLUMN snapshot_operacao.extraido_em       IS 'Momento exato da carga. Distingue duas cargas do mesmo dia (reprocessamento).';

CREATE INDEX ix_snap_lote_data ON snapshot_operacao (lote, data_snapshot);
CREATE INDEX ix_snap_ordem     ON snapshot_operacao (ordem, data_snapshot);


-- -----------------------------------------------------------------------------
-- Log de execucao do job
-- -----------------------------------------------------------------------------
-- Sem isto, um job que parou de rodar ha duas semanas parece um lote sem
-- movimento. O buraco na serie tem que ser visivel COMO buraco.
CREATE TABLE snapshot_execucao (
  data_snapshot date        NOT NULL,
  iniciado_em   timestamptz NOT NULL DEFAULT now(),
  terminado_em  timestamptz,
  linhas        integer,
  situacao      text        NOT NULL DEFAULT 'rodando',   -- rodando | ok | falha | suspeito
  observacao    text,
  PRIMARY KEY (data_snapshot, iniciado_em)
);

COMMENT ON TABLE snapshot_execucao IS 'Uma linha por execucao do job. Dia sem linha aqui e dia sem coleta, nao dia sem movimento.';


-- -----------------------------------------------------------------------------
-- Usuario de escrita do job
-- -----------------------------------------------------------------------------
CREATE ROLE ppcp_carga LOGIN PASSWORD 'DEFINA_UMA_SENHA_FORTE';
GRANT CONNECT ON DATABASE ppcp_bi TO ppcp_carga;
GRANT USAGE   ON SCHEMA   public  TO ppcp_carga;
GRANT INSERT, SELECT ON snapshot_operacao TO ppcp_carga;
GRANT INSERT, SELECT, UPDATE ON snapshot_execucao TO ppcp_carga;
-- Sem UPDATE nem DELETE em snapshot_operacao: a regra "so INSERT" fica no
-- banco, nao so na disciplina de quem escreve o script.

-- Usuario de leitura para o Power BI
CREATE ROLE ppcp_bi_leitura LOGIN PASSWORD 'DEFINA_UMA_SENHA_FORTE';
GRANT CONNECT ON DATABASE ppcp_bi TO ppcp_bi_leitura;
GRANT USAGE   ON SCHEMA   public  TO ppcp_bi_leitura;
GRANT SELECT  ON ALL TABLES IN SCHEMA public TO ppcp_bi_leitura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ppcp_bi_leitura;
