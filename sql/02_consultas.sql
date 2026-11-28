-- 02_consultas.sql | consultas básicas (sintaxe compatível com PostgreSQL e MySQL)
-- 1. Consumo por produto em fevereiro de 2025, em quantidade e valor bruto.
SELECT produto_id,
       SUM(qtde_vendida) AS quantidade_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_total_reais
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao <  '2025-03-01'
GROUP BY produto_id
ORDER BY produto_id;

-- 2. Produtos requisitados e ainda não recebidos (saldo pendente positivo).
SELECT pedido_id, ordem_compra, produto_id, descricao_produto,
       qtde_pedida, qtde_entregue,
       GREATEST(qtde_pedida - qtde_entregue, 0) AS qtde_pendente
FROM pedido_compra
WHERE qtde_pedida > qtde_entregue
ORDER BY pedido_id, produto_id;

-- 3. Resumo do saldo pendente por produto.
SELECT produto_id, descricao_produto,
       SUM(GREATEST(qtde_pedida - qtde_entregue, 0)) AS total_pendente
FROM pedido_compra
WHERE qtde_pedida > qtde_entregue
GROUP BY produto_id, descricao_produto
ORDER BY produto_id;
