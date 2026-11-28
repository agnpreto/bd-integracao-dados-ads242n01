# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

## 1. Pontos a validar

1. Confirmar se o período considerado é de 01/02/2025 a 28/02/2025 e se as vendas são avaliadas pela data de emissão.
2. Conferir quantidade vendida e valor bruto por produto, incluindo a regra de cálculo `quantidade × valor_unitario`.
3. Validar os pedidos realizados em fevereiro, as quantidades pedidas, recebidas e ainda pendentes.
4. Confirmar se `ordem_compra = 0` representa pedido sem vínculo, erro de cadastro ou informação ainda não preenchida.
5. Conciliar cada pedido com as entradas de mercadoria pela `ordem_compra` e pelo produto.
6. Confirmar o relacionamento dos produtos com seus fornecedores e a identificação numérica gerada.
7. Verificar se as datas, unidades de medida, preços e quantidades correspondem aos documentos de origem.
8. Solicitar ao cliente a interpretação das 11 colunas extras sem cabeçalho encontradas em nove linhas da aba `pedido_compra` antes de incorporá-las aos dados oficiais.

## 2. Técnicas para garantir exatidão e precisão

- **Conferência de totais:** comparar totais de quantidade e valor calculados no banco com a planilha e documentos de venda.
- **Reconciliação:** comparar `qtde_entregue` com a soma de `qtde_recebida` por ordem de compra e produto.
- **Integridade referencial:** validar se cada código de fornecedor existe e se cada produto aponta para o fornecedor correto.
- **Validação de domínio:** conferir datas válidas, quantidades não negativas, preços numéricos e códigos não vazios.
- **Amostragem documental:** selecionar registros de fevereiro e comparar com notas fiscais, pedidos e comprovantes do cliente.
- **Rastreabilidade:** manter os dados extras originais em tabela auxiliar, sem sobrescrever nem descartar valores sem autorização.
- **Reexecução controlada:** executar a carga em transação, registrar erros e comparar contagens por tabela.
- **Aceite do cliente:** apresentar divergências, registrar a decisão e só então corrigir os dados de origem.

## 3. Consultas preparadas para a reunião

As consultas estão em `sql/04_validacao.sql`:

- **V1:** total de linhas, quantidade vendida e valor bruto no mês.
- **V2:** quantidade e valor de vendas agrupados por produto.
- **V3:** pedidos feitos em fevereiro e saldo pendente por pedido/produto.
- **V4:** pedidos com `ordem_compra = 0`, que não podem ser conciliados com uma ordem válida sem esclarecimento.
- **V5:** divergência entre quantidade entregue informada no pedido e soma das entradas vinculadas.
- **V6:** entradas de mercadoria sem pedido correspondente.
- **V7:** produtos cujo código de fornecedor não foi relacionado ao ID numérico.
- **V8:** quantidades negativas ou recebimento maior que a quantidade pedida.

## Erros encontrados nos dados

| Tabela | Problema | Quantidade observada | Consulta que mostra |
|---|---|---:|---|
| pedido_compra | `ordem_compra = 0` em registros sem chave de conciliação identificável | 11 linhas | V4 |
| pedido_compra | 11 colunas extras sem cabeçalho, preenchidas em nove registros (linhas Excel 21–29) | 9 linhas | Conferência da aba Excel / tabela `pedido_compra_extras` |
| pedido_compra x entradas_mercadoria | Divergência entre `qtde_entregue` e a soma de `qtde_recebida` nas ordens 1 a 18 | 18 ordens | V5 |
| entradas_mercadoria | Entradas das ordens 19 e 20 não encontram pedido operacional com a mesma ordem (os pedidos 28 e 29 estão com ordem zero) | 2 linhas | V6 |

### Resultado observado na planilha para fevereiro/2025

- A aba `venda` possui **14 registros** no mês, com **173,22** unidades vendidas e valor bruto de **R$ 14.093,17**.
- A aba `pedido_compra` possui 17 registros com data de pedido em fevereiro. Nenhum produto aparece mais de 10 vezes no mês; a maior frequência observada é 2.
- Os números acima são cálculos sobre o arquivo Excel fornecido. Devem ser confirmados após a carga no banco e confrontados com o cliente.

### Conclusão para o cliente

A base pode ser utilizada para demonstrar as consultas, mas a validação final deve ficar condicionada ao esclarecimento das ordens zeradas, das divergências entre pedidos e entradas e dos campos extras sem cabeçalho. Esses pontos não devem ser corrigidos por suposição, pois podem alterar o histórico de compras e recebimentos.
