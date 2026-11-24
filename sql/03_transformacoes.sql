-- =============================================================================
-- 03_transformacoes.sql — Parte 3 (transformações, somente SQL)
-- Banco: atividade (PostgreSQL 16)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- (a) Concatenar produto_id e descricao no formato "12345 - Detergente"
-- Fonte: produtos_filial (tem produto_id e descricao). Exemplo: "P1 - Produto 1".
-- -----------------------------------------------------------------------------
SELECT
    produto_id || ' - ' || descricao AS produto
FROM public.produtos_filial
ORDER BY produto_id;

-- -----------------------------------------------------------------------------
-- (b) Datas no formato DD/MM/YYYY
-- Aplicado em venda.data_emissao e pedido_compra.data_pedido (TO_CHAR).
-- -----------------------------------------------------------------------------
SELECT
    venda_id,
    TO_CHAR(data_emissao, 'DD/MM/YYYY') AS data_emissao,
    produto_id,
    qtde_vendida
FROM public.venda
ORDER BY venda_id
LIMIT 10;

SELECT
    pedido_id,
    TO_CHAR(data_pedido, 'DD/MM/YYYY')  AS data_pedido,
    TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega,
    produto_id
FROM public.pedido_compra
ORDER BY pedido_id
LIMIT 10;

-- -----------------------------------------------------------------------------
-- (c) Produtos requisitados MAIS DE 10 VEZES no período
-- Interpretação de "mais de 10 vezes": optei por "número de linhas (pedidos)
-- em pedido_compra com aquele produto" (COUNT(*) > 10), e não pela soma de
-- qtde_pedida. Justificativa: "vezes" em português refere-se a ocorrências/
-- solicitações distintas, não à quantidade total pedida; somar qtde_pedida
-- mediria volume, não frequência. A alternativa (SUM(qtde_pedida) > 10) seria
-- quase sempre verdadeira neste dataset (todas as qtde_pedida são >= 2) e não
-- distinguiria os produtos de fato mais requisitados.
-- Mostra produto, contagem e data da primeira solicitação.
-- -----------------------------------------------------------------------------
SELECT
    pc.produto_id || ' - ' || COALESCE(pf.descricao, pc.descricao_produto) AS produto,
    COUNT(*)              AS vezes_requisitado,
    MIN(pc.data_pedido)   AS primeira_solicitacao
FROM public.pedido_compra pc
LEFT JOIN public.produtos_filial pf
       ON pf.produto_id = pc.produto_id
GROUP BY pc.produto_id, pf.descricao, pc.descricao_produto
HAVING COUNT(*) > 10
ORDER BY vezes_requisitado DESC, produto;

-- -----------------------------------------------------------------------------
-- (d) TRIGGER: gera automaticamente um novo idfornecedor em produtos_filial
-- Formato definido: 'F' + próximo número (se existe F20, o próximo é F21).
-- - função PL/pgSQL calcula o próximo idfornecedor a partir de fornecedor
-- - trigger BEFORE INSERT: se idfornecedor for NULL, preenche; se vier
--   preenchido, respeita.
-- Teste em transação (ROLLBACK) para não alterar os dados.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.gerar_idfornecedor()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    proximo integer;
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        SELECT COALESCE(MAX(CAST(SUBSTRING(idfornecedor FROM 2) AS integer)), 0) + 1
        INTO proximo
        FROM public.fornecedor;
        NEW.idfornecedor := 'F' || proximo;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_produtos_filial_idfornecedor ON public.produtos_filial;

CREATE TRIGGER trg_produtos_filial_idfornecedor
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION public.gerar_idfornecedor();

-- Teste: INSERT com idfornecedor NULL deve resultar em F21
-- (FK temporariamente removida na transação para isolar o teste do gatilho;
--  ROLLBACK restaura a constraint e os dados.)
BEGIN;
ALTER TABLE public.produtos_filial DROP CONSTRAINT fk_produtos_filial_fornecedor;
INSERT INTO public.produtos_filial
    (filial_id, produto_id, descricao, estoque, idfornecedor)
VALUES (1, 'P99', 'Produto 99 (teste trigger)', 0, NULL);
SELECT filial_id, produto_id, descricao, idfornecedor
FROM public.produtos_filial
WHERE produto_id = 'P99';
ROLLBACK;
