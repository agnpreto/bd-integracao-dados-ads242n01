-- 03_transformacoes
-- Parte 3: Transformações de Dados

-- ─────────────────────────────────────────────────────────────
-- 1) Concatenar produto_id e descricao_produto (onde houver), no
--    formato "12345 - Detergente". Quando não há descrição,
--    mostra só o produto_id.
-- ─────────────────────────────────────────────────────────────

-- pedido_compra
SELECT
    pedido_id,
    CASE WHEN descricao_produto IS NOT NULL AND descricao_produto <> ''
         THEN produto_id || ' - ' || descricao_produto
         ELSE produto_id
    END AS produto
FROM pedido_compra
ORDER BY pedido_id;

-- produtos_filial (descricao é NOT NULL, mas a mesma lógica é mantida por consistência)
SELECT
    filial_id,
    CASE WHEN descricao IS NOT NULL AND descricao <> ''
         THEN produto_id || ' - ' || descricao
         ELSE produto_id
    END AS produto
FROM produtos_filial
ORDER BY filial_id, produto_id;

-- venda (a tabela não guarda descrição do produto; busca em produtos_filial "onde houver")
SELECT
    v.venda_id,
    CASE WHEN pf.descricao IS NOT NULL AND pf.descricao <> ''
         THEN v.produto_id || ' - ' || pf.descricao
         ELSE v.produto_id
    END AS produto
FROM venda v
LEFT JOIN produtos_filial pf
       ON pf.produto_id = v.produto_id
      AND pf.filial_id  = v.filial_id
ORDER BY v.venda_id;

-- ─────────────────────────────────────────────────────────────
-- 2) Datas no formato DD/MM/YYYY.
-- ─────────────────────────────────────────────────────────────

SELECT venda_id, TO_CHAR(data_emissao, 'DD/MM/YYYY') AS data_emissao
FROM venda
ORDER BY venda_id;

SELECT pedido_id,
       TO_CHAR(data_pedido, 'DD/MM/YYYY')  AS data_pedido,
       TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega
FROM pedido_compra
ORDER BY pedido_id;

SELECT nro_nfe, TO_CHAR(data_entrada, 'DD/MM/YYYY') AS data_entrada
FROM entradas_mercadoria
ORDER BY data_entrada;

-- ─────────────────────────────────────────────────────────────
-- 3) Produtos requisitados mais de 10 vezes no período, no
--    formato do exemplo do enunciado (Produto | Qtde Requisitada
--    | Data Solicitação).
--
-- Interpretação de "mais de 10 vezes": testei a leitura literal
-- ("o produto aparece em mais de 10 pedidos de compra"), mas
-- nenhum produto desta base foi pedido mais de 2 vezes — essa
-- leitura devolveria a tabela vazia e não seria útil ao cliente.
-- Por isso interpretei "vezes" como "unidades": produtos cuja
-- quantidade requisitada (qtde_pedida) em um pedido foi maior que
-- 10, que é também o que o exemplo do enunciado sugere (linha
-- única por pedido, com a quantidade do próprio pedido).
-- ─────────────────────────────────────────────────────────────
SELECT
    CASE WHEN pc.descricao_produto IS NOT NULL AND pc.descricao_produto <> ''
         THEN pc.produto_id || ' - ' || pc.descricao_produto
         ELSE pc.produto_id
    END AS "Produto",
    pc.qtde_pedida                       AS "Qtde Requisitada",
    TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS "Data Solicitação"
FROM pedido_compra pc
WHERE pc.qtde_pedida > 10
ORDER BY pc.produto_id, pc.data_pedido;

-- ─────────────────────────────────────────────────────────────
-- 4) Trigger: gera automaticamente um novo idfornecedor na tabela
--    de produtos (produtos_filial), relacionado à tabela de
--    fornecedor, quando um produto é cadastrado sem fornecedor.
--
-- Os ids de fornecedor existentes seguem o padrão "F<número>"
-- (F1, F2, ..., F20). A trigger calcula o próximo número livre,
-- cria o fornecedor correspondente (com razão social provisória,
-- a confirmar com o cliente) e grava esse id no produto novo.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.gerar_fornecedor_produto()
RETURNS trigger AS $$
DECLARE
    novo_numero int;
    novo_id     varchar(25);
BEGIN
    IF NEW.idfornecedor IS NOT NULL THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(MAX(NULLIF(regexp_replace(idfornecedor, '\D', '', 'g'), '')::int), 0) + 1
      INTO novo_numero
      FROM public.fornecedor;

    novo_id := 'F' || novo_numero;

    INSERT INTO public.fornecedor (idfornecedor, razao_social)
    VALUES (novo_id, 'Fornecedor a definir (gerado automaticamente)');

    NEW.idfornecedor := novo_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_produtos_filial_gera_fornecedor ON public.produtos_filial;

CREATE TRIGGER trg_produtos_filial_gera_fornecedor
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION public.gerar_fornecedor_produto();
