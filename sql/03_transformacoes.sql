-- 03_transformacoes
-- Nome:
-- Sintaxe MySQL 8 (Workbench). A versão PostgreSQL está no fim do arquivo, comentada.

USE integracao_dados;

-- ═════════════════════════════════════════════════════════════
-- 3.1 + 3.2  Produto no formato "codigo - descricao" e datas em DD/MM/AAAA
--            para pedidos de compra, vendas e produtos.
-- ═════════════════════════════════════════════════════════════

-- Pedidos de compra: a descrição vem da própria tabela; se faltar, do cadastro.
SELECT
    pc.pedido_id,
    CASE WHEN COALESCE(pc.descricao_produto, p.descricao) IS NULL
         THEN pc.produto_id
         ELSE CONCAT(pc.produto_id, ' - ', COALESCE(pc.descricao_produto, p.descricao))
    END                                          AS produto,
    pc.qtde_pedida,
    DATE_FORMAT(pc.data_pedido,  '%d/%m/%Y')     AS data_pedido,
    DATE_FORMAT(pc.data_entrega, '%d/%m/%Y')     AS data_entrega
FROM pedido_compra pc
LEFT JOIN produtos_filial p
       ON p.produto_id = pc.produto_id
      AND p.filial_id  = pc.filial_id
ORDER BY pc.pedido_id;

-- Vendas: a tabela venda não tem descrição; ela vem do cadastro "onde houver".
-- Produtos sem cadastro (P21 a P28) aparecem só com o código.
SELECT
    v.venda_id,
    CASE WHEN p.descricao IS NULL
         THEN v.produto_id
         ELSE CONCAT(v.produto_id, ' - ', p.descricao)
    END                                          AS produto,
    v.qtde_vendida,
    v.valor_unitario,
    DATE_FORMAT(v.data_emissao, '%d/%m/%Y')      AS data_emissao
FROM venda v
LEFT JOIN produtos_filial p
       ON p.produto_id = v.produto_id
      AND p.filial_id  = v.filial_id
ORDER BY v.data_emissao, v.venda_id;

-- Produtos
SELECT
    p.filial_id,
    CONCAT(p.produto_id, ' - ', p.descricao)     AS produto,
    p.estoque,
    p.preco_venda,
    p.idfornecedor
FROM produtos_filial p
ORDER BY p.filial_id, p.produto_id;


-- ═════════════════════════════════════════════════════════════
-- 3.3  Produtos requisitados mais de 10 vezes no período
--
-- COMO INTERPRETEI "mais de 10 vezes":
--   Cada pedido requisita uma QUANTIDADE do produto. Entendi "requisitado mais
--   de 10 vezes" como "quantidade total requisitada maior que 10" no período,
--   que é o que o exemplo do enunciado mostra (coluna "Qtde Requisitada" = 15).
--   A outra leitura possível (mais de 10 PEDIDOS do mesmo produto) não retorna
--   nada nesta base: nenhum produto tem mais de 2 pedidos (consulta de
--   conferência logo abaixo).
--
-- PERÍODO: toda a base de pedidos (02/01/2025 a 01/03/2025). Para outro período,
--   troque as duas datas nas variáveis abaixo.
--
-- RESULTADO: nesta base os 20 produtos passam do limite (o menor total é 12,
--   do P3). Isso mostra que o filtro está certo, mas que o limite de 10 é baixo
--   para o volume de compras do cliente; vale confirmar com ele (Parte 4).
-- ═════════════════════════════════════════════════════════════
SET @inicio = '2025-01-01';
SET @fim    = '2025-03-31';

-- Resultado no formato do exemplo: um produto por linha.
-- "Data Solicitação" = data da primeira requisição do produto no período.
SELECT
    CONCAT(pc.produto_id, ' - ', MAX(pc.descricao_produto))   AS `Produto`,
    SUM(pc.qtde_pedida)                                        AS `Qtde Requisitada`,
    DATE_FORMAT(MIN(pc.data_pedido), '%d/%m/%Y')               AS `Data Solicitação`
FROM pedido_compra pc
WHERE pc.data_pedido BETWEEN @inicio AND @fim
GROUP BY pc.produto_id
HAVING SUM(pc.qtde_pedida) > 10
ORDER BY SUM(pc.qtde_pedida) DESC;

