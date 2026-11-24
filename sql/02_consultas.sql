-- 02_consultas
-- Nome: Márcio Deoclides Marinho da Rocha 
-- Parte 2: Consultas SQL (fevereiro de 2025 e pedidos não recebidos)

-- 1) Total vendido em quantidade e em R$ por produto em fevereiro de 2025
SELECT
    v.produto_id,
    COALESCE(MAX(pf.descricao_produto), v.produto_id) AS descricao_produto,
    SUM(COALESCE(v.qtde_vendida, 0)) AS qtde_total_vendida,
    SUM(COALESCE(v.qtde_vendida, 0) * COALESCE(v.valor_unitario, 0)) AS valor_total_rs
FROM public.venda v
LEFT JOIN public.produtos_filial pf
    ON pf.produto_id = v.produto_id
   AND pf.filial_id = v.filial_id
WHERE v.data_emissao >= DATE '2025-02-01'
  AND v.data_emissao <  DATE '2025-03-01'
GROUP BY v.produto_id
ORDER BY valor_total_rs DESC, v.produto_id;

-- 2) Produtos requisitados (em pedido_compra) e não recebidos (sem entrada em entradas_mercadoria)
-- A ligação entre pedido de compra e entrada de mercadoria dá-se por ordem_compra.
SELECT DISTINCT
    pc.ordem_compra,
    pc.pedido_id,
    pc.produto_id,
    pc.descricao_produto,
    pc.filial_id,
    pc.qtde_pedida,
    pc.qtde_pendente
FROM public.pedido_compra pc
LEFT JOIN public.entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra
   AND em.produto_id = pc.produto_id
WHERE em.ordem_compra IS NULL
   OR COALESCE(pc.qtde_pendente, 0) > 0
ORDER BY pc.ordem_compra, pc.produto_id;

