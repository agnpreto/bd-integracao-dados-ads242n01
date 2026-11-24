
-- ============================================================
-- PARTE 3 - TRANSFORMACOES DE DADOS
-- Projeto: Integracao de Dados - ADS242N01
-- SGBD: PostgreSQL
-- ============================================================

-- 1. Concatenar codigo e descricao do produto
SELECT
    produto_id || ' - ' ||
    COALESCE(NULLIF(descricao_produto, ''), 'Sem descricao')
        AS produto
FROM pedido_compra;

-- 2. Exibir datas no formato DD/MM/YYYY
SELECT
    pedido_id,
    produto_id,
    TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_solicitacao,
    TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega
FROM pedido_compra;

-- 3. Produtos requisitados mais de 10 vezes
WITH produtos_frequentes AS (
    SELECT
        produto_id,
        COUNT(*) AS quantidade_requisicoes
    FROM pedido_compra
    WHERE data_pedido >= DATE '2025-01-01'
      AND data_pedido < DATE '2026-01-01'
    GROUP BY produto_id
    HAVING COUNT(*) > 10
)
SELECT
    pc.produto_id || ' - ' ||
    COALESCE(NULLIF(pc.descricao_produto, ''), 'Sem descricao')
        AS "Produto",
    pf.quantidade_requisicoes AS "Qtde Requisitada",
    TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS "Data Solicitacao"
FROM pedido_compra pc
JOIN produtos_frequentes pf
    ON pf.produto_id = pc.produto_id
ORDER BY
    pc.produto_id,
    pc.data_pedido,
    pc.pedido_id;

-- 4. Trigger para gerar identificador numerico de fornecedor
-- quando o produto ainda nao possuir fornecedor.
-- O identificador gerado e armazenado como texto para
-- manter compatibilidade com fornecedor.idfornecedor.

CREATE SEQUENCE IF NOT EXISTS fornecedor_id_seq
START WITH 1000
INCREMENT BY 1;

CREATE OR REPLACE FUNCTION gerar_idfornecedor()
RETURNS TRIGGER AS $$
DECLARE
    novo_id TEXT;
BEGIN
    IF NEW.idfornecedor IS NULL OR TRIM(NEW.idfornecedor) = '' THEN
        novo_id := NEXTVAL('fornecedor_id_seq')::TEXT;

        INSERT INTO fornecedor (
            idfornecedor,
            razao_social
        )
        VALUES (
            novo_id,
            'Fornecedor gerado automaticamente'
        );

        NEW.idfornecedor := novo_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_gerar_idfornecedor
ON produtos_filial;

CREATE TRIGGER trg_gerar_idfornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
EXECUTE FUNCTION gerar_idfornecedor();
