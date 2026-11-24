-- DDL corrigido para PostgreSQL
-- Baseado em sql/01_ddl_enunciado.sql. Erros encontrados e correções
-- documentados em docs/parte1_importacao.md.

CREATE TABLE public.venda (
 venda_id int8 NOT NULL,
 data_emissao date NOT NULL,
 horariomov varchar(8) DEFAULT '00:00:00'::character varying NOT NULL,
 produto_id varchar(25) DEFAULT ''::character varying NOT NULL,
 qtde_vendida float8 NULL,
 valor_unitario numeric(12, 4) DEFAULT 0 NOT NULL,
 filial_id int8 DEFAULT 1 NOT NULL,
 item int4 DEFAULT 0 NOT NULL,
 unidade_medida varchar(3) NULL,
 CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov));

CREATE TABLE public.pedido_compra (
 pedido_id float8 DEFAULT 0 NOT NULL, data_pedido date NULL, item float8 DEFAULT 0 NOT NULL,
 produto_id varchar(25) DEFAULT '0' NOT NULL, descricao_produto varchar(255) NULL,
 ordem_compra float8 DEFAULT 0 NOT NULL, qtde_pedida float8 NULL, filial_id int4 NULL,
 data_entrega date NULL, qtde_entregue float8 DEFAULT 0 NOT NULL, qtde_pendente float8 DEFAULT 0 NOT NULL,
 preco_compra float8 DEFAULT 0 NULL, fornecedor_id int4 DEFAULT 0 NULL,
 CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id , produto_id, item));

-- Erro 1: faltava a coluna ordem_compra (usada na PK, mas nunca declarada).
-- É por ela que uma entrada de mercadoria se liga ao seu pedido de compra.
CREATE TABLE public.entradas_mercadoria (
 data_entrada date NULL, nro_nfe varchar(255) NOT NULL, item float8 DEFAULT 0 NOT NULL,
 produto_id varchar(25) DEFAULT '0' NOT NULL, descricao_produto varchar(255) NULL,
 ordem_compra float8 DEFAULT 0 NOT NULL,
 qtde_recebida float8 NULL, filial_id int4 NULL, custo_unitario numeric(12, 4) DEFAULT 0 NOT NULL,
 CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe));

-- Erro 2: faltava vírgula antes do CONSTRAINT (erro de sintaxe).
-- Erro 3: colunas com typo (decricao, idfonecedor) não batiam com o script de importação.
-- Erro 4: a PK apontava para "idproduto", coluna que não existe (é produto_id).
-- Erro 5: idfornecedor estava como int4, mas fornecedor.idfornecedor é varchar(25)
-- (o próprio script de importação trata o id do fornecedor como texto).
-- Erro 6: filial_id estava como NULL, mas é parte da PK (o MySQL rejeita coluna de
-- PK nula; o PostgreSQL aceita e força NOT NULL silenciosamente).
CREATE TABLE public.produtos_filial (
 filial_id int4 NOT NULL, produto_id varchar(255) NOT NULL, descricao varchar(255) NOT NULL,
 estoque float8 DEFAULT 0 NOT NULL, preco_unitario float8 DEFAULT '0' NOT NULL,
 preco_compra float8 DEFAULT '0' NOT NULL, preco_venda float8 DEFAULT '0' NOT NULL,
 idfornecedor varchar(25) NULL,
 CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id));

-- Erro 7: coluna com typo (idforncedor) não batia com o script de importação.
-- Erro 8: a PK apontava para "idproduto", coluna que não existe nesta tabela
-- (fornecedor não tem relação direta por produto; quem referencia o fornecedor
-- é produtos_filial, pela FK abaixo).
CREATE TABLE public.fornecedor (
 idfornecedor varchar(25) NOT NULL, razao_social varchar(255) NOT NULL,
 CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor));

ALTER TABLE public.produtos_filial
 ADD CONSTRAINT produtos_filial_fornecedor_fkey
 FOREIGN KEY (idfornecedor) REFERENCES public.fornecedor (idfornecedor);
