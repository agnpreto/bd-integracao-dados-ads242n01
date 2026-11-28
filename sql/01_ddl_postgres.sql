-- DDL Corrigido para PostgreSQL
-- Ordem de criacao ajustada para respeitar integridade referencial (FK)

DROP TABLE IF EXISTS public.venda CASCADE;
DROP TABLE IF EXISTS public.entradas_mercadoria CASCADE;
DROP TABLE IF EXISTS public.pedido_compra CASCADE;
DROP TABLE IF EXISTS public.produtos_filial CASCADE;
DROP TABLE IF EXISTS public.fornecedor CASCADE;

-- 1. Tabela Fornecedor (corrigido nome idforncedor -> idfornecedor, tipo para int4 e PK)
CREATE TABLE public.fornecedor (
    idfornecedor int4 NOT NULL,
    razao_social varchar(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

-- 2. Tabela Produtos por Filial (corrigido decricao -> descricao, idfonecedor -> idfornecedor, virgula da PK e colunas da PK)
CREATE TABLE public.produtos_filial (
    filial_id int4 NOT NULL,
    produto_id varchar(255) NOT NULL,
    descricao varchar(255) NOT NULL,
    estoque float8 DEFAULT 0 NOT NULL,
    preco_unitario numeric(12, 4) DEFAULT 0 NOT NULL,
    preco_compra numeric(12, 4) DEFAULT 0 NOT NULL,
    preco_venda numeric(12, 4) DEFAULT 0 NOT NULL,
    idfornecedor int4 NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (idfornecedor) REFERENCES public.fornecedor (idfornecedor)
);

-- 3. Tabela Pedido de Compra
CREATE TABLE public.pedido_compra (
    pedido_id int8 DEFAULT 0 NOT NULL,
    data_pedido date NULL,
    item int4 DEFAULT 0 NOT NULL,
    produto_id varchar(25) DEFAULT '0' NOT NULL,
    descricao_produto varchar(255) NULL,
    ordem_compra int8 DEFAULT 0 NOT NULL,
    qtde_pedida float8 NULL,
    filial_id int4 NULL,
    data_entrega date NULL,
    qtde_entregue float8 DEFAULT 0 NOT NULL,
    qtde_pendente float8 DEFAULT 0 NOT NULL,
    preco_compra numeric(12, 4) DEFAULT 0 NULL,
    fornecedor_id int4 DEFAULT 0 NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT fk_pedido_fornecedor FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedor (idfornecedor)
);

-- 4. Tabela Entradas de Mercadoria (adicionada coluna ordem_compra exigida pela PK e regra de negocio)
CREATE TABLE public.entradas_mercadoria (
    data_entrada date NULL,
    nro_nfe varchar(255) NOT NULL,
    item int4 DEFAULT 0 NOT NULL,
    produto_id varchar(25) DEFAULT '0' NOT NULL,
    descricao_produto varchar(255) NULL,
    ordem_compra int8 DEFAULT 0 NOT NULL,
    qtde_recebida float8 NULL,
    filial_id int4 NULL,
    custo_unitario numeric(12, 4) DEFAULT 0 NOT NULL,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

-- 5. Tabela Venda
CREATE TABLE public.venda (
    venda_id int8 NOT NULL,
    data_emissao date NOT NULL,
    horariomov varchar(8) DEFAULT '00:00:00' NOT NULL,
    produto_id varchar(25) DEFAULT '' NOT NULL,
    qtde_vendida float8 NULL,
    valor_unitario numeric(12, 4) DEFAULT 0 NOT NULL,
    filial_id int8 DEFAULT 1 NOT NULL,
    item int4 DEFAULT 0 NOT NULL,
    unidade_medida varchar(3) NULL,
    CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);