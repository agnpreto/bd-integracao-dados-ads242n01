-- 04_validacao
-- Nome: João Gustavo Gonçalves Vasconcelos  | Matrícula: 2408298 | GitHub: SukitaAM
-- Consultas prontas para a reunião de validação dos dados de FEVEREIRO/2025 (PostgreSQL 16).
-- Cada bloco "Vn" tem o mesmo número na tabela de docs/parte4_validacao.md.

-- ===================================================================================
-- A) CONFERÊNCIAS GERAIS (mostram ao cliente que nada se perdeu na carga)
-- ===================================================================================

-- A1. Linhas por tabela (comparar com a planilha: 20 / 20 / 29 / 20 / 33)
SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas FROM public.fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*) FROM public.produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*) FROM public.pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM public.entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*) FROM public.venda;

-- A2. Totais de fevereiro/2025 para o cliente conferir com o sistema de origem:
--     nº de vendas, quantidade, valor, menor e maior data
SELECT  COUNT(*)                                  AS qtd_linhas_venda,
        SUM(qtde_vendida)                         AS qtde_total,
        SUM(qtde_vendida * valor_unitario)        AS valor_total_rs,
        MIN(data_emissao)                         AS primeira_data,
        MAX(data_emissao)                         AS ultima_data
FROM    public.venda
WHERE   data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01';

-- A3. Vendas por mês presentes na base (a base não é só de fevereiro)
SELECT  TO_CHAR(data_emissao, 'YYYY-MM') AS mes, COUNT(*) AS linhas, SUM(qtde_vendida * valor_unitario) AS valor_rs
FROM    public.venda
GROUP BY 1 ORDER BY 1;

-- A4. Chaves duplicadas (esperado: 0 linhas em cada)
SELECT 'venda' AS tabela, venda_id::text AS chave, COUNT(*) FROM public.venda GROUP BY venda_id HAVING COUNT(*) > 1
UNION ALL
SELECT 'pedido_compra', pedido_id::text, COUNT(*) FROM public.pedido_compra GROUP BY pedido_id HAVING COUNT(*) > 1
UNION ALL
SELECT 'entradas_mercadoria', nro_nfe, COUNT(*) FROM public.entradas_mercadoria GROUP BY nro_nfe HAVING COUNT(*) > 1;

-- A5. Campos obrigatórios vazios (esperado: tudo 0)
SELECT  COUNT(*) FILTER (WHERE qtde_vendida IS NULL)        AS venda_sem_qtde,
        COUNT(*) FILTER (WHERE valor_unitario <= 0)         AS venda_valor_zero_ou_neg,
        COUNT(*) FILTER (WHERE qtde_vendida <= 0)           AS venda_qtde_zero_ou_neg
FROM    public.venda;

-- ===================================================================================
-- B) ERROS ENCONTRADOS NOS DADOS (uma consulta por erro, V1 a V17)
-- ===================================================================================

-- V1. Vendas de produtos que NÃO existem no cadastro (P21 a P28) -> 13 linhas
SELECT  v.venda_id, v.data_emissao, v.produto_id, v.filial_id, v.qtde_vendida, v.valor_unitario
FROM    public.venda v
WHERE   NOT EXISTS (SELECT 1 FROM public.produtos_filial p
                    WHERE p.produto_id = v.produto_id AND p.filial_id = v.filial_id)
ORDER BY v.venda_id;

-- V2. Vendas em filiais (2 e 3) que não têm nenhum produto cadastrado -> 4 linhas
SELECT  v.venda_id, v.filial_id, v.produto_id, v.data_emissao
FROM    public.venda v
WHERE NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.filial_id = v.filial_id)
ORDER BY v.venda_id;

-- V3. Quantidade fracionada em unidade "UN" (não existe 2,86 unidade) -> 5 linhas
SELECT  venda_id, produto_id, qtde_vendida, unidade_medida
FROM    public.venda
WHERE   unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida)
ORDER BY venda_id;

-- V4. Preço de venda idêntico em produtos diferentes (valores copiados, ex.: P13 = P21 = 61,85) -> 21 linhas
SELECT  v.valor_unitario, STRING_AGG(DISTINCT v.produto_id, ', ' ORDER BY v.produto_id) AS produtos
FROM    public.venda v
GROUP BY v.valor_unitario
HAVING  COUNT(DISTINCT v.produto_id) > 1
ORDER BY v.valor_unitario;

-- V5. Valor unitário vendido diferente do preço de venda do cadastro -> 20 de 20 produtos cadastrados
SELECT  v.venda_id, v.produto_id, v.valor_unitario AS valor_vendido, p.preco_venda AS preco_cadastro
FROM    public.venda v
JOIN    public.produtos_filial p ON p.produto_id = v.produto_id AND p.filial_id = v.filial_id
WHERE   v.valor_unitario <> p.preco_venda
ORDER BY v.venda_id;

-- V6. Horário igual para todas as vendas (08:00:00 = valor padrão, não é horário real) -> 33 linhas
SELECT  horariomov, COUNT(*) AS linhas
FROM    public.venda
GROUP BY horariomov;

-- V7. Pedido com data de entrega ANTERIOR à data do pedido -> 20 linhas
SELECT  pedido_id, produto_id, data_pedido, data_entrega, (data_entrega - data_pedido) AS dias
FROM    public.pedido_compra
WHERE   data_entrega < data_pedido
ORDER BY pedido_id;

-- V8. Pedido com ordem_compra = 0 (sem vínculo possível com entrada) -> 11 linhas (pedidos 19 a 29)
SELECT  pedido_id, produto_id, ordem_compra, qtde_pedida
FROM    public.pedido_compra
WHERE   ordem_compra = 0
ORDER BY pedido_id;

