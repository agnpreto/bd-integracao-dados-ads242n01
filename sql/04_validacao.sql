
-- PARTE 4 - VALIDACAO DOS DADOS
-- Base recebida: 33 registros na tabela venda.

-- 1. Conferir quantidade total de registros.
SELECT COUNT(*) AS total_registros
FROM venda;

-- 2. Identificar campos obrigatorios vazios.
SELECT *
FROM venda
WHERE venda_id IS NULL
   OR data_emissao IS NULL
   OR produto_id IS NULL
   OR qtde_vendida IS NULL
   OR valor_unitario IS NULL
   OR filial_id IS NULL;

-- 3. Identificar identificadores de venda duplicados.
SELECT venda_id, COUNT(*) AS quantidade
FROM venda
GROUP BY venda_id
HAVING COUNT(*) > 1;

-- 4. Identificar quantidades ou valores negativos ou zerados.
SELECT *
FROM venda
WHERE qtde_vendida <= 0
   OR valor_unitario <= 0;

-- 5. Identificar quantidades fracionadas para unidade UN.
SELECT *
FROM venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida <> TRUNC(qtde_vendida);

-- 6. Conferir vendas fora do ano de 2025.
SELECT *
FROM venda
WHERE data_emissao < DATE '2025-01-01'
   OR data_emissao >= DATE '2026-01-01';

-- 7. Conferir vendas de fevereiro de 2025.
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
SELECT filial_id, COUNT(*) AS total_vendas
FROM venda
GROUP BY filial_id
ORDER BY filial_id;

-- 10. Conferir unidades de medida utilizadas.
SELECT unidade_medida, COUNT(*) AS total
FROM venda
GROUP BY unidade_medida
ORDER BY unidade_medida;
