# Parte 4 — Estratégia de Validação com o Cliente

## 1. Objetivo da validação

A validação tem como objetivo confirmar com o cliente se os dados de vendas de fevereiro de 2025 estão corretos, completos e de acordo com as informações utilizadas pela empresa.

## 2. Pontos que serão validados

Durante a reunião, serão conferidos:

- Quantidade total de vendas realizadas em fevereiro de 2025.
- Quantidade de produtos vendidos.
- Valor total das vendas em reais.
- Vendas separadas por produto e filial.
- Existência de registros duplicados.
- Campos obrigatórios sem preenchimento.
- Datas, quantidades e valores inconsistentes.
- Diferenças entre os dados da planilha original e os dados armazenados no banco.

## 3. Técnicas utilizadas

Para garantir a exatidão e a precisão dos dados, serão utilizadas:

- **Conferência de totais:** comparar a quantidade de registros e os valores da planilha com os resultados do banco.
- **Verificação de duplicidade:** identificar vendas repetidas.
- **Verificação de campos vazios:** localizar informações obrigatórias não preenchidas.
- **Conferência de datas:** garantir que os registros estejam dentro do período analisado.
- **Conferência de valores:** comparar quantidades e valores unitários com o total calculado.
- **Agrupamento por produto e filial:** facilitar a comparação dos resultados com os controles do cliente.

## 4. Consultas SQL utilizadas na reunião

### 4.1. Total de vendas em fevereiro de 2025

```sql
SELECT
    COUNT(*) AS quantidade_vendas,
    SUM(qtde_vendida) AS quantidade_total,
    SUM(qtde_vendida * valor_unitario) AS valor_total
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao < DATE '2025-03-01';
```

### 4.2. Consumo por produto

```sql
SELECT
    produto_id,
    SUM(qtde_vendida) AS quantidade_vendida,
    SUM(qtde_vendida * valor_unitario) AS valor_total
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao < DATE '2025-03-01'
GROUP BY produto_id
ORDER BY produto_id;
```

### 4.3. Vendas por filial

```sql
SELECT
    filial_id,
    COUNT(*) AS quantidade_vendas,
    SUM(qtde_vendida * valor_unitario) AS valor_total
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao < DATE '2025-03-01'
GROUP BY filial_id
ORDER BY filial_id;
```

### 4.4. Verificação de registros duplicados

```sql
SELECT
    filial_id,
    venda_id,
    data_emissao,
    produto_id,
    item,
    horariomov,
    COUNT(*) AS ocorrencias
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao < DATE '2025-03-01'
GROUP BY
    filial_id,
    venda_id,
    data_emissao,
    produto_id,
    item,
    horariomov
HAVING COUNT(*) > 1;
```

### 4.5. Verificação de campos obrigatórios vazios

```sql
SELECT COUNT(*) AS registros_com_problemas
FROM venda
WHERE data_emissao IS NULL
   OR venda_id IS NULL
   OR produto_id IS NULL
   OR filial_id IS NULL;
```

## 5. Resultados do teste anterior

Em um teste anterior, realizado com os 33 registros da tabela `venda`, foram encontrados os seguintes resultados:

| Indicador | Resultado |
|---|---:|
| Registros analisados | 33 |
| Vendas em fevereiro de 2025 | 14 |
| Quantidade vendida em fevereiro | 173,22 |
| Valor total em fevereiro | R$ 14.093,17 |
| Campos obrigatórios vazios | 0 |
| Duplicidades encontradas | 0 |
| Quantidades ou valores não positivos | 0 |
| Datas fora de 2025 | 0 |
| Quantidades fracionadas em unidade `UN` | 5 |

As cinco quantidades fracionadas foram identificadas para análise com o cliente. Elas não foram consideradas erros automaticamente, pois dependem das regras comerciais da empresa.

Esses resultados representam somente o teste anterior da tabela `venda`. A validação definitiva deverá ser realizada após a importação completa das cinco tabelas.

## 6. Apresentação ao cliente

Na reunião, os resultados serão apresentados de forma simples, mostrando os totais de vendas, os produtos mais vendidos e os valores por filial.

Caso sejam encontradas diferenças, elas serão registradas e comparadas com a planilha original. Nenhuma correção será realizada sem verificar sua origem.

## 7. Conclusão

A estratégia permite verificar a confiabilidade das informações antes de sua utilização pela empresa. A aprovação final dependerá da conferência dos resultados com o cliente e da resolução das divergências identificadas.
