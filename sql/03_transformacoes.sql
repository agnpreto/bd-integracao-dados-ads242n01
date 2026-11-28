-- 03_transformacoes
-- Nome: Mateus Farias Bentes
-- Escrito para PostgreSQL. Onde a sintaxe do MySQL muda, a versão MySQL está comentada logo abaixo.
-- A trigger em MySQL está no fim do arquivo.

-- ═════════════════════════════════════════════════════════════
-- 3.1  Concatenar produto_id e descricao_produto ("onde houver")
-- ═════════════════════════════════════════════════════════════
-- CONCAT_WS(separador, a, b) ignora valores NULL: se não houver descrição, sai só o código
-- ("P21") em vez de "P21 - " ou NULL. Funciona igual no PostgreSQL e no MySQL.
-- Com o operador || do PostgreSQL, 'P21' || ' - ' || NULL daria NULL e o produto sumiria.

-- Pedidos de compra
SELECT CONCAT_WS(' - ', produto_id, descricao_produto) AS produto, pedido_id, qtde_pedida
FROM pedido_compra
ORDER BY pedido_id;

-- Produtos (cadastro)
SELECT CONCAT_WS(' - ', produto_id, descricao) AS produto, filial_id, estoque
FROM produtos_filial
ORDER BY filial_id, LENGTH(produto_id), produto_id;

-- Vendas: a tabela venda não tem descrição, então buscamos no cadastro (LEFT JOIN).
-- Produtos sem cadastro (P21..P28) aparecem só com o código: é o "onde houver".
SELECT CONCAT_WS(' - ', v.produto_id, p.descricao) AS produto, v.venda_id, v.qtde_vendida
FROM venda v
LEFT JOIN produtos_filial p
       ON p.produto_id = v.produto_id
      AND p.filial_id  = v.filial_id
ORDER BY v.venda_id;


-- ═════════════════════════════════════════════════════════════
-- 3.2  Datas no formato DD/MM/YYYY
-- ═════════════════════════════════════════════════════════════
-- Formatar só na saída. No banco a coluna continua DATE, para ordenar e filtrar certo
-- (como texto, '01/03/2025' < '28/02/2025' e a ordenação quebra).
SELECT pedido_id,
       TO_CHAR(data_pedido,  'DD/MM/YYYY') AS data_pedido,
       TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega
FROM pedido_compra
ORDER BY data_pedido;          -- ordena pela coluna DATE original, não pelo texto
-- MySQL: DATE_FORMAT(data_pedido, '%d/%m/%Y')

SELECT venda_id, TO_CHAR(data_emissao, 'DD/MM/YYYY') AS data_emissao
FROM venda
ORDER BY venda.data_emissao;
-- MySQL: DATE_FORMAT(data_emissao, '%d/%m/%Y')

SELECT nro_nfe, TO_CHAR(data_entrada, 'DD/MM/YYYY') AS data_entrada
FROM entradas_mercadoria
ORDER BY entradas_mercadoria.data_entrada;


-- ═════════════════════════════════════════════════════════════
-- 3.3  Só os produtos requisitados MAIS DE 10 VEZES no período
--      (consulta final no formato do exemplo do enunciado)
-- ═════════════════════════════════════════════════════════════
-- COMO INTERPRETEI "MAIS DE 10 VEZES":
--   Há duas leituras possíveis:
--     (a) o produto aparece em mais de 10 pedidos (COUNT de linhas);
--     (b) a quantidade total requisitada do produto passa de 10 unidades (SUM da qtde).
--   Na base, nenhum produto aparece em mais de 2 pedidos, então a leitura (a) devolve
--   ZERO linhas (a consulta de conferência logo abaixo prova isso). O exemplo do enunciado
--   também mostra "Qtde Requisitada = 15" na coluna de quantidade.
--   Por isso adotei a leitura (b): o produto entra no resultado quando a SOMA de qtde_pedida
--   dele no período é maior que 10. Cada linha mostra um pedido do produto, com a data.
--   Resultado na base atual: todos os 20 produtos passam do corte (o menor total é 12, do P3),
--   então o filtro não elimina ninguém. Se o corte fosse por fevereiro, também passariam todos
--   os que tiveram pedido em fevereiro.
--   Essa definição deve ser confirmada com o cliente (está na pauta da Parte 4).
--
-- PERÍODO: toda a base (pedidos de 01/01/2025 a 31/03/2025). Para olhar só fevereiro,
--   troque as duas datas do CTE "periodo".
WITH periodo AS (
    SELECT DATE '2025-01-01' AS inicio, DATE '2025-04-01' AS fim_exclusivo
),
pedidos_periodo AS (
    SELECT pc.*
    FROM pedido_compra pc, periodo
    WHERE pc.data_pedido >= periodo.inicio
      AND pc.data_pedido <  periodo.fim_exclusivo
),
produtos_mais_de_10 AS (
    SELECT produto_id
    FROM pedidos_periodo
    GROUP BY produto_id
    HAVING SUM(qtde_pedida) > 10
)
SELECT
    CONCAT_WS(' - ', pp.produto_id, pp.descricao_produto) AS "Produto",
    pp.qtde_pedida                                        AS "Qtde Requisitada",
    TO_CHAR(pp.data_pedido, 'DD/MM/YYYY')                 AS "Data Solicitação"
