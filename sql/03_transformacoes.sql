-- 03_transformacoes
-- Nome: Áderson Teixeira

-- Interpretação de "mais de 10 vezes":
-- Considera-se estritamente maior que 10 (COUNT(*) > 10) ocorrências/registros
-- de requisição na tabela pedido_compra para cada produto no período analisado.
-- Nota sobre base_teste.xlsx: na base de teste atual, a frequência máxima por produto
-- em pedido_compra é de 2 requisições (P12 a P20 têm 2 registros; P1 a P11 têm 1),
-- portanto o filtro estrito HAVING COUNT(*) > 10 retorna 0 linhas nesta amostra,
-- mantendo exatamente a regra solicitada no enunciado.
SELECT
    CONCAT(
        TRIM(CAST(pc.produto_id AS VARCHAR(25))),
        CASE
            WHEN COALESCE(TRIM(pc.descricao_produto), '') <> ''
                THEN CONCAT(' - ', TRIM(pc.descricao_produto))
            WHEN COALESCE(TRIM(pf.descricao), '') <> ''
                THEN CONCAT(' - ', TRIM(pf.descricao))
            ELSE ''
        END
    ) AS "Produto",
    COUNT(*) AS "Qtde Requisitada",
    TO_CHAR(MAX(pc.data_pedido), 'DD/MM/YYYY') AS "Data Solicitação"
FROM public.pedido_compra pc
LEFT JOIN public.produtos_filial pf
    ON pf.produto_id = pc.produto_id
-- Se precisar restringir a um período específico, adicione aqui (ex.: WHERE pc.data_pedido >= DATE '2025-02-01' AND pc.data_pedido < DATE '2025-03-01')
GROUP BY
    pc.produto_id,
    pc.descricao_produto,
    pf.descricao
HAVING COUNT(*) > 10
ORDER BY "Produto";

-- Trigger (PostgreSQL) que gera automaticamente um novo idfornecedor numérico
-- na tabela de produtos (produtos_filial), relacionado à tabela fornecedor
CREATE OR REPLACE FUNCTION public.fn_gerar_idfornecedor_num_produto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_novo_id_num INTEGER;
    v_id_fornecedor_txt VARCHAR(25);
BEGIN
    IF NEW.idfornecedor_num IS NULL THEN
        IF NEW.idfornecedor IS NOT NULL AND TRIM(NEW.idfornecedor) <> '' THEN
            SELECT f.idfornecedor_num
            INTO v_novo_id_num
            FROM public.fornecedor f
            WHERE f.idfornecedor = TRIM(NEW.idfornecedor);

            IF v_novo_id_num IS NULL THEN
                SELECT COALESCE(MAX(idfornecedor_num), 0) + 1
                INTO v_novo_id_num
                FROM public.fornecedor;

                INSERT INTO public.fornecedor (idfornecedor, idfornecedor_num, razao_social)
                VALUES (
                    TRIM(NEW.idfornecedor),
                    v_novo_id_num,
                    CONCAT('Fornecedor ', TRIM(NEW.idfornecedor))
                )
                ON CONFLICT (idfornecedor) DO UPDATE
                SET idfornecedor_num = COALESCE(
                    public.fornecedor.idfornecedor_num,
                    EXCLUDED.idfornecedor_num
                )
                RETURNING idfornecedor_num INTO v_novo_id_num;
            END IF;
        ELSE
            SELECT COALESCE(MAX(idfornecedor_num), 0) + 1
            INTO v_novo_id_num
            FROM public.fornecedor;

            v_id_fornecedor_txt := CONCAT('F', v_novo_id_num::TEXT);
            NEW.idfornecedor := v_id_fornecedor_txt;

            INSERT INTO public.fornecedor (idfornecedor, idfornecedor_num, razao_social)
            VALUES (
                v_id_fornecedor_txt,
                v_novo_id_num,
                CONCAT('Fornecedor Automático ', v_novo_id_num)
            )
            ON CONFLICT (idfornecedor) DO UPDATE
            SET idfornecedor_num = COALESCE(
                public.fornecedor.idfornecedor_num,
                EXCLUDED.idfornecedor_num
            )
            RETURNING idfornecedor_num INTO v_novo_id_num;
        END IF;

        NEW.idfornecedor_num := v_novo_id_num;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gerar_idfornecedor_num_produto ON public.produtos_filial;

CREATE TRIGGER trg_gerar_idfornecedor_num_produto
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION public.fn_gerar_idfornecedor_num_produto();
