# Parte 4 — Validação dos dados com o cliente

## 1. Objetivo da reunião

Validar os dados importados da planilha fornecida pelo cliente para o banco de dados PostgreSQL, com foco nas movimentações de fevereiro de 2025, garantindo a integridade, consistência e exatidão das informações.

## 2. Pontos a serem validados com o cliente

- Quantidade de registros importados em cada tabela.
- Valores e quantidades das vendas de fevereiro de 2025.
- Datas dos pedidos de compra e das entregas.
- Correspondência entre produtos, fornecedores e filiais.
- Pedidos de compra sem recebimento correspondente.
- Ordens de compra com identificador igual a zero.
- Produtos vendidos sem cadastro correspondente na filial.
- Quantidades pedidas, entregues e pendentes.
- Produtos com quantidade requisitada superior a 10 unidades.
- Valores adicionais presentes em colunas sem cabeçalho na planilha original.

## 3. Técnicas utilizadas para garantir a exatidão dos dados

- Comparação da quantidade de registros da planilha com os registros armazenados no banco.
- Utilização de consultas SQL com COUNT, SUM, GROUP BY e HAVING.
- Validação dos relacionamentos por meio de LEFT JOIN.
- Identificação de registros sem correspondência utilizando NOT EXISTS.
- Verificação da consistência cronológica das datas.
- Conferência dos cálculos das quantidades pendentes.
- Verificação das chaves primárias e dos relacionamentos entre tabelas.
- Comparação dos resultados financeiros com a planilha original.
- Preservação da planilha original, sem alterações nos dados fornecidos pelo cliente.

## 4. Resultados da importação

| Tabela | Registros importados |
|---|---:|
| fornecedor | 20 |
| produtos_filial | 20 |
| pedido_compra | 29 |
| entradas_mercadoria | 20 |
| venda | 33 |
| Total | 122 |

A importação foi concluída sem erros de inserção e sem conflitos registrados pelo script.

## 5. Resultados referentes a fevereiro de 2025

- Registros de vendas: 14.
- Valor total calculado das vendas: R$ 14.093,17.
- Produtos com quantidade requisitada superior a 10 unidades: 10.
- Registros de pedidos com datas de entrega anteriores às datas dos pedidos: 16.

## 6. Inconsistências identificadas

### 6.1. Datas de entrega anteriores às datas dos pedidos

Foram encontrados 20 registros inconsistentes na base completa, dos quais 16 possuem data de pedido em fevereiro de 2025.

Essas datas deverão ser verificadas com o cliente antes de qualquer correção.

Consulta: SELECT * FROM public.pedido_compra WHERE data_entrega &lt; data_pedido;

### 6.2. Ordens de compra zeradas

Foram encontrados 11 registros com ordem de compra igual a zero.

É necessário confirmar se esse valor representa uma ordem inexistente, não informada ou inválida.

Consulta: SELECT * FROM public.pedido_compra WHERE ordem_compra = 0;

### 6.3. Vendas sem produto cadastrado na filial

Foram identificados 13 registros de vendas sem correspondência entre produto e filial na tabela produtos_filial, considerando toda a base.

Consulta:

SELECT v.*
FROM public.venda v
LEFT JOIN public.produtos_filial p
ON v.produto_id = p.produto_id
AND v.filial_id = p.filial_id
WHERE p.produto_id IS NULL;

### 6.4. Pedidos sem recebimento correspondente

Foram identificados 11 registros de pedidos sem recebimento positivo correspondente, conforme os critérios utilizados na consulta.

Todos os registros retornados possuem ordem de compra igual a zero, o que limita a confiabilidade do relacionamento entre pedidos e entradas de mercadorias.

Consulta:

SELECT p.*
FROM public.pedido_compra p
WHERE NOT EXISTS (
SELECT 1
FROM public.entradas_mercadoria e
WHERE e.ordem_compra = p.ordem_compra
AND e.produto_id = p.produto_id
AND e.filial_id = p.filial_id
AND e.qtde_recebida > 0
);

### 6.5. Colunas sem cabeçalho

Durante a importação, foram identificados valores adicionais em colunas sem cabeçalho nos pedidos de compra de identificadores 21 a 29, conforme o aviso do script.

Esses valores foram preservados na planilha original e precisam ser esclarecidos pelo cliente antes de serem incorporados ao banco.

Essa ocorrência deve ser conferida diretamente na planilha, pois os valores adicionais não estão representados nas tabelas importadas.

## 7. Validações sem inconsistências

- Quantidades pendentes divergentes do cálculo: 0.
- Pedidos sem fornecedor correspondente: 0.
- Produtos sem fornecedor correspondente: 0.

## 8. Consultas SQL

As consultas utilizadas para a reunião de validação estão disponibilizadas no arquivo sql/04_validacao.sql.

## 9. Conclusão

A integração dos dados foi realizada com sucesso do ponto de vista da importação, totalizando 122 registros inseridos sem erros.

Entretanto, foram identificadas inconsistências relacionadas às datas, ordens de compra, cadastros de produtos e correspondência entre pedidos e recebimentos.

Essas ocorrências deverão ser apresentadas ao cliente para esclarecimento e definição das correções necessárias.

A aprovação definitiva dos dados dependerá da validação do cliente, mantendo a planilha original preservada.