FROM pedidos_periodo pp
JOIN produtos_mais_de_10 m ON m.produto_id = pp.produto_id
ORDER BY LENGTH(pp.produto_id), pp.produto_id, pp.data_pedido;   -- LENGTH antes: P2 vem antes de P10
-- MySQL: troque TO_CHAR por DATE_FORMAT(pp.data_pedido, '%d/%m/%Y'),
--        DATE '2025-01-01' funciona igual, e as aspas duplas dos apelidos por crases (`Produto`).

-- Conferência da leitura (a): quantas vezes cada produto foi pedido. Maior valor = 2.
SELECT produto_id, COUNT(*) AS vezes_pedido, SUM(qtde_pedida) AS qtde_total
FROM pedido_compra
GROUP BY produto_id
ORDER BY vezes_pedido DESC, LENGTH(produto_id), produto_id;


-- ═════════════════════════════════════════════════════════════
-- 3.4  Trigger: gerar automaticamente um novo idfornecedor numérico em produtos_filial
-- ═════════════════════════════════════════════════════════════
-- Contexto: no DDL corrigido, fornecedor.idfornecedor é numérico (F1 -> 1) e
-- produtos_filial.idfornecedor tem FK para ele.
--
-- Regra: ao inserir um produto SEM idfornecedor, a trigger
--   1. pega o próximo número da sequência de fornecedor (sem MAX()+1, que dá número
--      repetido quando dois cadastros acontecem ao mesmo tempo);
--   2. cria o fornecedor com esse id (razão social provisória "A CADASTRAR", código 'F<n>'),
--      para a FK continuar válida;
--   3. grava o id no produto.
-- Se o produto vier com idfornecedor preenchido, a trigger não mexe; a FK garante que ele existe.

CREATE OR REPLACE FUNCTION public.fn_gera_idfornecedor()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    novo_id integer;
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        novo_id := nextval(pg_get_serial_sequence('public.fornecedor', 'idfornecedor'));

        INSERT INTO public.fornecedor (idfornecedor, codigo_origem, razao_social)
        VALUES (novo_id, 'F' || novo_id, 'A CADASTRAR (gerado para o produto ' || NEW.produto_id || ')');

        NEW.idfornecedor := novo_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gera_idfornecedor ON public.produtos_filial;
CREATE TRIGGER trg_gera_idfornecedor
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION public.fn_gera_idfornecedor();

-- Teste (dentro de transação desfeita no final, para não sujar a base):
BEGIN;
INSERT INTO produtos_filial (filial_id, produto_id, descricao, estoque, preco_unitario, preco_compra, preco_venda)
VALUES (1, 'P99', 'Produto teste trigger', 0, 0, 0, 0);

SELECT p.produto_id, p.idfornecedor, f.codigo_origem, f.razao_social
FROM produtos_filial p
JOIN fornecedor f ON f.idfornecedor = p.idfornecedor
WHERE p.produto_id = 'P99';          -- esperado: idfornecedor 21, código F21
ROLLBACK;
-- Obs.: o ROLLBACK desfaz o produto e o fornecedor, mas a sequência não volta (comportamento
-- normal do PostgreSQL). O próximo fornecedor gerado será 22: buraco na numeração não é erro.


-- ─────────────────────────────────────────────────────────────
-- Versão MySQL da trigger (rodar no MySQL, não no PostgreSQL).
-- No MySQL o AUTO_INCREMENT faz o papel da sequência e LAST_INSERT_ID() devolve o id criado.
-- ─────────────────────────────────────────────────────────────
/*
DROP TRIGGER IF EXISTS trg_gera_idfornecedor;
DELIMITER //
CREATE TRIGGER trg_gera_idfornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO fornecedor (razao_social)
        VALUES (CONCAT('A CADASTRAR (gerado para o produto ', NEW.produto_id, ')'));
        SET NEW.idfornecedor = LAST_INSERT_ID();
        UPDATE fornecedor SET codigo_origem = CONCAT('F', NEW.idfornecedor)
         WHERE idfornecedor = NEW.idfornecedor;
    END IF;
END//
DELIMITER ;
*/
