-- 04_validacao
-- Nome: Matheus Nogueira
--
-- Parte 4: consultas que levo prontas para a reuniao de validacao de
-- fevereiro/2025. O roteiro que usa estas consultas esta em
-- docs/parte4_validacao.md.
--
-- Escrito para PostgreSQL. Todas as consultas sao somente leitura: nenhum dado
-- e corrigido aqui, porque cada divergencia precisa do aval do cliente.
--
-- Organizacao:
--   Bloco A (V01-V04)  reconciliacao: o banco bate com a planilha?
--   Bloco B (V05-V14)  erros nos dados, um por consulta (E01-E10)
--   Bloco C (V15-V17)  checagens que devem voltar zero e pontos a confirmar
--   Bloco D (V18)      pendencias de fevereiro para discutir linha a linha
-- O "esperado" de cada consulta foi conferido na base carregada.


-- ###########################################################################
-- BLOCO A - RECONCILIACAO
-- ###########################################################################

-- [V01] Linhas por tabela x linhas por aba da planilha.
-- Esperado: fornecedor 20, produtos_filial 20, pedido_compra 29,
--           entradas_mercadoria 20, venda 33.
SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas_banco, 20 AS linhas_planilha FROM public.fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*), 20 FROM public.produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*), 29 FROM public.pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*), 20 FROM public.entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*), 33 FROM public.venda;

-- [V02] Numeros-chave de fevereiro/2025 (comparar com o relatorio do cliente).
-- Esperado: 14 linhas de venda, 14 produtos, 173,22 unidades, R$ 14.093,17.
SELECT COUNT(*)                                                   AS linhas_venda,
       COUNT(DISTINCT produto_id)                                 AS produtos,
       COUNT(DISTINCT filial_id)                                  AS filiais,
       SUM(qtde_vendida)                                          AS qtde_vendida,
       CAST(SUM(qtde_vendida * valor_unitario) AS DECIMAL(14, 2)) AS valor_rs
FROM public.venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao <  DATE '2025-03-01';

-- [V03] Vendas por mes: mostra o corte de fevereiro dentro da base.
-- Esperado: jan 12 linhas / fev 14 / mar 7.
SELECT TO_CHAR(data_emissao, 'YYYY-MM')                           AS mes,
       COUNT(*)                                                   AS linhas_venda,
       SUM(qtde_vendida)                                          AS qtde_vendida,
       CAST(SUM(qtde_vendida * valor_unitario) AS DECIMAL(14, 2)) AS valor_rs
FROM public.venda
GROUP BY TO_CHAR(data_emissao, 'YYYY-MM')
ORDER BY mes;

-- [V04] Fevereiro por filial e produto, com a descricao do cadastro.
-- E a lista que o cliente confere item a item contra o sistema dele.
SELECT v.filial_id,
       v.produto_id || COALESCE(' - ' || c.descricao, ' (sem cadastro)') AS produto,
       COUNT(*)                                                   AS linhas,
       SUM(v.qtde_vendida)                                        AS qtde_vendida,
       CAST(SUM(v.qtde_vendida * v.valor_unitario) AS DECIMAL(14, 2)) AS valor_rs
FROM public.venda v
LEFT JOIN (
    SELECT produto_id, MAX(descricao) AS descricao
    FROM public.produtos_filial
    GROUP BY produto_id
) c ON c.produto_id = v.produto_id
WHERE v.data_emissao >= DATE '2025-02-01'
  AND v.data_emissao <  DATE '2025-03-01'
GROUP BY v.filial_id, v.produto_id, c.descricao
ORDER BY v.filial_id, v.produto_id;


-- ###########################################################################
-- BLOCO B - ERROS NOS DADOS
-- ###########################################################################

-- [V05] E01 - Vendas de produtos que nao existem no cadastro.
-- Esperado: 8 produtos (P21..P28) em 13 linhas; 6 linhas em fevereiro.
SELECT v.produto_id,
       COUNT(*)                                                           AS linhas_venda,
       COUNT(*) FILTER (WHERE v.data_emissao >= DATE '2025-02-01'
                          AND v.data_emissao <  DATE '2025-03-01')       AS linhas_fevereiro,
       SUM(v.qtde_vendida)                                                AS qtde_vendida,
       CAST(SUM(v.qtde_vendida * v.valor_unitario) AS DECIMAL(14, 2))     AS valor_rs