-- Detalhe: cada requisição desses produtos, com a data de cada uma.
SELECT
    CONCAT(pc.produto_id, ' - ', pc.descricao_produto)   AS `Produto`,
    pc.qtde_pedida                                        AS `Qtde Requisitada`,
    DATE_FORMAT(pc.data_pedido, '%d/%m/%Y')               AS `Data Solicitação`
FROM pedido_compra pc
WHERE pc.data_pedido BETWEEN @inicio AND @fim
  AND pc.produto_id IN (
        SELECT produto_id
        FROM pedido_compra
        WHERE data_pedido BETWEEN @inicio AND @fim
        GROUP BY produto_id
        HAVING SUM(qtde_pedida) > 10
      )
ORDER BY pc.produto_id, pc.data_pedido;

-- Conferência da outra interpretação (nº de pedidos > 10): retorna vazio.
SELECT produto_id, COUNT(*) AS qtde_pedidos
FROM pedido_compra
WHERE data_pedido BETWEEN @inicio AND @fim
GROUP BY produto_id
HAVING COUNT(*) > 10;


-- ═════════════════════════════════════════════════════════════
-- 3.4  Trigger: idfornecedor NUMÉRICO em produtos_filial, ligado a fornecedor
--
-- Problema: o código do fornecedor é texto ("F8") em fornecedor e em
-- produtos_filial, mas em pedido_compra o fornecedor é numérico (fornecedor_id).
-- Solução:
--   1. fornecedor ganha idfornecedor_num (único). Uma trigger gera esse número
--      automaticamente em todo fornecedor novo: usa os dígitos do código
--      ("F8" -> 8) ou, se não houver dígitos ou o número já existir, o próximo
--      número livre (MAX + 1).
--   2. produtos_filial ganha idfornecedor_num, com chave estrangeira para
--      fornecedor(idfornecedor_num). Uma trigger preenche esse campo sozinha
--      em todo INSERT/UPDATE de produto, a partir do idfornecedor texto.
--   Assim produtos, fornecedor e pedido_compra.fornecedor_id passam a se
--   relacionar pelo mesmo número.
-- ═════════════════════════════════════════════════════════════

-- O MySQL Workbench vem com "safe update mode" ligado, que bloqueia os UPDATEs
-- abaixo (erro 1175). Desligado só nesta sessão:
SET SQL_SAFE_UPDATES = 0;

-- Os ALTER TABLE abaixo devem rodar UMA vez. Para repetir do zero, rode de novo
-- sql/01_ddl_mysql.sql e sql/carga_mysql.sql antes deste arquivo.
DROP TRIGGER IF EXISTS trg_fornecedor_gera_num;
DROP TRIGGER IF EXISTS trg_produtos_fornecedor_num_ins;
DROP TRIGGER IF EXISTS trg_produtos_fornecedor_num_upd;

-- 1) Coluna numérica em fornecedor
ALTER TABLE fornecedor ADD COLUMN idfornecedor_num INT NULL;
UPDATE fornecedor
   SET idfornecedor_num = CAST(REGEXP_REPLACE(idfornecedor, '[^0-9]', '') AS UNSIGNED)
 WHERE idfornecedor_num IS NULL;
ALTER TABLE fornecedor
  MODIFY idfornecedor_num INT NOT NULL,
  ADD CONSTRAINT uq_fornecedor_num UNIQUE (idfornecedor_num);

-- 2) Coluna numérica em produtos_filial + chave estrangeira
ALTER TABLE produtos_filial ADD COLUMN idfornecedor_num INT NULL;
UPDATE produtos_filial p
  JOIN fornecedor f ON f.idfornecedor = p.idfornecedor
   SET p.idfornecedor_num = f.idfornecedor_num;
ALTER TABLE produtos_filial
  ADD CONSTRAINT fk_produtos_fornecedor_num
      FOREIGN KEY (idfornecedor_num) REFERENCES fornecedor (idfornecedor_num);

DELIMITER $$

