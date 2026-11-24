-- 04_validacao
-- Parte 4: Consultas de apoio para a reunião de validação com o
-- cliente (dados de fevereiro de 2025). Cada bloco corresponde a
-- um ponto do roteiro em docs/parte4_validacao.md.

-- ─────────────────────────────────────────────────────────────
-- A) Visão geral: total vendido (quantidade e R$) por produto e
--    filial em fevereiro/2025 — o número que o cliente vai
--    conferir contra o relatório dele.
-- ─────────────────────────────────────────────────────────────
SELECT
    v.filial_id,
    v.produto_id,
    pf.descricao,
    SUM(v.qtde_vendida)                    AS qtde_total_vendida,
    SUM(v.qtde_vendida * v.valor_unitario) AS valor_total_vendido
FROM venda v
LEFT JOIN produtos_filial pf
       ON pf.produto_id = v.produto_id
      AND pf.filial_id  = v.filial_id
WHERE v.data_emissao >= '2025-02-01'
  AND v.data_emissao <  '2025-03-01'
GROUP BY v.filial_id, v.produto_id, pf.descricao
ORDER BY v.filial_id, v.produto_id;

-- ─────────────────────────────────────────────────────────────
-- ERRO 1: produtos vendidos sem nenhum cadastro em produtos_filial
-- (sem descrição, preço de custo/venda ou estoque conhecidos).
-- Mostra, de quebra, que produtos_filial só tem dados da filial 1
-- — não cobre as vendas das filiais 2 e 3.
-- ─────────────────────────────────────────────────────────────
SELECT DISTINCT v.filial_id, v.produto_id
FROM venda v
LEFT JOIN produtos_filial pf
       ON pf.produto_id = v.produto_id
      AND pf.filial_id  = v.filial_id
WHERE pf.produto_id IS NULL
ORDER BY v.filial_id, v.produto_id;

-- ─────────────────────────────────────────────────────────────
-- ERRO 2: vendas com quantidade fracionária em um produto cuja
-- unidade de medida é "UN" (unidade inteira) — valor fisicamente
-- incoerente (ex.: 37,11 unidades).
-- ─────────────────────────────────────────────────────────────
SELECT venda_id, produto_id, qtde_vendida, unidade_medida, data_emissao
FROM venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida <> trunc(qtde_vendida)
ORDER BY venda_id;

-- ─────────────────────────────────────────────────────────────
-- ERRO 3: pedidos de compra com data de entrega anterior à data
-- do próprio pedido (a mercadoria "chegou" antes de ser pedida).
-- ─────────────────────────────────────────────────────────────
SELECT pedido_id, produto_id, data_pedido, data_entrega
FROM pedido_compra
WHERE data_entrega < data_pedido
ORDER BY pedido_id;

-- ─────────────────────────────────────────────────────────────
-- ERRO 4: pedidos de compra sem número de ordem de compra
-- (ordem_compra = 0, valor padrão por ausência na planilha) —
-- ficam impossíveis de conciliar com entradas_mercadoria.
-- ─────────────────────────────────────────────────────────────
SELECT pedido_id, produto_id, data_pedido, qtde_pedida, qtde_entregue
FROM pedido_compra
WHERE ordem_compra = 0
ORDER BY pedido_id;

-- ─────────────────────────────────────────────────────────────
-- TÉCNICA: conferência cruzada entre o que pedido_compra registra
-- como "entregue" e o que realmente consta em entradas_mercadoria
-- para a mesma ordem_compra (exclui as ordem_compra = 0 do ERRO 4,
-- que não têm como ser conferidas).
-- ─────────────────────────────────────────────────────────────
SELECT
    pc.ordem_compra,
    pc.produto_id,
    pc.qtde_entregue                           AS entregue_no_pedido,
    COALESCE(SUM(em.qtde_recebida), 0)         AS recebido_em_entradas,
    pc.qtde_entregue - COALESCE(SUM(em.qtde_recebida), 0) AS diferenca
FROM pedido_compra pc
LEFT JOIN entradas_mercadoria em ON em.ordem_compra = pc.ordem_compra
WHERE pc.ordem_compra <> 0
GROUP BY pc.ordem_compra, pc.produto_id, pc.qtde_entregue
HAVING pc.qtde_entregue <> COALESCE(SUM(em.qtde_recebida), 0)
ORDER BY pc.ordem_compra;
