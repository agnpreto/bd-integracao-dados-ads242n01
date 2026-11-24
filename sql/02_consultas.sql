-- 02_consultas
-- Nome: Matheus Nogueira
--
-- Parte 2: consultas pedidas pelo cliente.
-- Escritas em SQL padrao: rodam no PostgreSQL e no MySQL 8 (sem prefixo de
-- schema; no PostgreSQL o search_path ja aponta para public).
-- Pre-requisito: DDL de sql/01_ddl_*.sql aplicado e scripts/importar.py executado.


-- ===========================================================================
-- 2.1 Total vendido em quantidade e em R$ por produto, em fevereiro de 2025
-- ---------------------------------------------------------------------------
-- * O periodo e um intervalo semiaberto [01/02/2025, 01/03/2025): pega o mes
--   inteiro sem depender do ultimo dia (28/29) nem de funcoes de data.
-- * Valor em R$ = qtde_vendida * valor_unitario, somado por produto.
-- * A descricao vem de produtos_filial com LEFT JOIN, para que as vendas de
--   produtos sem cadastro (P22..P27 em fevereiro) NAO sumam do total.
-- * O cadastro e por filial; o MAX(descricao) evita duplicar a venda caso o
--   mesmo produto esteja cadastrado em mais de uma filial.
-- Resultado nesta base: 14 produtos, 173,22 unidades, R$ 14.093,17.
-- ===========================================================================
WITH cadastro AS (
    SELECT produto_id, MAX(descricao) AS descricao
    FROM produtos_filial
    GROUP BY produto_id
)
SELECT v.produto_id,
       COALESCE(c.descricao, '(produto sem cadastro)')               AS descricao,
       SUM(v.qtde_vendida)                                           AS qtde_vendida,
       CAST(SUM(v.qtde_vendida * v.valor_unitario) AS DECIMAL(14, 2)) AS valor_vendido_rs
FROM venda v
LEFT JOIN cadastro c ON c.produto_id = v.produto_id
WHERE v.data_emissao >= DATE '2025-02-01'
  AND v.data_emissao <  DATE '2025-03-01'
GROUP BY v.produto_id, c.descricao
ORDER BY valor_vendido_rs DESC;

-- Linha de total para conferir com o relatorio do cliente.
SELECT COUNT(DISTINCT produto_id)                                AS produtos,
       SUM(qtde_vendida)                                         AS qtde_total,
       CAST(SUM(qtde_vendida * valor_unitario) AS DECIMAL(14, 2)) AS valor_total_rs
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao <  DATE '2025-03-01';


-- ===========================================================================
-- 2.2 Produtos requisitados e nao recebidos
-- ---------------------------------------------------------------------------
-- Como interpretei:
-- * "Requisitado" = linha de pedido_compra.
-- * "Recebido"    = entradas_mercadoria ligadas ao pedido por
--                   ordem_compra + item + produto_id (o README diz que a
--                   ligacao e pela ordem_compra; item e produto evitam casar
--                   a entrada de um produto com o pedido de outro).
-- * A quantidade recebida e a SOMA real das notas de entrada, e nao o campo
--   pedido_compra.qtde_entregue, porque os dois nao batem (ver erro E05 na
--   Parte 4).
-- * Entra no resultado todo produto com saldo (pedido - recebido) > 0.
--   A coluna situacao separa "nada recebido" de "recebido em parte".
-- * O saldo e calculado por pedido e so depois somado: o excesso recebido em
--   um pedido nao "paga" outro pedido do mesmo produto (ex.: P15).
-- Resultado nesta base: 14 produtos, 21 linhas de pedido. P19 e P20 aparecem
-- como "nada recebido": seus pedidos estao com ordem_compra = 0, enquanto as
-- notas NFE19/NFE20 chegaram com as ordens 19 e 20 (erros E03/E04 da Parte 4).
-- ===========================================================================
WITH recebido AS (
    SELECT ordem_compra, item, produto_id,
           SUM(qtde_recebida) AS qtde_recebida
    FROM entradas_mercadoria
    GROUP BY ordem_compra, item, produto_id
),
por_pedido AS (
    SELECT pc.produto_id,
           pc.descricao_produto,
           COALESCE(pc.qtde_pedida, 0)  AS qtde_pedida,
           COALESCE(r.qtde_recebida, 0) AS qtde_recebida
    FROM pedido_compra pc
    LEFT JOIN recebido r
           ON r.ordem_compra = pc.ordem_compra
          AND r.item         = pc.item
          AND r.produto_id   = pc.produto_id
)
SELECT produto_id,
       MAX(descricao_produto)                           AS descricao,
       COUNT(*)                                         AS pedidos,
       SUM(qtde_pedida)                                 AS qtde_pedida,
       SUM(qtde_recebida)                               AS qtde_recebida,
       SUM(GREATEST(qtde_pedida - qtde_recebida, 0))    AS qtde_nao_recebida,
       CASE WHEN SUM(qtde_recebida) = 0 THEN 'nada recebido'
            ELSE 'recebido em parte' END                AS situacao
FROM por_pedido
GROUP BY produto_id
HAVING SUM(GREATEST(qtde_pedida - qtde_recebida, 0)) > 0
ORDER BY qtde_nao_recebida DESC, produto_id;

-- Mesma regra, uma linha por pedido (para conferir pedido a pedido).
WITH recebido AS (
    SELECT ordem_compra, item, produto_id,
           SUM(qtde_recebida) AS qtde_recebida
    FROM entradas_mercadoria
    GROUP BY ordem_compra, item, produto_id
)
SELECT pc.pedido_id,
       pc.item,
       pc.ordem_compra,
       pc.produto_id,
       pc.data_pedido,
       pc.qtde_pedida,
       COALESCE(r.qtde_recebida, 0)                   AS qtde_recebida,
       pc.qtde_pedida - COALESCE(r.qtde_recebida, 0)  AS qtde_nao_recebida
FROM pedido_compra pc
LEFT JOIN recebido r
       ON r.ordem_compra = pc.ordem_compra
      AND r.item         = pc.item
      AND r.produto_id   = pc.produto_id
WHERE pc.qtde_pedida > COALESCE(r.qtde_recebida, 0)
ORDER BY pc.pedido_id, pc.item;
