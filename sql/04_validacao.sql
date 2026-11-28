-- 04_validacao
-- Nome: Mateus Farias Bentes
-- Consultas para a reunião de validação de fevereiro/2025.
-- SQL padrão: roda no PostgreSQL e no MySQL sem alteração.
-- A explicação de cada consulta está em docs/parte4_validacao.md.

-- ═════════════════════════════════════════════════════════════
-- BLOCO A: conferência de totais (planilha do cliente x banco)
-- ═════════════════════════════════════════════════════════════

-- A1. Quantidade de linhas por tabela (tem que bater com a planilha: 20/20/29/20/33)
SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas FROM fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*) FROM produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*) FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*) FROM venda;

-- A2. Fechamento de vendas de fevereiro: nº de vendas, quantidade e faturamento
SELECT COUNT(*)                                     AS linhas_de_venda,
       COUNT(DISTINCT produto_id)                   AS produtos_vendidos,
       SUM(qtde_vendida)                            AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS faturamento_rs
FROM venda
WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01';

-- A3. Faturamento de fevereiro por filial
SELECT filial_id,
       COUNT(*)                                     AS linhas_de_venda,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS faturamento_rs
FROM venda
WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
GROUP BY filial_id
ORDER BY filial_id;

-- A4. Faturamento de fevereiro dia a dia (o cliente compara com o caixa / relatório dele)
SELECT data_emissao,
       COUNT(*)                                     AS linhas_de_venda,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS faturamento_rs
FROM venda
WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
GROUP BY data_emissao
ORDER BY data_emissao;

-- A5. Compras de fevereiro: pedidos feitos e mercadoria que entrou no mês
SELECT 'pedidos feitos em fev'    AS indicador, COUNT(*) AS linhas, SUM(qtde_pedida) AS qtde,
       ROUND(SUM(qtde_pedida * preco_compra), 2) AS valor_rs
FROM pedido_compra
WHERE data_pedido >= '2025-02-01' AND data_pedido < '2025-03-01'
UNION ALL
SELECT 'entradas (NF) em fev', COUNT(*), SUM(qtde_recebida),
       ROUND(SUM(qtde_recebida * custo_unitario), 2)
FROM entradas_mercadoria
WHERE data_entrada >= '2025-02-01' AND data_entrada < '2025-03-01';


-- ═════════════════════════════════════════════════════════════
-- BLOCO B: erros encontrados nos dados (um SELECT por erro)
-- ═════════════════════════════════════════════════════════════

-- E01. Vendas de produto que não existe no cadastro (produtos_filial)
SELECT v.*
FROM venda v
WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.produto_id = v.produto_id)
ORDER BY v.venda_id;

-- E02. Vendas em filial que não tem nenhum produto cadastrado (filiais 2 e 3)
SELECT v.*
FROM venda v
WHERE v.filial_id NOT IN (SELECT DISTINCT filial_id FROM produtos_filial)
ORDER BY v.venda_id;

-- E03. Quantidade fracionada vendida em unidade "UN" (ex.: 38,6 unidades)
SELECT venda_id, produto_id, qtde_vendida, unidade_medida
FROM venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida <> FLOOR(qtde_vendida)
ORDER BY venda_id;

-- E04. Preço praticado na venda diferente do preço de venda do cadastro
SELECT v.venda_id, v.produto_id, v.valor_unitario AS preco_na_venda, p.preco_venda AS preco_cadastro
FROM venda v
JOIN produtos_filial p ON p.produto_id = v.produto_id AND p.filial_id = v.filial_id
WHERE v.valor_unitario <> p.preco_venda
ORDER BY v.venda_id;

-- E05. Mesmo preço unitário em produtos diferentes (indício de linha copiada e colada)
SELECT valor_unitario,
       COUNT(DISTINCT produto_id) AS produtos_diferentes,
       MIN(produto_id) AS exemplo_1, MAX(produto_id) AS exemplo_2
FROM venda
GROUP BY valor_unitario
HAVING COUNT(DISTINCT produto_id) > 1
ORDER BY valor_unitario;

-- E06. Pedido de compra sem ordem de compra (ordem_compra = 0): não dá para ligar com a entrada
SELECT pedido_id, produto_id, ordem_compra, data_pedido, qtde_pedida
FROM pedido_compra
WHERE ordem_compra = 0
ORDER BY pedido_id;

