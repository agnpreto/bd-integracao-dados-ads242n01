-- PARTE 4 - VALIDACAO COM O CLIENTE
-- Periodo de referencia: fevereiro de 2025

-- 1. Conferencia da quantidade de registros importados

SELECT 'fornecedor' AS tabela, COUNT(*) AS total
FROM public.fornecedor

UNION ALL

SELECT 'produtos_filial', COUNT(*)
FROM public.produtos_filial

UNION ALL

SELECT 'pedido_compra', COUNT(*)
FROM public.pedido_compra

UNION ALL

SELECT 'entradas_mercadoria', COUNT(*)
FROM public.entradas_mercadoria

UNION ALL

SELECT 'venda', COUNT(*)
FROM public.venda;


-- 2. Pedidos com data de entrega anterior ao pedido

SELECT
    pedido_id,
    produto_id,
    data_pedido,
    data_entrega,
    data_entrega - data_pedido AS diferenca_dias
FROM public.pedido_compra
WHERE data_entrega < data_pedido
ORDER BY pedido_id;


-- 3. Quantidade de pedidos com datas inconsistentes

SELECT COUNT(*) AS pedidos_inconsistentes
FROM public.pedido_compra
WHERE data_entrega < data_pedido;


-- 4. Pedidos inconsistentes de fevereiro de 2025

SELECT
    pedido_id,
    produto_id,
    data_pedido,
    data_entrega
FROM public.pedido_compra
WHERE data_entrega < data_pedido
    AND data_pedido >= '2025-02-01'
    AND data_pedido < '2025-03-01';


-- 5. Pedidos com fornecedores sem correspondencia

SELECT
    p.pedido_id,
    p.fornecedor_id
FROM public.pedido_compra p
LEFT JOIN public.fornecedor f
    ON p.fornecedor_id = f.idfornecedor
WHERE f.idfornecedor IS NULL;


-- 6. Produtos com fornecedores sem correspondencia

SELECT
    p.produto_id,
    p.idfornecedor
FROM public.produtos_filial p
LEFT JOIN public.fornecedor f
    ON p.idfornecedor = f.idfornecedor
WHERE f.idfornecedor IS NULL;


-- 7. Pedidos sem entrada de mercadoria correspondente

SELECT
    p.pedido_id,
    p.ordem_compra,
    p.produto_id,
    p.descricao_produto,
    p.filial_id,
    p.data_pedido,
    p.qtde_pedida
FROM public.pedido_compra p
WHERE NOT EXISTS (
    SELECT 1
    FROM public.entradas_mercadoria e
    WHERE e.ordem_compra = p.ordem_compra
        AND e.produto_id = p.produto_id
        AND e.filial_id = p.filial_id
        AND e.qtde_recebida > 0
)
ORDER BY p.pedido_id;


-- 8. Pedidos com ordem de compra igual a zero

SELECT
    pedido_id,
    produto_id,
    ordem_compra,
    data_pedido
FROM public.pedido_compra
WHERE ordem_compra = 0;


-- 9. Vendas de produtos sem cadastro na filial

SELECT
    v.venda_id,
    v.produto_id,
    v.filial_id
FROM public.venda v
LEFT JOIN public.produtos_filial p
    ON v.produto_id = p.produto_id
    AND v.filial_id = p.filial_id
WHERE p.produto_id IS NULL;


-- 10. Conferencia de quantidades pendentes

SELECT
    pedido_id,
    produto_id,
    qtde_pedida,
    qtde_entregue,
    qtde_pendente
FROM public.pedido_compra
WHERE qtde_pendente IS DISTINCT FROM
    (qtde_pedida - qtde_entregue);


-- 11. Conferencia das vendas de fevereiro de 2025

SELECT
    produto_id,
    SUM(qtde_vendida) AS quantidade_total,
    ROUND(
        SUM(qtde_vendida * valor_unitario)::NUMERIC,
        2
    ) AS valor_total
FROM public.venda
WHERE data_emissao >= '2025-02-01'
    AND data_emissao < '2025-03-01'
GROUP BY produto_id
ORDER BY produto_id;


-- 12. Valor total das vendas de fevereiro

SELECT
    COUNT(*) AS registros_venda,
    ROUND(
        SUM(qtde_vendida * valor_unitario)::NUMERIC,
        2
    ) AS valor_total
FROM public.venda
WHERE data_emissao >= '2025-02-01'
    AND data_emissao < '2025-03-01';


-- 13. Produtos com mais de 10 unidades requisitadas

SELECT
    CONCAT(produto_id, ' - ', descricao_produto)
        AS produto,
    SUM(qtde_pedida) AS qtde_requisitada,
    TO_CHAR(MIN(data_pedido), 'DD/MM/YYYY')
        AS primeira_solicitacao
FROM public.pedido_compra
WHERE data_pedido >= '2025-02-01'
    AND data_pedido < '2025-03-01'
GROUP BY produto_id, descricao_produto
HAVING SUM(qtde_pedida) > 10
ORDER BY qtde_requisitada DESC;