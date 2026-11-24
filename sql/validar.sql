-- =============================================================================
-- validar.sql — Conferência da importação (Etapa 1)
-- Rode depois de:
--   1) psql -f sql/01_ddl_postgres.sql
--   2) python scripts/importar.py
--
-- Cada bloco traz, em comentário, o resultado esperado com a planilha atual.
-- Nenhuma consulta altera dados.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CONTAGENS x PLANILHA
-- Esperado: 20 / 20 / 29 / 20 / 33
-- -----------------------------------------------------------------------------
SELECT 'fornecedor'          AS tabela, COUNT(*) AS linhas, 20 AS planilha FROM public.fornecedor
UNION ALL
SELECT 'produtos_filial',    COUNT(*), 20 FROM public.produtos_filial
UNION ALL
SELECT 'pedido_compra',      COUNT(*), 29 FROM public.pedido_compra
UNION ALL
SELECT 'entradas_mercadoria',COUNT(*), 20 FROM public.entradas_mercadoria
UNION ALL
SELECT 'venda',              COUNT(*), 33 FROM public.venda;

-- Status por tabela (OK / DIVERGENTE)
SELECT tabela, linhas, planilha,
       CASE WHEN linhas = planilha THEN 'OK' ELSE 'DIVERGENTE' END AS status
FROM (
    SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas, 20 AS planilha FROM public.fornecedor
    UNION ALL SELECT 'produtos_filial', COUNT(*), 20 FROM public.produtos_filial
    UNION ALL SELECT 'pedido_compra', COUNT(*), 29 FROM public.pedido_compra
    UNION ALL SELECT 'entradas_mercadoria', COUNT(*), 20 FROM public.entradas_mercadoria
    UNION ALL SELECT 'venda', COUNT(*), 33 FROM public.venda
) t;

-- -----------------------------------------------------------------------------
-- 2. ÓRFÃOS DE FK (relacionamentos lógicos)
-- -----------------------------------------------------------------------------

-- 2.1 Entradas de mercadoria sem pedido de compra (ligação por ordem_compra).
-- Esperado: 2 linhas (ordens 19 e 20).
SELECT e.ordem_compra, e.nro_nfe, e.produto_id, e.qtde_recebida
FROM public.entradas_mercadoria e
LEFT JOIN public.pedido_compra p
       ON p.ordem_compra = e.ordem_compra
      AND p.item = e.item
      AND p.produto_id = e.produto_id
WHERE p.pedido_id IS NULL
ORDER BY e.ordem_compra;

-- 2.2 Vendas sem produto cadastrado em produtos_filial (mesma filial).
-- Esperado: 8 grupos (13 vendas), produtos P21..P28.
SELECT v.filial_id, v.produto_id, COUNT(*) AS linhas_venda,
       SUM(v.qtde_vendida) AS qtde_total,
       SUM(v.qtde_vendida * v.valor_unitario) AS valor_total
FROM public.venda v
LEFT JOIN public.produtos_filial pf
       ON pf.filial_id = v.filial_id
      AND pf.produto_id = v.produto_id
WHERE pf.produto_id IS NULL
GROUP BY v.filial_id, v.produto_id
ORDER BY v.filial_id, v.produto_id;

-- 2.3 Pedidos sem fornecedor cadastrado.
-- Esperado: 0 (o script mapeia 1..20 -> F1..F20).
SELECT p.pedido_id, p.fornecedor_id
FROM public.pedido_compra p
LEFT JOIN public.fornecedor f ON f.idfornecedor = p.fornecedor_id
WHERE p.fornecedor_id IS NOT NULL AND f.idfornecedor IS NULL
ORDER BY p.pedido_id;

-- 2.4 Produtos com fornecedor inexistente.
-- Esperado: 0.
SELECT pf.filial_id, pf.produto_id, pf.idfornecedor
FROM public.produtos_filial pf
LEFT JOIN public.fornecedor f ON f.idfornecedor = pf.idfornecedor
WHERE pf.idfornecedor IS NOT NULL AND f.idfornecedor IS NULL;

-- -----------------------------------------------------------------------------
-- 3. DUPLICIDADES
-- -----------------------------------------------------------------------------

