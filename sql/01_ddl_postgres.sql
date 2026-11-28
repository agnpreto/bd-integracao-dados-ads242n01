-- DDL corrigido para PostgreSQL

CREATE TABLE IF NOT EXISTS public.fornecedor (
    idfornecedor VARCHAR(25) NOT NULL,
    idfornecedor_num INTEGER UNIQUE,
    razao_social VARCHAR(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

CREATE TABLE IF NOT EXISTS public.produtos_filial (
    filial_id INT4 NOT NULL,
    produto_id VARCHAR(255) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque FLOAT8 NOT NULL DEFAULT 0,
    preco_unitario FLOAT8 NOT NULL DEFAULT 0,
    preco_compra FLOAT8 NOT NULL DEFAULT 0,
    preco_venda FLOAT8 NOT NULL DEFAULT 0,
    idfornecedor VARCHAR(25) NULL,
    idfornecedor_num INT4 NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_filial_fornecedor_num
        FOREIGN KEY (idfornecedor_num) REFERENCES public.fornecedor (idfornecedor_num)
);

CREATE TABLE IF NOT EXISTS public.pedido_compra (
    pedido_id FLOAT8 NOT NULL DEFAULT 0,
    data_pedido DATE NULL,
    item FLOAT8 NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255) NULL,
    ordem_compra FLOAT8 NOT NULL DEFAULT 0,
    qtde_pedida FLOAT8 NULL,
    filial_id INT4 NULL,
    data_entrega DATE NULL,
    qtde_entregue FLOAT8 NOT NULL DEFAULT 0,
    qtde_pendente FLOAT8 NOT NULL DEFAULT 0,
    preco_compra FLOAT8 NULL DEFAULT 0,
    fornecedor_id INT4 NULL DEFAULT 0,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item)
);

CREATE TABLE IF NOT EXISTS public.entradas_mercadoria (
    ordem_compra FLOAT8 NOT NULL DEFAULT 0,
    data_entrada DATE NULL,
    nro_nfe VARCHAR(255) NOT NULL,
    item FLOAT8 NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255) NULL,
    qtde_recebida FLOAT8 NULL,
    filial_id INT4 NULL,
    custo_unitario NUMERIC(12, 4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

CREATE TABLE IF NOT EXISTS public.venda (
    venda_id INT8 NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov VARCHAR(8) NOT NULL DEFAULT '00:00:00',
    produto_id VARCHAR(25) NOT NULL DEFAULT '',
    qtde_vendida FLOAT8 NULL,
    valor_unitario NUMERIC(12, 4) NOT NULL DEFAULT 0,
    filial_id INT8 NOT NULL DEFAULT 1,
    item INT4 NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3) NULL,
    CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);
