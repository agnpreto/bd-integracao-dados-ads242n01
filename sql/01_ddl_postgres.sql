-- ============================================================
-- DDL corrigido — PostgreSQL 18
-- Correções aplicadas sobre o DDL original:
--   * tipagem de identificadores/itens: float8 -> INTEGER
--   * nomes de colunas corrigidos (idforncedor, decricao, idfonecedor)
--   * PK de venda simplificada para venda_id
--   * FKs adicionadas (fornecedor, produtos_filial, pedido_compra,
--     entradas_mercadoria, venda)
--   * coluna ordem_compra criada em entradas_mercadoria
-- ============================================================

DROP TABLE IF EXISTS venda CASCADE;
DROP TABLE IF EXISTS entradas_mercadoria CASCADE;
DROP TABLE IF EXISTS pedido_compra CASCADE;
DROP TABLE IF EXISTS produtos_filial CASCADE;
DROP TABLE IF EXISTS fornecedor CASCADE;

CREATE TABLE fornecedor (
    idfornecedor   INTEGER PRIMARY KEY,
    nome           VARCHAR(120) NOT NULL,
    cnpj           VARCHAR(18),
    telefone       VARCHAR(20),
    email          VARCHAR(120),
    endereco       VARCHAR(200)
);

CREATE TABLE produtos_filial (
    filial_id      INTEGER NOT NULL,
    produto_id     VARCHAR(20) NOT NULL,
    descricao      VARCHAR(200) NOT NULL,
    idfornecedor   INTEGER NOT NULL,
    unidade_medida VARCHAR(10) NOT NULL,
    preco_unitario NUMERIC(12,2) NOT NULL,
    PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_filial_fornecedor
        FOREIGN KEY (idfornecedor) REFERENCES fornecedor(idfornecedor)
);

CREATE TABLE pedido_compra (
    pedido_id         INTEGER NOT NULL,
    fornecedor_id     INTEGER NOT NULL,
    item              INTEGER NOT NULL,
    produto_id        VARCHAR(20) NOT NULL,
    qtde_pedida       NUMERIC(12,3) NOT NULL,
    qtde_entregue     NUMERIC(12,3) NOT NULL DEFAULT 0,
    data_pedido       DATE NOT NULL,
    valor_unitario    NUMERIC(12,2) NOT NULL,
    PRIMARY KEY (pedido_id, item),
    CONSTRAINT fk_pedido_compra_fornecedor
        FOREIGN KEY (fornecedor_id) REFERENCES fornecedor(idfornecedor)
);

CREATE TABLE entradas_mercadoria (
    filial_id        INTEGER NOT NULL,
    fornecedor_id    INTEGER NOT NULL,
    produto_id       VARCHAR(20) NOT NULL,
    item             INTEGER NOT NULL,
    ordem_compra     INTEGER NOT NULL,
    data_entrada     DATE NOT NULL,
    qtde_entregue    NUMERIC(12,3) NOT NULL,
    valor_unitario   NUMERIC(12,2) NOT NULL,
    PRIMARY KEY (filial_id, fornecedor_id, produto_id, item, ordem_compra),
    CONSTRAINT fk_entradas_pedido_compra
        FOREIGN KEY (ordem_compra) REFERENCES pedido_compra(pedido_id),
    CONSTRAINT fk_entradas_produtos_filial
        FOREIGN KEY (filial_id, produto_id)
        REFERENCES produtos_filial(filial_id, produto_id)
);

CREATE TABLE venda (
    venda_id         INTEGER PRIMARY KEY,
    data_emissao     DATE NOT NULL,
    horariomov       TIME NOT NULL,
    produto_id       VARCHAR(20) NOT NULL,
    qtde_vendida     NUMERIC(12,3) NOT NULL,
    valor_unitario   NUMERIC(12,2) NOT NULL,
    filial_id        INTEGER NOT NULL,
    item             INTEGER NOT NULL,
    unidade_medida   VARCHAR(10) NOT NULL,
    CONSTRAINT fk_venda_produtos_filial
        FOREIGN KEY (filial_id, produto_id)
        REFERENCES produtos_filial(filial_id, produto_id)
);