-- Gera o número de todo fornecedor novo
CREATE TRIGGER trg_fornecedor_gera_num
BEFORE INSERT ON fornecedor
FOR EACH ROW
BEGIN
    DECLARE v_num INT;
    IF NEW.idfornecedor_num IS NULL THEN
        SET v_num = CAST(NULLIF(REGEXP_REPLACE(NEW.idfornecedor, '[^0-9]', ''), '') AS UNSIGNED);
        IF v_num IS NULL
           OR EXISTS (SELECT 1 FROM fornecedor WHERE idfornecedor_num = v_num) THEN
            SELECT COALESCE(MAX(idfornecedor_num), 0) + 1 INTO v_num FROM fornecedor;
        END IF;
        SET NEW.idfornecedor_num = v_num;
    END IF;
END$$

-- Preenche o número do fornecedor ao cadastrar um produto
CREATE TRIGGER trg_produtos_fornecedor_num_ins
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        SET NEW.idfornecedor_num = NULL;
    ELSE
        SET NEW.idfornecedor_num = (SELECT idfornecedor_num
                                      FROM fornecedor
                                     WHERE idfornecedor = NEW.idfornecedor);
    END IF;
END$$

-- Mantém o número certo se o fornecedor do produto for trocado
CREATE TRIGGER trg_produtos_fornecedor_num_upd
BEFORE UPDATE ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        SET NEW.idfornecedor_num = NULL;
    ELSE
        SET NEW.idfornecedor_num = (SELECT idfornecedor_num
                                      FROM fornecedor
                                     WHERE idfornecedor = NEW.idfornecedor);
    END IF;
END$$

DELIMITER ;

-- ── Teste da trigger (roda dentro de uma transação e desfaz no fim) ──
START TRANSACTION;
INSERT INTO fornecedor (idfornecedor, razao_social) VALUES ('F21', 'Fornecedor Teste LTDA');
INSERT INTO fornecedor (idfornecedor, razao_social) VALUES ('ACME', 'Fornecedor Sem Numero LTDA');
INSERT INTO produtos_filial (filial_id, produto_id, descricao, idfornecedor)
VALUES (1, 'P99', 'Produto Teste', 'F21'),
       (1, 'P98', 'Produto Teste 2', 'ACME');
SELECT p.produto_id, p.idfornecedor, p.idfornecedor_num, f.razao_social
  FROM produtos_filial p
  JOIN fornecedor f ON f.idfornecedor_num = p.idfornecedor_num
 WHERE p.produto_id IN ('P98', 'P99');
-- esperado: P99 -> F21 -> 21 ; P98 -> ACME -> 22 (próximo número livre)
ROLLBACK;

-- Produtos com o número do fornecedor gerado
SELECT p.produto_id, p.idfornecedor, p.idfornecedor_num, f.razao_social
  FROM produtos_filial p
  JOIN fornecedor f ON f.idfornecedor_num = p.idfornecedor_num
 ORDER BY p.idfornecedor_num, p.produto_id;


