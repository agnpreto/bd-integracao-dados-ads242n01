# Parte 4 — Validação dos dados

## 1. Objetivo

Esta etapa tem como objetivo verificar se os dados importados para o PostgreSQL estão corretos, identificando registros ausentes, campos vazios, duplicidades e possíveis inconsistências.

## 2. Quantidade de registros esperada

A planilha `dados/base_teste.xlsx` possui cinco abas, com a seguinte quantidade de registros:

| Tabela | Registros esperados |
|---|---:|
| fornecedor | 20 |
| produtos_filial | 20 |
| pedido_compra | 29 |
| entradas_mercadoria | 20 |
| venda | 33 |
| **Total** | **122** |

A quantidade efetivamente importada deve ser conferida com consultas `COUNT(*)` em cada tabela.

## 3. Consultas de validação

As consultas estão disponíveis no arquivo `sql/04_validacao.sql`.

Foram previstas verificações para:

- Quantidade total de registros em cada tabela.
- Campos obrigatórios sem preenchimento.
- Registros duplicados conforme as chaves primárias.
- Quantidades e valores zerados ou negativos.
- Datas fora do período esperado.
- Quantidades fracionadas na unidade de medida `UN`.
- Resumo das inconsistências encontradas.

## 4. Resultados do teste anterior da tabela venda

Em um teste anterior, realizado somente com os 33 registros da tabela `venda`, foram encontrados:

| Verificação | Resultado |
|---|---:|
| Registros analisados | 33 |
| Campos obrigatórios vazios | 0 |
| Grupos de registros duplicados | 0 |
| Quantidades ou valores não positivos | 0 |
| Registros com datas fora de 2025 | 0 |
| Quantidades fracionadas em unidade `UN` | 5 |

As cinco quantidades fracionadas foram mantidas como ocorrências para análise, pois precisam ser avaliadas conforme as regras do negócio.

Na análise das vendas de fevereiro de 2025, foram encontrados:

| Indicador | Resultado |
|---|---:|
| Quantidade de vendas | 14 |
| Quantidade total vendida | 173,22 |
| Valor total | R$ 14.093,17 |

Esses resultados correspondem apenas ao teste anterior da tabela `venda`, não à validação completa das cinco tabelas.

## 5. Conclusão

As consultas de validação permitem conferir a integridade dos dados e identificar possíveis problemas após a importação.

A validação completa do projeto depende da execução do importador e da conferência dos 122 registros esperados nas cinco tabelas. Os resultados definitivos devem ser registrados após essa conferência.
