-- 03_transformacoes
-- Nome: Márcio Deoclides Marinho da Rocha 

-- Parte 3: Formatação, filtro de recorrência e trigger de fornecedor

-- Interpretação de "mais de 10 vezes":
-- Consideramos a contagem de registros/ocorrências de requisição de cada produto
-- no período (> 10), ou seja, mais de 10 linhas/pedidos registrados (COUNT(*) > 10).
-- Se a regra de negócio exigir soma de quantidades em vez de contagem de pedidos,
-- basta alterar o critério na cláusula HAVING.

SELECT
    CONCAT_WS(' - ', pc.produto_id, NULLIF(TRIM(pc.descricao_produto), '')) AS "Produto",
    COUNT(*) AS "Qtde Requisitada",
    TO_CHAR(MAX(pc.data_pedido), 'DD/MM/YYYY') AS "Data Solicitação"
FROM public.pedido_compra pc
WHERE pc.data_pedido >= DATE '2025-01-01'
  AND pc.data_pedido <  DATE '2025-03-01'
GROUP BY pc.produto_id, pc.descricao_produto
HAVING COUNT(*) > 10
ORDER BY "Qtde Requisitada" DESC, "Produto";

-- Trigger para gerar automaticamente um novo idfornecedor na tabela de produtos
-- e garantir a ligação à tabela fornecedor.
CREATE OR REPLACE FUNCTION public.fn_gerar_idfornecedor_produtos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_novo_id varchar(25);
BEGIN
    IF NEW.idfornecedor IS NULL OR BTRIM(NEW.idfornecedor) = '' THEN
        SELECT COALESCE(MAX(
            CASE
                WHEN idfornecedor ~ '^[0-9]+$' THEN idfornecedor::bigint
                ELSE NULL
            END
        ), 0) + 1::varchar(25)
        INTO v_novo_id
        FROM public.fornecedor;

        INSERT INTO public.fornecedor (idfornecedor, razao_social)
        VALUES (
            v_novo_id,
            'Fornecedor Automático ' || v_novo_id
        )
        ON CONFLICT (idfornecedor) DO NOTHING;

        NEW.idfornecedor := v_novo_id;
    ELSE
        INSERT INTO public.fornecedor (idfornecedor, razao_social)
        VALUES (
            NEW.idfornecedor,
            'Fornecedor ' || NEW.idfornecedor
        )
        ON CONFLICT (idfornecedor) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_produtos_filial_gerar_fornecedor ON public.produtos_filial;

CREATE TRIGGER trg_produtos_filial_gerar_fornecedor
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION public.fn_gerar_idfornecedor_produtos();
