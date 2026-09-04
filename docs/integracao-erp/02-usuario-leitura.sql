-- =============================================================================
-- 02 — USUARIO SOMENTE LEITURA NO BANCO DO ERP
-- =============================================================================
-- Rode como superuser (ou como dono dos objetos) no banco do ERP.
-- Ajuste o nome do banco: aqui esta como "logica".
--
-- Nenhum objeto e criado DENTRO do banco do ERP. Um role e um objeto de
-- instancia, nao de banco — nao ha tabela, view, indice nem procedure nossa
-- convivendo com as da Logica. Essa separacao nao e preciosismo: no dia em que
-- o ERP apresentar lentidao ou erro e o suporte encontrar objeto estranho no
-- banco deles, a causa vira a integracao, esteja ela certa ou errada, e a
-- discussao de suporte acaba ali.
-- =============================================================================

CREATE ROLE ppcp_leitura LOGIN PASSWORD 'DEFINA_UMA_SENHA_FORTE';

GRANT CONNECT ON DATABASE logica TO ppcp_leitura;
GRANT USAGE   ON SCHEMA   public TO ppcp_leitura;

-- Amplo para a fase de mapeamento. RESTRINJA depois (ver o bloco no fim).
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ppcp_leitura;

-- Tabela criada depois do GRANT acima nao herda a permissao sozinha.
-- Rodar como DONO das tabelas do ERP.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ppcp_leitura;


-- -----------------------------------------------------------------------------
-- A protecao que responde ao medo legitimo da TI
-- -----------------------------------------------------------------------------
-- Consulta que passar de 60 segundos morre sozinha, em vez de segurar o banco
-- que atende o apontamento. Este e o argumento que derruba o "BI vai travar o
-- ERP" — inclua no pedido, nao espere perguntarem.
ALTER ROLE ppcp_leitura SET statement_timeout = '60s';

-- O snapshot roda em janela sem concorrencia e pode precisar de mais folga.
-- Se precisar, eleve por SESSAO dentro do job, nunca no role:
--   SET statement_timeout = '10min';


-- -----------------------------------------------------------------------------
-- Depois do mapeamento: fechar o acesso
-- -----------------------------------------------------------------------------
-- Terminado o passo 01, o usuario nao precisa mais enxergar o banco inteiro.
-- Troque o GRANT amplo pelo minimo, com os nomes reais das tabelas.
--
--   REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM ppcp_leitura;
--   ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM ppcp_leitura;
--   GRANT SELECT ON tabela_lote, tabela_ordem, tabela_operacao, tabela_apontamento
--     TO ppcp_leitura;
--
-- Conferir o que o usuario enxerga hoje:
--   SELECT table_name, privilege_type
--   FROM information_schema.table_privileges
--   WHERE grantee = 'ppcp_leitura'
--   ORDER BY table_name;
