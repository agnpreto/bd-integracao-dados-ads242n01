# Parte 1 – Implantação e importação de dados

## 1. Ambiente utilizado

- SGBD: PostgreSQL.
- Ferramenta de gerenciamento: DBeaver Community.
- Editor de código: Visual Studio Code.
- Versionamento: Git e GitHub.

## 2. Execução do DDL original

Foi realizada a execução individual dos comandos CREATE TABLE presentes no arquivo 01_ddl_enunciado.sql, com o objetivo de identificar os erros existentes na estrutura do banco de dados.

## 3. Erros identificados e soluções propostas

### Erro 1 – Tabela entradas_mercadoria

**Código do erro:** 42703.

**Mensagem:** column "ordem_compra" named in key does not exist.

**Causa:** a coluna ordem_compra foi utilizada na chave primária, porém não foi declarada na estrutura da tabela.

**Solução:** adicionar a coluna ordem_compra, utilizando o mesmo tipo de dado da tabela pedido_compra.

### Erro 2 – Tabela produtos_filial

**Código do erro:** 42601.

**Mensagem:** syntax error at or near "(".

**Causa:** ausência de uma vírgula antes da declaração da constraint.

**Outros problemas identificados:**

- Nome incorreto da coluna decricao.
- Nome incorreto da coluna idfonecedor.
- Utilização da coluna inexistente idproduto na chave primária.

**Solução:**

- Adicionar a vírgula ausente.
- Alterar decricao para descricao.
- Alterar idfonecedor para idfornecedor.
- Substituir idproduto por produto_id na chave primária.
- Declarar filial_id como NOT NULL.

### Erro 3 – Tabela fornecedor

**Código do erro:** 42703.

**Mensagem:** column "idproduto" named in key does not exist.

**Causa:** utilização de uma coluna inexistente na chave primária.

**Solução:** remover idproduto da chave primária e corrigir o nome idforncedor para idfornecedor.

## 4. Correção do DDL

As correções serão registradas em um novo arquivo denominado 01_ddl_postgres.sql, preservando o arquivo original disponibilizado pelo professor.

## 5. Validação da criação das tabelas

Pendente de execução e conferência.

## 6. Importação dos dados

Pendente de execução.