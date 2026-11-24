-- 02_consultas
-- Parte 2: Consultas SQL Básicas

-- ─────────────────────────────────────────────────────────────
-- 1) Consumo por produto e mês: total vendido em quantidade e em
--    valor (R$), por produto, em fevereiro de 2025.
-- ─────────────────────────────────────────────────────────────
SELECT
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
GROUP BY v.produto_id, pf.descricao
ORDER BY v.produto_id;

-- ─────────────────────────────────────────────────────────────
-- 2) Produtos com requisição pendente: produtos que foram
--    requisitados (pedido_compra) mas não receberam nenhuma
--    unidade (qtde_entregue = 0).
--
-- Interpretação: "requisitados, mas não recebidos" = qtde_entregue
-- igual a zero (nenhuma entrega contra o pedido), e não apenas
-- "ainda falta receber uma parte" (qtde_pendente > 0) — quase todo
-- pedido da base tem alguma pendência, então esse segundo critério
-- devolveria praticamente a tabela inteira e não ajudaria o cliente
-- a identificar o problema real.
-- ─────────────────────────────────────────────────────────────
SELECT
    pc.pedido_id,
    pc.produto_id,
    pc.descricao_produto,
    pc.ordem_compra,
    pc.data_pedido,
    pc.qtde_pedida,
    pc.qtde_entregue,
    pc.qtde_pendente
FROM pedido_compra pc
WHERE pc.qtde_entregue = 0
ORDER BY pc.produto_id, pc.pedido_id;
