# Parte 1 — Documentação do processo de importação

## Ferramentas utilizadas

- PostgreSQL 18 para armazenamento dos dados.
- Python com pandas e openpyxl para leitura da planilha Excel.
- psycopg2 para conexão e importação dos dados no PostgreSQL.
- MySQL 8.0 para teste da estrutura alternativa do banco.

## Estrutura da planilha

O arquivo `dados/base_teste.xlsx` possui cinco abas:

| Aba | Registros esperados |
|---|---:|
| fornecedor | 20 |
| produtos_filial | 20 |
| pedido_compra | 29 |
| entradas_mercadoria | 20 |
| venda | 33 |
| **Total** | **122** |

### Tratamento das colunas

- Na aba `produtos_filial`, a coluna `idproduto` é utilizada para preencher `produto_id` no banco.
- Os códigos de fornecedores, como `F1` e `F8`, são mantidos como texto.
- Na aba `pedido_compra`, as colunas extras vazias são descartadas.
- As datas são convertidas corretamente para o formato de data do PostgreSQL.
- A quantidade pendente é calculada pela diferença entre a quantidade pedida e a quantidade entregue.

## Correções realizadas

O DDL original apresentou problemas de sintaxe, nomes de colunas e tipos de dados incompatíveis.

Foram corrigidos:
- Nomes de colunas com erros de digitação.
- Chaves primárias e estrangeiras.
- Tipos de dados dos identificadores.
- Coluna `ordem_compra` em `entradas_mercadoria`.
- Compatibilidade entre PostgreSQL e MySQL.

O script de importação também foi ajustado para tratar datas, valores vazios, colunas extras e registros duplicados.

## Conferência da importação

A quantidade de registros esperada em cada tabela é:

| Tabela | Planilha |
|---|---:|
| fornecedor | 20 |
| produtos_filial | 20 |
| pedido_compra | 29 |
| entradas_mercadoria | 20 |
| venda | 33 |

A quantidade efetivamente gravada no banco deverá ser conferida com consultas `SELECT COUNT(*)` após a execução do script
