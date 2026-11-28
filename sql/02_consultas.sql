-- 02_consultas
-- Nome: Mateus Farias Bentes
-- SQL padrão: roda igual no PostgreSQL e no MySQL (exceto onde indicado).

-- ═════════════════════════════════════════════════════════════
-- 2.1  Total vendido por produto em fevereiro/2025 (quantidade e R$)
-- ═════════════════════════════════════════════════════════════
-- * Filtro por intervalo (>= 01/02 e < 01/03) em vez de EXTRACT/MONTH(): pega o mês
--   inteiro sem se preocupar com dia 28/29 e deixa o banco usar o índice da data.
-- * Valor = quantidade x valor unitário de cada linha, somado (e não SUM(qtde) x preço,
--   porque o preço pode mudar de uma venda para outra).
-- * LEFT JOIN com produtos: vendas de produto não cadastrado (P21..P28) continuam
--   aparecendo, com a descrição "(não cadastrado)". Com INNER JOIN elas sumiriam do total.
-- * A descrição é buscada por produto_id em qualquer filial (subconsulta), porque a venda
--   de P27 é da filial 2 e só existe cadastro na filial 1.
SELECT
    v.produto_id,
    COALESCE(p.descricao, '(não cadastrado)') AS descricao,
    SUM(v.qtde_vendida)                              AS qtde_total,
    ROUND(SUM(v.qtde_vendida * v.valor_unitario), 2) AS valor_total_rs
FROM venda v
LEFT JOIN (SELECT produto_id, MAX(descricao) AS descricao
             FROM produtos_filial
            GROUP BY produto_id) p
       ON p.produto_id = v.produto_id
WHERE v.data_emissao >= '2025-02-01'
  AND v.data_emissao <  '2025-03-01'
GROUP BY v.produto_id, p.descricao
ORDER BY valor_total_rs DESC;

-- Total geral do mês (para conferir com o cliente: a soma das linhas acima tem que bater)
SELECT COUNT(*)                                         AS linhas_de_venda,
       SUM(qtde_vendida)                                AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2)     AS valor_total_rs
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao <  '2025-03-01';


-- ═════════════════════════════════════════════════════════════
-- 2.2  Produtos requisitados e não recebidos
-- ═════════════════════════════════════════════════════════════
-- Regra do enunciado: a entrada de mercadoria se liga ao pedido pela ORDEM_COMPRA.
-- Então "recebido" = existe entrada com a mesma ordem_compra e o mesmo produto.
-- Usamos as entradas (nota fiscal) como fonte da verdade, e não o campo qtde_entregue
-- do pedido, porque os dois não batem na planilha (ver Parte 4).

-- 2.2.a  Itens de pedido SEM NENHUMA entrada vinculada (requisitado e não recebido)
SELECT
    pc.pedido_id,
    pc.ordem_compra,
    pc.produto_id,
    pc.descricao_produto,
    pc.data_pedido,
    pc.qtde_pedida
FROM pedido_compra pc
WHERE NOT EXISTS (SELECT 1
                    FROM entradas_mercadoria em
                   WHERE em.ordem_compra = pc.ordem_compra
                     AND em.produto_id   = pc.produto_id)
ORDER BY pc.produto_id, pc.pedido_id;

-- 2.2.b  Visão por produto: quanto foi pedido, quanto entrou e quanto falta.
-- Inclui também quem recebeu só uma parte. Saldo negativo = recebeu MAIS do que pediu
-- (aparece em separado na Parte 4 como erro de dado).
SELECT
    pc.produto_id,
    MAX(pc.descricao_produto)                         AS descricao,
    SUM(pc.qtde_pedida)                               AS qtde_pedida,
    SUM(COALESCE(em.qtde_recebida, 0))                AS qtde_recebida,
    SUM(pc.qtde_pedida - COALESCE(em.qtde_recebida, 0)) AS qtde_pendente
FROM pedido_compra pc
LEFT JOIN (SELECT ordem_compra, produto_id, SUM(qtde_recebida) AS qtde_recebida
             FROM entradas_mercadoria
            GROUP BY ordem_compra, produto_id) em
       ON em.ordem_compra = pc.ordem_compra
      AND em.produto_id   = pc.produto_id
GROUP BY pc.produto_id
HAVING SUM(pc.qtde_pedida - COALESCE(em.qtde_recebida, 0)) > 0
ORDER BY qtde_pendente DESC;
