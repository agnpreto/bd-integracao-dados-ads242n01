-- 03_transformacoes
-- Nome: Matheus Nogueira
--
-- Parte 3: transformacoes so com SQL.
-- Escrito para PostgreSQL. Onde a sintaxe do MySQL muda, a versao MySQL esta
-- logo abaixo, em comentario.


-- ===========================================================================
-- 3.1 Concatenar produto_id e descricao_produto: "12345 - Detergente"
-- ---------------------------------------------------------------------------
-- "Onde houver": se a descricao for nula ou vazia, mostra so o codigo, sem
-- deixar um " - " solto no final. O truque e que ' - ' || NULL da NULL, e o
-- COALESCE troca esse NULL por ''.
--   MySQL: CONCAT(produto_id, COALESCE(CONCAT(' - ', NULLIF(TRIM(descricao_produto), '')), ''))
-- ===========================================================================

-- Pedidos de compra (tem descricao_produto na propria tabela)
SELECT pedido_id,
       item,
       produto_id || COALESCE(' - ' || NULLIF(BTRIM(descricao_produto), ''), '') AS produto,
       qtde_pedida
FROM public.pedido_compra
ORDER BY pedido_id, item;

-- Entradas de mercadoria (tambem tem descricao_produto)
SELECT nro_nfe,
       ordem_compra,
       produto_id || COALESCE(' - ' || NULLIF(BTRIM(descricao_produto), ''), '') AS produto,
       qtde_recebida
FROM public.entradas_mercadoria
ORDER BY ordem_compra, item;

-- Vendas: a tabela nao tem descricao, entao ela vem do cadastro. Os produtos
-- sem cadastro (P21..P28) saem so com o codigo.
SELECT v.venda_id,
       v.produto_id || COALESCE(' - ' || NULLIF(BTRIM(c.descricao), ''), '') AS produto,
       v.qtde_vendida
FROM public.venda v
LEFT JOIN (
    SELECT produto_id, MAX(descricao) AS descricao
    FROM public.produtos_filial
    GROUP BY produto_id
) c ON c.produto_id = v.produto_id
ORDER BY v.venda_id;


-- ===========================================================================
-- 3.2 Datas no formato DD/MM/YYYY
-- ---------------------------------------------------------------------------
-- TO_CHAR devolve texto: usar so na apresentacao. Filtros e ORDER BY continuam
-- na coluna date original (ordenar o texto '01/02' antes de '31/01' daria
-- ordem errada).
--   MySQL: DATE_FORMAT(data_pedido, '%d/%m/%Y')
-- ===========================================================================
SELECT pedido_id,
       produto_id,
       TO_CHAR(data_pedido,  'DD/MM/YYYY') AS data_pedido,
       TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega
FROM public.pedido_compra
ORDER BY pedido_compra.data_pedido, pedido_id;

SELECT nro_nfe,
       TO_CHAR(data_entrada, 'DD/MM/YYYY') AS data_entrada
FROM public.entradas_mercadoria
ORDER BY entradas_mercadoria.data_entrada;

SELECT venda_id,
       TO_CHAR(data_emissao, 'DD/MM/YYYY') AS data_emissao
FROM public.venda
ORDER BY venda.data_emissao, venda_id;


-- ===========================================================================
-- 3.3 So os produtos requisitados mais de 10 vezes no periodo
-- ---------------------------------------------------------------------------
-- COMO INTERPRETEI "MAIS DE 10 VEZES":
--   "Vezes" pode ser lido de duas formas:
--     (a) numero de pedidos do produto (COUNT de linhas de pedido_compra);
--     (b) quantidade total requisitada do produto (SUM de qtde_pedida).
--   Adotei (b). O resultado esperado do enunciado tem a coluna
--   "Qtde Requisitada" com o valor 15, ou seja, o criterio e medido em
--   quantidade. Alem disso, em (a) nenhum produto passa: o maximo nesta base
--   e 2 pedidos por produto, e a consulta voltaria vazia.
--
-- PERIODO: o enunciado nao fixa datas, entao o periodo fica parametrizado no
--   CTE "periodo". Usei toda a base de pedidos (01/01/2025 a 31/03/2025).
--   Observacao honesta: nesse periodo todos os 20 produtos passam no filtro
--   (o menor total e 12, do P3). Trocando o periodo para fevereiro/2025
--   ('2025-02-01' a '2025-02-28'), 10 produtos passam.
--
-- FORMATO: igual ao exemplo (Produto | Qtde Requisitada | Data Solicitacao),
--   uma linha por produto e data de solicitacao. O filtro "> 10" e aplicado ao
--   total do produto no periodo, calculado com SUM() OVER (PARTITION BY ...).
-- ===========================================================================
WITH periodo AS (
    SELECT DATE '2025-01-01' AS inicio, DATE '2025-03-31' AS fim
),
requisicoes AS (
    SELECT pc.produto_id,
           MAX(pc.descricao_produto)                       AS descricao,
           pc.data_pedido,
           SUM(pc.qtde_pedida)                             AS qtde_no_dia,
           SUM(SUM(pc.qtde_pedida)) OVER (PARTITION BY pc.produto_id) AS qtde_no_periodo
    FROM public.pedido_compra pc
    JOIN periodo p ON pc.data_pedido BETWEEN p.inicio AND p.fim
    GROUP BY pc.produto_id, pc.data_pedido
)
SELECT produto_id || COALESCE(' - ' || NULLIF(BTRIM(descricao), ''), '') AS "Produto",
       qtde_no_dia                                                       AS "Qtde Requisitada",
       TO_CHAR(data_pedido, 'DD/MM/YYYY')                                AS "Data Solicitacao"
