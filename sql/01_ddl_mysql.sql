-- DDL corrigido para MySQL 8
-- Origem: sql/01_ddl_enunciado.sql, que e PostgreSQL puro (int8, float8,
-- schema public., casts '::character varying'). Aqui os tipos foram trocados
-- pelos equivalentes do MySQL e os mesmos erros do original foram corrigidos.
-- Detalhes em docs/parte1_importacao.md.
--
-- Como executar:
--   mysql -u root -p -e "CREATE DATABASE base_teste CHARACTER SET utf8mb4"
--   mysql -u root -p base_teste < sql/01_ddl_mysql.sql
--
-- Mesmas decisoes do DDL PostgreSQL:
--   * ids de fornecedor INT; fornecedor com AUTO_INCREMENT a partir de 21;
--   * sem FK em venda.produto_id e entradas_mercadoria.ordem_compra, porque a
--     base de teste tem registros orfaos (ver sql/04_validacao.sql).

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE fornecedor (
    idfornecedor INT          NOT NULL AUTO_INCREMENT,
    razao_social VARCHAR(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
) ENGINE = InnoDB AUTO_INCREMENT = 21 DEFAULT CHARSET = utf8mb4;

CREATE TABLE produtos_filial (
    filial_id      INT          NOT NULL,
    produto_id     VARCHAR(25)  NOT NULL,
    descricao      VARCHAR(255) NOT NULL,
    estoque        DOUBLE       NOT NULL DEFAULT 0,
    preco_unitario DOUBLE       NOT NULL DEFAULT 0,
    preco_compra   DOUBLE       NOT NULL DEFAULT 0,
    preco_venda    DOUBLE       NOT NULL DEFAULT 0,
    idfornecedor   INT          NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT produtos_filial_fornecedor_fk
        FOREIGN KEY (idfornecedor) REFERENCES fornecedor (idfornecedor)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE pedido_compra (
    pedido_id         BIGINT       NOT NULL,
    data_pedido       DATE         NULL,
    item              INT          NOT NULL DEFAULT 0,
    produto_id        VARCHAR(25)  NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255) NULL,
    ordem_compra      BIGINT       NOT NULL DEFAULT 0,
    qtde_pedida       DOUBLE       NULL,
    filial_id         INT          NULL,
    data_entrega      DATE         NULL,
    qtde_entregue     DOUBLE       NOT NULL DEFAULT 0,
    qtde_pendente     DOUBLE       NOT NULL DEFAULT 0,
    preco_compra      DOUBLE       NULL DEFAULT 0,
    fornecedor_id     INT          NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT pedido_compra_fornecedor_fk
        FOREIGN KEY (fornecedor_id) REFERENCES fornecedor (idfornecedor),
    INDEX ix_pedido_compra_ordem (ordem_compra, item, produto_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE entradas_mercadoria (
    data_entrada      DATE           NULL,
    nro_nfe           VARCHAR(255)   NOT NULL,
    item              INT            NOT NULL DEFAULT 0,
    produto_id        VARCHAR(25)    NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255)   NULL,
    ordem_compra      BIGINT         NOT NULL DEFAULT 0,
    qtde_recebida     DOUBLE         NULL,
    filial_id         INT            NULL,
    custo_unitario    DECIMAL(12, 4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey
        PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE venda (
    venda_id       BIGINT         NOT NULL,
    data_emissao   DATE           NOT NULL,
    horariomov     VARCHAR(8)     NOT NULL DEFAULT '00:00:00',
    produto_id     VARCHAR(25)    NOT NULL DEFAULT '',
    qtde_vendida   DOUBLE         NULL,
    valor_unitario DECIMAL(12, 4) NOT NULL DEFAULT 0,
    filial_id      BIGINT         NOT NULL DEFAULT 1,
    item           INT            NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3)     NULL,
    CONSTRAINT pk_consumo
        PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    INDEX ix_venda_data_emissao (data_emissao)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
