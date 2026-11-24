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

## Resultado final da importação

Após as correções realizadas nos scripts DDL e no código Python, foi executada novamente a importação dos dados da planilha base_teste.xlsx.

| Tabela | Planilha | Inseridos | Conflitos | Erros |
|---|---:|---:|---:|---:|
| fornecedor | 20 | 20 | 0 | 0 |
| produtos_filial | 20 | 20 | 0 | 0 |
| pedido_compra | 29 | 29 | 0 | 0 |
| entradas_mercadoria | 20 | 20 | 0 | 0 |
| venda | 33 | 33 | 0 | 0 |
| **Total** | **122** | **122** | **0** | **0** |

A importação apresentou uma taxa de sucesso de 100%, sem erros de inserção ou conflitos de chave primária.

### Ressalvas sobre a qualidade dos dados

Durante a importação, foram identificadas colunas sem cabeçalho na aba pedido_compra, referentes aos pedidos 21 a 29.

Optou-se por utilizar as colunas nomeadas, mantendo as informações adicionais preservadas na planilha original para posterior validação com o cliente.

A conclusão bem-sucedida da importação não elimina a necessidade de verificar a consistência e a exatidão dos dados.

### Conclusão da implantação

As correções realizadas permitiram a criação das estruturas e a importação dos 122 registros no PostgreSQL. A próxima etapa consiste na elaboração das consultas SQL e na validação das informações importadas.