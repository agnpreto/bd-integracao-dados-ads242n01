-- DDL corrigido para PostgreSQL
-- Mesmas correções do 01_ddl_mysql.sql (comentadas lá e em docs/parte1_importacao.md).
-- Aqui "public." e "::character varying" são válidos, mas o cast é desnecessário.

DROP TABLE IF EXISTS public.venda;
DROP TABLE IF EXISTS public.entradas_mercadoria;
DROP TABLE IF EXISTS public.pedido_compra;
DROP TABLE IF EXISTS public.produtos_filial;
DROP TABLE IF EXISTS public.fornecedor;

-- idforncedor -> idfornecedor ; PK sem a coluna inexistente "idproduto"
CREATE TABLE public.fornecedor (
  idfornecedor  varchar(25)  NOT NULL,
  razao_social  varchar(255) NOT NULL,
  CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

-- vírgula faltando ; decricao -> descricao ; idfonecedor -> idfornecedor (texto, com FK)
-- PK (filial_id, idproduto) -> (filial_id, produto_id) ; filial_id NOT NULL
-- produto_id varchar(255) -> varchar(25) ; DEFAULT '0' -> 0 ; float8 -> numeric
CREATE TABLE public.produtos_filial (
  filial_id       int4           NOT NULL,
  produto_id      varchar(25)    NOT NULL,
  descricao       varchar(255)   NOT NULL,
  estoque         numeric(12,3)  NOT NULL DEFAULT 0,
  preco_unitario  numeric(12,4)  NOT NULL DEFAULT 0,
  preco_compra    numeric(12,4)  NOT NULL DEFAULT 0,
  preco_venda     numeric(12,4)  NOT NULL DEFAULT 0,
  idfornecedor    varchar(25)    NULL,
  CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
  CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (idfornecedor)
    REFERENCES public.fornecedor (idfornecedor)
);

-- pedido_id, item, ordem_compra: float8 -> inteiros ; quantidades/preço -> numeric
CREATE TABLE public.pedido_compra (
  pedido_id          int8           NOT NULL,
  data_pedido        date           NULL,
  item               int4           NOT NULL DEFAULT 0,
  produto_id         varchar(25)    NOT NULL DEFAULT '0',
  descricao_produto  varchar(255)   NULL,
  ordem_compra       int8           NOT NULL DEFAULT 0,
  qtde_pedida        numeric(12,3)  NULL,
  filial_id          int4           NULL,
  data_entrega       date           NULL,
  qtde_entregue      numeric(12,3)  NOT NULL DEFAULT 0,
  qtde_pendente      numeric(12,3)  NOT NULL DEFAULT 0,
  preco_compra       numeric(12,4)  NULL DEFAULT 0,
  fornecedor_id      int4           NULL DEFAULT 0,
  CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item)
);
CREATE INDEX idx_pedido_ordem_compra ON public.pedido_compra (ordem_compra);

-- coluna ordem_compra criada (estava na PK mas não existia) ; item -> int4
CREATE TABLE public.entradas_mercadoria (
  data_entrada       date           NULL,
  nro_nfe            varchar(255)   NOT NULL,
  item               int4           NOT NULL DEFAULT 0,
  produto_id         varchar(25)    NOT NULL DEFAULT '0',
  descricao_produto  varchar(255)   NULL,
  ordem_compra       int8           NOT NULL,
  qtde_recebida      numeric(12,3)  NULL,
  filial_id          int4           NULL,
  custo_unitario     numeric(12,4)  NOT NULL DEFAULT 0,
  CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

-- pk_consumo -> venda_pkey ; qtde_vendida float8 -> numeric
CREATE TABLE public.venda (
  venda_id        int8           NOT NULL,
  data_emissao    date           NOT NULL,
  horariomov      varchar(8)     NOT NULL DEFAULT '00:00:00',
  produto_id      varchar(25)    NOT NULL DEFAULT '',
  qtde_vendida    numeric(12,3)  NULL,
  valor_unitario  numeric(12,4)  NOT NULL DEFAULT 0,
  filial_id       int8           NOT NULL DEFAULT 1,
  item            int4           NOT NULL DEFAULT 0,
  unidade_medida  varchar(3)     NULL,
  CONSTRAINT venda_pkey PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);
CREATE INDEX idx_venda_data ON public.venda (data_emissao);

-- Sem FK de venda/pedido/entrada para produtos_filial de propósito:
-- a planilha tem vendas de produtos não cadastrados (P21 a P28). Ver sql/04_validacao.sql.
