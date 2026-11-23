-- 02_consultas
-- Nome:
-- Sintaxe MySQL (Workbench). As duas consultas também rodam no PostgreSQL sem alteração.

USE integracao_dados;

-- ─────────────────────────────────────────────────────────────
-- 2.1 Consumo por produto e mês: total vendido em quantidade e em R$
--     de cada produto em fevereiro de 2025.
--
--  * Intervalo de datas ">= 01/02 e < 01/03" pega o mês inteiro sem depender
--    do último dia e aproveita o índice em data_emissao.
--  * Valor = quantidade × valor unitário de cada linha de venda.
--  * LEFT JOIN no cadastro: produtos vendidos que NÃO existem em produtos_filial
--    (P21 a P28) continuam no total, com a descrição "(não cadastrado)".
--    Se fosse INNER JOIN, essas vendas sumiriam do faturamento.
-- ─────────────────────────────────────────────────────────────
SELECT
    v.produto_id,
    COALESCE(MAX(p.descricao), '(não cadastrado)')      AS descricao,
    SUM(v.qtde_vendida)                                  AS qtde_vendida,
    ROUND(SUM(v.qtde_vendida * v.valor_unitario), 2)     AS valor_total_rs
FROM venda v
LEFT JOIN produtos_filial p
       ON p.produto_id = v.produto_id
      AND p.filial_id  = v.filial_id
WHERE v.data_emissao >= '2025-02-01'
  AND v.data_emissao <  '2025-03-01'
GROUP BY v.produto_id
ORDER BY valor_total_rs DESC;

-- Total geral do mês (para conferir a soma da consulta acima)
SELECT
    COUNT(*)                                         AS linhas_de_venda,
    SUM(qtde_vendida)                                AS qtde_total,
    ROUND(SUM(qtde_vendida * valor_unitario), 2)     AS valor_total_rs
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao <  '2025-03-01';


-- ─────────────────────────────────────────────────────────────
-- 2.2 Produtos com requisição pendente: requisitados mas não recebidos.
--
--  A entrada de mercadoria se liga ao pedido pelo campo ordem_compra
--  (e pelo produto). Um item de pedido está "não recebido" quando não existe
--  nenhuma entrada com a mesma ordem_compra e o mesmo produto.
--  Pedidos com ordem_compra = 0 não têm ordem emitida, então também não
--  podem ter sido recebidos; a coluna "situacao" deixa isso explícito.
-- ─────────────────────────────────────────────────────────────
SELECT
    pc.pedido_id,
    pc.data_pedido,
    pc.produto_id,
    pc.descricao_produto,
    pc.ordem_compra,
    pc.qtde_pedida,
    pc.qtde_entregue,
    pc.qtde_pendente,
    CASE WHEN pc.ordem_compra = 0
         THEN 'Sem ordem de compra emitida'
         ELSE 'Ordem emitida, sem entrada de mercadoria'
    END AS situacao
FROM pedido_compra pc
WHERE NOT EXISTS (
        SELECT 1
        FROM entradas_mercadoria em
        WHERE em.ordem_compra = pc.ordem_compra
          AND em.produto_id   = pc.produto_id
      )
ORDER BY pc.produto_id, pc.data_pedido;

-- Complemento: itens que tiveram entrada, mas em quantidade MENOR que a pedida
-- (recebidos só em parte).
SELECT
    pc.pedido_id,
    pc.produto_id,
    pc.descricao_produto,
    pc.ordem_compra,
    pc.qtde_pedida,
    SUM(em.qtde_recebida)                    AS qtde_recebida,
    pc.qtde_pedida - SUM(em.qtde_recebida)   AS falta_receber
FROM pedido_compra pc
JOIN entradas_mercadoria em
  ON em.ordem_compra = pc.ordem_compra
 AND em.produto_id   = pc.produto_id
GROUP BY pc.pedido_id, pc.produto_id, pc.descricao_produto, pc.ordem_compra, pc.qtde_pedida
HAVING SUM(em.qtde_recebida) < pc.qtde_pedida
ORDER BY falta_receber DESC;
