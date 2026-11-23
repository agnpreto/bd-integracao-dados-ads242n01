-- ============================================================================
-- PARTE 4: CONSULTAS DE AUDITORIA E VALIDAÇÃO DE DADOS (FEVEREIRO DE 2025)
-- ============================================================================

-- 1. Resumo Executivo de Vendas e Compras de Fevereiro/2025 (Reconciliação)
SELECT
    'Vendas Fevereiro/2025' AS indicador,
    COUNT(*) AS total_registros,
    SUM(qtde_vendida) AS volume_itens,
    ROUND(SUM(qtde_vendida * valor_unitario)::numeric, 2) AS valor_total_rs
FROM public.venda
WHERE data_emissao BETWEEN DATE '2025-02-01' AND DATE '2025-02-28'
UNION ALL
SELECT
    'Pedidos Compra Fevereiro/2025',
    COUNT(*),
    SUM(qtde_pedida),
    ROUND(SUM(qtde_pedida * preco_compra)::numeric, 2)
FROM public.pedido_compra
WHERE data_pedido BETWEEN DATE '2025-02-01' AND DATE '2025-02-28'
UNION ALL
SELECT
    'Entradas Mercadoria Fevereiro/2025',
    COUNT(*),
    SUM(qtde_recebida),
    ROUND(SUM(qtde_recebida * custo_unitario)::numeric, 2)
FROM public.entradas_mercadoria
WHERE data_entrada BETWEEN DATE '2025-02-01' AND DATE '2025-02-28';


-- 2. ERRO 1: Produtos vendidos sem cadastro na tabela produtos_filial (Integridade Órfã)
-- Detecta vendas de P21 a P28 que não possuem registro mestre em produtos_filial.
SELECT
    v.venda_id,
    v.filial_id,
    v.produto_id,
    TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS data_emissao,
    v.qtde_vendida,
    v.valor_unitario
FROM public.venda v
LEFT JOIN public.produtos_filial pf
    ON pf.produto_id = v.produto_id
   AND pf.filial_id = v.filial_id
WHERE pf.produto_id IS NULL
ORDER BY v.data_emissao, v.venda_id;


-- 3. ERRO 2: Pedidos de compra com data_entrega anterior à data_pedido (Inconsistência Temporal)
-- Detecta 19 pedidos onde a entrega consta antes mesmo da emissão do pedido.
SELECT
    pedido_id,
    produto_id,
    descricao_produto,
    TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_pedido,
    TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega,
    (data_entrega - data_pedido) AS diferenca_dias
FROM public.pedido_compra
WHERE data_entrega < data_pedido
ORDER BY pedido_id;


-- 4. ERRO 3: Entradas de mercadoria com data_entrada anterior à data_pedido
-- Detecta notas fiscais cuja entrada física ocorreu antes da solicitação de compra.
SELECT
    pc.pedido_id,
    pc.ordem_compra,
    em.nro_nfe,
    pc.produto_id,
    TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS data_pedido,
    TO_CHAR(em.data_entrada, 'DD/MM/YYYY') AS data_entrada
FROM public.pedido_compra pc
INNER JOIN public.entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra
   AND em.produto_id = pc.produto_id
WHERE em.data_entrada < pc.data_pedido
ORDER BY pc.pedido_id;


-- 5. ERRO 4: Divergência entre qtde_entregue (pedido_compra) e qtde_recebida (entradas_mercadoria)
-- Todas as 18 ordens de compra vinculadas possuem quantidades divergentes entre o pedido e a NF-e,
-- além de casos em que qtde_recebida na NF-e supera a qtde_pedida.
SELECT
    pc.pedido_id,
    pc.ordem_compra,
    em.nro_nfe,
    pc.produto_id,
    pc.qtde_pedida,
    pc.qtde_entregue AS qtde_baixa_pedido,
    em.qtde_recebida AS qtde_nota_fiscal,
    (em.qtde_recebida - pc.qtde_entregue) AS divergencia_baixa
FROM public.pedido_compra pc
INNER JOIN public.entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra
   AND em.produto_id = pc.produto_id
WHERE pc.qtde_entregue <> em.qtde_recebida
ORDER BY pc.ordem_compra;


-- 6. ERRO 5: Pedidos de compra duplicados/complementares sem ordem_compra (ordem_compra = 0)
-- Identifica os pedidos 19 a 29 (incluindo duplicidades de P12..P20) sem vínculo com entrada.
SELECT
    pedido_id,
    produto_id,
    descricao_produto,
    TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_pedido,
    ordem_compra,
    qtde_pedida,
    qtde_entregue
FROM public.pedido_compra
WHERE ordem_compra = 0
ORDER BY pedido_id;


-- 7. ERRO 6: Margem negativa e inconsistência de preços em produtos_filial e entradas
-- Detecta produtos com preco_venda menor que preco_compra e divergência com preco_unitario.
SELECT
    filial_id,
    produto_id,
    descricao,
    preco_compra,
    preco_unitario,
    preco_venda,
    ROUND((preco_venda - preco_compra)::numeric, 2) AS margem_bruta_unitaria
FROM public.produtos_filial
WHERE preco_venda < preco_compra
   OR preco_unitario <> preco_venda
ORDER BY margem_bruta_unitaria ASC;