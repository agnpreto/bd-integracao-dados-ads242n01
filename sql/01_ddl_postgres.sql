--- DDL corrigido para PostgreSQL

CREATE TABLE IF NOT EXISTS public.fornecedor (
    idfornecedor varchar(25) NOT NULL,
    razao_social varchar(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

CREATE TABLE IF NOT EXISTS public.produtos_filial (
    filial_id int4 NOT NULL,
    produto_id varchar(255) NOT NULL,
    descricao_produto varchar(255) NOT NULL,
    estoque float8 NOT NULL DEFAULT 0,
    preco_unitario float8 NOT NULL DEFAULT 0,
    preco_compra float8 NOT NULL DEFAULT 0,
    preco_venda float8 NOT NULL DEFAULT 0,
    idfornecedor varchar(25) NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_filial_fornecedor
        FOREIGN KEY (idfornecedor) REFERENCES public.fornecedor (idfornecedor)
);

CREATE TABLE IF NOT EXISTS public.pedido_compra (
    pedido_id float8 NOT NULL DEFAULT 0,
    data_pedido date NULL,
    item float8 NOT NULL DEFAULT 0,
    produto_id varchar(25) NOT NULL DEFAULT '0',
    descricao_produto varchar(255) NULL,
    ordem_compra float8 NOT NULL DEFAULT 0,
    qtde_pedida float8 NULL,
    filial_id int4 NULL,
    data_entrega date NULL,
    qtde_entregue float8 NOT NULL DEFAULT 0,
    qtde_pendente float8 NOT NULL DEFAULT 0,
    preco_compra float8 NULL DEFAULT 0,
    fornecedor_id int4 NULL DEFAULT 0,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item)
);

CREATE TABLE IF NOT EXISTS public.entradas_mercadoria (
    ordem_compra float8 NOT NULL DEFAULT 0,
    data_entrada date NULL,
    nro_nfe varchar(255) NOT NULL,
    item float8 NOT NULL DEFAULT 0,
    produto_id varchar(25) NOT NULL DEFAULT '0',
    descricao_produto varchar(255) NULL,
    qtde_recebida float8 NULL,
    filial_id int4 NULL,
    custo_unitario numeric(12, 4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

CREATE TABLE IF NOT EXISTS public.venda (
    venda_id int8 NOT NULL,
    data_emissao date NOT NULL,
    horariomov varchar(8) NOT NULL DEFAULT '00:00:00',
    produto_id varchar(25) NOT NULL DEFAULT '',
    qtde_vendida float8 NULL,
    valor_unitario numeric(12, 4) NOT NULL DEFAULT 0,
    filial_id int8 NOT NULL DEFAULT 1,
    item int4 NOT NULL DEFAULT 0,
    unidade_medida varchar(3) NULL,
    CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);
 DDL corrigido para PostgreSQL
