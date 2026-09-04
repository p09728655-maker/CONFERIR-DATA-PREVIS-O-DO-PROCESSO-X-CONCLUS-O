#!/usr/bin/env bash
# =============================================================================
# 04 — JOB DIARIO DE SNAPSHOT
# =============================================================================
# Le a situacao das operacoes no banco do ERP e grava uma foto no ppcp_bi.
# Agende as 05:00, antes do primeiro turno: consulta pesada em banco de ERP no
# meio do expediente concorre com o terminal de apontamento do chao de fabrica.
#
# Agendamento
#   Linux:   crontab -e   ->   0 5 * * 1-5  /opt/ppcp/04-snapshot-job.sh
#   Windows: Agendador de Tarefas chamando este script via Git Bash / WSL, ou
#            um .bat com as mesmas tres chamadas psql.
#
# NAO use pg_cron: ele exige entrar em shared_preload_libraries, o que exige
# reiniciar o servidor — ou seja, parar o ERP. Nao vale por um agendamento que
# o sistema operacional ja faz de graca.
#
# Senhas em ~/.pgpass (Linux, chmod 600) ou %APPDATA%\postgresql\pgpass.conf
# (Windows). Nunca no script — este arquivo esta versionado.
#   SERVIDOR:5432:logica:ppcp_leitura:senha
#   SERVIDOR:5432:ppcp_bi:ppcp_carga:senha
# =============================================================================

set -euo pipefail

PGHOST_ERP="${PGHOST_ERP:-localhost}"
PGHOST_BI="${PGHOST_BI:-localhost}"
DB_ERP="${DB_ERP:-logica}"
DB_BI="${DB_BI:-ppcp_bi}"
USER_ERP="${USER_ERP:-ppcp_leitura}"
USER_BI="${USER_BI:-ppcp_carga}"

DIA="$(date +%F)"
TMP="$(mktemp -t snapshot-XXXXXX.csv)"
trap 'rm -f "$TMP"' EXIT

psql_bi() { psql -h "$PGHOST_BI" -U "$USER_BI" -d "$DB_BI" -v ON_ERROR_STOP=1 "$@"; }

# Os valores vao por variavel do psql (:'nome'), que ja entrega o literal
# escapado. Montar a SQL por interpolacao do shell abriria injecao no proprio
# job e, pior, quebraria em silencio com apostrofo na observacao.
registrar() {  # situacao, linhas, observacao
  psql_bi -q -v sit="$1" -v lin="$2" -v obs="$3" \
    -c "UPDATE snapshot_execucao
           SET terminado_em = now(), situacao = :'sit', linhas = :'lin',
               observacao = NULLIF(:'obs', '')
         WHERE data_snapshot = '$DIA'
           AND iniciado_em = (SELECT max(iniciado_em) FROM snapshot_execucao
                               WHERE data_snapshot = '$DIA');"
}

psql_bi -q -c "INSERT INTO snapshot_execucao (data_snapshot) VALUES ('$DIA');"

