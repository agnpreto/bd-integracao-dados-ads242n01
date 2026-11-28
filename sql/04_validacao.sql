-- 04_validacao
-- Nome:
-- Consultas de apoio ao roteiro de validação (docs/parte4_validacao.md).
-- Rodam no MySQL e no PostgreSQL. Rode depois de 01, carga e 03 (a consulta
-- E10 usa a coluna idfornecedor_num criada pela trigger da Parte 3).

USE integracao_dados;

-- ═════════════════════════════════════════════════════════════
-- A. CONSULTAS PARA A REUNIÃO (fevereiro/2025)
-- ═════════════════════════════════════════════════════════════

-- A1. Conferência de volume: linhas no banco x linhas na planilha
--     (planilha: fornecedor 20, produtos_filial 20, pedido_compra 29,
--      entradas_mercadoria 20, venda 33)
SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas FROM fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*) FROM produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*) FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*) FROM venda;

-- A2. Resumo do mês: o cliente compara com o fechamento dele
SELECT 'Vendas'   AS movimento, COUNT(*) AS linhas,
       SUM(qtde_vendida) AS quantidade,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
  FROM venda
 WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
UNION ALL
SELECT 'Pedidos de compra', COUNT(*), SUM(qtde_pedida),
       ROUND(SUM(qtde_pedida * preco_compra), 2)
  FROM pedido_compra
 WHERE data_pedido >= '2025-02-01' AND data_pedido < '2025-03-01'
UNION ALL
SELECT 'Entradas de mercadoria', COUNT(*), SUM(qtde_recebida),
       ROUND(SUM(qtde_recebida * custo_unitario), 2)
  FROM entradas_mercadoria
 WHERE data_entrada >= '2025-02-01' AND data_entrada < '2025-03-01';

-- A3. Vendas por dia em fevereiro (cliente confere com o caixa de cada dia)
SELECT data_emissao,
       COUNT(*) AS linhas,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
  FROM venda
 WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
 GROUP BY data_emissao
 ORDER BY data_emissao;

-- A4. Vendas por filial em fevereiro
SELECT filial_id,
       COUNT(*) AS linhas,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
  FROM venda
 WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
 GROUP BY filial_id
 ORDER BY filial_id;

-- A5. Amostragem: 5 vendas de fevereiro para o cliente achar no sistema dele
--     (conferência linha a linha, com a nota/cupom em mãos)
SELECT venda_id, data_emissao, produto_id, qtde_vendida, valor_unitario,
       ROUND(qtde_vendida * valor_unitario, 2) AS total_linha
  FROM venda
 WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
 ORDER BY qtde_vendida * valor_unitario DESC
 LIMIT 5;

-- A6. Pedido x entrada de fevereiro: o que foi pedido, o que chegou e a diferença
SELECT pc.pedido_id, pc.produto_id, pc.ordem_compra, pc.data_pedido,
       pc.qtde_pedida, pc.qtde_entregue AS entregue_no_pedido,
       COALESCE(SUM(em.qtde_recebida), 0) AS recebido_nas_entradas
  FROM pedido_compra pc
  LEFT JOIN entradas_mercadoria em
         ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
 WHERE pc.data_pedido >= '2025-02-01' AND pc.data_pedido < '2025-03-01'
 GROUP BY pc.pedido_id, pc.produto_id, pc.ordem_compra, pc.data_pedido,
          pc.qtde_pedida, pc.qtde_entregue
 ORDER BY pc.pedido_id;


-- ═════════════════════════════════════════════════════════════
-- B. ERROS ENCONTRADOS NOS DADOS (uma consulta para cada um)
--    A quantidade de cada erro está em docs/parte4_validacao.md.
-- ═════════════════════════════════════════════════════════════

-- E1. Vendas de produtos que não existem no cadastro (produtos_filial)
SELECT v.*
  FROM venda v
 WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.produto_id = v.produto_id)
 ORDER BY v.produto_id;

-- E2. Vendas de filiais sem nenhum produto cadastrado
SELECT v.*
  FROM venda v
 WHERE v.filial_id NOT IN (SELECT DISTINCT filial_id FROM produtos_filial)
 ORDER BY v.filial_id;

-- E3. Quantidade fracionada em produto vendido por unidade (UN)
SELECT venda_id, produto_id, qtde_vendida, unidade_medida
  FROM venda
 WHERE unidade_medida = 'UN'
   AND qtde_vendida <> ROUND(qtde_vendida, 0);

-- E4. Preço da venda diferente do preço de venda do cadastro
SELECT v.venda_id, v.produto_id, v.valor_unitario AS preco_na_venda,
       p.preco_venda AS preco_no_cadastro
  FROM venda v
  JOIN produtos_filial p ON p.produto_id = v.produto_id AND p.filial_id = v.filial_id
 WHERE v.valor_unitario <> p.preco_venda
 ORDER BY v.produto_id;

-- E5. Mesmo preço unitário em produtos diferentes (indício de cópia de linhas)
SELECT v1.produto_id AS produto, v2.produto_id AS mesmo_preco_que,
       v1.valor_unitario
  FROM venda v1
  JOIN venda v2 ON v2.valor_unitario = v1.valor_unitario
               AND v2.produto_id < v1.produto_id
 GROUP BY v1.produto_id, v2.produto_id, v1.valor_unitario
 ORDER BY v1.valor_unitario;

