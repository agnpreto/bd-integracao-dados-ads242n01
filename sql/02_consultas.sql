
-- ============================================================
-- PARTE 2 - CONSULTAS SQL
-- Projeto: Integracao de Dados - ADS242N01
-- ============================================================

-- 1. Total vendido por produto em fevereiro de 2025
-- Calcula quantidade e valor total das vendas.

SELECT
    produto_id,
    SUM(qtde_vendida) AS quantidade_total,
    SUM(qtde_vendida * valor_unitario) AS valor_total
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao < DATE '2025-03-01'
GROUP BY produto_id
ORDER BY produto_id;


-- 2. Produtos requisitados e ainda nao recebidos
-- Relacionamento realizado por ordem_compra,
-- produto, item e filial para evitar misturar registros.

SELECT
    p.pedido_id,
    p.ordem_compra,
    p.produto_id,
    p.descricao_produto,
    p.qtde_pedida,
    COALESCE(e.total_recebido, 0) AS qtde_recebida,
    p.qtde_pedida - COALESCE(e.total_recebido, 0)
        AS qtde_pendente
FROM pedido_compra p
LEFT JOIN (
    SELECT
        ordem_compra,
        produto_id,
        item,
        filial_id,
        SUM(COALESCE(qtde_recebida, 0)) AS total_recebido
    FROM entradas_mercadoria
    GROUP BY
        ordem_compra,
        produto_id,
        item,
        filial_id
) e
    ON p.ordem_compra = e.ordem_compra
   AND p.produto_id = e.produto_id
   AND p.item = e.item
   AND p.filial_id = e.filial_id
WHERE p.qtde_pedida > COALESCE(e.total_recebido, 0)
ORDER BY p.pedido_id, p.produto_id;
