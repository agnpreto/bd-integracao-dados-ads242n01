-- 01_ddl_mysql.sql
-- DDL corrigido para MySQL 8 (testado em MariaDB/MySQL compatível)
-- Autor: João Gustavo Gonçalves Vasconcelos (2408298)
-- Mesmas correções do PostgreSQL (ver 01_ddl_postgres.sql e docs/parte1_importacao.md).
-- Diferenças de sintaxe: sem schema "public.", AUTO_INCREMENT no lugar de IDENTITY,
-- DECIMAL no lugar de NUMERIC, BIGINT/INT no lugar de int8/int4.

DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;

CREATE TABLE fornecedor (
    idfornecedor  INT NOT NULL AUTO_INCREMENT,
    razao_social  VARCHAR(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
) ENGINE=InnoDB;

CREATE TABLE produtos_filial (
    filial_id       INT           NOT NULL,
    produto_id      VARCHAR(25)   NOT NULL,
    descricao       VARCHAR(255)  NOT NULL,
    estoque         DECIMAL(14,3) NOT NULL DEFAULT 0,
    preco_unitario  DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_compra    DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_venda     DECIMAL(12,4) NOT NULL DEFAULT 0,
    idfornecedor    INT           NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (idfornecedor) REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB;

CREATE TABLE pedido_compra (
    pedido_id          BIGINT        NOT NULL DEFAULT 0,
    data_pedido        DATE          NULL,
    item               INT           NOT NULL DEFAULT 0,
    produto_id         VARCHAR(25)   NOT NULL DEFAULT '0',
    descricao_produto  VARCHAR(255)  NULL,
    ordem_compra       BIGINT        NOT NULL DEFAULT 0,
    qtde_pedida        DECIMAL(14,3) NULL,
    filial_id          INT           NULL,
    data_entrega       DATE          NULL,
    qtde_entregue      DECIMAL(14,3) NOT NULL DEFAULT 0,
    qtde_pendente      DECIMAL(14,3) NOT NULL DEFAULT 0,
    preco_compra       DECIMAL(12,4) NULL DEFAULT 0,
    fornecedor_id      INT           NULL DEFAULT 0,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    INDEX idx_pedido_ordem (ordem_compra)
) ENGINE=InnoDB;

CREATE TABLE entradas_mercadoria (
    data_entrada       DATE          NULL,
    nro_nfe            VARCHAR(255)  NOT NULL,
    item               INT           NOT NULL DEFAULT 0,
    produto_id         VARCHAR(25)   NOT NULL DEFAULT '0',
    descricao_produto  VARCHAR(255)  NULL,
    ordem_compra       BIGINT        NOT NULL DEFAULT 0,
    qtde_recebida      DECIMAL(14,3) NULL,
    filial_id          INT           NULL,
    custo_unitario     DECIMAL(12,4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe(100)),
    INDEX idx_entradas_ordem (ordem_compra)
) ENGINE=InnoDB;

CREATE TABLE venda (
    venda_id        BIGINT        NOT NULL,
    data_emissao    DATE          NOT NULL,
    horariomov      VARCHAR(8)    NOT NULL DEFAULT '00:00:00',
    produto_id      VARCHAR(25)   NOT NULL DEFAULT '',
    qtde_vendida    DECIMAL(14,3) NULL,
    valor_unitario  DECIMAL(12,4) NOT NULL DEFAULT 0,
    filial_id       BIGINT        NOT NULL DEFAULT 1,
    item            INT           NOT NULL DEFAULT 0,
    unidade_medida  VARCHAR(3)    NULL,
    CONSTRAINT pk_venda PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    INDEX idx_venda_data (data_emissao)
) ENGINE=InnoDB;
