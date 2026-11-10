
-- Parte 4: Validacao dos dados
-- Aluna: Franciane de Carvalho Nogueira
-- Periodo: fevereiro de 2025

-- 1. Conferir quantidade de registros por tabela
SELECT 'fornecedor' AS tabela, COUNT(*) AS total
FROM fornecedor
UNION ALL
SELECT 'produtos_filial', COUNT(*) FROM produtos_filial
UNION ALL
SELECT 'pedido_compra', COUNT(*) FROM pedido_compra
UNION ALL
SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL
SELECT 'venda', COUNT(*) FROM venda;

-- 2. Total vendido por produto em fevereiro
SELECT
    produto_id,
    SUM(qtde_vendida) AS quantidade_total,
    SUM(qtde_vendida * valor_unitario) AS valor_total
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao < '2025-03-01'
GROUP BY produto_id
ORDER BY produto_id;

-- 3. Vendas com quantidades ou valores invalidos
SELECT *
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao < '2025-03-01'
  AND (
      qtde_vendida IS NULL
      OR qtde_vendida <= 0
      OR valor_unitario < 0
  );

-- 4. Pedidos com quantidades inconsistentes
SELECT *
FROM pedido_compra
WHERE data_pedido >= '2025-02-01'
  AND data_pedido < '2025-03-01'
  AND (
      qtde_pedida IS NULL
      OR qtde_pedida < 0
      OR qtde_entregue < 0
      OR qtde_entregue > qtde_pedida
      OR ABS(qtde_pendente -
          (qtde_pedida - qtde_entregue)) > 0.0001
  );

-- 5. Entradas sem pedido correspondente
SELECT e.*
FROM entradas_mercadoria e
WHERE e.data_entrada >= '2025-02-01'
  AND e.data_entrada < '2025-03-01'
  AND NOT EXISTS (
      SELECT 1
      FROM pedido_compra p
      WHERE p.ordem_compra = e.ordem_compra
        AND p.produto_id = e.produto_id
  );

-- 6. Produtos com fornecedor inexistente
SELECT pf.*
FROM produtos_filial pf
LEFT JOIN fornecedor f
    ON pf.idfornecedor = f.idfornecedor
WHERE pf.idfornecedor IS NOT NULL
  AND f.idfornecedor IS NULL;

-- 7. Produtos vendidos sem cadastro na filial
SELECT DISTINCT
    v.filial_id,
    v.produto_id
FROM venda v
LEFT JOIN produtos_filial pf
    ON v.filial_id = pf.filial_id
   AND v.produto_id = pf.produto_id
WHERE v.data_emissao >= '2025-02-01'
  AND v.data_emissao < '2025-03-01'
  AND pf.produto_id IS NULL;

-- 8. Possiveis pedidos duplicados
SELECT
    ordem_compra,
    produto_id,
    item,
    COUNT(*) AS repeticoes
FROM pedido_compra
GROUP BY ordem_compra, produto_id, item
HAVING COUNT(*) > 1;

-- 9. Datas de entrega anteriores ao pedido
SELECT *
FROM pedido_compra
WHERE data_pedido >= '2025-02-01'
  AND data_pedido < '2025-03-01'
  AND data_entrega < data_pedido;

-- 10. Recebimentos com quantidades invalidas
SELECT *
FROM entradas_mercadoria
WHERE data_entrada >= '2025-02-01'
  AND data_entrada < '2025-03-01'
  AND (
      qtde_recebida IS NULL
      OR qtde_recebida <= 0
  );

