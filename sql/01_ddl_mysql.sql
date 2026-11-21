-- DDL corrigido para MySQL (testado para MySQL 8 / MySQL Workbench)
-- Cada correção em relação ao 01_ddl_enunciado.sql está comentada.
-- Detalhes em docs/parte1_importacao.md.

CREATE DATABASE IF NOT EXISTS integracao_dados
  DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE integracao_dados;

-- Ordem de remoção respeita as chaves estrangeiras (permite rodar o script de novo)
DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;

-- ── fornecedor ──────────────────────────────────────────────
-- Erros corrigidos:
--   * "idforncedor" (digitação)            -> idfornecedor
--   * PK usava "idproduto", que não existe; fornecedor não depende de produto
--     -> PK só em idfornecedor
--   * "public." é schema do PostgreSQL      -> removido
-- idfornecedor continua texto: na planilha os códigos são "F1", "F2"...
CREATE TABLE fornecedor (
  idfornecedor  VARCHAR(25)  NOT NULL,
  razao_social  VARCHAR(255) NOT NULL,
  CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

-- ── produtos_filial ────────────────────────────────────────
-- Erros corrigidos:
--   * faltava a vírgula depois de "idfonecedor int4 NULL"
--   * "decricao" -> descricao ; "idfonecedor" -> idfornecedor
--   * PK usava "idproduto", que não existe -> produto_id
--   * filial_id NULL dentro da PK (erro 1171 no MySQL) -> NOT NULL
--   * produto_id varchar(255) -> varchar(25), igual às outras tabelas
--   * DEFAULT '0' (texto) em coluna numérica -> DEFAULT 0
--   * idfornecedor int4, mas fornecedor.idfornecedor é texto ("F8")
--     -> VARCHAR(25) com chave estrangeira para fornecedor
--   * float8 em preços -> DECIMAL(12,4) (float gera erro de arredondamento em dinheiro)
CREATE TABLE produtos_filial (
  filial_id       INT            NOT NULL,
  produto_id      VARCHAR(25)    NOT NULL,
  descricao       VARCHAR(255)   NOT NULL,
  estoque         DECIMAL(12,3)  NOT NULL DEFAULT 0,
  preco_unitario  DECIMAL(12,4)  NOT NULL DEFAULT 0,
  preco_compra    DECIMAL(12,4)  NOT NULL DEFAULT 0,
  preco_venda     DECIMAL(12,4)  NOT NULL DEFAULT 0,
  idfornecedor    VARCHAR(25)    NULL,
  CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
  CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (idfornecedor)
    REFERENCES fornecedor (idfornecedor)
);

-- ── pedido_compra ──────────────────────────────────────────
-- Erros corrigidos:
--   * pedido_id, item e ordem_compra eram float8: identificador não pode ter
--     casa decimal -> BIGINT / INT
--   * quantidades e preço float8 -> DECIMAL
--   * índice em ordem_compra, que é o campo que liga o pedido à entrada
CREATE TABLE pedido_compra (
  pedido_id          BIGINT         NOT NULL,
  data_pedido        DATE           NULL,
  item               INT            NOT NULL DEFAULT 0,
  produto_id         VARCHAR(25)    NOT NULL DEFAULT '0',
  descricao_produto  VARCHAR(255)   NULL,
  ordem_compra       BIGINT         NOT NULL DEFAULT 0,
  qtde_pedida        DECIMAL(12,3)  NULL,
  filial_id          INT            NULL,
  data_entrega       DATE           NULL,
  qtde_entregue      DECIMAL(12,3)  NOT NULL DEFAULT 0,
  qtde_pendente      DECIMAL(12,3)  NOT NULL DEFAULT 0,
  preco_compra       DECIMAL(12,4)  NULL DEFAULT 0,
  fornecedor_id      INT            NULL DEFAULT 0,
  CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
  INDEX idx_pedido_ordem_compra (ordem_compra)
);

-- ── entradas_mercadoria ────────────────────────────────────
-- Erros corrigidos:
--   * a PK usava "ordem_compra", mas a coluna não existia; sem ela também não
--     há como ligar a entrada ao pedido -> coluna criada
--   * item float8 -> INT ; qtde_recebida float8 -> DECIMAL
CREATE TABLE entradas_mercadoria (
  data_entrada       DATE           NULL,
  nro_nfe            VARCHAR(255)   NOT NULL,
  item               INT            NOT NULL DEFAULT 0,
  produto_id         VARCHAR(25)    NOT NULL DEFAULT '0',
  descricao_produto  VARCHAR(255)   NULL,
  ordem_compra       BIGINT         NOT NULL,
  qtde_recebida      DECIMAL(12,3)  NULL,
  filial_id          INT            NULL,
  custo_unitario     DECIMAL(12,4)  NOT NULL DEFAULT 0,
  CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

-- ── venda ──────────────────────────────────────────────────
-- Erros corrigidos:
--   * "::character varying" é sintaxe só do PostgreSQL -> removido
--   * PK chamada "pk_consumo" (nome de outra tabela) -> venda_pkey
--   * qtde_vendida float8 -> DECIMAL(12,3)
CREATE TABLE venda (
  venda_id        BIGINT         NOT NULL,
  data_emissao    DATE           NOT NULL,
  horariomov      VARCHAR(8)     NOT NULL DEFAULT '00:00:00',
  produto_id      VARCHAR(25)    NOT NULL DEFAULT '',
  qtde_vendida    DECIMAL(12,3)  NULL,
  valor_unitario  DECIMAL(12,4)  NOT NULL DEFAULT 0,
  filial_id       BIGINT         NOT NULL DEFAULT 1,
  item            INT            NOT NULL DEFAULT 0,
  unidade_medida  VARCHAR(3)     NULL,
  CONSTRAINT venda_pkey PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
  INDEX idx_venda_data (data_emissao)
);

-- Observação: venda, pedido_compra e entradas_mercadoria NÃO têm chave
-- estrangeira para produtos_filial de propósito. A planilha do cliente tem
-- vendas de produtos não cadastrados (P21 a P28) e de filiais sem cadastro;
-- com FK essas linhas seriam rejeitadas e o total de vendas ficaria errado.
-- Esses casos são importados e apontados na validação (sql/04_validacao.sql).
