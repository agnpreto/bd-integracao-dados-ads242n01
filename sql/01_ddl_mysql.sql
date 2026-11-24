-- DDL corrigido para MySQL
-- Mesmas correções de sql/01_ddl_postgres.sql, adaptadas para a sintaxe do MySQL
-- (sem "public.", tipos int8/int4/float8 trocados pelos equivalentes do MySQL).

CREATE TABLE venda (
 venda_id bigint NOT NULL,
 data_emissao date NOT NULL,
 horariomov varchar(8) NOT NULL DEFAULT '00:00:00',
 produto_id varchar(25) NOT NULL DEFAULT '',
 qtde_vendida double NULL,
 valor_unitario decimal(12, 4) NOT NULL DEFAULT 0,
 filial_id bigint NOT NULL DEFAULT 1,
 item int NOT NULL DEFAULT 0,
 unidade_medida varchar(3) NULL,
 CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);

CREATE TABLE pedido_compra (
 pedido_id double NOT NULL DEFAULT 0, data_pedido date NULL, item double NOT NULL DEFAULT 0,
 produto_id varchar(25) NOT NULL DEFAULT '0', descricao_produto varchar(255) NULL,
 ordem_compra double NOT NULL DEFAULT 0, qtde_pedida double NULL, filial_id int NULL,
 data_entrega date NULL, qtde_entregue double NOT NULL DEFAULT 0, qtde_pendente double NOT NULL DEFAULT 0,
 preco_compra double NULL DEFAULT 0, fornecedor_id int NULL DEFAULT 0,
 CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item)
);

-- Erro 1: faltava a coluna ordem_compra (usada na PK, mas nunca declarada).
-- É por ela que uma entrada de mercadoria se liga ao seu pedido de compra.
CREATE TABLE entradas_mercadoria (
 data_entrada date NULL, nro_nfe varchar(255) NOT NULL, item double NOT NULL DEFAULT 0,
 produto_id varchar(25) NOT NULL DEFAULT '0', descricao_produto varchar(255) NULL,
 ordem_compra double NOT NULL DEFAULT 0,
 qtde_recebida double NULL, filial_id int NULL, custo_unitario decimal(12, 4) NOT NULL DEFAULT 0,
 CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

-- Erro 2: faltava vírgula antes do CONSTRAINT (erro de sintaxe).
-- Erro 3: colunas com typo (decricao, idfonecedor) não batiam com o script de importação.
-- Erro 4: a PK apontava para "idproduto", coluna que não existe (é produto_id).
-- Erro 5: idfornecedor estava como inteiro, mas fornecedor.idfornecedor é varchar(25)
-- (o próprio script de importação trata o id do fornecedor como texto).
-- Erro 6: filial_id estava como NULL, mas é parte da PK (o MySQL rejeita coluna de
-- PK nula; o PostgreSQL aceita e força NOT NULL silenciosamente).
CREATE TABLE produtos_filial (
 filial_id int NOT NULL, produto_id varchar(255) NOT NULL, descricao varchar(255) NOT NULL,
 estoque double NOT NULL DEFAULT 0, preco_unitario double NOT NULL DEFAULT 0,
 preco_compra double NOT NULL DEFAULT 0, preco_venda double NOT NULL DEFAULT 0,
 idfornecedor varchar(25) NULL,
 CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id)
);

-- Erro 7: coluna com typo (idforncedor) não batia com o script de importação.
-- Erro 8: a PK apontava para "idproduto", coluna que não existe nesta tabela
-- (fornecedor não tem relação direta por produto; quem referencia o fornecedor
-- é produtos_filial, pela FK abaixo).
CREATE TABLE fornecedor (
 idfornecedor varchar(25) NOT NULL, razao_social varchar(255) NOT NULL,
 CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

ALTER TABLE produtos_filial
 ADD CONSTRAINT produtos_filial_fornecedor_fkey
 FOREIGN KEY (idfornecedor) REFERENCES fornecedor (idfornecedor);
