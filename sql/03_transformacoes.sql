-- ============================================================================
-- PARTE 3: TRANSFORMAÇÕES DE DADOS E TRIGGER
-- ============================================================================

-- 1, 2 e 3. Consulta de requisições formatada:
-- - Concatena produto_id e descricao_produto apenas onde houver descrição;
-- - Formata data_pedido para DD/MM/YYYY;
-- - Filtra produtos requisitados mais de 10 vezes no período.
--
-- INTERPRETAÇÃO DO CRITÉRIO "MAIS DE 10 VEZES NO PERÍODO":
-- Na base de testes, cada produto aparece em no máximo 2 linhas de pedido_compra,
-- enquanto o volume de unidades requisitadas (qtde_pedida) varia de 2 a 99 unidades.
-- Portanto, interpretou-se "requisitados mais de 10 vezes" como o volume de unidades
-- solicitadas na requisição (pc.qtde_pedida > 10), aderente ao exemplo esperado do
-- enunciado ("12345 - Detergente | 15 | 01/01/2025").
SELECT
    CASE
        WHEN pc.descricao_produto IS NOT NULL AND TRIM(pc.descricao_produto) <> ''
            THEN CONCAT(pc.produto_id, ' - ', TRIM(pc.descricao_produto))
        ELSE pc.produto_id
    END AS "Produto",
    pc.qtde_pedida AS "Qtde Requisitada",
    TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS "Data Solicitação"
FROM public.pedido_compra pc
WHERE pc.qtde_pedida > 10
ORDER BY pc.data_pedido, pc.produto_id;


-- 4. Trigger que gera automaticamente um novo idfornecedor numérico na tabela
--    produtos_filial e garante o relacionamento na tabela fornecedor.
CREATE OR REPLACE FUNCTION public.fn_gerar_idfornecedor_produto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_novo_id int4;
BEGIN
    -- Caso o novo produto seja inserido sem idfornecedor informado (NULL ou <= 0),
    -- gera automaticamente o próximo ID numérico sequencial considerando ambas as tabelas.
    IF NEW.idfornecedor IS NULL OR NEW.idfornecedor <= 0 THEN
        SELECT GREATEST(
            COALESCE((SELECT MAX(idfornecedor) FROM public.fornecedor), 0),
            COALESCE((SELECT MAX(idfornecedor) FROM public.produtos_filial), 0)
        ) + 1
        INTO v_novo_id;

        NEW.idfornecedor := v_novo_id;
    END IF;

    -- Garante que o idfornecedor exista na tabela pai (fornecedor) para manter
    -- a integridade referencial da chave estrangeira fk_produtos_fornecedor.
    INSERT INTO public.fornecedor (idfornecedor, razao_social)
    VALUES (
        NEW.idfornecedor,
        CONCAT('Fornecedor ', NEW.idfornecedor, ' LTDA (Auto)')
    )
    ON CONFLICT (idfornecedor) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gerar_idfornecedor_produto ON public.produtos_filial;

CREATE TRIGGER trg_gerar_idfornecedor_produto
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION public.fn_gerar_idfornecedor_produto();

-- Bloco de teste comentado (descomente se desejar validar a inserção automática):
-- INSERT INTO public.produtos_filial (filial_id, produto_id, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor)
-- VALUES (1, 'P99', 'Produto Teste Trigger', 10, 50.00, 30.00, 60.00, NULL);
-- SELECT * FROM public.produtos_filial WHERE produto_id = 'P99';
-- SELECT * FROM public.fornecedor WHERE idfornecedor = 21;