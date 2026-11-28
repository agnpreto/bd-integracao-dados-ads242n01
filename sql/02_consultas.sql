-- 02_consultas
-- Nome: João Gustavo Gonçalves Vasconcelos  | Matrícula: 2408298 | GitHub: SukitaAM
-- Banco: PostgreSQL 16 (tabelas de sql/01_ddl_postgres.sql, dados via scripts/importar.py)

-- =====================================================================================
-- 1) Consumo por produto em FEVEREIRO/2025: total em quantidade e em R$
-- =====================================================================================
-- Valor (R$) = SUM(qtde_vendida * valor_unitario). Intervalo "[01/02, 01/03)" para não perder
-- vendas do dia 28 e funcionar também se o campo um dia ganhar hora.
-- LEFT JOIN: P21..P28 são vendidos mas não existem em produtos_filial (erro de dados, Parte 4);
-- eles não podem sumir do total, por isso aparecem como "(sem cadastro)".
SELECT  v.produto_id,
        COALESCE(p.descricao, '(sem cadastro)')        AS descricao,
        SUM(v.qtde_vendida)                            AS qtde_total,
        SUM(v.qtde_vendida * v.valor_unitario)         AS valor_total_rs
FROM    public.venda v
LEFT JOIN public.produtos_filial p
       ON p.produto_id = v.produto_id
      AND p.filial_id  = v.filial_id
WHERE   v.data_emissao >= DATE '2025-02-01'
  AND   v.data_emissao <  DATE '2025-03-01'
GROUP BY v.produto_id, p.descricao
ORDER BY SUM(v.qtde_vendida * v.valor_unitario) DESC;

-- =====================================================================================
-- 2) Produtos com requisição pendente: requisitados (pedido_compra) e NÃO recebidos
--    (sem nenhuma linha em entradas_mercadoria)
-- =====================================================================================
-- O vínculo pedido x entrada é feito por ordem_compra (e produto_id, pois uma ordem pode ter
-- vários itens). Pedidos com ordem_compra = 0 não têm ordem válida e, portanto, nunca casam
-- com nenhuma entrada: aparecem como não recebidos (ver Parte 4).
SELECT  p.pedido_id,
        p.ordem_compra,
        p.produto_id,
        p.descricao_produto,
        p.qtde_pedida,
        p.data_pedido
FROM    public.pedido_compra p
WHERE   NOT EXISTS (
            SELECT 1
            FROM   public.entradas_mercadoria e
            WHERE  e.ordem_compra = p.ordem_compra
              AND  e.produto_id   = p.produto_id
        )
ORDER BY p.pedido_id;

-- 2b) Complemento: requisitados e recebidos PARCIALMENTE (recebido < pedido), por ordem de compra.
SELECT  p.ordem_compra,
        p.produto_id,
        p.qtde_pedida,
        SUM(e.qtde_recebida)                    AS qtde_recebida,
        p.qtde_pedida - SUM(e.qtde_recebida)    AS saldo_pendente
FROM    public.pedido_compra p
JOIN    public.entradas_mercadoria e
          ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
GROUP BY p.ordem_compra, p.produto_id, p.qtde_pedida
HAVING  SUM(e.qtde_recebida) < p.qtde_pedida
ORDER BY p.ordem_compra;