FROM public.venda v
WHERE NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.produto_id = v.produto_id)
GROUP BY v.produto_id
ORDER BY v.produto_id;

-- [V06] E02 - Vendas em filial onde o produto nao esta cadastrado.
-- O cadastro so tem a filial 1; as vendas das filiais 2 e 3 ficam sem cadastro.
-- Esperado: 4 linhas (P27 na filial 2, P28 na filial 3).
SELECT v.venda_id, v.filial_id, v.produto_id, v.data_emissao, v.qtde_vendida
FROM public.venda v
WHERE NOT EXISTS (
    SELECT 1 FROM public.produtos_filial p
    WHERE p.produto_id = v.produto_id
      AND p.filial_id  = v.filial_id
)
  AND v.filial_id <> 1
ORDER BY v.filial_id, v.venda_id;

SELECT filial_id, COUNT(*) AS produtos_cadastrados   -- so aparece a filial 1
FROM public.produtos_filial
GROUP BY filial_id;

-- [V07] E03 - Quantidade fracionada vendida em unidade 'UN'.
-- Esperado: 5 linhas (vendas 4, 8, 12, 16 e 26); 2 em fevereiro (16 e 26).
SELECT venda_id, data_emissao, produto_id, qtde_vendida, unidade_medida
FROM public.venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida <> TRUNC(qtde_vendida)
ORDER BY venda_id;

-- [V08] E04 - Pedido entregue antes de ser feito (data_entrega < data_pedido).
-- Esperado: 20 de 29 pedidos.
SELECT pedido_id, produto_id, data_pedido, data_entrega,
       data_entrega - data_pedido AS dias
FROM public.pedido_compra
WHERE data_entrega < data_pedido
ORDER BY dias, pedido_id;

-- [V09] E05 - Entrada de mercadoria cuja ordem_compra nao existe em pedido_compra.
-- Esperado: NFE19 (ordem 19, P19) e NFE20 (ordem 20, P20). Repare que os
-- pedidos 19 e 20, dos mesmos produtos, estao com ordem_compra = 0 (V10).
SELECT em.nro_nfe, em.ordem_compra, em.produto_id, em.data_entrada, em.qtde_recebida,
       (SELECT STRING_AGG(pc.pedido_id || ' (ordem ' || pc.ordem_compra || ')', ', ')
        FROM public.pedido_compra pc
        WHERE pc.produto_id = em.produto_id)          AS pedidos_do_mesmo_produto
FROM public.entradas_mercadoria em
WHERE NOT EXISTS (SELECT 1 FROM public.pedido_compra pc WHERE pc.ordem_compra = em.ordem_compra)
ORDER BY em.ordem_compra;

-- [V10] E06 - Pedidos com ordem_compra = 0: nao casam com nenhuma entrada.
-- Esperado: 11 pedidos (19 a 29). Sao exatamente os pedidos sem entrada.
SELECT pc.pedido_id, pc.item, pc.produto_id, pc.data_pedido, pc.qtde_pedida,
       EXISTS (SELECT 1 FROM public.entradas_mercadoria em
               WHERE em.ordem_compra = pc.ordem_compra
                 AND em.item         = pc.item
                 AND em.produto_id   = pc.produto_id) AS tem_entrada
FROM public.pedido_compra pc
WHERE pc.ordem_compra = 0
ORDER BY pc.pedido_id;

-- Com a ordem 0, a chave de ligacao (ordem_compra, item, produto_id) se repete.
-- Esperado: (0, 1, P19) e (0, 1, P20), 2 vezes cada.
SELECT ordem_compra, item, produto_id, COUNT(*) AS vezes
FROM public.pedido_compra
GROUP BY ordem_compra, item, produto_id
HAVING COUNT(*) > 1;

-- Conferencia: pedidos sem nenhuma entrada, qualquer que seja a ordem.
-- Esperado: os mesmos 11 pedidos.
SELECT COUNT(*) AS pedidos_sem_entrada
FROM public.pedido_compra pc
WHERE NOT EXISTS (SELECT 1 FROM public.entradas_mercadoria em
                  WHERE em.ordem_compra = pc.ordem_compra
                    AND em.item         = pc.item
                    AND em.produto_id   = pc.produto_id);