# -----------------------------------------------------------------------------
# 1. Extrair — para ARQUIVO, nao direto para o destino
# -----------------------------------------------------------------------------
# Um pipe entre os dois psql e mais curto e esta errado: se a origem falhar no
# meio, ela ja emitiu CSV parcial, o destino carrega e commita esse pedaco, e o
# dia fica gravado pela metade sem ninguem saber. Arquivo intermediario permite
# conferir o codigo de saida ANTES de escrever qualquer coisa.
#
# >>> O SELECT abaixo e o unico ponto que depende do schema da Logica. Preencha
# >>> com os nomes reais descobertos no passo 01 e valide contra o operacoes.csv
# >>> do RitmoPatrimar antes de agendar (ver secao "Teste de aceite" do README).
if ! psql -h "$PGHOST_ERP" -U "$USER_ERP" -d "$DB_ERP" -v ON_ERROR_STOP=1 -q \
     -c "SET statement_timeout = '10min';" \
     -c "\copy (
           SELECT
             current_date        AS data_snapshot,
             NULL::text          AS lote,               -- PREENCHER
             NULL::text          AS lt,                 -- PREENCHER
             NULL::text          AS ordem,              -- PREENCHER
             NULL::smallint      AS seq,                -- PREENCHER
             NULL::text          AS produto,            -- PREENCHER
             NULL::text          AS descricao_produto,  -- PREENCHER
             NULL::text          AS operacao,           -- PREENCHER
             NULL::date          AS previsao_lote,      -- PREENCHER
             NULL::date          AS previsao_processo,  -- PREENCHER
             NULL::date          AS conclusao,          -- PREENCHER
             NULL::numeric       AS qtd_total,          -- PREENCHER
             NULL::numeric       AS ja_pronto,          -- PREENCHER
             NULL::date          AS ordem_previsao,     -- PREENCHER
             NULL::date          AS ordem_conclusao     -- PREENCHER
           FROM (SELECT 1) AS preencher
           WHERE false
         ) TO STDOUT WITH (FORMAT csv)" > "$TMP"
then
  registrar falha 0 'falha na extracao do ERP'
  echo "ERRO: extracao falhou. Nada foi gravado." >&2
  exit 1
fi

LINHAS="$(wc -l < "$TMP" | tr -d ' ')"
if [ "$LINHAS" -eq 0 ]; then
  registrar falha 0 'extracao voltou vazia'
  echo "ERRO: extracao voltou 0 linhas. Nada foi gravado." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 2. Carregar — transacional; ou entra o dia inteiro, ou nao entra nada
# -----------------------------------------------------------------------------
psql_bi -q -c "\copy snapshot_operacao (
    data_snapshot, lote, lt, ordem, seq, produto, descricao_produto, operacao,
    previsao_lote, previsao_processo, conclusao, qtd_total, ja_pronto,
    ordem_previsao, ordem_conclusao
  ) FROM '$TMP' WITH (FORMAT csv)"

# -----------------------------------------------------------------------------
# 3. Sanidade — o alerta que faz a serie ser confiavel
# -----------------------------------------------------------------------------
# Atualizacao do ERP renomeia uma coluna, o SELECT passa a trazer NULL ou metade
# das linhas, e o job continua "funcionando". Sem esta checagem, o erro so
# aparece meses depois, numa reuniao. Variacao acima de 30% contra o dia
# anterior nao reprova o dado — marca como suspeito para alguem olhar.
psql_bi -q -c "
  WITH hoje  AS (SELECT count(*) n FROM snapshot_operacao WHERE data_snapshot = '$DIA'),
       ontem AS (SELECT count(*) n FROM snapshot_operacao
                  WHERE data_snapshot = (SELECT max(data_snapshot) FROM snapshot_operacao
                                          WHERE data_snapshot < '$DIA'))
  UPDATE snapshot_execucao e
     SET terminado_em = now(),
         linhas   = (SELECT n FROM hoje),
         situacao = CASE WHEN (SELECT n FROM ontem) > 0
                          AND abs((SELECT n FROM hoje) - (SELECT n FROM ontem))::numeric
                              / (SELECT n FROM ontem) > 0.30
                         THEN 'suspeito' ELSE 'ok' END,
         observacao = CASE WHEN (SELECT n FROM ontem) > 0
                            AND abs((SELECT n FROM hoje) - (SELECT n FROM ontem))::numeric
                                / (SELECT n FROM ontem) > 0.30
                           THEN 'variacao de linhas acima de 30% contra a coleta anterior'
                      END
   WHERE e.data_snapshot = '$DIA'
     AND e.iniciado_em = (SELECT max(iniciado_em) FROM snapshot_execucao
                           WHERE data_snapshot = '$DIA');"

echo "snapshot $DIA: $LINHAS linhas."
