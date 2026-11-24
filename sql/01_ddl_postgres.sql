-- =============================================================================
-- 01_ddl_postgres.sql — DDL corrigido para PostgreSQL 16
-- Projeto: Integração de Dados (ADS242N01) — Etapa 1
--
-- Corrige os erros do arquivo original (sql/01_ddl_enunciado.sql), sem alterá-lo.
-- Cada correção está comentada junto do trecho correspondente.
--
-- Ordem de criação: fornecedor -> produtos_filial -> pedido_compra
--                   -> entradas_mercadoria -> venda
-- Para recriar do zero, rode (nessa ordem):
--   DROP TABLE IF EXISTS public.venda;
--   DROP TABLE IF EXISTS public.entradas_mercadoria;
--   DROP TABLE IF EXISTS public.pedido_compra;
--   DROP TABLE IF EXISTS public.produtos_filial;
--   DROP TABLE IF EXISTS public.fornecedor;
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fornecedor
-- Original: PK (idforncedor, idproduto) -> idproduto NÃO EXISTE na tabela.
--           Coluna escrita "idforncedor" (typo) -> corrigida para idfornecedor.
-- -----------------------------------------------------------------------------
CREATE TABLE public.fornecedor (
    idfornecedor varchar(25) NOT NULL,
    razao_social varchar(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

-- -----------------------------------------------------------------------------
-- produtos_filial
-- Original: faltava a vírgula antes de CONSTRAINT;
--           PK citava "idproduto" (não existe) -> agora (filial_id, produto_id);
--           "decricao" (typo)      -> descricao;
--           "idfonecedor" (typo)   -> idfornecedor;
--           preco_unitario float8 DEFAULT '0' (texto em coluna numérica) -> DEFAULT 0;
--           filial_id era NULL, mas faz parte da PK -> NOT NULL.
-- -----------------------------------------------------------------------------
CREATE TABLE public.produtos_filial (
    filial_id integer NOT NULL,
    produto_id varchar(25) NOT NULL,
    descricao varchar(255) NOT NULL,
    estoque numeric(12,3) NOT NULL DEFAULT 0,
    preco_unitario numeric(12,4) NOT NULL DEFAULT 0,
    preco_compra numeric(12,4) NOT NULL DEFAULT 0,
    preco_venda numeric(12,4) NOT NULL DEFAULT 0,
    idfornecedor varchar(25) NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT ck_produtos_filial_estoque CHECK (estoque >= 0),
    CONSTRAINT fk_produtos_filial_fornecedor
        FOREIGN KEY (idfornecedor) REFERENCES public.fornecedor (idfornecedor)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -----------------------------------------------------------------------------
-- pedido_compra
-- Original: pedido_id/ordem_compra/item eram float8 (identificadores não são reais);
--           fornecedor_id era int4, incompatível com fornecedor.idfornecedor (varchar);
--           não havia FK para fornecedor.
-- Nota: ordem_compra NÃO é único (11 pedidos têm ordem_compra = 0 por falta de
--       informação), por isso não há UNIQUE/FK em ordem_compra. Ver validar.sql.
-- -----------------------------------------------------------------------------
CREATE TABLE public.pedido_compra (
    pedido_id bigint NOT NULL,
    data_pedido date NULL,
    item integer NOT NULL DEFAULT 0,
    produto_id varchar(25) NOT NULL DEFAULT '0',
    descricao_produto varchar(255) NULL,
    ordem_compra bigint NOT NULL DEFAULT 0,
    qtde_pedida numeric(12,3) NULL,
    filial_id integer NULL,
    data_entrega date NULL,
    qtde_entregue numeric(12,3) NOT NULL DEFAULT 0,
    qtde_pendente numeric(12,3) NOT NULL DEFAULT 0,
    preco_compra numeric(12,4) NULL DEFAULT 0,
    fornecedor_id varchar(25) NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT ck_pedido_compra_qtde_pedida CHECK (qtde_pedida IS NULL OR qtde_pedida >= 0),
    CONSTRAINT ck_pedido_compra_qtde_entregue CHECK (qtde_entregue >= 0),
    CONSTRAINT ck_pedido_compra_preco CHECK (preco_compra IS NULL OR preco_compra >= 0),
    CONSTRAINT fk_pedido_compra_fornecedor
        FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedor (idfornecedor)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -----------------------------------------------------------------------------
-- entradas_mercadoria
-- Original: a PK citava "ordem_compra", coluna que NÃO EXISTIA na tabela
--           -> CREATE falhava. Coluna adicionada como bigint NOT NULL.
-- Nota: não há FK para pedido_compra porque a ligação lógica
--       (ordem_compra) não é única no pedido e 2 entradas ficam órfãs
--       (ordens 19 e 20, cujos pedidos vieram com ordem_compra = 0).
-- -----------------------------------------------------------------------------
CREATE TABLE public.entradas_mercadoria (
    data_entrada date NULL,
    nro_nfe varchar(255) NOT NULL,
    item integer NOT NULL DEFAULT 0,
    produto_id varchar(25) NOT NULL DEFAULT '0',
    descricao_produto varchar(255) NULL,
    ordem_compra bigint NOT NULL,
    qtde_recebida numeric(12,3) NULL,
    filial_id integer NULL,
    custo_unitario numeric(12,4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey
        PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe),
    CONSTRAINT ck_entradas_qtde CHECK (qtde_recebida IS NULL OR qtde_recebida >= 0),
    CONSTRAINT ck_entradas_custo CHECK (custo_unitario >= 0)
);

-- -----------------------------------------------------------------------------
-- venda
-- Original: horariomov varchar(8) -> time; qtde_vendida float8 -> numeric(12,3);
--           valor_unitario numeric(12,4) mantido; filial_id int8 -> integer;
--           PK renomeada de pk_consumo para pk_venda (o nome original confundia).
-- Nota: não há FK de produto_id para produtos_filial porque existem vendas de
--       P21..P28 sem cadastro em produtos_filial (ver validar.sql).
-- -----------------------------------------------------------------------------
CREATE TABLE public.venda (
    venda_id bigint NOT NULL,
    data_emissao date NOT NULL,
    horariomov time NOT NULL DEFAULT '00:00:00',
    produto_id varchar(25) NOT NULL DEFAULT '',
    qtde_vendida numeric(12,3) NULL,
    valor_unitario numeric(12,4) NOT NULL DEFAULT 0,
    filial_id integer NOT NULL DEFAULT 1,
    item integer NOT NULL DEFAULT 0,
    unidade_medida varchar(3) NULL,
    CONSTRAINT pk_venda PRIMARY KEY
        (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    CONSTRAINT ck_venda_qtde CHECK (qtde_vendida IS NULL OR qtde_vendida >= 0),
    CONSTRAINT ck_venda_valor CHECK (valor_unitario >= 0)
);

-- -----------------------------------------------------------------------------
-- Pós-importação (dados com órfãos)
-- fk_venda_produto é criada DEPOIS da importação, como NOT VALID, porque 13
-- vendas referenciam P21..P28 inexistentes em produtos_filial. NOT VALID mantém
-- os dados existentes e passa a validar apenas novas inserções/atualizações.
-- Rode após `python scripts/importar.py`:
--   ALTER TABLE public.venda
--     ADD CONSTRAINT fk_venda_produto
--     FOREIGN KEY (filial_id, produto_id)
--     REFERENCES public.produtos_filial (filial_id, produto_id) NOT VALID;
-- Para validar depois (quando os órfãos forem resolvidos):
--   ALTER TABLE public.venda VALIDATE CONSTRAINT fk_venda_produto;
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- Conferência rápida da estrutura criada
-- -----------------------------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('venda','pedido_compra','entradas_mercadoria','produtos_filial','fornecedor')
ORDER BY table_name;
