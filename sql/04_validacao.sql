-- 04_validacao
-- Nome: Áderson Teixeira
-- Consultas de apoio e auditoria para validação dos dados de fevereiro/2025

-- 1) Resumo geral das vendas em fevereiro de 2025 (14 registros, 173,22 un., R$ 14.093,1704)
SELECT
    COUNT(*) AS qtd_registros_fev,
    SUM(COALESCE(qtde_vendida, 0)) AS soma_qtde_fev,
    SUM(COALESCE(qtde_vendida, 0) * COALESCE(valor_unitario, 0)) AS soma_valor_fev
FROM public.venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao <  DATE '2025-03-01';

-- 2) Erro nos dados (11 linhas): pedidos de compra com ordem_compra = 0 sem vínculo com entradas_mercadoria
SELECT
    pedido_id,
    ordem_compra,
    produto_id,
    descricao_produto,
    data_pedido,
    qtde_pedida
FROM public.pedido_compra
WHERE ordem_compra = 0
   OR ordem_compra IS NULL
ORDER BY pedido_id;

-- 3) Erro nos dados (20 linhas): data_entrega anterior à data_pedido em pedido_compra
SELECT
    pedido_id,
    ordem_compra,
    produto_id,
    data_pedido,
    data_entrega
FROM public.pedido_compra
WHERE data_entrega IS NOT NULL
  AND data_pedido IS NOT NULL
  AND data_entrega < data_pedido
ORDER BY pedido_id;

-- 4) Erro nos dados (7 linhas): quantidade recebida maior que a quantidade pedida no pedido correspondente
SELECT
    em.ordem_compra,
    em.nro_nfe,
    em.produto_id,
    pc.qtde_pedida,
    em.qtde_recebida
FROM public.entradas_mercadoria em
JOIN public.pedido_compra pc
  ON pc.ordem_compra = em.ordem_compra
 AND pc.produto_id = em.produto_id
WHERE COALESCE(em.qtde_recebida, 0) > COALESCE(pc.qtde_pedida, 0)
ORDER BY em.ordem_compra, em.nro_nfe;

-- 5) Erro nos dados (13 linhas): vendas com produto_id inexistente na tabela produtos_filial
SELECT
    v.venda_id,
    v.data_emissao,
    v.produto_id,
    v.qtde_vendida,
    v.valor_unitario
FROM public.venda v
LEFT JOIN public.produtos_filial pf
  ON pf.produto_id = v.produto_id
WHERE pf.produto_id IS NULL
ORDER BY v.venda_id;

-- 6) Erro nos dados (13 linhas): produtos_filial com preco_venda menor que preco_compra ou preco_unitario
SELECT
    filial_id,
    produto_id,
    descricao,
    preco_unitario,
    preco_compra,
    preco_venda
FROM public.produtos_filial
WHERE preco_venda < preco_compra
   OR preco_venda < preco_unitario
ORDER BY produto_id;
