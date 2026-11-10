
-- 02_consultas
-- Nome:Franciane Nogueira
-- Parte 2: Consulta SQL
-- Consulta 1: Total vendido por produto em fevereiro de 2025

SELECT
    produto_id,
    SUM(qtde_vendida) AS quantidade_total,
    SUM(qtde_vendida * valor_unitario) AS valor_total
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao < '2025-03-01'
GROUP BY produto_id
ORDER BY produto_id;-- Consulta 2: Produtos pedidos e ainda não recebidos

SELECT
    pedido_id,
    produto_id,
    descricao_produto,
    qtde_pedida,
    qtde_entregue,
    qtde_pendente
FROM pedido_compra
WHERE qtde_pendente > 0
ORDER BY pedido_id, produto_id;
