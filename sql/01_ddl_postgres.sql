-- ============================================================
-- DDL — PostgreSQL 18
-- Schema derivado do arquivo dados/base_teste.xlsx (5 abas).
-- FKs criadas como NOT VALID após o load, porque a base de
-- teste contém inconsistências intencionais (vendas P21–P28 e
-- filiais 2/3 sem cadastro em produtos_filial; ver Parte 4).
-- ============================================================

DROP TABLE IF EXISTS venda CASCADE;
DROP TABLE IF EXISTS entradas_mercadoria CASCADE;
DROP TABLE IF EXISTS pedido_compra CASCADE;
DROP TABLE IF EXISTS produtos_filial CASCADE;
DROP TABLE IF EXISTS fornecedor CASCADE;

CREATE TABLE fornecedor (
    idfornecedor  VARCHAR(10)  PRIMARY KEY,
    razao_social  VARCHAR(120) NOT NULL
);

CREATE TABLE produtos_filial (
    filial_id       INTEGER       NOT NULL,
    produto_id      VARCHAR(20)   NOT NULL,
    descricao       VARCHAR(200)  NOT NULL,
    estoque         INTEGER,
    preco_unitario  NUMERIC(12,2),
    preco_compra    NUMERIC(12,2),
    preco_venda     NUMERIC(12,2),
    idfornecedor    VARCHAR(10),
    PRIMARY KEY (filial_id, produto_id)
);

CREATE TABLE pedido_compra (
    pedido_id         INTEGER       NOT NULL,
    item              INTEGER       NOT NULL,
    data_pedido       DATE          NOT NULL,
    produto_id        VARCHAR(20)   NOT NULL,
    descricao_produto VARCHAR(200),
    ordem_compra      INTEGER,
    qtde_pedida       NUMERIC(12,3) NOT NULL,
    filial_id         INTEGER       NOT NULL,
    data_entrega      DATE,
    qtde_entregue     NUMERIC(12,3) DEFAULT 0,
    preco_compra      NUMERIC(12,2),
    fornecedor_id     VARCHAR(10),
    PRIMARY KEY (pedido_id, item)
);

CREATE TABLE entradas_mercadoria (
    nro_nfe           VARCHAR(20)   NOT NULL,
    item              INTEGER       NOT NULL,
    data_entrada      DATE          NOT NULL,
    produto_id        VARCHAR(20)   NOT NULL,
    descricao_produto VARCHAR(200),
    ordem_compra      INTEGER,
    qtde_recebida     NUMERIC(12,3) NOT NULL,
    filial_id         INTEGER       NOT NULL,
    custo_unitario    NUMERIC(12,2),
    PRIMARY KEY (nro_nfe, item)
);

CREATE TABLE venda (
    venda_id         INTEGER PRIMARY KEY,
    data_emissao     DATE          NOT NULL,
    horariomov       TIME          NOT NULL,
    produto_id       VARCHAR(20)   NOT NULL,
    qtde_vendida     NUMERIC(12,3) NOT NULL,
    valor_unitario   NUMERIC(12,2) NOT NULL,
    filial_id        INTEGER       NOT NULL,
    item             INTEGER       NOT NULL,
    unidade_medida   VARCHAR(10)   NOT NULL
);

-- FKs em NOT VALID: preserva o load e permite medir violações depois
ALTER TABLE produtos_filial
    ADD CONSTRAINT fk_produtos_filial_fornecedor
    FOREIGN KEY (idfornecedor) REFERENCES fornecedor(idfornecedor) NOT VALID;

ALTER TABLE pedido_compra
    ADD CONSTRAINT fk_pedido_compra_produtos_filial
    FOREIGN KEY (filial_id, produto_id)
    REFERENCES produtos_filial(filial_id, produto_id) NOT VALID;

ALTER TABLE pedido_compra
    ADD CONSTRAINT fk_pedido_compra_fornecedor
    FOREIGN KEY (fornecedor_id) REFERENCES fornecedor(idfornecedor) NOT VALID;

ALTER TABLE entradas_mercadoria
    ADD CONSTRAINT fk_entradas_pedido_compra
    FOREIGN KEY (ordem_compra) REFERENCES pedido_compra(pedido_id) NOT VALID;

ALTER TABLE entradas_mercadoria
    ADD CONSTRAINT fk_entradas_produtos_filial
    FOREIGN KEY (filial_id, produto_id)
    REFERENCES produtos_filial(filial_id, produto_id) NOT VALID;

ALTER TABLE venda
    ADD CONSTRAINT fk_venda_produtos_filial
    FOREIGN KEY (filial_id, produto_id)
    REFERENCES produtos_filial(filial_id, produto_id) NOT VALID;
