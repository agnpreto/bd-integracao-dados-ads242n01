-- =============================================================================
-- 01_ddl_mysql.sql — DDL corrigido para MySQL 8.0+ (InnoDB)
-- Projeto: Integração de Dados (ADS242N01) — Etapa 1
--
-- Mesmas correções do 01_ddl_postgres.sql, adaptadas ao MySQL:
--   * NUMERIC -> DECIMAL (sinônimo no MySQL, mas explícito para clareza);
--   * FLOAT  -> DECIMAL para quantidades/preços (evita erro de arredondamento);
--   * DOUBLE/FLOAT de identificadores -> BIGINT/INT;
--   * ENGINE=InnoDB (obrigatório para FOREIGN KEY);
--   * sem o schema "public."; PK/UNIQUE obrigam NOT NULL.
--
-- Uso: selecione o banco antes (CREATE DATABASE cambio; USE cambio;).
-- Para recriar do zero, rode na ordem inversa:
--   DROP TABLE IF EXISTS venda;
--   DROP TABLE IF EXISTS entradas_mercadoria;
--   DROP TABLE IF EXISTS pedido_compra;
--   DROP TABLE IF EXISTS produtos_filial;
--   DROP TABLE IF EXISTS fornecedor;
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fornecedor
-- Original: PK (idforncedor, idproduto) citava coluna inexistente e tinha typo.
-- -----------------------------------------------------------------------------
CREATE TABLE fornecedor (
    idfornecedor VARCHAR(25) NOT NULL,
    razao_social VARCHAR(255) NOT NULL,
    PRIMARY KEY (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- produtos_filial
-- Original: faltava vírgula antes do CONSTRAINT; PK citava idproduto;
--           decricao/idfonecedor (typos); DEFAULT '0' em coluna numérica.
-- -----------------------------------------------------------------------------
CREATE TABLE produtos_filial (
    filial_id INT NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque DECIMAL(12,3) NOT NULL DEFAULT 0,
    preco_unitario DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_compra DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_venda DECIMAL(12,4) NOT NULL DEFAULT 0,
    idfornecedor VARCHAR(25) NULL,
    PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT ck_produtos_filial_estoque CHECK (estoque >= 0),
    CONSTRAINT fk_produtos_filial_fornecedor
        FOREIGN KEY (idfornecedor) REFERENCES fornecedor (idfornecedor)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- pedido_compra
-- Original: pedido_id/ordem_compra/item eram FLOAT; fornecedor_id INT
--           incompatível com fornecedor.idfornecedor VARCHAR.
-- -----------------------------------------------------------------------------
CREATE TABLE pedido_compra (
    pedido_id BIGINT NOT NULL,
    data_pedido DATE NULL,
    item INT NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255) NULL,
    ordem_compra BIGINT NOT NULL DEFAULT 0,
    qtde_pedida DECIMAL(12,3) NULL,
    filial_id INT NULL,
    data_entrega DATE NULL,
    qtde_entregue DECIMAL(12,3) NOT NULL DEFAULT 0,
    qtde_pendente DECIMAL(12,3) NOT NULL DEFAULT 0,
    preco_compra DECIMAL(12,4) NULL DEFAULT 0,
    fornecedor_id VARCHAR(25) NULL,
    PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT ck_pedido_compra_qtde_pedida CHECK (qtde_pedida IS NULL OR qtde_pedida >= 0),
    CONSTRAINT ck_pedido_compra_qtde_entregue CHECK (qtde_entregue >= 0),
    CONSTRAINT ck_pedido_compra_preco CHECK (preco_compra IS NULL OR preco_compra >= 0),
    CONSTRAINT fk_pedido_compra_fornecedor
        FOREIGN KEY (fornecedor_id) REFERENCES fornecedor (idfornecedor)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- entradas_mercadoria
-- Original: PK citava ordem_compra, coluna não declarada -> CREATE falhava.
-- -----------------------------------------------------------------------------
CREATE TABLE entradas_mercadoria (
    data_entrada DATE NULL,
    nro_nfe VARCHAR(255) NOT NULL,
    item INT NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255) NULL,
    ordem_compra BIGINT NOT NULL,
    qtde_recebida DECIMAL(12,3) NULL,
    filial_id INT NULL,
    custo_unitario DECIMAL(12,4) NOT NULL DEFAULT 0,
    PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe),
    CONSTRAINT ck_entradas_qtde CHECK (qtde_recebida IS NULL OR qtde_recebida >= 0),
    CONSTRAINT ck_entradas_custo CHECK (custo_unitario >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- venda
-- Original: horariomov VARCHAR(8) -> TIME; qtde_vendida FLOAT -> DECIMAL;
--           filial_id BIGINT -> INT; PK renomeada de pk_consumo para pk_venda.
-- -----------------------------------------------------------------------------
CREATE TABLE venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov TIME NOT NULL DEFAULT '00:00:00',
    produto_id VARCHAR(25) NOT NULL DEFAULT '',
    qtde_vendida DECIMAL(12,3) NULL,
    valor_unitario DECIMAL(12,4) NOT NULL DEFAULT 0,
    filial_id INT NOT NULL DEFAULT 1,
    item INT NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3) NULL,
    PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    CONSTRAINT ck_venda_qtde CHECK (qtde_vendida IS NULL OR qtde_vendida >= 0),
    CONSTRAINT ck_venda_valor CHECK (valor_unitario >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- Pós-importação (dados com órfãos)
-- O MySQL 8 nao suporta NOT VALID. A FK equivalente so pode ser criada em tabela
-- vazia ou apos a limpeza dos orfaos (P21..P28). Rode apos a importacao limpa:
--   ALTER TABLE venda
--     ADD CONSTRAINT fk_venda_produto
--     FOREIGN KEY (filial_id, produto_id) REFERENCES produtos_filial (filial_id, produto_id);
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- Conferência rápida da estrutura criada
-- -----------------------------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('venda','pedido_compra','entradas_mercadoria','produtos_filial','fornecedor')
ORDER BY table_name;
