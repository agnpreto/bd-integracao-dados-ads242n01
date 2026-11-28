-- DDL Corrigido e Adaptado para MySQL

DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;

-- 1. Tabela Fornecedor
CREATE TABLE fornecedor (
    idfornecedor INT NOT NULL,
    razao_social VARCHAR(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Tabela Produtos por Filial
CREATE TABLE produtos_filial (
    filial_id INT NOT NULL,
    produto_id VARCHAR(255) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque DOUBLE DEFAULT 0 NOT NULL,
    preco_unitario DECIMAL(12, 4) DEFAULT 0 NOT NULL,
    preco_compra DECIMAL(12, 4) DEFAULT 0 NOT NULL,
    preco_venda DECIMAL(12, 4) DEFAULT 0 NOT NULL,
    idfornecedor INT NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (idfornecedor) REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Tabela Pedido de Compra
CREATE TABLE pedido_compra (
    pedido_id BIGINT DEFAULT 0 NOT NULL,
    data_pedido DATE NULL,
    item INT DEFAULT 0 NOT NULL,
    produto_id VARCHAR(25) DEFAULT '0' NOT NULL,
    descricao_produto VARCHAR(255) NULL,
    ordem_compra BIGINT DEFAULT 0 NOT NULL,
    qtde_pedida DOUBLE NULL,
    filial_id INT NULL,
    data_entrega DATE NULL,
    qtde_entregue DOUBLE DEFAULT 0 NOT NULL,
    qtde_pendente DOUBLE DEFAULT 0 NOT NULL,
    preco_compra DECIMAL(12, 4) DEFAULT 0 NULL,
    fornecedor_id INT DEFAULT 0 NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT fk_pedido_fornecedor FOREIGN KEY (fornecedor_id) REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Tabela Entradas de Mercadoria
CREATE TABLE entradas_mercadoria (
    data_entrada DATE NULL,
    nro_nfe VARCHAR(255) NOT NULL,
    item INT DEFAULT 0 NOT NULL,
    produto_id VARCHAR(25) DEFAULT '0' NOT NULL,
    descricao_produto VARCHAR(255) NULL,
    ordem_compra BIGINT DEFAULT 0 NOT NULL,
    qtde_recebida DOUBLE NULL,
    filial_id INT NULL,
    custo_unitario DECIMAL(12, 4) DEFAULT 0 NOT NULL,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Tabela Venda
CREATE TABLE venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov VARCHAR(8) DEFAULT '00:00:00' NOT NULL,
    produto_id VARCHAR(25) DEFAULT '' NOT NULL,
    qtde_vendida DOUBLE NULL,
    valor_unitario DECIMAL(12, 4) DEFAULT 0 NOT NULL,
    filial_id BIGINT DEFAULT 1 NOT NULL,
    item INT DEFAULT 0 NOT NULL,
    unidade_medida VARCHAR(3) NULL,
    CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;