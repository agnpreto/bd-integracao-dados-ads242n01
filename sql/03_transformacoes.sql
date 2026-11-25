-- PARTE 3 - TRANSFORMACOES SQL

-- 1. Concatenacao do codigo e descricao do produto

SELECT
    CONCAT(produto_id, ' - ', descricao_produto) AS produto
FROM public.pedido_compra;

SELECT
    CONCAT(produto_id, ' - ', descricao_produto) AS produto
FROM public.entradas_mercadoria;

SELECT
    CONCAT(produto_id, ' - ', descricao) AS produto
FROM public.produtos_filial;

Produto
P1 - Produto 1
P2 - Produto 2
P3 - Produto 3

Utilizamos CONCAT() para unir o código e a descrição em uma única coluna.
Passo 3 — Formatar as datas
O professor solicita que as datas sejam apresentadas no formato brasileiro: DD/MM/YYYY.
-- 2. Formatacao das datas

SELECT
    venda_id,
    produto_id,
    TO_CHAR(data_emissao, 'DD/MM/YYYY') AS data_emissao
FROM public.venda;

SELECT
    pedido_id,
    produto_id,
    TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_pedido,
    TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega
FROM public.pedido_compra;

SELECT
    nro_nfe,
    produto_id,
    TO_CHAR(data_entrada, 'DD/MM/YYYY') AS data_entrada
FROM public.entradas_mercadoria;

-- 3. Produtos requisitados mais de 10 vezes.
-- Interpretacao: soma das unidades requisitadas
-- por produto durante fevereiro de 2025.
-- Nao representa a quantidade de pedidos distintos.

SELECT
    CONCAT(produto_id, ' - ', descricao_produto)
        AS produto,
    SUM(qtde_pedida) AS qtde_requisitada,
    TO_CHAR(MIN(data_pedido), 'DD/MM/YYYY')
        AS primeira_solicitacao
FROM public.pedido_compra
WHERE data_pedido >= '2025-02-01'
    AND data_pedido < '2025-03-01'
GROUP BY produto_id, descricao_produto
HAVING SUM(qtde_pedida) > 10
ORDER BY qtde_requisitada DESC;

-- 4. Sequencia para gerar identificadores

CREATE SEQUENCE IF NOT EXISTS public.seq_fornecedor
START WITH 1;

-- Sincronizar a sequencia com os fornecedores existentes

SELECT setval(
    'public.seq_fornecedor',
    COALESCE(
        MAX(SUBSTRING(idfornecedor FROM 2)::BIGINT),
        0
    ) + 1,
    false
)
FROM public.fornecedor
WHERE idfornecedor ~ '^F[0-9]+$';

CREATE OR REPLACE FUNCTION public.gerar_idfornecedor()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.idfornecedor IS NULL
        OR TRIM(NEW.idfornecedor) = '' THEN

        NEW.idfornecedor :=
            'F' || nextval('public.seq_fornecedor');

        INSERT INTO public.fornecedor (
            idfornecedor,
            razao_social
        )
        VALUES (
            NEW.idfornecedor,
            'Fornecedor provisório'
        );

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_gerar_idfornecedor
ON public.produtos_filial;

CREATE TRIGGER trg_gerar_idfornecedor
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION public.gerar_idfornecedor();

BEGIN;

INSERT INTO public.produtos_filial (
    filial_id,
    produto_id,
    descricao,
    estoque,
    preco_unitario,
    preco_compra,
    preco_venda,
    idfornecedor
)
VALUES (
    1,
    'P_TESTE',
    'Produto de teste',
    10,
    20,
    15,
    25,
    NULL
);

SELECT *
FROM public.produtos_filial
WHERE produto_id = 'P_TESTE';

SELECT f.*
FROM public.fornecedor f
JOIN public.produtos_filial p
    ON f.idfornecedor = p.idfornecedor
WHERE p.produto_id = 'P_TESTE';

ROLLBACK;