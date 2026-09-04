-- =============================================================================
-- 06 — TESTE DE ACEITE: a consulta bate com o relatorio?
-- =============================================================================
-- Este e o passo que nao pode ser pulado.
--
-- O PDF nao e a tabela crua. O relatorio da Logica aplica regra — "Faltam" so e
-- impresso quando nao ha conclusao, "Qtd. Concluida na Fase" e derivada — e uma
-- consulta que le as tabelas e supoe que da no mesmo esta errada ate prova em
-- contrario. A prova e esta.
--
-- No dia em que o numero da sua tela discordar do relatorio oficial numa
-- reuniao, a ferramenta perde credibilidade inteira, esteja voce certo ou
-- errado. Rode isto antes de agendar o job, e de novo a cada atualizacao do ERP.
--
-- Procedimento:
--   1. Abra no RitmoPatrimar o PDF do lote de teste e exporte operacoes.csv.
--   2. Rode a consulta do job para o MESMO lote e a MESMA data de emissao,
--      gravando em snapshot_operacao.
--   3. Rode este arquivo. As tres consultas tem que voltar VAZIAS.
--
-- Se voltar linha, o mapa das tabelas esta errado. Nao ajuste o teste.
-- =============================================================================

-- operacoes.csv sai com BOM, separador ';', quebra CRLF, data dd/mm/aaaa e
-- decimal com virgula. Carregue como texto e converta depois — deixar o COPY
-- adivinhar tipo com esse formato falha de maneiras dificeis de perceber.
CREATE TEMP TABLE csv_bruto (
  arquivo text, lote text, ordem text, produto text, descricao_produto text,
  seq text, operacao text, previsao_processo text, conclusao text,
  desvio_dias_uteis text, qtd_total text, ja_pronto text, saldo text,
  fora_da_conta text
);

\copy csv_bruto FROM 'operacoes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8')

CREATE TEMP VIEW csv_pdf AS
SELECT lote,
       ordem,
       seq::smallint                                   AS seq,
       operacao,
       to_date(nullif(previsao_processo,''), 'DD/MM/YYYY') AS previsao_processo,
       to_date(nullif(conclusao,''),         'DD/MM/YYYY') AS conclusao,
       replace(nullif(qtd_total,''), ',', '.')::numeric    AS qtd_total,
       replace(nullif(ja_pronto,''), ',', '.')::numeric    AS ja_pronto
FROM csv_bruto;

-- Ajuste para o lote e a data que voce carregou
\set lote '163/26'
\set dia  '2026-09-04'

CREATE TEMP VIEW erp AS
SELECT lote, ordem, seq, operacao, previsao_processo, conclusao, qtd_total, ja_pronto
FROM snapshot_operacao
WHERE lote = :'lote' AND data_snapshot = :'dia';


-- -----------------------------------------------------------------------------
-- 1. Existe no ERP e nao existe no PDF
-- -----------------------------------------------------------------------------
-- Causa tipica: a consulta esta trazendo ordem de outro lote, ou nao esta
-- aplicando o mesmo filtro de status que o relatorio usa.
SELECT 'so no ERP' AS onde, e.ordem, e.seq, e.operacao
FROM erp e
LEFT JOIN csv_pdf c USING (lote, ordem, seq)
WHERE c.ordem IS NULL
ORDER BY e.ordem, e.seq;


-- -----------------------------------------------------------------------------
-- 2. Existe no PDF e nao existe no ERP
-- -----------------------------------------------------------------------------
-- Causa tipica: JOIN derrubando linha (INNER onde devia ser LEFT), ou formato
-- de chave diferente — o PDF traz "025139" e a tabela guarda 25139 como
-- inteiro. Normalize a chave, nao remova a linha do teste.
SELECT 'so no PDF' AS onde, c.ordem, c.seq, c.operacao
FROM csv_pdf c
LEFT JOIN erp e USING (lote, ordem, seq)
WHERE e.ordem IS NULL
ORDER BY c.ordem, c.seq;


-- -----------------------------------------------------------------------------
-- 3. Existe nos dois, com valor diferente
-- -----------------------------------------------------------------------------
-- A tolerancia de quantidade e a mesma que a ferramenta usa (CFG.tolQtd),
-- 0,001 peca. Data nao tem tolerancia: ou e o mesmo dia, ou nao e.
SELECT e.ordem, e.seq, e.operacao,
       c.previsao_processo AS prev_pdf, e.previsao_processo AS prev_erp,
       c.conclusao         AS concl_pdf, e.conclusao        AS concl_erp,
       c.qtd_total         AS qtd_pdf,   e.qtd_total        AS qtd_erp,
       c.ja_pronto         AS pronto_pdf, e.ja_pronto       AS pronto_erp
FROM erp e
JOIN csv_pdf c USING (lote, ordem, seq)
WHERE c.previsao_processo IS DISTINCT FROM e.previsao_processo
   OR c.conclusao         IS DISTINCT FROM e.conclusao
   OR abs(coalesce(c.qtd_total,0) - coalesce(e.qtd_total,0)) > 0.001
   OR abs(coalesce(c.ja_pronto,0) - coalesce(e.ja_pronto,0)) > 0.001
ORDER BY e.ordem, e.seq;


-- -----------------------------------------------------------------------------
-- 4. Contagem, para o registro
-- -----------------------------------------------------------------------------
SELECT (SELECT count(*) FROM csv_pdf) AS linhas_pdf,
       (SELECT count(*) FROM erp)     AS linhas_erp;
