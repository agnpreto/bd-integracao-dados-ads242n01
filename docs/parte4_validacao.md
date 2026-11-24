# Validação dos dados

## 1. Objetivo

Foram realizadas consultas SQL no PostgreSQL para identificar possíveis inconsistências nos registros importados da tabela `venda`.

## 2. Resultados das verificações

Foram importados 33 registros da tabela `venda`.

| Verificação | Resultado |
|---|---:|
| Campos obrigatórios nulos | 0 |
| Grupos de registros duplicados | 0 |
| Quantidades ou valores zerados/negativos | 0 |
| Datas fora do ano de 2025 | 0 |
| Quantidades fracionadas na unidade UN | 5 |

Não foram identificados campos obrigatórios nulos, grupos duplicados, quantidades ou valores inválidos, nem datas fora do período analisado.

## 3. Quantidades fracionadas

Foram identificados cinco registros com quantidades fracionadas na unidade de medida `UN`:

| Venda | Produto | Quantidade |
|---|---|---:|
| 4 | P4 | 38,60 |
| 8 | P8 | 20,04 |
| 12 | P12 | 2,86 |
| 16 | P16 | 37,11 |
| 26 | P26 | 3,11 |

Esses registros foram classificados como situações que necessitam de investigação, pois não é possível afirmar, somente com os dados disponíveis, que representam erros.

## 4. Indicadores de fevereiro de 2025

| Indicador | Resultado |
|---|---:|
| Quantidade de registros | 14 |
| Quantidade total vendida | 173,22 |
| Valor total vendido | R$ 14.093,17 |

## 5. Distribuição por filial

| Filial | Quantidade de vendas |
|---|---:|
| 1 | 29 |
| 2 | 2 |
| 3 | 2 |
| **Total** | **33** |

## 6. Limitações da análise

A planilha disponibilizada continha somente a aba `venda`, com 33 registros. As abas `fornecedor`, `produtos_filial`, `pedido_compra` e `entradas_mercadoria` não estavam disponíveis na fonte recebida.

Por esse motivo, não foi possível validar os relacionamentos, pedidos de compra e entradas de mercadorias com dados reais dessas tabelas.

## 7. Conclusão

As consultas executadas no PostgreSQL não identificaram campos obrigatórios nulos, duplicidades na chave primária, quantidades ou valores zerados/negativos ou datas fora de 2025.

Foram identificadas cinco quantidades fracionadas em registros cuja unidade de medida é `UN`, permanecendo pendente a confirmação de sua validade com base nas regras do negócio.

A validação foi concluída para os 33 registros disponíveis na tabela `venda`, respeitando as limitações da planilha fornecida.
