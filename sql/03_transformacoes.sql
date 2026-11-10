-- Parte 3: Transformacoes SQL
-- Aluna: Franciane Nogueira

-- Consulta 1: Juntar codigo e descricao do produto

SELECT
    CONCAT(produto_id, ' - ', descricao_produto) AS produto
FROM pedido_compra;

-- Consulta 2: Formatar datas no padrao brasileiro

SELECT
    produto_id,
    descricao_produto,
    TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_solicitacao
FROM pedido_compra;

-- Interpretacao: mais de 10 registros de pedidos
-- para o mesmo produto.

SELECT
    produto_id,
    COUNT(*) AS total_requisicoes
FROM pedido_compra
GROUP BY produto_id
HAVING COUNT(*) > 10
ORDER BY total_requisicoes DESC;-- 03_transformaco-- Nome:



-- Parte 3: Trigger de fornecedor
-- Objetivo: gerar automaticamente um identificador
-- para produtos sem fornecedor cadastrado.
-- Funcao para atribuir fornecedor automaticamente
-- Funcao para gerar um novo fornecedor

CREATE OR REPLACE FUNCTION gerar_idfornecedor()
RETURNS TRIGGER AS $$
DECLARE
    novo_id VARCHAR(25);
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        novo_id := 'FORN-' ||
            SUBSTRING(MD5(gen_random_uuid()::TEXT), 1, 12);

        INSERT INTO fornecedor (idfornecedor, razao_social)
        VALUES (novo_id, 'Fornecedor pendente de identificacao');

        NEW.idfornecedor := novo_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Gatilho executado antes de inserir um produto

CREATE TRIGGER trg_gerar_idfornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
EXECUTE FUNCTION gerar_idfornecedor();