FROM requisicoes
WHERE qtde_no_periodo > 10
ORDER BY qtde_no_periodo DESC, produto_id, requisicoes.data_pedido;

-- Variante resumida: uma linha por produto, com o total do periodo e a data
-- da primeira solicitacao.
WITH periodo AS (
    SELECT DATE '2025-01-01' AS inicio, DATE '2025-03-31' AS fim
)
SELECT pc.produto_id || COALESCE(' - ' || NULLIF(BTRIM(MAX(pc.descricao_produto)), ''), '') AS "Produto",
       SUM(pc.qtde_pedida)                                     AS "Qtde Requisitada",
       TO_CHAR(MIN(pc.data_pedido), 'DD/MM/YYYY')              AS "Data Solicitacao",
       COUNT(*)                                                AS pedidos
FROM public.pedido_compra pc
JOIN periodo p ON pc.data_pedido BETWEEN p.inicio AND p.fim
GROUP BY pc.produto_id
HAVING SUM(pc.qtde_pedida) > 10
ORDER BY SUM(pc.qtde_pedida) DESC, pc.produto_id;

-- Interpretacao (a), para comparacao: troque o HAVING acima por
--   HAVING COUNT(*) > 10
-- Nesta base o resultado e vazio.


-- ===========================================================================
-- 3.4 Trigger: gera automaticamente um novo idfornecedor na tabela de
--     produtos, relacionado a tabela de fornecedor
-- ---------------------------------------------------------------------------
-- Funcionamento: quando um produto e gravado em produtos_filial sem
-- idfornecedor, a trigger cria um fornecedor provisorio em "fornecedor" (o id
-- vem da identidade, que comeca em 21) e grava esse id no produto. Assim o
-- produto nunca fica sem fornecedor e o vinculo e garantido pela FK
-- produtos_filial_fornecedor_fk. Se o idfornecedor vier preenchido, nada
-- muda e a FK valida se ele existe.
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.fn_gera_fornecedor_produto()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO public.fornecedor (razao_social)
        VALUES ('A DEFINIR - criado para o produto ' || NEW.produto_id
                || ' da filial ' || NEW.filial_id)
        RETURNING idfornecedor INTO NEW.idfornecedor;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gera_fornecedor_produto ON public.produtos_filial;

CREATE TRIGGER trg_gera_fornecedor_produto
    BEFORE INSERT OR UPDATE OF idfornecedor ON public.produtos_filial
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_gera_fornecedor_produto();

-- Teste (rode manualmente; o ROLLBACK desfaz tudo, mas a sequencia da
-- identidade nao volta, entao o proximo id real pode ser 22):
/*
BEGIN;
INSERT INTO public.produtos_filial (filial_id, produto_id, descricao)
VALUES (1, 'P99', 'Produto de teste')
RETURNING filial_id, produto_id, idfornecedor;          -- esperado: 21

SELECT p.produto_id, p.idfornecedor, f.razao_social
FROM public.produtos_filial p
JOIN public.fornecedor f ON f.idfornecedor = p.idfornecedor
WHERE p.produto_id = 'P99';
ROLLBACK;
*/

-- Versao MySQL 8 (rodar no cliente mysql; o DELIMITER e comando do cliente):
/*
DROP TRIGGER IF EXISTS trg_gera_fornecedor_produto;
DELIMITER $$
CREATE TRIGGER trg_gera_fornecedor_produto
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO fornecedor (razao_social)
        VALUES (CONCAT('A DEFINIR - criado para o produto ', NEW.produto_id,
                       ' da filial ', NEW.filial_id));
        SET NEW.idfornecedor = LAST_INSERT_ID();
    END IF;
END$$
DELIMITER ;
*/
