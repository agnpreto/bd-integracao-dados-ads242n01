# Parte 1 — Documentação do Processo de Importação

## 1. Objetivo

Esta etapa teve como objetivo analisar a planilha `dados/base_teste.xlsx`, preparar a estrutura do banco de dados e importar os registros disponíveis, identificando problemas nos dados e no DDL original.

## 2. Ferramentas utilizadas

- Excel: inspeção da planilha recebida.
- PostgreSQL 18.6: ambiente utilizado para testar a estrutura e as consultas SQL.
- SQL: criação das tabelas, inserção e conferência dos registros.
- Python, pandas, openpyxl e psycopg2: utilizados na preparação do script de importação `scripts/importar.py`.

## 3. Estrutura da planilha recebida

A base disponibilizada continha somente a aba `venda`, com 33 registros.

As outras quatro abas previstas na atividade não estavam presentes no arquivo recebido.

| Coluna | Tipo de dado |
|---|---|
| venda_id | Inteiro |
| data_emissao | Data |
| horariomov | Texto |
| produto_id | Texto |
| qtde_vendida | Numérico |
| valor_unitario | Numérico decimal |
| filial_id | Inteiro |
| item | Inteiro |
| unidade_medida | Texto |

## 4. Tratamentos e correções

Foram considerados os seguintes cuidados:

- Conversão das datas para o formato aceito pelo banco.
- Preservação dos códigos de produtos como texto.
- Utilização de tipos numéricos para quantidades e valores.
- Definição de chaves primárias para evitar duplicidade de registros.
- Correção de nomes de colunas e restrições do DDL original.
- Utilização de variáveis de ambiente para as credenciais do banco, evitando senhas reais diretamente no código.

## 5. Quantidade de registros

A quantidade encontrada na base recebida foi:

| Tabela | Registros disponíveis |
|---|---:|
| fornecedor | Não disponibilizada |
| produtos_filial | Não disponibilizada |
| pedido_compra | Não disponibilizada |
| entradas_mercadoria | Não disponibilizada |
| venda | 33 |
| **Total disponível** | **33** |

A conferência da tabela `venda` foi realizada por meio de consulta SQL com `COUNT(*)`.

As quatro tabelas sem dados não foram preenchidas com registros fictícios.

## 6. Limitações encontradas

A ausência das abas `fornecedor`, `produtos_filial`, `pedido_compra` e `entradas_mercadoria` impediu a importação e a conferência dessas informações.

Por isso, as consultas que dependem dessas tabelas foram preparadas conforme a estrutura definida no projeto, mas não puderam ser testadas com os dados originais dessas abas.

## 7. Conclusão

A base recebida permitiu trabalhar com os 33 registros de vendas e realizar consultas e verificações sobre essas informações.

A importação completa das cinco tabelas depende do fornecimento das quatro abas ausentes. Nenhum dado fictício foi criado para apresentar uma conclusão que não pudesse ser comprovada.