-- E07. Pedido duplicado: mesmo produto, mesma data de pedido e de entrega em outro pedido_id
SELECT a.pedido_id AS pedido, b.pedido_id AS repetido_em, a.produto_id,
       a.data_pedido, a.qtde_pedida AS qtde_original, b.qtde_pedida AS qtde_repetido
FROM pedido_compra a
JOIN pedido_compra b
  ON b.produto_id   = a.produto_id
 AND b.data_pedido  = a.data_pedido
 AND b.data_entrega = a.data_entrega
 AND b.pedido_id    > a.pedido_id
ORDER BY a.pedido_id;

-- E08. Data de entrega ANTERIOR à data do pedido (entregou antes de pedir)
SELECT pedido_id, produto_id, data_pedido, data_entrega
FROM pedido_compra
WHERE data_entrega < data_pedido
ORDER BY pedido_id;

-- E09. Pedido com data de entrega preenchida, mas quantidade entregue = 0
SELECT pedido_id, produto_id, data_entrega, qtde_pedida, qtde_entregue
FROM pedido_compra
WHERE data_entrega IS NOT NULL AND qtde_entregue = 0
ORDER BY pedido_id;

-- E10. qtde_entregue do pedido diferente do que a nota fiscal (entrada) diz que chegou
SELECT pc.pedido_id, pc.ordem_compra, pc.produto_id,
       pc.qtde_entregue AS entregue_no_pedido, em.qtde_recebida AS recebido_na_nf
FROM pedido_compra pc
JOIN entradas_mercadoria em
  ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE pc.qtde_entregue <> em.qtde_recebida
ORDER BY pc.pedido_id;

-- E11. Recebeu MAIS do que pediu
SELECT pc.pedido_id, pc.produto_id, pc.qtde_pedida, em.qtde_recebida,
       em.qtde_recebida - pc.qtde_pedida AS excesso
FROM pedido_compra pc
JOIN entradas_mercadoria em
  ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE em.qtde_recebida > pc.qtde_pedida
ORDER BY excesso DESC;

-- E12. Mercadoria que entrou ANTES de ser pedida
SELECT pc.pedido_id, pc.produto_id, pc.data_pedido, em.data_entrada, em.nro_nfe
FROM pedido_compra pc
JOIN entradas_mercadoria em
  ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE em.data_entrada < pc.data_pedido
ORDER BY pc.pedido_id;

-- E13. Entrada cuja ordem_compra não existe em nenhum pedido (entrada "órfã")
SELECT em.*
FROM entradas_mercadoria em
WHERE NOT EXISTS (SELECT 1 FROM pedido_compra pc
                   WHERE pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id)
ORDER BY em.ordem_compra;

-- E14. Data de entrada da NF diferente da data de entrega registrada no pedido
SELECT pc.pedido_id, pc.produto_id, pc.data_entrega AS entrega_no_pedido, em.data_entrada AS entrada_na_nf
FROM pedido_compra pc
JOIN entradas_mercadoria em
  ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE pc.data_entrega <> em.data_entrada
ORDER BY pc.pedido_id;

-- E15. Custo na NF muito diferente do preço combinado no pedido (mais de 20% de diferença)
SELECT pc.pedido_id, pc.produto_id, pc.preco_compra AS preco_pedido, em.custo_unitario AS custo_nf,
       ROUND((em.custo_unitario - pc.preco_compra) * 100 / pc.preco_compra, 1) AS diferenca_pct
FROM pedido_compra pc
JOIN entradas_mercadoria em
  ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE ABS(em.custo_unitario - pc.preco_compra) > 0.2 * pc.preco_compra
ORDER BY pc.pedido_id;

-- E16. Fornecedor do pedido diferente do fornecedor do cadastro do produto
SELECT pc.pedido_id, pc.produto_id, pc.fornecedor_id AS fornecedor_no_pedido,
       p.idfornecedor AS fornecedor_no_cadastro
FROM pedido_compra pc
JOIN produtos_filial p ON p.produto_id = pc.produto_id AND p.filial_id = pc.filial_id
WHERE pc.fornecedor_id <> p.idfornecedor
ORDER BY pc.pedido_id;

