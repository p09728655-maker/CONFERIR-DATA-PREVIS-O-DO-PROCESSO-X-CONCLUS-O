-- =============================================================================
-- 05 — O QUE MUDOU DE ONTEM PARA HOJE
-- =============================================================================
-- A pergunta que originou toda a integracao: "ontem o lote 163/26 estava numa
-- situacao e hoje mudou; como conferir?"
--
-- Rode no ppcp_bi. Precisa de pelo menos duas coletas do mesmo lote.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Linha a linha: o que andou e o que nao andou
-- -----------------------------------------------------------------------------
-- `sem movimento` e a linha que interessa. Fase que fechou e informacao boa;
-- fase parada dois dias seguidos e a visita ao chao de fabrica.
WITH par AS (
  SELECT max(data_snapshot) FILTER (WHERE data_snapshot <= current_date)   AS d1,
         max(data_snapshot) FILTER (WHERE data_snapshot <  current_date)   AS d0
  FROM snapshot_operacao WHERE lote = :'lote'
),
hoje  AS (SELECT s.* FROM snapshot_operacao s, par
           WHERE s.lote = :'lote' AND s.data_snapshot = par.d1),
ontem AS (SELECT s.* FROM snapshot_operacao s, par
           WHERE s.lote = :'lote' AND s.data_snapshot = par.d0)
SELECT ordem,
       seq,
       coalesce(h.operacao, o.operacao)                    AS operacao,
       o.conclusao                                         AS conclusao_antes,
       h.conclusao                                         AS conclusao_agora,
       o.ja_pronto                                         AS pronto_antes,
       h.ja_pronto                                         AS pronto_agora,
       coalesce(h.ja_pronto, 0) - coalesce(o.ja_pronto, 0) AS avanco_pecas,
       CASE
         WHEN o.ordem     IS NULL                                 THEN 'ordem nova'
         WHEN h.ordem     IS NULL                                 THEN 'ordem sumiu'
         WHEN o.conclusao IS NULL AND h.conclusao IS NOT NULL     THEN 'fase fechada'
         WHEN o.conclusao IS NOT NULL AND h.conclusao IS NULL     THEN 'ESTORNO - investigar'
         WHEN coalesce(h.ja_pronto,0) > coalesce(o.ja_pronto,0)   THEN 'avanco parcial'
         WHEN coalesce(h.ja_pronto,0) < coalesce(o.ja_pronto,0)   THEN 'ESTORNO PARCIAL - investigar'
         ELSE 'sem movimento'
       END AS situacao
FROM hoje h FULL JOIN ontem o USING (lote, ordem, seq)
ORDER BY situacao, ordem, seq;

-- Uso:
--   psql -d ppcp_bi -v lote="'163/26'" -f 05-diff-lote.sql
-- ou, no cliente, defina antes:  \set lote '163/26'


-- -----------------------------------------------------------------------------
-- 2. Resumo do dia, todos os lotes
-- -----------------------------------------------------------------------------
-- Comeco de dia: quantas fases fecharam ontem, quantas nao andaram, e onde.
WITH d AS (
  SELECT max(data_snapshot) AS hoje,
         max(data_snapshot) FILTER (WHERE data_snapshot < (SELECT max(data_snapshot)
                                                             FROM snapshot_operacao)) AS ontem
  FROM snapshot_operacao
)
-- `parado` exclui a linha que nao existia na coleta anterior: ordem que entrou
-- hoje nao esta parada, esta comecando. Contar as duas juntas inflaria o numero
-- justamente no dia em que o lote recebe reposicao.
SELECT h.lote,
       h.operacao,
       count(*) FILTER (WHERE o.ordem IS NULL)                                   AS novas,
       count(*) FILTER (WHERE o.conclusao IS NULL AND h.conclusao IS NOT NULL)   AS fechou,
       count(*) FILTER (WHERE coalesce(h.ja_pronto,0) > coalesce(o.ja_pronto,0)
                          AND o.ordem IS NOT NULL)                               AS avancou,
       count(*) FILTER (WHERE h.conclusao IS NULL
                          AND o.ordem IS NOT NULL
                          AND coalesce(h.ja_pronto,0) = coalesce(o.ja_pronto,0)) AS parado,
       sum(coalesce(h.ja_pronto,0) - coalesce(o.ja_pronto,0))
         FILTER (WHERE o.ordem IS NOT NULL)                                      AS pecas_no_dia
FROM snapshot_operacao h
JOIN d ON h.data_snapshot = d.hoje
LEFT JOIN snapshot_operacao o
       ON o.data_snapshot = d.ontem
      AND o.lote = h.lote AND o.ordem = h.ordem AND o.seq = h.seq
GROUP BY h.lote, h.operacao
ORDER BY parado DESC, fechou DESC, h.lote, h.operacao;


-- -----------------------------------------------------------------------------
-- 3. Sanidade: dia sem coleta nao e dia sem movimento
-- -----------------------------------------------------------------------------
-- Job parado ha duas semanas produz exatamente a mesma tela que uma fabrica
-- parada ha duas semanas. Confira isto antes de acreditar em qualquer serie.
SELECT data_snapshot, situacao, linhas, terminado_em - iniciado_em AS duracao, observacao
FROM snapshot_execucao
ORDER BY data_snapshot DESC, iniciado_em DESC
LIMIT 30;

-- Buracos na serie de dias uteis
SELECT d::date AS dia_util_sem_coleta
FROM generate_series((SELECT min(data_snapshot) FROM snapshot_operacao),
                     current_date, '1 day') d
WHERE extract(isodow FROM d) < 6
  AND NOT EXISTS (SELECT 1 FROM snapshot_execucao e
                   WHERE e.data_snapshot = d::date AND e.situacao = 'ok')
ORDER BY 1;
