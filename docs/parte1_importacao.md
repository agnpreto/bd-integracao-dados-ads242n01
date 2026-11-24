# Parte 1 — Importação e implantação dos dados

## 1. Objetivo

Preparar a estrutura do banco de dados e realizar a importação dos dados disponibilizados para teste, conferindo a quantidade de registros entre a fonte original e o PostgreSQL.

## 2. Fonte dos dados

Arquivo utilizado: `dados/base_teste.xlsx`.

A base disponibilizada contém somente a aba `venda`, com 33 registros e os seguintes campos:

- `venda_id`
- `data_emissao`
- `horariomov`
- `produto_id`
- `qtde_vendida`
- `valor_unitario`
- `filial_id`
- `item`
- `unidade_medida`

## 3. Limitação identificada

As abas `fornecedor`, `produtos_filial`, `pedido_compra` e `entradas_mercadoria`, previstas no enunciado, não estavam disponíveis no arquivo recebido.

Por esse motivo, não foi possível importar nem validar essas quatro tabelas com dados reais.

Nenhum registro fictício foi criado para simular uma importação completa.

## 4. Comparação entre a fonte e o banco de dados

| Tabela | Registros na planilha | Registros no PostgreSQL | Situação |
|---|---:|---:|---|
| venda | 33 | 33 | Importação conferida |
| fornecedor | Aba ausente | 0 | Fonte indisponível |
| produtos_filial | Aba ausente | 0 | Fonte indisponível |
| pedido_compra | Aba ausente | 0 | Fonte indisponível |
| entradas_mercadoria | Aba ausente | 0 | Fonte indisponível |

A conferência foi realizada por consultas `SELECT COUNT(*)` no PostgreSQL. Os resultados confirmaram a importação dos 33 registros da tabela `venda`. As outras quatro tabelas foram criadas, mas permaneceram vazias devido à ausência das respectivas abas na planilha.

## 5. Conferência das vendas de fevereiro de 2025

Na aba `venda`, foram identificados 14 registros referentes a fevereiro de 2025.

- Quantidade vendida: 173,22.
- Valor total: R$ 14.093,17.

Esses valores foram calculados a partir dos dados disponibilizados na planilha e conferidos por consulta SQL no PostgreSQL.

## 6. Procedimento de importação

A implantação foi realizada no PostgreSQL, utilizando os seguintes procedimentos:

- criação das cinco tabelas por meio do script DDL;
- identificação das tabelas criadas no banco;
- inserção dos 33 registros disponíveis na tabela `venda`, por meio de comandos SQL `INSERT`;
- conferência da quantidade de registros por meio de consultas `SELECT COUNT(*)`.

A execução confirmou a inserção de 33 registros na tabela `venda`, sem registros nas quatro tabelas cujas abas estavam ausentes.

## 7. Conclusão

A base recebida permite trabalhar com os dados de vendas, mas não permite comprovar a importação integral das cinco tabelas previstas na atividade.

A ausência das demais abas foi documentada como limitação da fonte de dados, preservando a integridade das informações e sem criação de registros fictícios.

A importação da tabela `venda` foi concluída e conferida no PostgreSQL, com correspondência de 33 registros entre a planilha e o banco de dados.
