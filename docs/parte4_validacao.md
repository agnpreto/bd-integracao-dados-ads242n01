# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

## 1. Pontos a validar

* Conferência do volume e do faturamento de fevereiro de 2025 (14 registros de venda, 173,22 unidades vendidas e R$ 14.093,1704 no total, distribuídos entre `P7`, `P14`–`P20` e `P22`–`P27`), verificando se há vendas faltantes ou lançamentos fora do período.
* Esclarecimento sobre os pedidos de compra com `ordem_compra = 0` e sem correspondência nas entradas de mercadoria (`entradas_mercadoria` possui ordens de `1` a `20`), além dos pedidos pendentes/não recebidos.
* Validação de datas inconsistentes em `pedido_compra` (`data_entrega` anterior à `data_pedido`) e de notas com `qtde_recebida` maior que `qtde_pedida`.
* Revisão cadastral e comercial: vendas de produtos (`P21` a `P28`) ausentes em `produtos_filial` e itens em `produtos_filial` com `preco_venda` abaixo de `preco_compra` ou `preco_unitario`.

## 2. Técnicas para garantir exatidão e precisão

* Reconciliação de contagens (`COUNT(*)`) entre cada aba da planilha original `dados/base_teste.xlsx` e as tabelas carregadas no banco.
* Cruzamento referencial (`LEFT JOIN` e `JOIN`) entre `pedido_compra`, `entradas_mercadoria`, `produtos_filial` e `venda` para detectar órfãos e divergências de vínculo.
* Regras de consistência temporal, quantitativa e de margem (`data_entrega >= data_pedido`, `qtde_recebida <= qtde_pedida` e coerência de preços).
* Amostragem direcionada sobre os lançamentos de fevereiro de 2025 para confrontar quantidades, valores unitários e datas de emissão com o cliente.

## 3. Consultas preparadas para a reunião

As consultas de apoio ficam em `sql/04_validacao.sql`:
* **Consulta 1 (Resumo de vendas de fevereiro/2025):** consolida a quantidade de registros, a soma de unidades vendidas e o valor total em R$ no mês de fevereiro de 2025.
* **Consulta 2 (Pedidos com `ordem_compra = 0`):** lista os pedidos de compra sem número de ordem válido para rastreio no recebimento.
* **Consulta 3 (`data_entrega < data_pedido`):** aponta pedidos com data de entrega anterior à data de emissão do pedido.
* **Consulta 4 (`qtde_recebida > qtde_pedida`):** identifica entradas de mercadoria com quantidade recebida superior à quantidade pedida no pedido correspondente.
* **Consulta 5 (Vendas sem produto em `produtos_filial`):** mostra códigos vendidos que não constam no cadastro de `produtos_filial`.
* **Consulta 6 (Divergência de preços em `produtos_filial`):** destaca produtos com `preco_venda` menor que `preco_compra` ou `preco_unitario`.

## Erros encontrados nos dados

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| pedido_compra | Colunas extras não nomeadas (`Unnamed: 12`..`Unnamed: 22`) com dados deslocados nas linhas 22 a 30 do Excel | 9 linhas | Leitura da aba `pedido_compra` além da 12ª coluna (linhas Excel 22 a 30) |
| pedido_compra | `ordem_compra` igual a `0` sem correspondência em `entradas_mercadoria` | 11 linhas | Consulta 2 em `sql/04_validacao.sql` |
| pedido_compra | `data_entrega` anterior à `data_pedido` | 20 linhas | Consulta 3 em `sql/04_validacao.sql` |
| entradas_mercadoria | `qtde_recebida` maior que `qtde_pedida` no pedido correspondente | 7 linhas | Consulta 4 em `sql/04_validacao.sql` |
| venda | `produto_id` (`P21`..`P28`) inexistente em `produtos_filial` | 13 linhas | Consulta 5 em `sql/04_validacao.sql` |
| produtos_filial | `preco_venda` menor que `preco_compra` ou `preco_unitario` | 13 linhas | Consulta 6 em `sql/04_validacao.sql`[cite: 1, 2, 6, 12] |
