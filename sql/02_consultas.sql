-- 02_consultas
-- Nome: Áderson Teixeira

-- 1) Total vendido em quantidade e em R$ por produto, em fevereiro de 2025
SELECT
    v.produto_id,
    SUM(COALESCE(v.qtde_vendida, 0)) AS total_qtde_vendida,
    SUM(COALESCE(v.qtde_vendida, 0) * COALESCE(v.valor_unitario, 0)) AS total_reais_vendido
FROM public.venda v
WHERE v.data_emissao >= DATE '2025-02-01'
  AND v.data_emissao <  DATE '2025-03-01'
GROUP BY v.produto_id
ORDER BY v.produto_id;

-- 2) Produtos requisitados (pedido_compra) e não recebidos (entradas_mercadoria)
-- Ligação feita pelo campo ordem_compra conforme o enunciado
SELECT DISTINCT
    pc.produto_id,
    pc.descricao_produto,
    pc.ordem_compra,
    pc.data_pedido,
    pc.qtde_pedida
FROM public.pedido_compra pc
LEFT JOIN public.entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra
   AND em.produto_id = pc.produto_id
WHERE em.ordem_compra IS NULL
ORDER BY pc.produto_id, pc.ordem_compra;