-- [V11] E07 - Pedidos que parecem lancamento duplicado.
-- Os pedidos 21..29 repetem produto, data do pedido, data de entrega, preco e
-- fornecedor dos pedidos 12..20, so com quantidade menor e ordem 0.
-- Esperado: 9 pares.
SELECT o.pedido_id   AS pedido_original,
       d.pedido_id   AS pedido_repetido,
       o.produto_id,
       o.data_pedido,
       o.qtde_pedida AS qtde_original,
       d.qtde_pedida AS qtde_repetida,
       o.ordem_compra AS ordem_original,
       d.ordem_compra AS ordem_repetida
FROM public.pedido_compra o
JOIN public.pedido_compra d
  ON d.produto_id    = o.produto_id
 AND d.data_pedido   = o.data_pedido
 AND d.data_entrega IS NOT DISTINCT FROM o.data_entrega
 AND d.preco_compra  = o.preco_compra
 AND d.fornecedor_id = o.fornecedor_id
 AND d.pedido_id     > o.pedido_id
ORDER BY o.pedido_id;

-- Base comum de V12 e V13: total recebido por ordem/item/produto.
-- [V12] E08 - qtde_entregue do pedido diferente da soma das notas de entrada.
-- Esperado: 18 pedidos (desconsiderando os de ordem 0, ja tratados em V10).
WITH recebido AS (
    SELECT ordem_compra, item, produto_id, SUM(qtde_recebida) AS qtde_recebida
    FROM public.entradas_mercadoria
    GROUP BY ordem_compra, item, produto_id
)
SELECT pc.pedido_id, pc.ordem_compra, pc.produto_id,
       pc.qtde_pedida,
       pc.qtde_entregue                                 AS entregue_no_pedido,
       COALESCE(r.qtde_recebida, 0)                     AS recebido_nas_notas,
       pc.qtde_entregue - COALESCE(r.qtde_recebida, 0)  AS diferenca
FROM public.pedido_compra pc
LEFT JOIN recebido r
       ON r.ordem_compra = pc.ordem_compra
      AND r.item         = pc.item
      AND r.produto_id   = pc.produto_id
WHERE pc.ordem_compra <> 0
  AND pc.qtde_entregue IS DISTINCT FROM COALESCE(r.qtde_recebida, 0)
ORDER BY ABS(pc.qtde_entregue - COALESCE(r.qtde_recebida, 0)) DESC;

-- [V13] E09 - Recebido mais do que foi pedido.
-- Esperado: 7 pedidos.
WITH recebido AS (
    SELECT ordem_compra, item, produto_id, SUM(qtde_recebida) AS qtde_recebida
    FROM public.entradas_mercadoria
    GROUP BY ordem_compra, item, produto_id
)
SELECT pc.pedido_id, pc.ordem_compra, pc.produto_id,
       pc.qtde_pedida,
       r.qtde_recebida,
       r.qtde_recebida - pc.qtde_pedida AS excesso
FROM public.pedido_compra pc
JOIN recebido r
  ON r.ordem_compra = pc.ordem_compra
 AND r.item         = pc.item
 AND r.produto_id   = pc.produto_id
WHERE r.qtde_recebida > pc.qtde_pedida
ORDER BY excesso DESC;

-- [V14] E10 - Mercadoria recebida antes de o pedido existir.
-- Esperado: 9 entradas.
SELECT em.nro_nfe, pc.pedido_id, pc.produto_id,
       pc.data_pedido, em.data_entrada,
       em.data_entrada - pc.data_pedido AS dias
FROM public.entradas_mercadoria em
JOIN public.pedido_compra pc
  ON pc.ordem_compra = em.ordem_compra
 AND pc.item         = em.item
 AND pc.produto_id   = em.produto_id
WHERE em.data_entrada < pc.data_pedido
ORDER BY dias;

-- E11 (bloco de celulas sem cabecalho nas colunas M..W da aba pedido_compra)
-- nao tem consulta: os valores nao sao carregados no banco. Ele aparece como
-- aviso na saida do scripts/importar.py. Ver docs/parte4_validacao.md.


-- ###########################################################################
-- BLOCO C - CHECAGENS DE QUALIDADE E PONTOS A CONFIRMAR
-- ###########################################################################