-- V9. Pedidos repetidos para o mesmo produto/filial/item (pedidos 21 a 29 copiam P12 a P20) -> 9 linhas
SELECT  p.pedido_id, p.produto_id, p.data_pedido, p.data_entrega, p.preco_compra,
        (SELECT MIN(o.pedido_id) FROM public.pedido_compra o
         WHERE o.produto_id = p.produto_id AND o.filial_id = p.filial_id AND o.item = p.item) AS pedido_original
FROM    public.pedido_compra p
WHERE   EXISTS (SELECT 1 FROM public.pedido_compra o
                WHERE o.produto_id = p.produto_id AND o.filial_id = p.filial_id
                  AND o.item = p.item AND o.pedido_id < p.pedido_id)
ORDER BY p.pedido_id;

-- V10. Quantidade entregue no pedido diferente do total recebido nas entradas (mesma ordem) -> 18 linhas
SELECT  p.pedido_id, p.ordem_compra, p.produto_id, p.qtde_entregue AS entregue_no_pedido,
        COALESCE(SUM(e.qtde_recebida), 0) AS recebido_nas_entradas
FROM    public.pedido_compra p
LEFT JOIN public.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE   p.ordem_compra <> 0
GROUP BY p.pedido_id, p.ordem_compra, p.produto_id, p.qtde_entregue
HAVING  p.qtde_entregue <> COALESCE(SUM(e.qtde_recebida), 0)
ORDER BY p.pedido_id;

-- V11. Fornecedor do pedido diferente do fornecedor do cadastro do produto -> 22 linhas
SELECT  p.pedido_id, p.produto_id, p.fornecedor_id AS fornecedor_no_pedido, f.idfornecedor AS fornecedor_no_cadastro
FROM    public.pedido_compra p
JOIN    public.produtos_filial f ON f.produto_id = p.produto_id AND f.filial_id = p.filial_id
WHERE   p.fornecedor_id <> f.idfornecedor
ORDER BY p.pedido_id;

-- V12. Entradas sem pedido correspondente pela ordem_compra (NFE19 e NFE20) -> 2 linhas
SELECT  e.nro_nfe, e.ordem_compra, e.produto_id, e.qtde_recebida, e.data_entrada
FROM    public.entradas_mercadoria e
WHERE   NOT EXISTS (SELECT 1 FROM public.pedido_compra p
                    WHERE p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id)
ORDER BY e.nro_nfe;

-- V13. Mercadoria recebida ANTES de o pedido ser feito -> 9 linhas
SELECT  e.nro_nfe, e.produto_id, p.data_pedido, e.data_entrada, (e.data_entrada - p.data_pedido) AS dias
FROM    public.entradas_mercadoria e
JOIN    public.pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE   e.data_entrada < p.data_pedido
ORDER BY e.nro_nfe;

-- V14. Recebido MAIOR que o pedido (entrada acima da quantidade pedida) -> 7 linhas
SELECT  e.nro_nfe, e.produto_id, p.qtde_pedida, e.qtde_recebida
FROM    public.entradas_mercadoria e
JOIN    public.pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE   e.qtde_recebida > p.qtde_pedida
ORDER BY e.nro_nfe;

-- V15. Custo da nota diferente do preço combinado no pedido -> 18 linhas
SELECT  e.nro_nfe, e.produto_id, p.preco_compra AS preco_pedido, e.custo_unitario AS custo_nota,
        ROUND(e.custo_unitario - p.preco_compra, 2) AS diferenca
FROM    public.entradas_mercadoria e
JOIN    public.pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE   e.custo_unitario <> p.preco_compra
ORDER BY e.nro_nfe;

-- V16. Produto com preço de venda MENOR que o preço de compra (prejuízo em cada venda) -> 4 linhas
SELECT  produto_id, preco_compra, preco_venda, (preco_venda - preco_compra) AS margem
FROM    public.produtos_filial
WHERE   preco_venda < preco_compra
ORDER BY margem;

-- V17. preco_unitario diferente de preco_venda em todos os produtos (qual é o preço oficial?) -> 20 linhas
SELECT  produto_id, preco_unitario, preco_venda
FROM    public.produtos_filial
WHERE   preco_unitario <> preco_venda
ORDER BY produto_id;

-- V18. Fornecedores sem nenhum produto vinculado (F14, F15, F16): informativo -> 3 linhas
SELECT  f.idfornecedor, f.razao_social
FROM    public.fornecedor f
WHERE   NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.idfornecedor = f.idfornecedor);

-- ===================================================================================
-- C) PERGUNTAS DO CLIENTE PARA FEVEREIRO/2025 (apoio na reunião)
-- ===================================================================================

-- C1. Top 5 produtos de fevereiro por valor
SELECT  v.produto_id, SUM(v.qtde_vendida) AS qtde, SUM(v.qtde_vendida * v.valor_unitario) AS valor_rs
FROM    public.venda v
WHERE   v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01'
GROUP BY v.produto_id ORDER BY valor_rs DESC LIMIT 5;

-- C2. Quanto de fevereiro é "venda sem produto cadastrado" (o que depende de correção do cadastro)
SELECT  SUM(v.qtde_vendida * v.valor_unitario) FILTER (WHERE p.produto_id IS NULL)     AS valor_sem_cadastro,
        SUM(v.qtde_vendida * v.valor_unitario)                                          AS valor_total,
        ROUND(100.0 * SUM(v.qtde_vendida * v.valor_unitario) FILTER (WHERE p.produto_id IS NULL)
              / SUM(v.qtde_vendida * v.valor_unitario), 1)                              AS pct_sem_cadastro
FROM    public.venda v
LEFT JOIN public.produtos_filial p ON p.produto_id = v.produto_id AND p.filial_id = v.filial_id
WHERE   v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01';
