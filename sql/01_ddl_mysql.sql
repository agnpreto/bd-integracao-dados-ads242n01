-- DDL corrigido para MySQL (sintaxe MySQL 8; testado no MariaDB 10.11)
-- Nome: Mateus Farias Bentes
--
-- Mesmas decisões do 01_ddl_postgres.sql. Diferenças de sintaxe em relação ao PostgreSQL:
--   * Sem schema "public." (no MySQL o schema é o próprio banco).
--   * Sem cast "::character varying" (sintaxe exclusiva do PostgreSQL).
--   * int8/float8 -> BIGINT/DOUBLE; aqui usamos INT e DECIMAL.
--   * IDENTITY -> AUTO_INCREMENT.
--   * Coluna calculada: GENERATED ALWAYS AS (...) STORED funciona igual.
--   * ENGINE=InnoDB para ter suporte a chave estrangeira.

DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;

CREATE TABLE fornecedor (
    idfornecedor  INT          NOT NULL AUTO_INCREMENT,
    codigo_origem VARCHAR(25)  NULL,
    razao_social  VARCHAR(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor),
    CONSTRAINT fornecedor_codigo_uk UNIQUE (codigo_origem)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE produtos_filial (
    filial_id      INT           NOT NULL,
    produto_id     VARCHAR(25)   NOT NULL,
    descricao      VARCHAR(255)  NOT NULL,
    estoque        DECIMAL(14,3) NOT NULL DEFAULT 0,
    preco_unitario DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_compra   DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_venda    DECIMAL(12,4) NOT NULL DEFAULT 0,
    idfornecedor   INT           NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT produtos_filial_fornecedor_fk FOREIGN KEY (idfornecedor)
        REFERENCES fornecedor (idfornecedor),
    CONSTRAINT produtos_filial_precos_ck CHECK (preco_unitario >= 0 AND preco_compra >= 0 AND preco_venda >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pedido_compra (
    pedido_id         INT           NOT NULL,
    data_pedido       DATE          NULL,
    item              INT           NOT NULL DEFAULT 0,
    produto_id        VARCHAR(25)   NOT NULL,
    descricao_produto VARCHAR(255)  NULL,
    ordem_compra      INT           NOT NULL DEFAULT 0,
    qtde_pedida       DECIMAL(14,3) NULL,
    filial_id         INT           NULL,
    data_entrega      DATE          NULL,
    qtde_entregue     DECIMAL(14,3) NOT NULL DEFAULT 0,
    qtde_pendente     DECIMAL(14,3) GENERATED ALWAYS AS (COALESCE(qtde_pedida, 0) - qtde_entregue) STORED,
    preco_compra      DECIMAL(12,4) NULL DEFAULT 0,
    fornecedor_id     INT           NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT pedido_compra_fornecedor_fk FOREIGN KEY (fornecedor_id)
        REFERENCES fornecedor (idfornecedor),
    INDEX pedido_compra_ordem_idx (ordem_compra)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE entradas_mercadoria (
    data_entrada      DATE          NULL,
    nro_nfe           VARCHAR(255)  NOT NULL,
    item              INT           NOT NULL DEFAULT 0,
    produto_id        VARCHAR(25)   NOT NULL,
    descricao_produto VARCHAR(255)  NULL,
    ordem_compra      INT           NOT NULL,
    qtde_recebida     DECIMAL(14,3) NULL,
    filial_id         INT           NULL,
    custo_unitario    DECIMAL(12,4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE venda (
    venda_id       BIGINT        NOT NULL,
    data_emissao   DATE          NOT NULL,
    horariomov     TIME          NOT NULL DEFAULT '00:00:00',
    produto_id     VARCHAR(25)   NOT NULL,
    qtde_vendida   DECIMAL(14,3) NULL,
    valor_unitario DECIMAL(12,4) NOT NULL DEFAULT 0,
    filial_id      INT           NOT NULL DEFAULT 1,
    item           INT           NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3)    NULL,
    CONSTRAINT venda_pkey PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    INDEX venda_data_idx (data_emissao),
    INDEX venda_produto_idx (produto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
