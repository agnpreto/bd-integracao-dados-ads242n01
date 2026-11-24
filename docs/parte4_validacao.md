# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

## 1. Pontos a validar

1. **Totais de venda de fevereiro/2025** (quantidade e valor, por produto e por filial) — conferir contra o relatório interno do cliente, produto a produto.
2. **Cobertura de cadastro**: todo produto vendido tem ficha em `produtos_filial` (descrição, preço, estoque)? Hoje não — ver Erro 1.
3. **Coerência das quantidades vendidas**: produtos cuja unidade é "unidade" (UN) deveriam ter quantidade inteira — ver Erro 2.
4. **Cronologia dos pedidos de compra**: a data de entrega é sempre posterior (ou igual) à data do pedido? Hoje não, em boa parte dos casos — ver Erro 3.
5. **Rastreabilidade das entradas de mercadoria**: todo pedido de compra tem um número de ordem de compra válido, que permita localizar a nota fiscal de entrada correspondente? — ver Erro 4.
6. **Qual fonte é a verdade sobre "quanto foi recebido"**: o campo `qtde_entregue` do próprio pedido, ou a soma das entradas de mercadoria (`entradas_mercadoria.qtde_recebida`) ligadas à mesma ordem de compra? Hoje elas praticamente nunca batem — ver Erro 5.

## 2. Técnicas para garantir exatidão e precisão

- **Conferência de totais (reconciliação)**: comparar `COUNT(*)` e somas agregadas do banco contra os totais da planilha original, tabela por tabela (feito na Parte 1) e, aqui, mês a mês com o relatório que o cliente já tem.
- **Checagem de integridade referencial**: todo `produto_id` vendido existe em `produtos_filial`? Todo `idfornecedor` de produto existe em `fornecedor`? (consultas com `LEFT JOIN ... WHERE ... IS NULL`, usadas nos Erros 1 e 4).
- **Checagem de domínio/faixa de valores**: quantidades e preços não podem ser negativos ou zero; quantidades de itens vendidos por unidade (`UN`) não podem ser fracionárias.
- **Checagem de consistência temporal**: datas de entrega não podem ser anteriores às datas de pedido; vendas não podem ter data fora do período em análise.
- **Conferência cruzada entre tabelas relacionadas**: comparar um valor derivado (quanto foi "entregue" segundo o pedido de compra) com o dado primário equivalente em outra tabela (quanto foi de fato recebido, segundo as notas de entrada) — qualquer prática de negócio deveria ter as duas fontes batendo.
- **Amostragem com o cliente**: na reunião, pegar 2–3 pedidos específicos (inclusive um dos que deram erro) e conferir manualmente com a nota fiscal física/PDF, para validar se o erro está no dado ou na nossa interpretação.

## 3. Consultas preparadas para a reunião

(Todas em `sql/04_validacao.sql`.)

- **Visão geral de vendas de fev/2025** por produto e filial (quantidade e R$) — ponto de partida da conversa, para o cliente comparar com o relatório dele.
- Uma consulta para cada um dos 5 erros abaixo, mostrando exatamente as linhas afetadas (não apenas a contagem), para que o cliente veja o problema concreto.
- A consulta de **conferência cruzada** entre `pedido_compra.qtde_entregue` e `entradas_mercadoria.qtde_recebida`, que fundamenta o Erro 5.

## Erros encontrados nos dados

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| venda | Vendas de produtos sem nenhum cadastro em `produtos_filial` (sem descrição, preço ou estoque) — inclui vendas nas filiais 2 e 3, que não têm **nenhum** produto cadastrado | 8 produtos (`P21`–`P28`), em 3 filiais | Bloco "ERRO 1" de `sql/04_validacao.sql` |
| venda | Quantidade vendida fracionária (`qtde_vendida`) em produto cuja unidade de medida é "UN" (unidade inteira) | 5 vendas | Bloco "ERRO 2" de `sql/04_validacao.sql` |
| pedido_compra | Data de entrega (`data_entrega`) anterior à data do pedido (`data_pedido`) — mercadoria "chegando" antes de ser pedida | 20 de 29 pedidos | Bloco "ERRO 3" de `sql/04_validacao.sql` |
| pedido_compra | Pedido sem número de ordem de compra (`ordem_compra = 0`), impossível de conciliar com as entradas de mercadoria | 11 de 29 pedidos | Bloco "ERRO 4" de `sql/04_validacao.sql` |
| pedido_compra / entradas_mercadoria | `qtde_entregue` do pedido não bate com a soma de `qtde_recebida` em `entradas_mercadoria` para a mesma `ordem_compra` | 18 de 18 pedidos com ordem de compra válida (100%) | Consulta de "conferência cruzada" em `sql/04_validacao.sql` |

**Observação para o cliente**: os erros 1 e 4 indicam cadastro incompleto (faltam produtos/filiais e números de ordem de compra); os erros 2, 3 e 5 indicam inconsistência entre o que foi digitado e o que faz sentido no processo de negócio. Antes de fechar os números de fevereiro/2025, recomendo que o cliente confirme, para cada um desses casos, qual fonte (planilha, sistema legado, nota fiscal) está correta, para sabermos se corrigimos o dado ou se o processo de origem precisa de ajuste.
