-- =============================================================================
-- 04_validacao.sql — Parte 4 (validação com o cliente, fevereiro/2025)
-- Cada consulta retorna os registros problemáticos (não só contagem).
-- Banco: atividade (PostgreSQL 16)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- (a) Total vendido em fev/2025 (qtde e R$) — referência para a reunião
-- Comparação com sql/02_consultas.sql item (a). Sem registros problemáticos;
-- serve de base para conferir o fechamento do mês.
-- -----------------------------------------------------------------------------
SELECT
    v.produto_id,
    COALESCE(pf.descricao, '(sem cadastro)') AS descricao,
    SUM(v.qtde_vendida)                    AS qtde_total,
    SUM(v.qtde_vendida * v.valor_unitario) AS valor_total
FROM public.venda v
LEFT JOIN public.produtos_filial pf
       ON pf.filial_id = v.filial_id
      AND pf.produto_id = v.produto_id
WHERE v.data_emissao >= DATE '2025-02-01'
  AND v.data_emissao <= DATE '2025-02-28'
GROUP BY v.produto_id, pf.descricao
ORDER BY valor_total DESC;

-- -----------------------------------------------------------------------------
-- (b) Vendas com data_emissao fora de fevereiro/2025
-- Útil para garantir que o fechamento do mês não inclui outras datas.
-- -----------------------------------------------------------------------------
SELECT venda_id, data_emissao, produto_id, qtde_vendida, valor_unitario, filial_id
FROM public.venda
WHERE data_emissao < DATE '2025-02-01'
   OR data_emissao > DATE '2025-02-28'
ORDER BY data_emissao, venda_id;

-- -----------------------------------------------------------------------------
-- (c) Pedidos sem entrada correspondente (produtos requisitados não recebidos)
-- Elo via ordem_compra (+ item + produto_id). Retorna o pedido e a qtde pedida.
-- -----------------------------------------------------------------------------
SELECT
    pc.pedido_id, pc.produto_id, pc.ordem_compra, pc.data_pedido,
    pc.qtde_pedida, pc.qtde_entregue, pc.fornecedor_id
FROM public.pedido_compra pc
WHERE NOT EXISTS (
        SELECT 1 FROM public.entradas_mercadoria em
        WHERE em.ordem_compra = pc.ordem_compra
          AND em.item          = pc.item
          AND em.produto_id    = pc.produto_id
      )
ORDER BY pc.pedido_id;

-- -----------------------------------------------------------------------------
-- (d) Entradas sem pedido (órfãs) — ordens 19 e 20
-- -----------------------------------------------------------------------------
SELECT e.data_entrada, e.nro_nfe, e.ordem_compra, e.item, e.produto_id,
       e.qtde_recebida, e.custo_unitario
FROM public.entradas_mercadoria e
LEFT JOIN public.pedido_compra p
       ON p.ordem_compra = e.ordem_compra
      AND p.item          = e.item
      AND p.produto_id    = e.produto_id
WHERE p.pedido_id IS NULL
ORDER BY e.ordem_compra;

-- -----------------------------------------------------------------------------
-- (e) Pedidos com ordem_compra = 0 (dados faltantes)
-- -----------------------------------------------------------------------------
SELECT pedido_id, produto_id, data_pedido, qtde_pedida, qtde_entregue,
       fornecedor_id, ordem_compra
FROM public.pedido_compra
WHERE ordem_compra = 0 OR ordem_compra IS NULL
ORDER BY pedido_id;

-- -----------------------------------------------------------------------------
-- (f) Vendas com quantidade fracionada em unidade "UN"
-- -----------------------------------------------------------------------------
SELECT venda_id, produto_id, qtde_vendida, unidade_medida, data_emissao
FROM public.venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida <> TRUNC(qtde_vendida)
ORDER BY venda_id;

-- -----------------------------------------------------------------------------
-- (g) Vendas com produto sem cadastro (P21..P28)
-- -----------------------------------------------------------------------------
SELECT v.venda_id, v.filial_id, v.produto_id, v.data_emissao,
       v.qtde_vendida, v.valor_unitario
FROM public.venda v
LEFT JOIN public.produtos_filial pf
       ON pf.filial_id = v.filial_id
      AND pf.produto_id = v.produto_id
WHERE pf.produto_id IS NULL
ORDER BY v.produto_id, v.venda_id;

-- -----------------------------------------------------------------------------
-- (h) Pedidos com data_entrega anterior a data_pedido
-- -----------------------------------------------------------------------------
SELECT pedido_id, produto_id, data_pedido, data_entrega,
       (data_entrega - data_pedido) AS diferenca_dias
FROM public.pedido_compra
WHERE data_entrega < data_pedido
ORDER BY diferenca_dias, pedido_id;

-- -----------------------------------------------------------------------------
-- (i) Pedidos duplicados (21..29 repetem 12..20)
-- -----------------------------------------------------------------------------
SELECT
    a.pedido_id AS pedido_original,
    b.pedido_id AS pedido_duplicado,
    a.produto_id,
    a.data_pedido,
    a.preco_compra
FROM public.pedido_compra a
JOIN public.pedido_compra b
  ON  b.produto_id    = a.produto_id
  AND b.data_pedido   = a.data_pedido
  AND b.preco_compra  = a.preco_compra
  AND b.pedido_id     > a.pedido_id
ORDER BY a.pedido_id;

-- -----------------------------------------------------------------------------
-- (j) Divergência de quantidade: qtde_pedida vs soma(qtde_recebida) por ordem
-- -----------------------------------------------------------------------------
SELECT
    p.ordem_compra,
    SUM(p.qtde_pedida)                AS qtde_pedida,
    COALESCE(e.qtde_recebida, 0)      AS qtde_recebida,
    SUM(p.qtde_pedida) - COALESCE(e.qtde_recebida, 0) AS diferenca
FROM public.pedido_compra p
LEFT JOIN (
    SELECT ordem_compra, SUM(qtde_recebida) AS qtde_recebida
    FROM public.entradas_mercadoria
    GROUP BY ordem_compra
) e ON e.ordem_compra = p.ordem_compra
GROUP BY p.ordem_compra, e.qtde_recebida
HAVING SUM(p.qtde_pedida) <> COALESCE(e.qtde_recebida, 0)
ORDER BY p.ordem_compra;
