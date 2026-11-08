-- DDL corrigido para MySQL
-- Tabela fornecedor corrigida
-- Correções: nome do identificador e chave primária.
CREATE TABLE 
fornecedor (
  idfornecedor
VARCHAR(25) NOT NULL,
  razao_social
  VARCHAR(255) NOT 
  NULL,
PRIMARY KEY 
  (idfornecedor)
);

--Tabela produtos_filial corrigida
-- Correcoes: nomes das colunas e chave primaria.
CREATE TABLE
produtos_filial (
  filial_id INT
  NOT NULL,
  produto_id
  VARCHAR (255) NOT 
NULL,
descricao
  VARCHAR (255) NOT
  NULL,
  estoque DOUBLE
DEFAULT 0 NOT NULL,
  preco_unitario
  DECIMAL(12,4)
  DEFAULT 0 NOT NULL,
  preco_compra
DECIMAL(12,4)
DEFAULT 0 NOT NULL,
preco_venda
DECIMAL(12,4)
DEFAULT 0 NOT NULL,
idfornecedor
VARCHAR (25),
PRIMARY KEY
(filial_id,
  produto_id),
FOREIGN KEY
(idfornecedor)
     REFERENCES
fornecedor(idfornecedor)
);
