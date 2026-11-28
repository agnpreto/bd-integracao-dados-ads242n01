-- 04_validacao.sql | roteiro de consultas para validação de fevereiro/2025
-- Consultas compatíveis com PostgreSQL e MySQL 8+.

-- V1. Total de vendas do mês: quantidade e valor bruto.
SELECT COUNT(*) AS linhas_venda,
       SUM(qtde_vendida) AS quantidade_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_total_reais
FROM venda
WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01';

-- V2. Vendas detalhadas por produto no mês.
SELECT produto_id, SUM(qtde_vendida) AS quantidade,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_reais
FROM venda
WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
GROUP BY produto_id ORDER BY produto_id;

-- V3. Pedidos feitos em fevereiro e saldo pendente.
SELECT pedido_id, ordem_compra, produto_id, descricao_produto,
       qtde_pedida, qtde_entregue,
       GREATEST(qtde_pedida - qtde_entregue, 0) AS saldo_pendente
FROM pedido_compra
WHERE data_pedido >= '2025-02-01' AND data_pedido < '2025-03-01'
ORDER BY pedido_id;

-- V4. Linhas com ordem_compra zerada: precisam de confirmação antes de conciliar recebimentos.
SELECT pedido_id, data_pedido, produto_id, qtde_pedida, qtde_entregue, fornecedor_id
FROM pedido_compra WHERE ordem_compra = 0 ORDER BY pedido_id;

-- V5. Diferença entre qtde_entregue do pedido e soma das entradas vinculadas.
SELECT p.ordem_compra, p.produto_id, p.qtde_entregue,
       COALESCE(SUM(e.qtde_recebida), 0) AS total_entradas,
       p.qtde_entregue - COALESCE(SUM(e.qtde_recebida), 0) AS diferenca
FROM pedido_compra p
LEFT JOIN entradas_mercadoria e
  ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE p.ordem_compra > 0
GROUP BY p.ordem_compra, p.produto_id, p.qtde_entregue
HAVING p.qtde_entregue <> COALESCE(SUM(e.qtde_recebida), 0)
ORDER BY p.ordem_compra;

-- V6. Entradas sem pedido operacional correspondente.
SELECT e.ordem_compra, e.nro_nfe, e.produto_id, e.qtde_recebida
FROM entradas_mercadoria e
LEFT JOIN pedido_compra p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE p.pedido_id IS NULL;

-- V7. Produtos cujo código de fornecedor não foi relacionado.
SELECT filial_id, produto_id, codigo_fornecedor, idfornecedor
FROM produtos_filial
WHERE codigo_fornecedor IS NOT NULL AND idfornecedor IS NULL;

-- V8. Verificação de quantidades negativas ou recebimento maior que pedido.
SELECT pedido_id, produto_id, qtde_pedida, qtde_entregue
FROM pedido_compra
WHERE qtde_pedida < 0 OR qtde_entregue < 0 OR qtde_entregue > qtde_pedida;
