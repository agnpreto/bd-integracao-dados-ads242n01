-- Formatar data como DD/MM/YYYY no PostgreSQL
SELECT pedido_id, produto_id, TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_solicitacao
FROM pedido_compra;
