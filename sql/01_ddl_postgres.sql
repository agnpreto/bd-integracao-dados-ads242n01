CREATE TABLE fornecedor (
    idfornecedor VARCHAR(25) NOT NULL,
    razao_social VARCHAR(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

CREATE TABLE produtos_filial (
    filial_id INTEGER NOT NULL,
    produto_id VARCHAR(255) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque DOUBLE PRECISION NOT NULL DEFAULT 0,
    preco_unitario DOUBLE PRECISION NOT NULL DEFAULT 0,
    preco_compra DOUBLE PRECISION NOT NULL DEFAULT 0,
    preco_venda DOUBLE PRECISION NOT NULL DEFAULT 0,
    idfornecedor VARCHAR(25),
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id)
);

CREATE TABLE pedido_compra (
    pedido_id DOUBLE PRECISION NOT NULL DEFAULT 0,
    data_pedido DATE,
    item DOUBLE PRECISION NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255),
    ordem_compra DOUBLE PRECISION NOT NULL DEFAULT 0,
    qtde_pedida DOUBLE PRECISION,
    filial_id INTEGER,
    data_entrega DATE,
    qtde_entregue DOUBLE PRECISION NOT NULL DEFAULT 0,
    qtde_pendente DOUBLE PRECISION NOT NULL DEFAULT 0,
    preco_compra DOUBLE PRECISION DEFAULT 0,
    fornecedor_id INTEGER DEFAULT 0,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item)
);

CREATE TABLE entradas_mercadoria (
    data_entrada DATE,
    nro_nfe VARCHAR(255) NOT NULL,
    item DOUBLE PRECISION NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255),
    ordem_compra DOUBLE PRECISION NOT NULL DEFAULT 0,
    qtde_recebida DOUBLE PRECISION,
    filial_id INTEGER,
    custo_unitario NUMERIC(12, 4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey
        PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

CREATE TABLE venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov VARCHAR(8) NOT NULL DEFAULT '00:00:00',
    produto_id VARCHAR(25) NOT NULL DEFAULT '',
    qtde_vendida DOUBLE PRECISION,
    valor_unitario NUMERIC(12, 4) NOT NULL DEFAULT 0,
    filial_id BIGINT NOT NULL DEFAULT 1,
    item INTEGER NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3),
    CONSTRAINT pk_consumo
        PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);-- DDL corrigido para PostgreSQL
