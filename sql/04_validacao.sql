-- 04_validacao
-- Nome: Márcio Deoclides Marinho da Rocha 
-- Parte 4: Consultas de validação de dados (fevereiro de 2025) e auditoria de erros

-- ============================================================================
-- 1. CONTAGEM GERAL E VOLUMETRIA POR TABELA (CONFERÊNCIA PÓS-IMPORTAÇÃO)
-- ============================================================================
SELECT 'fornecedor' AS tabela, COUNT(*) AS total_registros FROM public.fornecedor
UNION ALL
SELECT 'produtos_filial', COUNT(*) FROM public.produtos_filial
UNION ALL
SELECT 'pedido_compra', COUNT(*) FROM public.pedido_compra
UNION ALL
SELECT 'entradas_mercadoria', COUNT(*) FROM public.entradas_mercadoria
UNION ALL
SELECT 'venda', COUNT(*) FROM public.venda;

-- ============================================================================
-- 2. TOTAIS CONSOLIDADOS DE FEVEREIRO DE 2025 (FECHAMENTO COM O CLIENTE)
-- ============================================================================
SELECT
    COUNT(DISTINCT venda_id) AS total_vendas_distintas,
    COUNT(*) AS total_itens_vendidos,
    SUM(COALESCE(qtde_vendida, 0)) AS soma_unidades_vendidas,
    SUM(COALESCE(qtde_vendida, 0) * COALESCE(valor_unitario, 0)) AS faturamento_total_fev_20

