-- ============================================================================
-- PARTE 2: CONSULTAS SQL BÁSICAS
-- ============================================================================

-- 1. Total vendido em quantidade e em R$ por produto, em fevereiro de 2025
-- Utiliza LEFT JOIN com produtos_filial para exibir a descrição quando cadastrada,
-- sem ocultar produtos vendidos que ainda não possuem cadastro na filial (ex: P22..P27).
SELECT
    v.produto_id,
    COALESCE(pf.descricao, 'Produto sem cadastro na filial') AS descricao_produto,
    SUM(v.qtde_vendida) AS quantidade_total_vendida,
    ROUND(SUM(v.qtde_vendida * v.valor_unitario)::numeric, 2) AS valor_total_reais
FROM public.venda v
LEFT JOIN public.produtos_filial pf
    ON pf.produto_id = v.produto_id
   AND pf.filial_id = v.filial_id
WHERE v.data_emissao >= DATE '2025-02-01'
  AND v.data_emissao <= DATE '2025-02-28'
GROUP BY v.produto_id, pf.descricao
ORDER BY valor_total_reais DESC;


-- 2. Produtos requisitados e não recebidos
-- Liga pedido_compra com entradas_mercadoria pelo campo ordem_compra (e produto_id/item).
-- Considera como "não recebido" os pedidos sem entrada correspondente (ordem_compra = 0
-- ou sem registro em entradas_mercadoria) ou com quantidade entregue igual a zero.
SELECT
    pc.pedido_id,
    pc.ordem_compra,
    pc.produto_id,
    pc.descricao_produto,
    TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS data_pedido,
    pc.qtde_pedida,
    pc.qtde_entregue,
    pc.qtde_pendente,
    CASE
        WHEN pc.ordem_compra = 0 OR em.ordem_compra IS NULL THEN 'Sem nota de entrada vinculada'
        ELSE 'Recebimento pendente'
    END AS status_recebimento
FROM public.pedido_compra pc
LEFT JOIN public.entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra
   AND em.produto_id = pc.produto_id
   AND em.item = pc.item
   AND pc.ordem_compra > 0
WHERE em.ordem_compra IS NULL
   OR COALESCE(pc.qtde_entregue, 0) = 0
ORDER BY pc.pedido_id;