/* ═════════════════════════════════════════════════════════════
   VERSÃO POSTGRESQL (copie e rode no PostgreSQL / DBeaver)
   Diferenças: TO_CHAR em vez de DATE_FORMAT, datas fixas em vez de @variáveis,
   e trigger = função plpgsql + CREATE TRIGGER.
-- -- POSTGRES-INICIO
SELECT pc.pedido_id,
       CASE WHEN COALESCE(pc.descricao_produto, p.descricao) IS NULL THEN pc.produto_id
            ELSE pc.produto_id || ' - ' || COALESCE(pc.descricao_produto, p.descricao) END AS produto,
       pc.qtde_pedida,
       TO_CHAR(pc.data_pedido, 'DD/MM/YYYY')  AS data_pedido,
       TO_CHAR(pc.data_entrega, 'DD/MM/YYYY') AS data_entrega
FROM pedido_compra pc
LEFT JOIN produtos_filial p ON p.produto_id = pc.produto_id AND p.filial_id = pc.filial_id
ORDER BY pc.pedido_id;

SELECT v.venda_id,
       CASE WHEN p.descricao IS NULL THEN v.produto_id
            ELSE v.produto_id || ' - ' || p.descricao END AS produto,
       v.qtde_vendida, v.valor_unitario,
       TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS data_emissao
FROM venda v
LEFT JOIN produtos_filial p ON p.produto_id = v.produto_id AND p.filial_id = v.filial_id
ORDER BY v.data_emissao, v.venda_id;

SELECT p.filial_id, p.produto_id || ' - ' || p.descricao AS produto,
       p.estoque, p.preco_venda, p.idfornecedor
FROM produtos_filial p ORDER BY p.filial_id, p.produto_id;

SELECT pc.produto_id || ' - ' || MAX(pc.descricao_produto) AS "Produto",
       SUM(pc.qtde_pedida)                                 AS "Qtde Requisitada",
       TO_CHAR(MIN(pc.data_pedido), 'DD/MM/YYYY')          AS "Data Solicitação"
FROM pedido_compra pc
WHERE pc.data_pedido BETWEEN DATE '2025-01-01' AND DATE '2025-03-31'
GROUP BY pc.produto_id
HAVING SUM(pc.qtde_pedida) > 10
ORDER BY SUM(pc.qtde_pedida) DESC;

ALTER TABLE fornecedor ADD COLUMN IF NOT EXISTS idfornecedor_num int4;
UPDATE fornecedor SET idfornecedor_num = regexp_replace(idfornecedor, '[^0-9]', '', 'g')::int4
 WHERE idfornecedor_num IS NULL;
ALTER TABLE fornecedor ALTER COLUMN idfornecedor_num SET NOT NULL;
ALTER TABLE fornecedor ADD CONSTRAINT uq_fornecedor_num UNIQUE (idfornecedor_num);

ALTER TABLE produtos_filial ADD COLUMN IF NOT EXISTS idfornecedor_num int4;
UPDATE produtos_filial p SET idfornecedor_num = f.idfornecedor_num
  FROM fornecedor f WHERE f.idfornecedor = p.idfornecedor;
ALTER TABLE produtos_filial ADD CONSTRAINT fk_produtos_fornecedor_num
  FOREIGN KEY (idfornecedor_num) REFERENCES fornecedor (idfornecedor_num);

CREATE OR REPLACE FUNCTION fn_fornecedor_gera_num() RETURNS trigger AS $$
DECLARE v_num int4;
BEGIN
  IF NEW.idfornecedor_num IS NULL THEN
    v_num := NULLIF(regexp_replace(NEW.idfornecedor, '[^0-9]', '', 'g'), '')::int4;
    IF v_num IS NULL OR EXISTS (SELECT 1 FROM fornecedor WHERE idfornecedor_num = v_num) THEN
      SELECT COALESCE(MAX(idfornecedor_num), 0) + 1 INTO v_num FROM fornecedor;
    END IF;
    NEW.idfornecedor_num := v_num;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_produtos_fornecedor_num() RETURNS trigger AS $$
BEGIN
  NEW.idfornecedor_num := (SELECT idfornecedor_num FROM fornecedor
                            WHERE idfornecedor = NEW.idfornecedor);
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_fornecedor_gera_num ON fornecedor;
CREATE TRIGGER trg_fornecedor_gera_num BEFORE INSERT ON fornecedor
  FOR EACH ROW EXECUTE FUNCTION fn_fornecedor_gera_num();

DROP TRIGGER IF EXISTS trg_produtos_fornecedor_num ON produtos_filial;
CREATE TRIGGER trg_produtos_fornecedor_num BEFORE INSERT OR UPDATE ON produtos_filial
  FOR EACH ROW EXECUTE FUNCTION fn_produtos_fornecedor_num();

BEGIN;
INSERT INTO fornecedor (idfornecedor, razao_social) VALUES ('F21', 'Fornecedor Teste LTDA');
INSERT INTO fornecedor (idfornecedor, razao_social) VALUES ('ACME', 'Fornecedor Sem Numero LTDA');
INSERT INTO produtos_filial (filial_id, produto_id, descricao, idfornecedor)
VALUES (1, 'P99', 'Produto Teste', 'F21'), (1, 'P98', 'Produto Teste 2', 'ACME');
SELECT p.produto_id, p.idfornecedor, p.idfornecedor_num, f.razao_social
  FROM produtos_filial p JOIN fornecedor f ON f.idfornecedor_num = p.idfornecedor_num
 WHERE p.produto_id IN ('P98', 'P99');
ROLLBACK;
-- -- POSTGRES-FIM
═════════════════════════════════════════════════════════════ */
