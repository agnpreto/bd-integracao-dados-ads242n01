# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

**Objetivo da reunião:** o cliente confirmar que os números de fevereiro/2025
no banco são os mesmos do sistema dele, e decidir o que fazer com cada erro
encontrado nos dados.

**Escopo:** vendas com `data_emissao` de 01/02/2025 a 28/02/2025, e os pedidos e
entradas de mercadoria que explicam o estoque desse mês.

**Material levado:** `sql/04_validacao.sql` aberto no DBeaver, com as consultas
numeradas de **V01** a **V18**, e a planilha original para mostrar a origem de
cada dado.

**Números de fevereiro que o cliente precisa reconhecer (V02):**

| Linhas de venda | Produtos | Filiais | Quantidade | Valor |
| --- | --- | --- | --- | --- |
| 14 | 14 | 2 (1 e 2) | 173,22 | R$ 14.093,17 |

Para contexto (V03): janeiro tem 12 vendas (R$ 17.947,15) e março tem 7 (R$ 2.727,89).

## 1. Pontos a validar

Organizei em ordem de impacto no resultado de fevereiro: primeiro o que muda
o total vendido, depois compras e recebimentos, por fim cadastro.

**A. Vendas de fevereiro**

1. **O total bate?** Comparar 14 vendas / 173,22 un. / R$ 14.093,17 (V02) com o
   relatório de vendas do cliente. Se não bater, abrir por filial e produto (V04)
   para achar a diferença.
2. **O corte do mês está certo?** Confirmar que a referência é a data de emissão
   e que não há cancelamentos ou devoluções que deveriam abater o valor.
3. **Produtos vendidos que não existem no cadastro** (E01, V05). Em fevereiro são
   6 vendas (P22 a P27), R$ 3.241,24 de R$ 14.093,17, ou seja, 23% do faturamento
   do mês sem descrição nem custo. Pergunta: são produtos novos ainda não
   cadastrados ou códigos digitados errado?
4. **Filiais sem cadastro** (E02, V06). O cadastro de produtos só tem a filial 1,
   mas há vendas nas filiais 2 e 3. Pergunta: falta enviar o cadastro dessas
   filiais ou o cadastro é único para a rede?
5. **Quantidade quebrada em unidade "UN"** (E03, V07). Em fevereiro, a venda 16
   (37,11 un. de P16) e a 26 (3,11 un. de P26). Pergunta: a unidade está
   errada (é KG?) ou a quantidade foi digitada errada?

**B. Compras e recebimentos**

6. **Pedido × nota de entrada.** Confirmar que o vínculo é `ordem_compra` (+
   item + produto), como foi dito no enunciado.
7. **Pedidos com ordem 0** (E06, V10) e **notas de ordens que não existem** (E05,
   V09). Os pedidos 19 e 20 (P19 e P20) estão com ordem 0, e as notas NFE19 e
   NFE20 (P19 e P20) chegaram com as ordens 19 e 20. Pergunta: posso ligar a
   NFE19 ao pedido 19 e a NFE20 ao pedido 20?
8. **Pedidos 21 a 29 repetidos** (E07, V11). Repetem produto, data, entrega,
   preço e fornecedor dos pedidos 12 a 20, com quantidade pequena e ordem 0.
   Pergunta: são complementos legítimos ou lançamento duplicado que deve ser excluído?
9. **Datas impossíveis** (E04, V08 e E10, V14). Pedidos entregues antes de
   serem feitos e notas de entrada anteriores ao pedido. Pergunta: qual das duas
   datas está errada? A data do pedido pode ser a de aprovação, e não a de emissão?
10. **Quantidade entregue** (E08, V12 e E09, V13). O campo `qtde_entregue` do
    pedido não bate com a soma das notas, e em 7 pedidos chegou mais do que foi
    pedido. Pergunta: qual fonte vale, o pedido ou a nota fiscal? Recebimento
    acima do pedido é aceito?
11. **Pendências de fevereiro** (V18). 14 linhas de pedido de fevereiro com saldo
    a receber. Revisar uma a uma: ainda está para chegar, foi cancelado ou
    chegou e não foi lançado?

**C. Cadastro e preços** (não classifiquei como erro, mas precisa de confirmação)

12. **Preço de venda abaixo do preço de compra** (V16). P1, P8, P15 e P18. É
    promoção ou o preço está errado?
13. **Fornecedor do pedido diferente do fornecedor do cadastro** (V17). Em 22
    pedidos. O produto pode ter mais de um fornecedor?
14. **Custo da nota diferente do preço de compra do cadastro** (V17). Em todas
    as 20 notas. O cadastro guarda custo médio, último custo ou preço de tabela?
15. **Planilha de pedidos com células soltas** (E11). Perguntar de onde veio o
    bloco das colunas M a W e se ele é a versão correta dos pedidos 12 a 20.

## 2. Técnicas para garantir exatidão e precisão

| Técnica | Como apliquei | Consulta |
| --- | --- | --- |
| **Reconciliação de contagem** origem × destino | Linhas por aba = linhas por tabela. O script de importação já faz isso ao final de cada carga | V01 |
| **Reconciliação de totais** (soma de controle) | Quantidade e valor de fevereiro conferidos no total, por filial e por produto, contra o relatório do cliente | V02, V03, V04 |
| **Integridade referencial** | `NOT EXISTS` para achar filhos sem pai: venda sem produto, nota sem pedido, pedido sem fornecedor | V05, V06, V09, V15 |
| **Regras de negócio** | Testes que devem ser sempre verdadeiros: entrega ≥ pedido, entrada ≥ pedido, recebido ≤ pedido, quantidade inteira em `UN` | V07, V08, V13, V14 |
| **Detecção de duplicidade** | Agrupar pela chave de negócio (`HAVING COUNT(*) > 1`) e auto-junção para pedidos iguais com ids diferentes | V10, V11 |
| **Valores sentinela e nulos** | Procurar 0 usado como "sem valor" (ordem 0), nulos e negativos | V10, V15 |
| **Comparação entre fontes do mesmo dado** | `qtde_entregue` do pedido × soma das notas. Preço do cadastro × custo da nota | V12, V17 |
| **Checagens que devem dar zero** | Uma consulta só com vários testes. Qualquer número diferente de 0 indica problema de carga | V15 |
| **Rastreabilidade** | Toda consulta de erro traz a chave de origem (pedido, NFE, venda) para achar a linha na planilha ou no sistema do cliente | V05 a V14 |
| **Revisão pelo cliente (amostragem)** | Escolher 3 ou 4 vendas de fevereiro e conferir com o cupom/nota do cliente, além do total | V04 |
| **Reprodutibilidade** | DDL + script + consultas versionados no Git. Recriar o banco do zero dá o mesmo resultado, e a carga pode ser repetida sem duplicar | todos |
| **Não corrigir sem aval** | Nenhum dado foi alterado. Correções só depois da reunião, por script em transação, rodando V01 a V18 de novo depois | todos |

## 3. Consultas preparadas para a reunião

Todas em `sql/04_validacao.sql`, cada uma com o resultado esperado em comentário.

| Consulta | O que mostra | Resultado nesta base |
| --- | --- | --- |
| V01 | Linhas por tabela × linhas da planilha | 20 / 20 / 29 / 20 / 33, tudo bate |
| V02 | Totais de fevereiro | 14 vendas, 173,22 un., R$ 14.093,17 |
| V03 | Vendas por mês | jan 12, fev 14, mar 7 |
| V04 | Fevereiro por filial e produto | 14 linhas para o cliente conferir |
| V05 | E01: vendas de produto sem cadastro | 8 produtos, 13 vendas (6 em fev.) |
| V06 | E02: vendas em filial sem cadastro | 4 vendas, filiais 2 e 3 |
| V07 | E03: quantidade fracionada em "UN" | 5 vendas (2 em fev.) |
| V08 | E04: entrega antes do pedido | 20 pedidos |
| V09 | E05: nota de entrada sem pedido | NFE19 e NFE20 |
| V10 | E06: pedidos com ordem 0 e chave repetida | 11 pedidos, 2 chaves repetidas |
| V11 | E07: pedidos duplicados | 9 pares (21–29 × 12–20) |
| V12 | E08: entregue no pedido × recebido nas notas | 18 pedidos |
| V13 | E09: recebido acima do pedido | 7 pedidos |
| V14 | E10: nota anterior ao pedido | 9 notas |
| V15 | Checagens que devem dar zero | todas 0 |
| V16 | Preço de venda < preço de compra | 4 produtos |
| V17 | Fornecedor e custo: pedido × cadastro × nota | 22 pedidos, 20 notas |
| V18 | Pedidos de fevereiro com saldo a receber | 14 linhas |

## Erros encontrados nos dados

Todos os números foram conferidos rodando as consultas na base carregada.
Nenhum erro foi corrigido: cada um depende de decisão do cliente.

| ID | Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- | --- |
| E01 | venda × produtos_filial | Venda de produto que não existe no cadastro (P21..P28) | 8 produtos, 13 vendas (6 em fevereiro, R$ 3.241,24) | V05 |
| E02 | venda × produtos_filial | Venda em filial que não tem o produto cadastrado (o cadastro só tem a filial 1) | 4 vendas: P27 na filial 2, P28 na filial 3 | V06 |
| E03 | venda | Quantidade fracionada em unidade `UN` (38,6; 20,04; 2,86; 37,11; 3,11) | 5 vendas (2 em fevereiro) | V07 |
| E04 | pedido_compra | `data_entrega` anterior a `data_pedido` (até 48 dias antes) | 20 de 29 pedidos | V08 |
| E05 | entradas_mercadoria | `ordem_compra` que não existe em nenhum pedido | 2 notas (NFE19 e NFE20, ordens 19 e 20) | V09 |
| E06 | pedido_compra | `ordem_compra = 0`: o pedido não liga a nenhuma nota, e a chave `(0, 1, P19)` / `(0, 1, P20)` se repete | 11 pedidos (19 a 29), 2 chaves repetidas | V10 |
| E07 | pedido_compra | Pedidos 21 a 29 repetem produto, data, entrega, preço e fornecedor dos pedidos 12 a 20 | 9 pares | V11 |
| E08 | pedido_compra × entradas | `qtde_entregue` diferente da soma das notas de entrada (diferenças de até 86 un.) | 18 pedidos | V12 |
| E09 | pedido_compra × entradas | Quantidade recebida maior que a pedida | 7 pedidos | V13 |
| E10 | pedido_compra × entradas | Nota de entrada com data anterior à data do pedido | 9 notas | V14 |
| E11 | planilha (aba pedido_compra) | Células preenchidas sem cabeçalho nas colunas M a W, linhas 22 a 30: cópia dos pedidos 12 a 20 com ordens 12 a 20 e uma coluna de saldo pendente | 9 linhas × 11 colunas | Aviso do `scripts/importar.py` (o bloco não é carregado no banco) |

### Verificado e sem problema

- Sem chave primária duplicada em nenhuma tabela. Sem nulos ou negativos em
  datas, quantidades e valores (V15).
- Depois de converter `F1`..`F20` para 1..20, todo produto e todo pedido aponta
  para um fornecedor existente (V15).

### Pontos para confirmar (não são erro, à primeira vista)

- Preço de venda abaixo do de compra em 4 produtos (V16).
- Fornecedor do pedido ≠ fornecedor do cadastro em 22 pedidos (V17).
- Custo da nota ≠ preço de compra do cadastro nas 20 notas (V17).

## Decisões que vou pedir ao cliente

1. P21 a P28: cadastrar ou corrigir o código na venda?
2. Enviar o cadastro de produtos das filiais 2 e 3?
3. Vendas 4, 8, 12, 16 e 26: corrigir a quantidade ou a unidade?
4. Ligar NFE19 → pedido 19 e NFE20 → pedido 20, trocando a ordem 0 por 19 e 20?
5. Pedidos 21 a 29: manter ou excluir?
6. Para quantidade recebida, a fonte oficial é o pedido ou a nota?
7. Nas datas invertidas, qual data corrigir?

Depois das respostas: script de correção em uma transação, nova carga se for o
caso, e repetir V01 a V18 para mostrar que os números fecham. O aceite do
cliente fica registrado na ata.
