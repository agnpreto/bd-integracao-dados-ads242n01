# Parte 4 — Estratégia de Validação com o Cliente

## 1. Objetivo da validação

Confirmar com o cliente se os dados das cinco tabelas (fornecedor, produtos_filial, pedido_compra, entradas_mercadoria e venda) estão corretos, completos e aderentes às informações utilizadas pela empresa. O foco da reunião é apresentar as inconsistências identificadas na base recebida, cada uma com a consulta SQL que a evidencia e a quantidade de registros afetada.

## 2. Pontos que serão validados

- Quantidade de registros importados por tabela (planilha × banco).
- Existência de registros sem cadastro correspondente (chaves órfãs).
- Consistência temporal (data de entrega anterior ao pedido).
- Coerência de unidade de medida (quantidade fracionada em UN).
- Campos obrigatórios sem preenchimento.
- Registros duplicados.
- Diferenças entre planilha original e banco.

## 3. Técnicas utilizadas

- **Conferência de totais:** COUNT(*) por tabela, comparando planilha × banco.
- **Verificação de chaves órfãs:** LEFT JOIN … WHERE chave IS NULL.
- **Conferência de datas:** comparação entre datas relacionadas.
- **Verificação de domínio:** quantidade × unidade de medida.
- **Verificação de duplicidade:** GROUP BY … HAVING COUNT(*) > 1.
- **Verificação de campos vazios:** IS NULL.
- **Comparação entre tabelas:** divergência entre qtde_recebida e qtde_entregue.

## 4. Erros encontrados nos dados

A tabela abaixo lista todos os erros identificados nas cinco tabelas, com a consulta correspondente em sql/04_validacao.sql e a quantidade de registros retornada.

| # | Tabela | Erro | Consulta em 04_validacao.sql | Registros |
|---|---|---|---|---:|
| 1 | venda × produtos_filial | Vendas com (filial_id, produto_id) sem cadastro em produtos_filial — produtos P21–P28 e filiais 2 e 3 | Consultas 2 e 3 | 13 |
| 2 | pedido_compra | data_entrega anterior a data_pedido | Consulta 4 | 20 |
| 3 | venda | Quantidade fracionada em unidade UN (vendas 4, 8, 12, 16, 26) | Consulta 5 | 5 |
| 4 | venda | horariomov sempre 08:00:00 (sem variação em 33 registros) | Consulta 6 | 33 |
| 5 | pedido_compra | Pedidos com ordem_compra = 0 (sem vínculo) — pedidos 19 a 29 | Consulta 7 | 11 |
| 6 | entradas_mercadoria × pedido_compra | qtde_recebida divergente de qtde_entregue | Consultas 8 e 9 | 20 |
| 7 | pedido_compra | fornecedor_id numérico (1–20) na planilha, enquanto fornecedor.idfornecedor é texto (F1–F20) — corrigido em importar.py | Consulta 10 | 20 |

> Consulta 3 detalha os pares (filial_id, produto_id) sem cadastro. Consulta 9 detalha a divergência de quantidades por ordem_compra.

## 5. Detalhamento dos principais erros

### 5.1 Vendas sem cadastro de produto/filial (13 registros)

Vendas dos produtos P21 a P28 e das filiais 2 e 3 não possuem correspondência em produtos_filial (que só cadastra P1–P20 na filial 1). Por isso, a FK venda → produtos_filial foi criada como NOT VALID — preserva o carregamento e permite identificar a inconsistência sem bloquear a importação.

### 5.2 Entrega anterior ao pedido (20 registros)

Em 20 dos 29 pedidos, a data_entrega é anterior à data_pedido. Isso indica provável erro de digitação ou inversão de campos na origem. Os registros foram mantidos como estão para validação com o cliente.

### 5.3 Quantidade fracionada em UN (5 registros)

As vendas 4, 8, 12, 16 e 26 possuem quantidade fracionada, mas a unidade de medida é UN. Dependendo da regra comercial, pode ser necessário converter para KG, L ou M — decisão do cliente.

### 5.4 Pedidos sem ordem de compra (11 registros)

Onze pedidos (19 a 29) possuem ordem_compra = 0, indicando ausência de vínculo formal. Isso impacta o relacionamento entradas_mercadoria → pedido_compra.

### 5.5 Divergência de quantidade recebida (20 registros)

O qtde_recebida em entradas_mercadoria não coincide com o qtde_entregue registrado em pedido_compra. O cliente precisa definir qual dos dois é a fonte oficial.

## 6. Consultas SQL utilizadas na reunião

### 6.1 Total de vendas em fevereiro de 2025

SELECT COUNT(*) AS quantidade_vendas,
       SUM(qtde_vendida) AS quantidade_total,
       SUM(qtde_vendida * valor_unitario) AS valor_total
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao <  DATE '2025-03-01';

### 6.2 Consumo por produto (fevereiro/2025)

SELECT produto_id,
       SUM(qtde_vendida) AS quantidade_vendida,
       SUM(qtde_vendida * valor_unitario) AS valor_total
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao <  DATE '2025-03-01'
GROUP BY produto_id
ORDER BY produto_id;

### 6.3 Vendas por filial (fevereiro/2025)

SELECT filial_id,
       COUNT(*) AS quantidade_vendas,
       SUM(qtde_vendida * valor_unitario) AS valor_total
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao <  DATE '2025-03-01'
GROUP BY filial_id
ORDER BY filial_id;

### 6.4 Verificação de registros duplicados

SELECT venda_id, COUNT(*) AS ocorrencias
FROM venda
GROUP BY venda_id
HAVING COUNT(*) > 1;

### 6.5 Verificação de campos obrigatórios vazios

SELECT COUNT(*) AS registros_com_problemas
FROM venda
WHERE data_emissao IS NULL
   OR venda_id     IS NULL
   OR produto_id   IS NULL
   OR filial_id    IS NULL;

## 7. Resultados do teste com a base recebida

| Indicador | Resultado |
|---|---:|
| Registros analisados em venda | 33 |
| Vendas em fevereiro de 2025 | 14 |
| Quantidade vendida em fevereiro | 173,22 |
| Valor total em fevereiro | R$ 14.093,17 |
| Campos obrigatórios vazios | 0 |
| Duplicidades na PK de venda | 0 |
| Quantidades ou valores não positivos | 0 |
| Datas fora de 2025 | 0 |
| Quantidades fracionadas em UN | 5 |
| Vendas sem cadastro em produtos_filial | 13 |

## 8. Apresentação ao cliente

Na reunião serão apresentados, em ordem:

1. Totais planilha × banco para as 5 tabelas.
2. Lista dos 7 erros identificados, com a consulta e a contagem.
3. Detalhamento dos 5 principais erros (seção 5).
4. Proposta de tratamento para cada erro.

Nenhuma correção será aplicada sem confirmação do cliente e sem registro da decisão.

## 9. Conclusão

A estratégia permite verificar a confiabilidade das informações das cinco tabelas. As inconsistências foram mapeadas com consultas reproduzíveis em sql/04_validacao.sql, e a aprovação final dependerá da reunião com o cliente para definir o tratamento de cada uma.
