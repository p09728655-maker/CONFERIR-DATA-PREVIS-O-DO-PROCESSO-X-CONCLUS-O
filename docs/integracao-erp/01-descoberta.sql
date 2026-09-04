-- =============================================================================
-- 01 — DESCOBERTA DO SCHEMA DO ERP LOGICA (PostgreSQL)
-- =============================================================================
-- Rode na COPIA RESTAURADA, nao em producao. O passo 5 varre o banco inteiro e
-- nao tem lugar num servidor que esta atendendo apontamento de chao de fabrica.
--
-- Objetivo: descobrir em quais tabelas moram lote, ordem de fabricacao,
-- operacao do roteiro e apontamento, e onde estao os seis campos que a
-- ferramenta hoje le do PDF — Previsao do Lote, Previsao do Processo,
-- Conclusao, Qtd. Total, Ja Pronto e a conclusao da ordem.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Versao do servidor
-- -----------------------------------------------------------------------------
-- Define a sintaxe disponivel e os nomes de coluna do pg_stat_statements
-- (ate a 12: mean_time/max_time; da 13 em diante: mean_exec_time/max_exec_time).
SELECT version();


-- -----------------------------------------------------------------------------
-- 2. ATALHO: o SQL do proprio relatorio
-- -----------------------------------------------------------------------------
-- Se este caminho funcionar, ele economiza a maior parte do trabalho: devolve a
-- consulta que a propria Logica executa para montar o relatorio, com as regras
-- de negocio ja embutidas. O PDF nao e a tabela crua — ele deriva "Faltam" e
-- "Qtd. Concluida na Fase" —, e reproduzir essa derivacao no palpite e a parte
-- que da errado.

-- 2a. A extensao esta instalada?
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';

-- 2b. Se 2a devolveu linha: emita o relatorio "Situacao do Lote de Producao" no
--     ERP e SO ENTAO rode isto. Os parametros vem normalizados como $1, $2 — a
--     estrutura e o que interessa.
SELECT calls,
       round(mean_exec_time::numeric, 1) AS ms_medio,
       query
FROM pg_stat_statements
WHERE query ILIKE '%lote%'
  AND query ILIKE '%select%'
ORDER BY max_exec_time DESC
LIMIT 20;

-- 2c. Se 2a nao devolveu nada: flagre a consulta enquanto o relatorio processa.
--     Exige pg_read_all_stats (ou superuser) para enxergar o texto da consulta
--     de outro usuario; sem isso vem "<insufficient privilege>".
SELECT pid, usename, state, now() - query_start AS rodando_ha, query
FROM pg_stat_activity
WHERE state = 'active'
  AND query ILIKE '%lote%'
ORDER BY query_start;


-- -----------------------------------------------------------------------------
-- 3. Tabelas e colunas candidatas
-- -----------------------------------------------------------------------------
-- 3a. Tabelas cujo nome sugere o dominio
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
  AND table_name ~* 'lote|ordem|op(erac|_)|apont|roteir|fase|producao'
ORDER BY 1, 2;

-- 3b. Colunas de data e quantidade — onde estao previsao, conclusao e saldo
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name ~* 'previs|conclus|dt_|data|qtd|quant|pronto|saldo|seq|lote'
ORDER BY table_name, ordinal_position;

-- 3c. Quais sao as tabelas de fato (as que tem volume)
SELECT relname, n_live_tup
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC
LIMIT 30;


-- -----------------------------------------------------------------------------
-- 4. O mapa de relacionamentos
-- -----------------------------------------------------------------------------
-- Vale mais que os tres anteriores juntos: achada UMA tabela certa, as chaves
-- estrangeiras levam as outras em cascata.
SELECT conrelid::regclass  AS tabela,
       confrelid::regclass AS referencia,
       pg_get_constraintdef(oid) AS definicao
FROM pg_constraint
WHERE contype = 'f'
  AND (conrelid::regclass::text  ~* 'lote|ordem|operac|apont|roteir'
    OR confrelid::regclass::text ~* 'lote|ordem|operac|apont|roteir')
ORDER BY 1;


-- -----------------------------------------------------------------------------
-- 5. O tiro certeiro: procurar um valor conhecido
-- -----------------------------------------------------------------------------
-- Voce tem numeros de OF reais no PDF do lote. Procure em qual tabela e coluna
-- esse numero mora; dali as FKs do passo 4 abrem o resto.
--
-- ATENCAO: varre TODA coluna de texto e numero do banco. Em banco de ERP isso
-- demora e pesa. Rode SO na copia restaurada.
DO $$
DECLARE
  alvo text := '000000';   -- <<< troque pelo numero de uma OF tirada do PDF
  r    record;
  n    bigint;
BEGIN
  FOR r IN
    SELECT table_schema, table_name, column_name
    FROM information_schema.columns
    WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
      AND data_type IN ('character varying', 'text', 'character',
                        'integer', 'bigint', 'numeric')
  LOOP
    BEGIN
      EXECUTE format('SELECT count(*) FROM %I.%I WHERE %I::text = %L',
                     r.table_schema, r.table_name, r.column_name, alvo)
      INTO n;
      IF n > 0 THEN
        RAISE NOTICE '%.%.% -> % linha(s)',
          r.table_schema, r.table_name, r.column_name, n;
      END IF;
    EXCEPTION WHEN others THEN
      NULL;   -- coluna que nao aceita o cast; segue
    END;
  END LOOP;
END $$;