-- E17. Produto com preço de compra MAIOR que o preço de venda (venda com prejuízo)
SELECT produto_id, descricao, preco_compra, preco_venda
FROM produtos_filial
WHERE preco_compra > preco_venda
ORDER BY produto_id;


-- ═════════════════════════════════════════════════════════════
-- BLOCO C: painel resumo dos erros (uma linha por verificação)
-- Bom para abrir a reunião: o cliente vê de uma vez o tamanho de cada problema.
-- ═════════════════════════════════════════════════════════════
SELECT 'E01 venda de produto não cadastrado' AS verificacao, COUNT(*) AS ocorrencias
  FROM venda v WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.produto_id = v.produto_id)
UNION ALL SELECT 'E02 venda em filial sem cadastro', COUNT(*)
  FROM venda WHERE filial_id NOT IN (SELECT DISTINCT filial_id FROM produtos_filial)
UNION ALL SELECT 'E03 qtde fracionada em UN', COUNT(*)
  FROM venda WHERE unidade_medida = 'UN' AND qtde_vendida <> FLOOR(qtde_vendida)
UNION ALL SELECT 'E04 preço da venda <> cadastro', COUNT(*)
  FROM venda v JOIN produtos_filial p ON p.produto_id = v.produto_id AND p.filial_id = v.filial_id
 WHERE v.valor_unitario <> p.preco_venda
UNION ALL SELECT 'E05 preço repetido entre produtos (grupos)', COUNT(*)
  FROM (SELECT valor_unitario FROM venda GROUP BY valor_unitario HAVING COUNT(DISTINCT produto_id) > 1) x
UNION ALL SELECT 'E06 pedido sem ordem de compra', COUNT(*)
  FROM pedido_compra WHERE ordem_compra = 0
UNION ALL SELECT 'E07 pedido duplicado', COUNT(*)
  FROM pedido_compra a JOIN pedido_compra b
    ON b.produto_id = a.produto_id AND b.data_pedido = a.data_pedido
   AND b.data_entrega = a.data_entrega AND b.pedido_id > a.pedido_id
UNION ALL SELECT 'E08 entrega antes do pedido', COUNT(*)
  FROM pedido_compra WHERE data_entrega < data_pedido
UNION ALL SELECT 'E09 data de entrega com qtde entregue 0', COUNT(*)
  FROM pedido_compra WHERE data_entrega IS NOT NULL AND qtde_entregue = 0
UNION ALL SELECT 'E10 entregue no pedido <> recebido na NF', COUNT(*)
  FROM pedido_compra pc JOIN entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
 WHERE pc.qtde_entregue <> em.qtde_recebida
UNION ALL SELECT 'E11 recebeu mais do que pediu', COUNT(*)
  FROM pedido_compra pc JOIN entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
 WHERE em.qtde_recebida > pc.qtde_pedida
UNION ALL SELECT 'E12 entrada antes do pedido', COUNT(*)
  FROM pedido_compra pc JOIN entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
 WHERE em.data_entrada < pc.data_pedido
UNION ALL SELECT 'E13 entrada sem pedido (órfã)', COUNT(*)
  FROM entradas_mercadoria em WHERE NOT EXISTS (SELECT 1 FROM pedido_compra pc
   WHERE pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id)
UNION ALL SELECT 'E14 data NF <> data entrega do pedido', COUNT(*)
  FROM pedido_compra pc JOIN entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
 WHERE pc.data_entrega <> em.data_entrada
UNION ALL SELECT 'E15 custo NF difere >20% do pedido', COUNT(*)
  FROM pedido_compra pc JOIN entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
 WHERE ABS(em.custo_unitario - pc.preco_compra) > 0.2 * pc.preco_compra
UNION ALL SELECT 'E16 fornecedor pedido <> cadastro', COUNT(*)
  FROM pedido_compra pc JOIN produtos_filial p ON p.produto_id = pc.produto_id AND p.filial_id = pc.filial_id
 WHERE pc.fornecedor_id <> p.idfornecedor
UNION ALL SELECT 'E17 preço de compra > preço de venda', COUNT(*)
  FROM produtos_filial WHERE preco_compra > preco_venda;
