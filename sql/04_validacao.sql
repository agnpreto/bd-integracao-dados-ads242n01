-- ============================================================
-- Validação — base_teste.xlsx (5 abas)
-- Cada consulta retorna a quantidade de registros com o problema.
-- Corresponde à tabela de erros de docs/parte4_validacao.md.
-- ============================================================

-- 1. Totais por tabela (conferência da importação)
SELECT 'fornecedor' AS tabela, COUNT(*) FROM fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*) FROM produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*) FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*) FROM venda;

-- 2. Vendas com (filial_id, produto_id) sem cadastro em produtos_filial
SELECT COUNT(*) AS vendas_sem_cadastro
FROM venda v
LEFT JOIN produtos_filial pf
       ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
WHERE pf.produto_id IS NULL;

-- 3. Detalhe dos produtos/filiais sem cadastro
SELECT DISTINCT v.filial_id, v.produto_id
FROM venda v
LEFT JOIN produtos_filial pf
       ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
WHERE pf.produto_id IS NULL
ORDER BY v.filial_id, v.produto_id;

-- 4. Pedidos com data_entrega < data_pedido
SELECT COUNT(*) AS entrega_antes_pedido
FROM pedido_compra
WHERE data_entrega < data_pedido;

-- 5. Vendas com quantidade fracionada para unidade UN
SELECT venda_id, qtde_vendida, unidade_medida
FROM venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida <> FLOOR(qtde_vendida)
ORDER BY venda_id;

-- 6. Vendas por horário (suspeita de importação sem variação)
SELECT horariomov, COUNT(*) FROM venda
GROUP BY horariomov ORDER BY 2 DESC;

-- 7. Pedidos com ordem_compra = 0 (sem vínculo)
SELECT COUNT(*) AS pedidos_sem_ordem
FROM pedido_compra WHERE ordem_compra = 0;

-- 8. Divergência entre entradas.qtde_recebida e pedido_compra.qtde_entregue
SELECT COUNT(*) AS divergencias_qtde
FROM entradas_mercadoria em
JOIN pedido_compra pc ON pc.pedido_id = em.ordem_compra
WHERE em.qtde_recebida <> pc.qtde_entregue;

-- 9. Detalhe das divergências de quantidade
SELECT em.ordem_compra, em.qtde_recebida, pc.qtde_entregue,
       em.qtde_recebida - pc.qtde_entregue AS diferenca
FROM entradas_mercadoria em
JOIN pedido_compra pc ON pc.pedido_id = em.ordem_compra
ORDER BY em.ordem_compra;

-- 10. FKs órfãs (todas devem retornar 0 após conversão F1-F20)
SELECT 'pedido_compra.fornecedor_id' AS fk, COUNT(*) FROM pedido_compra pc
LEFT JOIN fornecedor f ON f.idfornecedor = pc.fornecedor_id
WHERE f.idfornecedor IS NULL
UNION ALL
SELECT 'produtos_filial.idfornecedor', COUNT(*) FROM produtos_filial pf
LEFT JOIN fornecedor f ON f.idfornecedor = pf.idfornecedor
WHERE f.idfornecedor IS NULL
UNION ALL
SELECT 'entradas.ordem_compra', COUNT(*) FROM entradas_mercadoria em
LEFT JOIN pedido_compra pc ON pc.pedido_id = em.ordem_compra
WHERE pc.pedido_id IS NULL;
