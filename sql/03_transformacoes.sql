
-- ============================================================
-- PARTE 3 - TRANSFORMACOES SQL
-- Projeto: Integracao de Dados - ADS242N01
-- Banco: PostgreSQL
-- ============================================================

-- 1. Concatenar codigo e descricao do produto.
-- Produtos sem descricao recebem a identificacao
-- "Sem descricao", sem desaparecer do resultado.

SELECT
    CONCAT(
        produto_id,
        ' - ',
        COALESCE(
            NULLIF(TRIM(descricao_produto), ''),
            'Sem descricao'
        )
    ) AS produto
FROM pedido_compra;


-- 2. Formatar datas no padrao brasileiro.

SELECT
    produto_id,
    COALESCE(
        NULLIF(TRIM(descricao_produto), ''),
        'Sem descricao'
    ) AS descricao_produto,
    TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_solicitacao
FROM pedido_compra
WHERE data_pedido IS NOT NULL;


-- 3. Produtos requisitados mais de 10 vezes.
--
-- Interpretacao: "mais de 10 vezes" significa possuir
-- mais de 10 registros de requisicao no periodo.
-- A quantidade requisitada exibida corresponde a cada
-- registro individual, e nao a soma de unidades.
-- O filtro considera fevereiro de 2025.

WITH produtos_frequentes AS (
    SELECT
        produto_id,
        COUNT(*) AS vezes_requisitado
    FROM pedido_compra
    WHERE data_pedido >= DATE '2025-02-01'
      AND data_pedido < DATE '2025-03-01'
    GROUP BY produto_id
    HAVING COUNT(*) > 10
)

SELECT
    CONCAT(
        p.produto_id,
        ' - ',
        COALESCE(
            NULLIF(TRIM(p.descricao_produto), ''),
            'Sem descricao'
        )
    ) AS "Produto",
    p.qtde_pedida AS "Qtde Requisitada",
    TO_CHAR(p.data_pedido, 'DD/MM/YYYY') AS "Data Solicitacao"
FROM pedido_compra p
INNER JOIN produtos_frequentes pf
    ON p.produto_id = pf.produto_id
WHERE p.data_pedido >= DATE '2025-02-01'
  AND p.data_pedido < DATE '2025-03-01'
ORDER BY p.produto_id, p.data_pedido, p.pedido_id;


-- ============================================================
-- 4. TRIGGER: GERACAO AUTOMATICA DE FORNECEDOR
-- ============================================================
-- Ao inserir um produto sem fornecedor, cria um cadastro
-- de fornecedor pendente e atribui seu identificador
-- ao registro de produtos_filial.

CREATE OR REPLACE FUNCTION gerar_idfornecedor()
RETURNS TRIGGER AS $$
DECLARE
    novo_id VARCHAR(25);
BEGIN
    IF NULLIF(BTRIM(NEW.idfornecedor), '') IS NULL THEN

        novo_id := 'FORN-' ||
            SUBSTRING(
                MD5(
                    RANDOM()::TEXT ||
                    CLOCK_TIMESTAMP()::TEXT
                ),
                1,
                12
            );

        INSERT INTO fornecedor (
            idfornecedor,
            razao_social
        )
        VALUES (
            novo_id,
            'Fornecedor pendente de identificacao'
        );

        NEW.idfornecedor := novo_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Remover trigger anterior, caso exista.

DROP TRIGGER IF EXISTS trg_gerar_idfornecedor
ON produtos_filial;


-- Criar trigger para novos produtos.

CREATE TRIGGER trg_gerar_idfornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
EXECUTE FUNCTION gerar_idfornecedor();


-- FIM DA PARTE 3