-- E6. Pedidos sem ordem de compra (ordem_compra = 0): não ligam com nenhuma entrada
SELECT pedido_id, produto_id, data_pedido, qtde_pedida, ordem_compra
  FROM pedido_compra
 WHERE ordem_compra = 0
 ORDER BY pedido_id;

-- E7. Data de entrega anterior à data do pedido
SELECT pedido_id, produto_id, data_pedido, data_entrega
  FROM pedido_compra
 WHERE data_entrega < data_pedido
 ORDER BY pedido_id;

-- E8. Pedido com data de entrega preenchida, mas nada entregue
SELECT pedido_id, produto_id, data_entrega, qtde_entregue
  FROM pedido_compra
 WHERE data_entrega IS NOT NULL AND qtde_entregue = 0
 ORDER BY pedido_id;

-- E9. Mesmo produto pedido duas vezes no mesmo dia (pedidos 21 a 29 repetem
--     os pedidos 12 a 20, com outra quantidade e sem ordem de compra)
SELECT a.produto_id, a.data_pedido,
       a.pedido_id AS pedido_1, a.qtde_pedida AS qtde_1,
       b.pedido_id AS pedido_2, b.qtde_pedida AS qtde_2
  FROM pedido_compra a
  JOIN pedido_compra b ON b.produto_id = a.produto_id
                      AND b.data_pedido = a.data_pedido
                      AND b.pedido_id > a.pedido_id
 ORDER BY a.produto_id;

-- E10. Fornecedor do pedido diferente do fornecedor do produto no cadastro
SELECT pc.pedido_id, pc.produto_id,
       pc.fornecedor_id     AS fornecedor_no_pedido,
       p.idfornecedor       AS fornecedor_no_cadastro,
       p.idfornecedor_num   AS numero_no_cadastro
  FROM pedido_compra pc
  JOIN produtos_filial p ON p.produto_id = pc.produto_id AND p.filial_id = pc.filial_id
 WHERE pc.fornecedor_id <> p.idfornecedor_num
 ORDER BY pc.pedido_id;

-- E11. Quantidade entregue no pedido diferente da recebida nas entradas
SELECT pc.pedido_id, pc.produto_id, pc.ordem_compra,
       pc.qtde_entregue AS entregue_no_pedido,
       SUM(em.qtde_recebida) AS recebido_nas_entradas
  FROM pedido_compra pc
  JOIN entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
 GROUP BY pc.pedido_id, pc.produto_id, pc.ordem_compra, pc.qtde_entregue
HAVING SUM(em.qtde_recebida) <> pc.qtde_entregue
 ORDER BY pc.pedido_id;

-- E12. Recebido mais do que foi pedido
SELECT pc.pedido_id, pc.produto_id, pc.qtde_pedida,
       SUM(em.qtde_recebida) AS qtde_recebida
  FROM pedido_compra pc
  JOIN entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
 GROUP BY pc.pedido_id, pc.produto_id, pc.qtde_pedida
HAVING SUM(em.qtde_recebida) > pc.qtde_pedida
 ORDER BY pc.pedido_id;

-- E13. Mercadoria que entrou ANTES de ser pedida
SELECT em.nro_nfe, em.produto_id, em.ordem_compra,
       pc.data_pedido, em.data_entrada
  FROM entradas_mercadoria em
  JOIN pedido_compra pc
    ON pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id
 WHERE em.data_entrada < pc.data_pedido
 ORDER BY em.ordem_compra;

-- E14. Custo na entrada diferente do preço combinado no pedido
SELECT em.nro_nfe, em.produto_id, pc.preco_compra AS preco_no_pedido,
       em.custo_unitario AS custo_na_entrada
  FROM entradas_mercadoria em
  JOIN pedido_compra pc
    ON pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id
 WHERE em.custo_unitario <> pc.preco_compra
 ORDER BY em.ordem_compra;

-- E15. Entradas sem pedido de compra correspondente
SELECT em.*
  FROM entradas_mercadoria em
 WHERE NOT EXISTS (SELECT 1 FROM pedido_compra pc
                    WHERE pc.ordem_compra = em.ordem_compra
                      AND pc.produto_id   = em.produto_id);

-- E16. Produto com preço de compra maior que o preço de venda (venda com prejuízo)
SELECT produto_id, descricao, preco_compra, preco_venda,
       preco_venda - preco_compra AS margem
  FROM produtos_filial
 WHERE preco_compra > preco_venda
 ORDER BY margem;

-- E17. Três preços diferentes para o mesmo produto: cadastro (preco_compra),
--      pedido (preco_compra) e nota fiscal (custo_unitario)
SELECT p.produto_id,
       p.preco_compra       AS compra_no_cadastro,
       pc.preco_compra      AS compra_no_pedido,
       em.custo_unitario    AS custo_na_nota
  FROM produtos_filial p
  JOIN pedido_compra pc ON pc.produto_id = p.produto_id AND pc.ordem_compra <> 0
  JOIN entradas_mercadoria em
    ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
 WHERE p.preco_compra <> pc.preco_compra
    OR pc.preco_compra <> em.custo_unitario
 ORDER BY p.produto_id;
