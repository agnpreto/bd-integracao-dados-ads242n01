-- 03_transformacoes
-- Nome: João Gustavo Gonçalves Vasconcelos  | Matrícula: 2408298 | GitHub: SukitaAM
-- Banco: PostgreSQL 16

-- =====================================================================================
-- 3.1) Concatenar produto_id e descricao_produto "onde houver" -> '12345 - Detergente'
-- =====================================================================================
-- Onde a descrição é NULL ou vazia, devolve só o produto_id (sem o " - " sobrando).
SELECT  CASE WHEN NULLIF(TRIM(descricao_produto), '') IS NOT NULL
             THEN produto_id || ' - ' || TRIM(descricao_produto)
             ELSE produto_id
        END AS produto
FROM    public.pedido_compra;

-- Mesma ideia para vendas e produtos (a venda não tem descrição: busca em produtos_filial).
SELECT  CASE WHEN NULLIF(TRIM(p.descricao), '') IS NOT NULL
             THEN v.produto_id || ' - ' || TRIM(p.descricao)
             ELSE v.produto_id
        END AS produto,
        v.qtde_vendida,
        TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS data_venda
FROM    public.venda v
LEFT JOIN public.produtos_filial p
       ON p.produto_id = v.produto_id AND p.filial_id = v.filial_id;

-- =====================================================================================
-- 3.2) Datas no formato DD/MM/YYYY (TO_CHAR devolve texto; o dado continua DATE no banco)
-- =====================================================================================
SELECT  pedido_id,
        TO_CHAR(data_pedido,  'DD/MM/YYYY') AS data_pedido,
        TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega
FROM    public.pedido_compra
ORDER BY pedido_id;

-- =====================================================================================
-- 3.3) Somente produtos "requisitados mais de 10 vezes no período"
-- =====================================================================================
-- INTERPRETAÇÃO: o resultado esperado do enunciado é "Produto | Qtde Requisitada | Data Solicitação",
-- onde "Qtde Requisitada" é uma QUANTIDADE (ex.: 15 unidades de Detergente). Portanto "mais de 10 vezes"
-- foi lido como: a quantidade total requisitada (SUM de qtde_pedida) do produto, no período, é > 10.
-- Período: 01/01/2025 a 31/03/2025 (todo o intervalo de datas existente na base); troque os
-- limites no CTE "periodo" para outro recorte.
-- A leitura alternativa (contar o NÚMERO de pedidos, COUNT(*) > 10) está na consulta 3.3b: na base
-- cada produto tem no máximo 2 pedidos, então ela não retorna linhas.
WITH periodo AS (
    SELECT DATE '2025-01-01' AS ini, DATE '2025-03-31' AS fim
),
req AS (
    SELECT  p.*,
            SUM(p.qtde_pedida) OVER (PARTITION BY p.produto_id) AS total_requisitado
    FROM    public.pedido_compra p, periodo
    WHERE   p.data_pedido BETWEEN periodo.ini AND periodo.fim
)
SELECT  CASE WHEN NULLIF(TRIM(descricao_produto), '') IS NOT NULL
             THEN produto_id || ' - ' || TRIM(descricao_produto)
             ELSE produto_id END                 AS "Produto",
        qtde_pedida                              AS "Qtde Requisitada",
        TO_CHAR(data_pedido, 'DD/MM/YYYY')       AS "Data Solicitação"
FROM    req
WHERE   total_requisitado > 10
ORDER BY produto_id, data_pedido;

-- 3.3b) Leitura alternativa: produtos com MAIS DE 10 PEDIDOS (linhas) no período -> 0 linhas nesta base.
SELECT  produto_id, COUNT(*) AS qtd_pedidos
FROM    public.pedido_compra
WHERE   data_pedido BETWEEN DATE '2025-01-01' AND DATE '2025-03-31'
GROUP BY produto_id
HAVING  COUNT(*) > 10;

-- =====================================================================================
-- 3.4) TRIGGER: gera automaticamente um idfornecedor numérico novo em produtos_filial,
--      relacionado com a tabela fornecedor
-- =====================================================================================
-- Regra: ao inserir um produto SEM idfornecedor, a trigger cria um fornecedor "provisório" na tabela
-- fornecedor (o id numérico é gerado pela coluna IDENTITY, sem risco de colisão) e grava esse novo id
-- no produto. A FK fk_produtos_fornecedor garante o relacionamento. Se o idfornecedor vier informado,
-- ele é respeitado (e a FK valida que existe).
CREATE OR REPLACE FUNCTION public.fn_gera_idfornecedor()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_novo integer;
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO public.fornecedor (razao_social)
        VALUES ('Fornecedor a definir - produto ' || NEW.produto_id)
        RETURNING idfornecedor INTO v_novo;

        NEW.idfornecedor := v_novo;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gera_idfornecedor ON public.produtos_filial;
CREATE TRIGGER trg_gera_idfornecedor
    BEFORE INSERT ON public.produtos_filial
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_gera_idfornecedor();

-- Teste da trigger (roda e desfaz, não deixa lixo no banco):
-- BEGIN;
--   INSERT INTO public.produtos_filial (filial_id, produto_id, descricao) VALUES (1, 'P99', 'Produto de teste');
--   SELECT p.produto_id, p.idfornecedor, f.razao_social
--   FROM   public.produtos_filial p JOIN public.fornecedor f USING (idfornecedor)
--   WHERE  p.produto_id = 'P99';          -- idfornecedor = 21, 'Fornecedor a definir - produto P99'
-- ROLLBACK;
