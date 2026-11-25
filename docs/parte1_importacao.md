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

## Erros identificados durante a importação dos dados

### Erro 1 – Incompatibilidade de tipos de dados

**Tabela:** produtos_filial.

**Problema:** a coluna idfornecedor estava definida como INTEGER, porém os dados da planilha possuem identificadores alfanuméricos, como F8, F9 e F10.

**Consequência:** falha na inserção de 20 registros.

**Solução proposta:** alterar o tipo da coluna idfornecedor para VARCHAR(25), tanto no PostgreSQL quanto no MySQL.

### Erro 2 – Conversão incorreta de datas

**Tabela:** venda.

**Problema:** durante a importação, a coluna data_emissao recebeu valores nulos, violando a restrição NOT NULL.

**Consequência:** falha na inserção de 33 registros.

**Possível causa:** a função excel_para_data não contempla todos os formatos de data presentes na planilha.

**Solução proposta:** modificar a função para aceitar números seriais do Excel, objetos de data e datas em formato de texto.

### Erro 3 – Contagem incorreta dos registros importados

**Problema:** o script informou que todos os registros foram inseridos, mesmo após apresentar erros de execução.

**Consequência:** divergência entre a quantidade informada pelo programa e a quantidade efetivamente armazenada no banco de dados.

**Solução proposta:** contabilizar somente as inserções efetivamente realizadas e registrar separadamente as falhas e duplicidades.

### Resultado da primeira tentativa de importação

O script informou a importação de 122 registros, porém foram identificadas 53 falhas de inserção. A quantidade efetivamente armazenada deverá ser confirmada por meio de consultas SQL no PostgreSQL.

## Análise da planilha original

Foi realizada uma análise das cinco abas da planilha base_teste.xlsx, totalizando 122 registros.

| Tabela | Quantidade de registros |
|---|---:|
| fornecedor | 20 |
| produtos_filial | 20 |
| pedido_compra | 29 |
| entradas_mercadoria | 20 |
| venda | 33 |
| Total | 122 |

### Inconsistências identificadas

1. Incompatibilidade entre o tipo inteiro definido no DDL e os identificadores alfanuméricos dos fornecedores.

2. Conversão inadequada das datas presentes na planilha Excel.

3. Divergência de nomenclatura entre a coluna idproduto da planilha e a coluna produto_id do banco.

4. Existência de 11 colunas sem cabeçalho na aba pedido_compra, contendo informações adicionais nos pedidos 21 a 29.

5. Divergência no formato dos identificadores dos fornecedores entre as abas fornecedor e pedido_compra.

6. Ausência de uma coluna nomeada qtde_pendente na aba pedido_compra.

### Soluções implementadas

- Padronização dos identificadores dos fornecedores para VARCHAR(25).
- Transformação dos identificadores numéricos dos fornecedores para o padrão alfanumérico com prefixo F.
- Correção da função de conversão de datas.
- Mapeamento das colunas pelo nome.
- Cálculo da quantidade pendente pela diferença entre quantidade pedida e quantidade entregue.
- Implementação de SAVEPOINT para tratamento individual dos erros.
- Contagem efetiva das inserções utilizando rowcount.
- Registro separado de erros e conflitos de chave.

### Tratamento das colunas adicionais

Optou-se por importar os valores das colunas que possuem cabeçalhos definidos, preservando a planilha original.

As informações adicionais presentes nos pedidos 21 a 29 deverão ser discutidas durante a validação com o cliente, pois apresentam divergências em relação às colunas nomeadas.

### Resultado da importação corrigida

Pendente de confirmação mediante execução do script corrigido e consultas de contagem no PostgreSQL.

## Resultado final da validação

Após a importação dos dados, foram executadas consultas SQL no PostgreSQL por meio do DBeaver, com o objetivo de verificar a quantidade de registros, a consistência das datas e a correspondência entre os fornecedores cadastrados.

| Validação | Resultado |
|---|---|
| Total de registros na planilha | 122 |
| Total de registros no PostgreSQL | 122 |
| Erros de inserção | 0 |
| Conflitos de chave primária | 0 |
| Pedidos com data de entrega anterior à data do pedido | 20 |
| Pedidos com fornecedores não cadastrados | 0 |
| Produtos com fornecedores não cadastrados | 0 |

### Inconsistências identificadas

Dos 29 registros da tabela pedido_compra, 20 apresentaram data de entrega anterior à data do pedido, correspondendo a aproximadamente 68,97% dos registros.

Também foram identificadas colunas sem cabeçalho na planilha original, referentes aos pedidos 21 a 29.

As inconsistências foram preservadas para investigação e validação com o cliente, evitando alterações nos dados sem confirmação das regras de negócio.

### Validação dos fornecedores

As consultas realizadas com LEFT JOIN não retornaram registros sem correspondência na tabela fornecedor, confirmando a consistência das associações verificadas.

### Conclusão da Parte 1

A implantação das estruturas e a importação dos dados no PostgreSQL foram concluídas com sucesso. Os 122 registros foram inseridos sem erros ou conflitos de chave primária.

Apesar do sucesso da importação, foram identificadas inconsistências relacionadas à qualidade dos dados, que deverão ser discutidas na etapa de validação com o cliente.