-- =============================================================================
-- 02_consultas.sql — Parte 2 (consultas básicas, somente SQL)
-- Banco: atividade (PostgreSQL 16)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- (a) Total vendido (quantidade e R$) por produto, em fevereiro de 2025
-- Interpretação: soma de qtde_vendida e de (qtde_vendida * valor_unitario)
-- para as vendas com data_emissao entre 01/02/2025 e 28/02/2025.
-- LEFT JOIN com produtos_filial para não perder vendas de produtos sem cadastro
-- (P21..P28); a descrição vem de produtos_filial quando existir.
-- -----------------------------------------------------------------------------
SELECT
    v.produto_id,
    COALESCE(pf.descricao, '(sem cadastro)') AS descricao,
    SUM(v.qtde_vendida)                      AS qtde_total,
    SUM(v.qtde_vendida * v.valor_unitario)   AS valor_total
FROM public.venda v
LEFT JOIN public.produtos_filial pf
       ON pf.filial_id = v.filial_id
      AND pf.produto_id = v.produto_id
WHERE v.data_emissao >= DATE '2025-02-01'
  AND v.data_emissao <= DATE '2025-02-28'
GROUP BY v.produto_id, pf.descricao
ORDER BY valor_total DESC;

-- -----------------------------------------------------------------------------
-- (b) Produtos requisitados e não recebidos (pendentes)
-- Interpretação: "requisitado" = existe em pedido_compra (qtde_pedida).
-- "Não recebido" = pedido (ordem_compra, item, produto_id) sem entrada
-- correspondente em entradas_mercadoria. O elo entre as duas tabelas é
-- ordem_compra (conforme enunciado: "uma entrada de mercadoria se liga ao seu
-- pedido de compra pelo campo ordem_compra"), reforçado por item e produto_id.
-- Agregamos por produto os pedidos sem entrada; qtde_recebida = 0 quando não
-- houve nenhuma entrada para aquele pedido.
-- -----------------------------------------------------------------------------
SELECT
    pc.produto_id,
    COALESCE(pf.descricao, pc.descricao_produto) AS descricao,
    SUM(pc.qtde_pedida)                          AS qtde_pedida_nao_recebida,
    0::numeric(12,3)                             AS qtde_recebida
FROM public.pedido_compra pc
LEFT JOIN public.produtos_filial pf
       ON pf.produto_id = pc.produto_id
WHERE NOT EXISTS (
        SELECT 1
        FROM public.entradas_mercadoria em
        WHERE em.ordem_compra = pc.ordem_compra
          AND em.item          = pc.item
          AND em.produto_id    = pc.produto_id
      )
GROUP BY pc.produto_id, pf.descricao, pc.descricao_produto
ORDER BY pc.produto_id;
