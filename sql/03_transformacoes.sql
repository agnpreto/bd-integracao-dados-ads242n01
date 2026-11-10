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
ORDER BY total_requisicoes DESC;-- 03_transformacoes
-- Nome:

