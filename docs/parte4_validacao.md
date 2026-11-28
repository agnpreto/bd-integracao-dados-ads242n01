# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

Objetivo da reunião: o cliente sair com a certeza de que os números do banco são os mesmos do sistema dele. Quando não forem, ele deve saber exatamente quais são as diferenças, por que existem e o que decidir sobre cada uma.

**Antes da reunião:** rodar `sql/04_validacao.sql` e levar os resultados impressos. Pedir ao cliente o fechamento de fevereiro/2025 do sistema dele: total de vendas, relação de pedidos de compra e notas fiscais de entrada.

## 1. Pontos a validar

1. **Volume importado.** Todas as linhas da planilha chegaram ao banco? (fornecedor 20, produtos 20, pedidos 29, entradas 20, vendas 33: tudo conferido, nenhuma perda).
2. **Faturamento de fevereiro.** O banco mostra **14 vendas, 173,22 unidades e R$ 14.093,17**. O cliente compara com o fechamento do mês, no total, **por dia** e **por filial** (filial 1: R$ 13.545,64; filial 2: R$ 547,53).
3. **Vendas de produtos sem cadastro.** Em fevereiro, R$ 3.241,24 das vendas (P22 a P27) são de produtos que não existem no cadastro. O cliente precisa dizer se são produtos novos (enviar o cadastro), códigos digitados errado (dizer o código certo) ou vendas que não deviam estar ali.
4. **Filiais 2 e 3.** Têm vendas, mas nenhum produto cadastrado. Elas existem? Qual é o cadastro delas?
5. **Quantidades quebradas.** Produto vendido por unidade ("UN") com quantidade 38,60 ou 20,04. A unidade está errada (deveria ser KG, por exemplo) ou a quantidade está errada?
6. **Compras de fevereiro.** 17 pedidos (R$ 28.396,93) e 10 entradas de nota (R$ 36.722,92). O valor das notas é maior que o dos pedidos, então é preciso explicar a diferença.
7. **Pedidos sem ordem de compra.** 11 pedidos estão com ordem_compra = 0. São requisições que ainda não viraram pedido ou é erro de digitação? Dois deles (P19 e P20) têm nota de entrada com as ordens 19 e 20. Provavelmente o número da ordem foi perdido.
8. **Pedidos repetidos.** Os produtos P12 a P20 foram pedidos duas vezes no mesmo dia (pedidos 21 a 29). É uma segunda requisição de verdade ou uma duplicação?
9. **Datas trocadas.** Em 20 pedidos a entrega é anterior ao pedido, e em 9 notas a mercadoria entrou antes de ser pedida. Qual das duas datas está certa?
10. **Fornecedor do produto.** Em 22 pedidos, o fornecedor do pedido é diferente do fornecedor do produto no cadastro. Qual dos dois vale?
11. **Preços.** Existem três preços de compra diferentes para o mesmo produto (cadastro, pedido e nota). Além disso, 4 produtos têm preço de compra maior que o de venda (venda com prejuízo), e o preço praticado na venda é diferente do preço do cadastro em todas as 20 vendas de produto cadastrado. Qual é a fonte oficial de preço?
12. **Dados fora da tabela.** A aba `pedido_compra` tem 9 linhas com dados soltos nas colunas M a W, sem cabeçalho, que contradizem as colunas principais. Esses dados não foram importados. O cliente confirma que podem ser descartados?

## 2. Técnicas para garantir exatidão e precisão

- **Contagem de linhas** planilha × banco por tabela (consulta A1). Uma diferença indica perda na importação.
- **Totais de controle:** soma de quantidade e de valor do mês, comparada com o fechamento do cliente (A2). Também por dia (A3) e por filial (A4), para localizar onde está a diferença quando o total não bate.
- **Amostragem:** 5 vendas de maior valor (A5) conferidas linha a linha contra o cupom/nota do sistema do cliente.
- **Conciliação entre tabelas:** pedido × entrada pela ordem de compra (A6). O que foi pedido tem que bater com o que chegou.
- **Integridade referencial:** procurar registros "órfãos": venda sem produto (E1), venda de filial sem cadastro (E2), pedido sem entrada (E6), entrada sem pedido (E15).
- **Regras de negócio:** datas em ordem lógica (E7, E13), quantidade inteira para unidade "UN" (E3), recebido ≤ pedido (E12), preço de compra < preço de venda (E16).
- **Tipos certos no banco:** `DECIMAL` em vez de `float` para dinheiro (sem erro de arredondamento) e `DATE` para datas.
- **Importação repetível:** o script mostra planilha × inseridas × erros. Se o cliente mandar uma planilha corrigida, é só rodar de novo e comparar.
- **Nada é corrigido sem o cliente:** dado suspeito é importado como veio e listado com uma consulta. A decisão de corrigir é do cliente, e cada decisão fica registrada.

## 3. Consultas preparadas para a reunião

As consultas ficam em `sql/04_validacao.sql`.

| Consulta | O que mostra ao cliente |
| --- | --- |
| A1 | Linhas por tabela no banco, para comparar com a planilha |
| A2 | Resumo de fevereiro: vendas, pedidos e entradas (linhas, quantidade e R$) |
| A3 | Vendas por dia de fevereiro, para conferir com o caixa diário |
| A4 | Vendas por filial em fevereiro |
| A5 | As 5 maiores vendas do mês, para conferência linha a linha |
| A6 | Cada pedido de fevereiro: quanto foi pedido, quanto o pedido diz que foi entregue e quanto chegou de fato pelas notas |
| E1 a E17 | Uma consulta para cada erro da tabela abaixo |
| `02_consultas.sql` | Consumo por produto em fevereiro e produtos pedidos e não recebidos |

## Erros encontrados nos dados

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| venda | Produto vendido que não existe no cadastro (P21 a P28) | 13 vendas, 8 produtos | E1 |
| venda | Venda de filial sem nenhum produto cadastrado (filiais 2 e 3) | 4 vendas | E2 |
| venda | Quantidade fracionada com unidade "UN" (38,60; 20,04; 2,86; 37,11; 3,11) | 5 vendas | E3 |
| venda | Preço da venda diferente do preço de venda do cadastro | 20 vendas (todas as de produto cadastrado) | E4 |
| venda | Mesmo preço unitário em produtos diferentes: P21 a P28 copiam o preço de P13 a P20, indicando linhas copiadas | 8 pares | E5 |
| pedido_compra | ordem_compra = 0: o pedido não se liga a nenhuma entrada | 11 pedidos | E6 |
| pedido_compra | Data de entrega anterior à data do pedido | 20 pedidos | E7 |
| pedido_compra | Data de entrega preenchida, mas quantidade entregue = 0 | 11 pedidos | E8 |
| pedido_compra | Mesmo produto pedido duas vezes no mesmo dia (pedidos 21 a 29 repetem 12 a 20) | 9 pares | E9 |
| pedido_compra | Fornecedor do pedido diferente do fornecedor do produto no cadastro | 22 pedidos | E10 |
| pedido_compra | Dados soltos nas colunas M a W, sem cabeçalho, contradizendo as colunas principais (ex.: P19 com 40 pedidos ali e 20 na tabela) | 9 linhas (planilha 22 a 30) | Aviso do `scripts/importar.py` (não foram importados) |
| pedido_compra | A planilha não tem a coluna `qtde_pendente`, que existe no DDL | 1 coluna | Calculada na importação |
| pedido × entrada | Quantidade entregue no pedido diferente da recebida nas notas | 18 de 18 pedidos com entrada | E11 |
| pedido × entrada | Recebido mais do que foi pedido (ex.: P3 pediu 12 e recebeu 88) | 7 pedidos | E12 |
| entradas_mercadoria | Mercadoria entrou antes de ser pedida | 9 notas | E13 |
| entradas_mercadoria | Custo na nota diferente do preço do pedido | 18 notas | E14 |
| entradas_mercadoria | Nota sem pedido correspondente (ordens 19 e 20, cujos pedidos estão com ordem 0) | 2 notas | E15 |
| produtos_filial | Preço de compra maior que o preço de venda (P1, P8, P15, P18) | 4 produtos | E16 |
| produtos_filial | Preço de compra do cadastro diferente do pedido e/ou da nota | 18 produtos | E17 |
| produtos_filial | Cabeçalho `idproduto` em vez de `produto_id`, e código do fornecedor em texto ("F8") enquanto o DDL esperava número | 2 colunas | Parte 1 (tratado na importação) |
