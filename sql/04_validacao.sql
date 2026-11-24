
-- ============================================================
-- PARTE 4 - VALIDACAO DOS DADOS
-- Projeto: Integracao de Dados - ADS242N01
-- Banco: PostgreSQL
-- Base recebida: 33 registros na aba venda
-- ============================================================

-- 1. Conferir quantidade total de registros.

SELECT COUNT(*) AS total_registros
FROM venda;


-- 2. Contar campos obrigatorios vazios.

SELECT COUNT(*) AS registros_com_campos_obrigatorios_vazios
FROM venda
WHERE venda_id IS NULL
   OR data_emissao IS NULL
   OR horariomov IS NULL
   OR produto_id IS NULL
   OR qtde_vendida IS NULL
   OR valor_unitario IS NULL
   OR filial_id IS NULL
   OR item IS NULL
   OR unidade_medida IS NULL;


-- 3. Identificar duplicidades na chave primaria composta.

SELECT COUNT(*) AS grupos_de_chaves_duplicadas
FROM (
    SELECT
        filial_id,
        venda_id,
        data_emissao,
        produto_id,
        item,
        horariomov
    FROM venda
    GROUP BY
        filial_id,
        venda_id,
        data_emissao,
        produto_id,
        item,
        horariomov
    HAVING COUNT(*) > 1
) AS duplicidades;


-- 4. Contar quantidades ou valores negativos ou zerados.

SELECT COUNT(*) AS registros_com_quantidade_ou_valor_invalido
FROM venda
WHERE qtde_vendida <= 0
   OR valor_unitario <= 0;


-- 5. Contar quantidades fracionadas para unidade UN.

SELECT COUNT(*) AS registros_com_quantidade_fracionada
FROM venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida <> TRUNC(qtde_vendida);


-- 6. Contar vendas fora do ano de 2025.

SELECT COUNT(*) AS registros_fora_de_2025
FROM venda
WHERE data_emissao < DATE '2025-01-01'
   OR data_emissao >= DATE '2026-01-01';


-- 7. Conferir vendas por produto em fevereiro de 2025.

SELECT
    produto_id,
    SUM(qtde_vendida) AS quantidade_vendida,
    ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_total
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao < DATE '2025-03-01'
GROUP BY produto_id
ORDER BY produto_id;


-- 8. Conferir total geral de fevereiro de 2025.

SELECT
    COUNT(*) AS quantidade_vendas,
    SUM(qtde_vendida) AS quantidade_total,
    ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_total
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao < DATE '2025-03-01';


-- 9. Conferir os registros por filial.

SELECT
    filial_id,
    COUNT(*) AS total_vendas
FROM venda
GROUP BY filial_id
ORDER BY filial_id;


-- 10. Conferir unidades de medida utilizadas.

SELECT
    unidade_medida,
    COUNT(*) AS total
FROM venda
GROUP BY unidade_medida
ORDER BY unidade_medida;


-- ============================================================
-- 11. RESUMO DAS VALIDACOES
-- ============================================================
-- Os resultados indicam quantos registros foram encontrados
-- em cada verificacao. Valores acima de zero exigem analise.
-- Nem toda ocorrencia representa necessariamente um erro.

SELECT 'Campos obrigatorios vazios' AS verificacao,
       COUNT(*) AS quantidade
FROM venda
WHERE venda_id IS NULL
   OR data_emissao IS NULL
   OR horariomov IS NULL
   OR produto_id IS NULL
   OR qtde_vendida IS NULL
   OR valor_unitario IS NULL
   OR filial_id IS NULL
   OR item IS NULL
   OR unidade_medida IS NULL

UNION ALL

SELECT 'Chaves primarias duplicadas',
       COUNT(*)
FROM (
    SELECT filial_id, venda_id, data_emissao,
           produto_id, item, horariomov
    FROM venda
    GROUP BY filial_id, venda_id, data_emissao,
             produto_id, item, horariomov
    HAVING COUNT(*) > 1
) AS duplicidades

UNION ALL

SELECT 'Quantidade ou valor negativo/zerado',
       COUNT(*)
FROM venda
WHERE qtde_vendida <= 0
   OR valor_unitario <= 0

UNION ALL

SELECT 'Quantidade fracionada para unidade UN',
       COUNT(*)
FROM venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida <> TRUNC(qtde_vendida)

UNION ALL

SELECT 'Vendas fora de 2025',
       COUNT(*)
FROM venda
WHERE data_emissao < DATE '2025-01-01'
   OR data_emissao >= DATE '2026-01-01';


-- FIM DA PARTE 4
