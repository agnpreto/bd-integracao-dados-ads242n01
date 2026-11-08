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
