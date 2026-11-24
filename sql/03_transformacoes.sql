
-- =====================================================
-- PARTE 3 - TRANSFORMACOES SQL
-- Projeto: Integracao de Dados - ADS242N01
-- Responsavel: Franciane Nogueira
-- Banco de dados: PostgreSQL
-- =====================================================

-- 1. Concatenar codigo e descricao do produto

SELECT
    CONCAT(produto_id, ' - ', descricao_produto) AS produto
FROM pedido_compra;


-- 2. Formatar datas no padrao brasileiro

SELECT
    produto_id,
    descricao_produto,
    TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_solicitacao
FROM pedido_compra;


-- 3. Identificar produtos com mais de 10 requisicoes

SELECT
    produto_id,
    COUNT(*) AS total_requisicoes
FROM pedido_compra
GROUP BY produto_id
HAVING COUNT(*) > 10
ORDER BY total_requisicoes DESC;


-- =====================================================
-- 4. TRIGGER PARA CADASTRO AUTOMATICO DE FORNECEDOR
-- Objetivo: gerar fornecedor quando o produto nao
-- possuir um fornecedor informado.
-- =====================================================

CREATE OR REPLACE FUNCTION gerar_idfornecedor()
RETURNS TRIGGER AS $$
DECLARE
    novo_id VARCHAR(25);
BEGIN
    IF NEW.idfornecedor IS NULL THEN

        novo_id := 'FORN-' ||
            SUBSTRING(MD5(gen_random_uuid()::TEXT), 1, 12);

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


-- Evita duplicidade do gatilho ao executar novamente

DROP TRIGGER IF EXISTS trg_gerar_idfornecedor
ON produtos_filial;

CREATE TRIGGER trg_gerar_idfornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
EXECUTE FUNCTION gerar_idfornecedor();


-- FIM DA PARTE 3