-- 3.1 Duplicidade de PK (não deve retornar linhas; a PK já impede).
SELECT 'venda' AS tabela, COUNT(*) AS grupos_duplicados FROM (
    SELECT 1 FROM public.venda
    GROUP BY filial_id, venda_id, data_emissao, produto_id, item, horariomov
    HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'pedido_compra', COUNT(*) FROM (
    SELECT 1 FROM public.pedido_compra GROUP BY pedido_id, produto_id, item
    HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'entradas_mercadoria', COUNT(*) FROM (
    SELECT 1 FROM public.entradas_mercadoria
    GROUP BY ordem_compra, item, produto_id, nro_nfe HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'produtos_filial', COUNT(*) FROM (
    SELECT 1 FROM public.produtos_filial GROUP BY filial_id, produto_id
    HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'fornecedor', COUNT(*) FROM (
    SELECT 1 FROM public.fornecedor GROUP BY idfornecedor HAVING COUNT(*) > 1) d;

-- 3.2 ordem_compra repetida em pedido_compra (chave de negócio, não é PK).
-- Esperado: uma linha, ordem_compra = 0 com 11 pedidos (19..29).
SELECT ordem_compra, COUNT(*) AS pedidos
FROM public.pedido_compra
GROUP BY ordem_compra
HAVING COUNT(*) > 1
ORDER BY pedidos DESC;

-- 3.3 Pedidos com mesma combinação (produto, data_pedido, preco_compra):
-- indício de pedido duplicado. Esperado: 9 grupos (pedidos 21..29 repetem 12..20).
SELECT p.produto_id, p.data_pedido, p.preco_compra, COUNT(*) AS pedidos,
       STRING_AGG(p.pedido_id::text, ', ' ORDER BY p.pedido_id) AS ids
FROM public.pedido_compra p
GROUP BY p.produto_id, p.data_pedido, p.preco_compra
HAVING COUNT(*) > 1
ORDER BY p.produto_id;

-- 3.4 NFE repetida em entradas.
-- Esperado: 0.
SELECT nro_nfe, COUNT(*) AS linhas
FROM public.entradas_mercadoria
GROUP BY nro_nfe
HAVING COUNT(*) > 1;

-- -----------------------------------------------------------------------------
-- 4. FAIXAS DE DATA E ID
-- -----------------------------------------------------------------------------
SELECT 'venda' AS tabela, MIN(venda_id) AS id_min, MAX(venda_id) AS id_max,
       MIN(data_emissao) AS data_min, MAX(data_emissao) AS data_max,
       MIN(horariomov) AS hora_min, MAX(horariomov) AS hora_max
FROM public.venda
UNION ALL
SELECT 'pedido_compra', MIN(pedido_id), MAX(pedido_id),
       MIN(data_pedido), MAX(data_pedido), NULL, NULL
FROM public.pedido_compra
UNION ALL
SELECT 'entradas_mercadoria', MIN(ordem_compra), MAX(ordem_compra),
       MIN(data_entrada), MAX(data_entrada), NULL, NULL
FROM public.entradas_mercadoria;

-- Registros fora de 2025 (esperado: 0).
SELECT 'venda' AS tabela, COUNT(*) AS fora_2025
FROM public.venda WHERE data_emissao NOT BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
UNION ALL
SELECT 'pedido_compra', COUNT(*) FROM public.pedido_compra
 WHERE data_pedido NOT BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
UNION ALL
SELECT 'entradas_mercadoria', COUNT(*) FROM public.entradas_mercadoria
 WHERE data_entrada NOT BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';

-- -----------------------------------------------------------------------------
-- 5. ERROS DE DADOS ENCONTRADOS (cada um com a consulta que o evidencia)
-- -----------------------------------------------------------------------------

-- 5.1 Pedidos sem ordem_compra (0 = não informado).
-- Esperado: 11 linhas (pedidos 19..29). Impede a ligação com entradas.
SELECT pedido_id, produto_id, qtde_pedida, fornecedor_id
FROM public.pedido_compra
WHERE ordem_compra = 0 OR ordem_compra IS NULL
ORDER BY pedido_id;

-- 5.2 Data de entrega anterior à data do pedido.
-- Esperado: 20 linhas.
SELECT pedido_id, produto_id, data_pedido, data_entrega,
       (data_entrega - data_pedido) AS diferenca_dias
FROM public.pedido_compra
WHERE data_entrega < data_pedido
ORDER BY diferenca_dias, pedido_id;

-- 5.3 Fornecedor fora da faixa F1..F20 no pedido.
-- Esperado: 0 (após a normalização do script).
SELECT pedido_id, fornecedor_id
FROM public.pedido_compra
WHERE fornecedor_id !~ '^F([1-9]|1[0-9]|20)$'
ORDER BY pedido_id;

-- 5.4 Quantidade fracionada em unidade "UN" (venda).
-- Esperado: 5 linhas.
SELECT venda_id, produto_id, qtde_vendida, unidade_medida
FROM public.venda
WHERE unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida)
ORDER BY venda_id;

-- 5.5 Divergência entre qtde_entregue do pedido e a soma das entradas da ordem.
-- Esperado: 18 ordens divergentes.
SELECT p.ordem_compra,
       SUM(p.qtde_entregue)                AS entregue_no_pedido,
       COALESCE(e.recebido, 0)             AS recebido_nas_entradas,
       SUM(p.qtde_entregue) - COALESCE(e.recebido, 0) AS diferenca
FROM public.pedido_compra p
LEFT JOIN (
    SELECT ordem_compra, SUM(qtde_recebida) AS recebido
    FROM public.entradas_mercadoria
    GROUP BY ordem_compra
) e ON e.ordem_compra = p.ordem_compra
GROUP BY p.ordem_compra, e.recebido
HAVING SUM(p.qtde_entregue) <> COALESCE(e.recebido, 0)
ORDER BY p.ordem_compra;

-- 5.6 Produtos vendidos sem cadastro (lista distinta).
-- Esperado: P21..P28.
SELECT DISTINCT v.produto_id
FROM public.venda v
LEFT JOIN public.produtos_filial pf ON pf.produto_id = v.produto_id
WHERE pf.produto_id IS NULL
ORDER BY v.produto_id;

-- 5.7 Nulos indevidos em campos que deveriam estar preenchidos.
SELECT 'venda.data_emissao' AS campo, COUNT(*) AS nulos
FROM public.venda WHERE data_emissao IS NULL
UNION ALL
SELECT 'venda.produto_id', COUNT(*) FROM public.venda WHERE produto_id IS NULL OR produto_id = ''
UNION ALL
SELECT 'pedido_compra.data_pedido', COUNT(*) FROM public.pedido_compra WHERE data_pedido IS NULL
UNION ALL
SELECT 'pedido_compra.fornecedor_id', COUNT(*) FROM public.pedido_compra WHERE fornecedor_id IS NULL
UNION ALL
SELECT 'entradas_mercadoria.data_entrada', COUNT(*) FROM public.entradas_mercadoria WHERE data_entrada IS NULL
UNION ALL
SELECT 'produtos_filial.idfornecedor', COUNT(*) FROM public.produtos_filial WHERE idfornecedor IS NULL;

-- 5.8 Resumo dos erros (uma linha por achado).
SELECT 'pedidos com ordem_compra = 0' AS erro, COUNT(*) AS ocorrencias
FROM public.pedido_compra WHERE ordem_compra = 0
UNION ALL
SELECT 'entregas antes do pedido', COUNT(*)
FROM public.pedido_compra WHERE data_entrega < data_pedido
UNION ALL
SELECT 'entradas sem pedido', COUNT(*)
FROM public.entradas_mercadoria e
LEFT JOIN public.pedido_compra p
       ON p.ordem_compra = e.ordem_compra AND p.item = e.item AND p.produto_id = e.produto_id
WHERE p.pedido_id IS NULL
UNION ALL
SELECT 'vendas de produto sem cadastro', COUNT(*)
FROM public.venda v
LEFT JOIN public.produtos_filial pf
       ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
WHERE pf.produto_id IS NULL
UNION ALL
SELECT 'pedidos duplicados (mesmo produto/data/preco)', COUNT(*)
FROM (SELECT 1 FROM public.pedido_compra
      GROUP BY produto_id, data_pedido, preco_compra HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'qtde fracionada em UN', COUNT(*)
FROM public.venda
WHERE unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida);
