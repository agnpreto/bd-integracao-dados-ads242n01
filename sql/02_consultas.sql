-- PARTE 2 - CONSULTAS SQL

-- Questao 1: Total vendido em quantidade
-- e em reais por produto em fevereiro de 2025.

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

-- Questao 2: Produtos requisitados
-- sem registro de recebimento.

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