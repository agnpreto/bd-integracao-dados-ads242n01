-- Formatar data como DD/MM/YYYY no MySQL 8+
SELECT pedido_id, produto_id, DATE_FORMAT(data_pedido, '%d/%m/%Y') AS data_solicitacao
FROM pedido_compra;
