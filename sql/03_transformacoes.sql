-- 03_transformacoes.sql | consultas compatíveis com PostgreSQL e MySQL 8+

-- 1. Concatenar código e descrição do produto. CONCAT funciona nos dois SGBDs.
SELECT CONCAT(produto_id, ' - ', COALESCE(descricao_produto, '')) AS produto,
       qtde_pedida, data_pedido
FROM pedido_compra;

-- 2. Formatação da data: use o arquivo específico do seu SGBD:
-- PostgreSQL: sql/03_data_postgres.sql (TO_CHAR)
-- MySQL:      sql/03_data_mysql.sql (DATE_FORMAT)

-- 3. Produtos requisitados mais de 10 vezes em fevereiro/2025.
SELECT produto_id, descricao_produto, COUNT(*) AS vezes_requisitado,
       SUM(qtde_pedida) AS quantidade_total
FROM pedido_compra
WHERE data_pedido >= '2025-02-01' AND data_pedido < '2025-03-01'
GROUP BY produto_id, descricao_produto
HAVING COUNT(*) > 10
ORDER BY vezes_requisitado DESC;
-- Na planilha fornecida, nenhum produto ultrapassa 10 requisições no mês.
