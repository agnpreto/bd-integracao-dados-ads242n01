
-- ============================================================
-- PARTE 1 - ESTRUTURA DO BANCO
-- Projeto: Integracao de Dados - ADS242N01
-- SGBD: MySQL 8.0
-- ============================================================

CREATE TABLE fornecedor (
    idfornecedor VARCHAR(25) NOT NULL,
    razao_social VARCHAR(255) NOT NULL,
    PRIMARY KEY (idfornecedor)
);

CREATE TABLE produtos_filial (
    filial_id INT NOT NULL,
    produto_id VARCHAR(255) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque DOUBLE NOT NULL DEFAULT 0,
    preco_unitario DOUBLE NOT NULL DEFAULT 0,
    preco_compra DOUBLE NOT NULL DEFAULT 0,
    preco_venda DOUBLE NOT NULL DEFAULT 0,
    idfornecedor VARCHAR(25),

    PRIMARY KEY (filial_id, produto_id),

    CONSTRAINT fk_produtos_fornecedor
        FOREIGN KEY (idfornecedor)
        REFERENCES fornecedor (idfornecedor)
);

CREATE TABLE pedido_compra (
    pedido_id DOUBLE NOT NULL DEFAULT 0,
    data_pedido DATE,
    item DOUBLE NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255),
    ordem_compra DOUBLE NOT NULL DEFAULT 0,
    qtde_pedida DOUBLE,
    filial_id INT,
    data_entrega DATE,
    qtde_entregue DOUBLE NOT NULL DEFAULT 0,
    qtde_pendente DOUBLE NOT NULL DEFAULT 0,
    preco_compra DOUBLE DEFAULT 0,
    fornecedor_id INT DEFAULT 0,

    PRIMARY KEY (pedido_id, produto_id, item)
);

CREATE TABLE entradas_mercadoria (
    data_entrada DATE,
    nro_nfe VARCHAR(255) NOT NULL,
    item DOUBLE NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255),
    ordem_compra DOUBLE NOT NULL DEFAULT 0,
    qtde_recebida DOUBLE,
    filial_id INT,
    custo_unitario DECIMAL(12, 4) NOT NULL DEFAULT 0,

    PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

CREATE TABLE venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov VARCHAR(8) NOT NULL DEFAULT '00:00:00',
    produto_id VARCHAR(25) NOT NULL DEFAULT '',
    qtde_vendida DOUBLE,
    valor_unitario DECIMAL(12, 4) NOT NULL DEFAULT 0,
    filial_id BIGINT NOT NULL DEFAULT 1,
    item INT NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3),

    PRIMARY KEY (
        filial_id,
        venda_id,
        data_emissao,
        produto_id,
        item,
        horariomov
    )
);