-- [V15] Checagens que devem voltar 0. Se alguma vier > 0, a carga tem problema.
SELECT 'venda sem data'                       AS checagem, COUNT(*) AS ocorrencias FROM public.venda WHERE data_emissao IS NULL
UNION ALL SELECT 'venda com qtde nula ou <= 0',          COUNT(*) FROM public.venda WHERE qtde_vendida IS NULL OR qtde_vendida <= 0
UNION ALL SELECT 'venda com valor unitario <= 0',        COUNT(*) FROM public.venda WHERE valor_unitario <= 0
UNION ALL SELECT 'pedido sem data',                      COUNT(*) FROM public.pedido_compra WHERE data_pedido IS NULL
UNION ALL SELECT 'pedido com qtde nula ou <= 0',         COUNT(*) FROM public.pedido_compra WHERE qtde_pedida IS NULL OR qtde_pedida <= 0
UNION ALL SELECT 'pedido com fornecedor inexistente',    COUNT(*) FROM public.pedido_compra pc
          WHERE NOT EXISTS (SELECT 1 FROM public.fornecedor f WHERE f.idfornecedor = pc.fornecedor_id)
UNION ALL SELECT 'produto sem fornecedor',               COUNT(*) FROM public.produtos_filial WHERE idfornecedor IS NULL
UNION ALL SELECT 'entrada sem data',                     COUNT(*) FROM public.entradas_mercadoria WHERE data_entrada IS NULL
UNION ALL SELECT 'entrada de produto sem cadastro',      COUNT(*) FROM public.entradas_mercadoria em
          WHERE NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.produto_id = em.produto_id)
UNION ALL SELECT 'qtde_pendente <> pedida - entregue',   COUNT(*) FROM public.pedido_compra
          WHERE qtde_pendente <> qtde_pedida - qtde_entregue;

-- [V16] Produtos com preco de venda abaixo do preco de compra do cadastro.
-- Nao classifiquei como erro (pode ser promocao/queima de estoque), mas
-- precisa ser confirmado. Esperado: 4 produtos (P1, P8, P15, P18).
SELECT filial_id, produto_id, descricao, preco_compra, preco_venda,
       preco_venda - preco_compra AS margem
FROM public.produtos_filial
WHERE preco_venda < preco_compra
ORDER BY margem;

-- [V17] Fornecedor e custo: pedido x cadastro x nota.
-- Pontos a confirmar, nao erros: um produto pode ter mais de um fornecedor e
-- o custo do cadastro pode ser medio. Esperado nesta base: 22 pedidos com
-- fornecedor diferente do cadastro e 20 notas com custo diferente do cadastro.
SELECT pc.pedido_id, pc.produto_id,
       pc.fornecedor_id AS fornecedor_pedido,
       p.idfornecedor   AS fornecedor_cadastro
FROM public.pedido_compra pc
JOIN public.produtos_filial p ON p.produto_id = pc.produto_id AND p.filial_id = pc.filial_id
WHERE pc.fornecedor_id <> p.idfornecedor
ORDER BY pc.pedido_id;

SELECT em.nro_nfe, em.produto_id,
       em.custo_unitario AS custo_nota,
       p.preco_compra    AS preco_compra_cadastro
FROM public.entradas_mercadoria em
JOIN public.produtos_filial p ON p.produto_id = em.produto_id AND p.filial_id = em.filial_id
WHERE em.custo_unitario <> CAST(p.preco_compra AS numeric(12, 4))
ORDER BY em.nro_nfe;


-- ###########################################################################
-- BLOCO D - PENDENCIAS DE FEVEREIRO
-- ###########################################################################

-- [V18] Pedidos feitos em fevereiro/2025 com saldo a receber.
-- Esperado: 14 linhas.
WITH recebido AS (
    SELECT ordem_compra, item, produto_id, SUM(qtde_recebida) AS qtde_recebida
    FROM public.entradas_mercadoria
    GROUP BY ordem_compra, item, produto_id
)
SELECT pc.pedido_id,
       TO_CHAR(pc.data_pedido, 'DD/MM/YYYY')         AS data_pedido,
       pc.ordem_compra,
       pc.produto_id,
       pc.qtde_pedida,
       COALESCE(r.qtde_recebida, 0)                  AS qtde_recebida,
       pc.qtde_pedida - COALESCE(r.qtde_recebida, 0) AS saldo
FROM public.pedido_compra pc
LEFT JOIN recebido r
       ON r.ordem_compra = pc.ordem_compra
      AND r.item         = pc.item
      AND r.produto_id   = pc.produto_id
WHERE pc.data_pedido >= DATE '2025-02-01'
  AND pc.data_pedido <  DATE '2025-03-01'
  AND pc.qtde_pedida > COALESCE(r.qtde_recebida, 0)
ORDER BY pc.data_pedido, pc.pedido_id;
