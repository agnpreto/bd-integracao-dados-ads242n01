# PARTE 4 — VALIDAÇÃO COM O CLIENTE

## 1. Objetivo

Documentar as inconsistências identificadas durante a importação, integração e transformação dos dados, apresentando os pontos que necessitam de validação com o cliente.

## 2. Validação da importação

A importação da planilha base_teste.xlsx para o PostgreSQL foi realizada sem erros de inserção.

| Tabela | Registros importados |
|---|---:|
| fornecedor | 20 |
| produtos_filial | 20 |
| pedido_compra | 29 |
| entradas_mercadoria | 20 |
| venda | 33 |
| **Total** | **122** |

## 3. Inconsistências identificadas

### 3.1. Datas de entrega inconsistentes

Foram identificados 20 registros de pedidos de compra cuja data de entrega é anterior à data do pedido.

**Validação com o cliente:** confirmar se as datas estão incorretas na planilha de origem e definir o procedimento de correção.

### 3.2. Pedidos sem entrada de mercadoria correspondente

Foram identificados 11 registros de pedidos sem entrada correspondente, considerando os critérios de ordem de compra, produto, filial e quantidade recebida positiva.

**Validação com o cliente:** verificar se os pedidos estão pendentes ou se existem inconsistências nos identificadores utilizados no relacionamento entre as tabelas.

### 3.3. Colunas sem cabeçalho

Foram identificadas colunas sem cabeçalho na aba pedido_compra da planilha original.

**Validação com o cliente:** identificar a finalidade dessas colunas e verificar se devem ser incorporadas ao banco de dados.

### 3.4. Ordens de compra com valor zero

Foram identificados registros com ordem de compra igual a zero.

**Validação com o cliente:** confirmar se o valor zero representa uma ordem inexistente, uma informação não preenchida ou um identificador válido.

## 4. Integridade dos fornecedores

As consultas de validação não identificaram pedidos de compra ou produtos cadastrados com fornecedores sem correspondência na tabela fornecedor.

## 5. Regras de negócio

### 5.1. Geração automática de fornecedores

Foi implementada uma sequência associada a uma função e uma trigger no PostgreSQL para gerar automaticamente um identificador de fornecedor quando um produto for inserido sem essa informação.

O fornecedor gerado recebe a descrição "Fornecedor provisório".

**Validação com o cliente:** confirmar se a criação automática de fornecedores provisórios atende às necessidades do negócio.

### 5.2. Produtos requisitados mais de dez vezes

A consulta foi implementada considerando a soma das quantidades requisitadas por produto durante fevereiro de 2025.

Foram encontrados dez produtos com quantidade requisitada superior a dez unidades.

**Validação com o cliente:** confirmar se o requisito corresponde à quantidade de unidades requisitadas ou à quantidade de solicitações distintas.

### 5.3. Padronização dos dados

Foram realizadas as seguintes transformações:

- Concatenação do código com a descrição do produto.
- Formatação das datas no padrão DD/MM/AAAA.
- Agrupamento das quantidades requisitadas por produto.
- Geração automática de identificadores de fornecedores.

## 6. Conclusão

A importação dos 122 registros e as transformações SQL foram executadas no PostgreSQL.

As inconsistências identificadas devem ser apresentadas ao cliente para definição das regras de tratamento, preservando os dados originais até que as correções sejam autorizadas.

A validação das regras de negócio pelo cliente permanece pendente.

## 7. Roteiro da reunião de validação

A reunião terá como objetivo validar os dados referentes a fevereiro de 2025.

- Apresentar os resultados da importação.
- Conferir os valores e as quantidades das vendas de fevereiro.
- Validar os pedidos de compra e as entradas de mercadorias.
- Apresentar as inconsistências identificadas.
- Confirmar as regras de negócio utilizadas nas consultas e transformações.
- Definir, junto ao cliente, os procedimentos para correção dos dados.
- Registrar a aprovação ou as solicitações de ajustes.

## 8. Técnicas para garantir a exatidão dos dados

- Comparação da quantidade de registros entre a planilha original e o banco de dados.
- Conferência dos valores financeiros e das quantidades movimentadas.
- Verificação da integridade referencial entre as tabelas.
- Validação dos formatos e da consistência das datas.
- Verificação de registros duplicados por meio das chaves primárias.
- Identificação de valores ausentes ou inconsistentes.
- Conferência dos cálculos das quantidades pendentes.
- Validação por amostragem dos registros com a planilha original.
- Preservação da planilha original, garantindo a rastreabilidade dos dados.
- Aprovação das regras de negócio pelo cliente.

## 9. Consultas preparadas para a reunião

As consultas estão disponíveis no arquivo `sql/04_validacao.sql`.

| Validação | Consulta |
|---|---|
| Quantidade de registros importados | 1 |
| Datas de entrega inconsistentes | 2, 3 e 4 |
| Integridade dos fornecedores | 5 e 6 |
| Pedidos sem entrada correspondente | 7 |
| Ordens de compra iguais a zero | 8 |
| Vendas sem produto cadastrado na filial | 9 |
| Quantidades pendentes inconsistentes | 10 |
| Vendas de fevereiro de 2025 | 11 e 12 |
| Produtos requisitados acima de dez unidades | 13 |

As colunas sem cabeçalho identificadas na planilha original devem ser verificadas diretamente no arquivo Excel, pois os valores adicionais não foram incorporados à estrutura relacional.

Os resultados das novas consultas deverão ser registrados após sua execução.

Nenhuma correção definitiva dos dados originais deverá ser realizada sem a validação do cliente.