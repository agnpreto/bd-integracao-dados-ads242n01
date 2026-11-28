# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

Objetivo da reunião: o cliente sair sabendo que **os números do sistema batem com os dele** e com uma lista clara do que precisa ser corrigido na origem antes de entrar em produção.

Roteiro sugerido (cerca de 1 hora):

1. **Abrir com os totais** (5 min): mostrar que entrou tudo (A1) e o faturamento de fevereiro (A2). Se o total bate com o relatório do cliente, a conversa começa com confiança.
2. **Descer no detalhe** (15 min): por filial (A3), por dia (A4), por produto (Parte 2). O cliente escolhe 2 ou 3 dias/produtos e confere com o sistema dele.
3. **Compras e recebimento** (10 min): pedidos e entradas do mês (A5) e o que está pendente (Parte 2, consulta 2.2).
4. **Apresentar os erros** (20 min): painel resumo (bloco C), depois cada erro com a lista de linhas. Para cada um, sair com **uma decisão e um responsável**.
5. **Fechar** (10 min): registrar as decisões em ata e combinar a data da nova carga.

## 1. Pontos a validar

**Volumes e totais de fevereiro**
- Linhas importadas por tabela = linhas da planilha (20 / 20 / 29 / 20 / 33).
- Faturamento de fevereiro: **14 vendas, 173,22 unidades, R$ 14.093,17**. Bate com o fechamento do cliente?
- Faturamento por filial: filial 1 = R$ 13.545,64; filial 2 = R$ 547,53. A filial 3 não vendeu em fevereiro. Isso está certo?
- Faturamento por dia: só há venda em 6 dias de fevereiro (07, 17, 18, 20, 22 e 28). A loja realmente não vendeu nos outros dias, ou a planilha é uma amostra?
- Compras de fevereiro: 17 linhas de pedido (619 un., R$ 28.396,93) e 10 entradas de NF (468 un., R$ 36.722,92).

**Cadastros**
- Os produtos P21 a P28 existem? Qual descrição e fornecedor?
- As filiais 2 e 3 existem? Por que não há produto cadastrado nelas?
- Qual fornecedor vale: o do cadastro do produto ou o do pedido? (Hoje discordam em 22 pedidos.)

**Regras de negócio que precisam ser confirmadas**
- Qual a fonte da verdade do recebimento: o campo `qtde_entregue` do pedido ou a nota fiscal (`entradas_mercadoria`)? Usamos a NF.
- O que significa `ordem_compra = 0`? Pedido sem ordem emitida ou falha na exportação?
- "Produto requisitado mais de 10 vezes": é **mais de 10 pedidos** ou **mais de 10 unidades**? (Parte 3; adotamos unidades, porque nenhum produto tem mais de 2 pedidos.)
- Pode vender fração de produto com unidade `UN`? Se pode, qual unidade correta (KG, L)?
- Qual a diferença entre `preco_unitario` e `preco_venda` no cadastro de produtos?

## 2. Técnicas para garantir exatidão e precisão

- **Contagem de linhas** origem × destino em todas as tabelas, feita no banco (`SELECT COUNT(*)`), nunca confiando na mensagem do script. Foi assim que descobrimos que o script original "inseria" 33 vendas e gravava 0.
- **Totais de controle (checksums de negócio)**: soma de quantidade e de R$ por mês, por filial e por dia, calculados de duas formas independentes (planilha via pandas e banco via SQL) e comparados. Fevereiro bateu nos dois: R$ 14.093,17.
- **Amostragem**: o cliente escolhe algumas vendas/notas reais (ex.: NF de um produto) e conferimos linha a linha no sistema.
- **Reconciliação entre tabelas**: pedido × entrada (pela `ordem_compra`), venda × cadastro de produto, pedido × fornecedor. É onde aparece a maior parte dos erros.
- **Regras de consistência**: datas em ordem lógica (pedido ≤ entrega ≤ entrada), quantidades coerentes (recebido ≤ pedido), preços positivos, unidade compatível com a quantidade.
- **Restrições no próprio banco**: tipos corretos (`numeric` para dinheiro, `integer` para ids, `date`), chaves primárias, chaves estrangeiras e `CHECK`. O banco recusa dado inválido em vez de aceitar calado.
- **Carga repetível e tudo-ou-nada**: o script valida antes, grava em uma transação e pode ser rodado de novo sem duplicar. Corrigiu a planilha? Roda de novo e confere.
- **Não corrigir dado do cliente por conta própria**: os erros entram como vieram e são decididos na reunião. Cada correção fica registrada (o que, quem decidiu, quando).
- **Precisão numérica**: valores em `numeric(12,4)` e arredondamento só na exibição (`ROUND(...,2)`), para não acumular erro de ponto flutuante.

## 3. Consultas preparadas para a reunião

Todas em `sql/04_validacao.sql`. Rodam sem alteração no PostgreSQL e no MySQL.

| Consulta | O que mostra | Para que serve na reunião |
| --- | --- | --- |
| A1 | Linhas por tabela | Provar que nada se perdeu na carga |
| A2 | Nº de vendas, quantidade e faturamento de fevereiro | Número principal para o cliente bater com o fechamento dele |
| A3 | Faturamento de fevereiro por filial | Conferir com o fechamento de cada loja |
| A4 | Faturamento de fevereiro por dia | Conferir com o caixa diário; revela dias sem venda |
| A5 | Pedidos e entradas de NF em fevereiro | Conferir com o setor de compras |
| E01 a E17 | Uma consulta por erro, listando as linhas com problema | Mostrar exatamente quais registros corrigir |
| Bloco C | Painel com a quantidade de ocorrências de cada erro | Abrir a parte de erros: o cliente vê o tamanho de cada problema de uma vez |

Também ficam prontas as consultas da Parte 2 (`sql/02_consultas.sql`): vendas por produto em fevereiro e produtos requisitados e não recebidos.

## Erros encontrados nos dados

Quantidades obtidas rodando o bloco C de `sql/04_validacao.sql` (iguais no PostgreSQL e no MySQL).

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| venda | Venda de produto que não existe no cadastro (P21 a P28); 6 delas em fevereiro, somando R$ 3.241,24 | 13 linhas | E01 |
| venda | Venda em filial sem nenhum produto cadastrado (filiais 2 e 3) | 4 linhas | E02 |
| venda | Quantidade fracionada com unidade `UN` (38,6 / 20,04 / 2,86 / 37,11 / 3,11) | 5 linhas | E03 |
| venda | Preço da venda diferente do `preco_venda` do cadastro (em todas as vendas de produto cadastrado) | 20 linhas | E04 |
| venda | Mesmo preço unitário em produtos diferentes (P13/P21 = 61,85; P14/P22 = 106,30 ...): indício de linhas copiadas | 8 grupos | E05 |
| pedido_compra | `ordem_compra = 0`: pedido sem ordem, não liga com nenhuma entrada | 11 linhas | E06 |
| pedido_compra | Pedido duplicado: pedidos 21 a 29 repetem produto, data do pedido e data de entrega dos pedidos 12 a 20, com outra quantidade | 9 pares | E07 |
| pedido_compra | Data de entrega anterior à data do pedido | 20 linhas | E08 |
| pedido_compra | Data de entrega preenchida com quantidade entregue = 0 | 11 linhas | E09 |
| pedido_compra × entradas | `qtde_entregue` do pedido diferente da quantidade da NF (ex.: pedido 1 diz 10, NF diz 77) | 18 linhas | E10 |
| pedido_compra × entradas | Recebeu mais do que pediu (ex.: P3 pediu 12, recebeu 88) | 7 linhas | E11 |
| pedido_compra × entradas | Mercadoria entrou antes de ser pedida | 9 linhas | E12 |
| entradas_mercadoria | Entrada sem pedido correspondente (NFE19 e NFE20: ordens 19 e 20, mas os pedidos 19 e 20 estão com ordem 0) | 2 linhas | E13 |
| pedido_compra × entradas | Data de entrada da NF diferente da data de entrega do pedido | 17 linhas | E14 |
| pedido_compra × entradas | Custo na NF difere mais de 20% do preço do pedido (ex.: P1 pedido R$ 46,67, NF R$ 84,35) | 16 linhas | E15 |
| pedido_compra × produtos | Fornecedor do pedido diferente do fornecedor do cadastro (ex.: P1: pedido diz 1, cadastro diz 8) | 22 linhas | E16 |
| produtos_filial | Preço de compra maior que o preço de venda (P1, P8, P15 e P18): venda com prejuízo | 4 linhas | E17 |
| planilha (aba pedido_compra) | 11 colunas sem cabeçalho (M a W) preenchidas nas linhas 22–30, com cópia dos pedidos 12 a 20 e valores que nem batem com eles (ex.: P19 com 40 pedidas, contra 20 no pedido 19) | 9 linhas | Aviso do `scripts/importar.py` |
| planilha (aba pedido_compra) | Coluna `qtde_pendente` do DDL não existe na planilha | 1 coluna | — (resolvido com coluna calculada) |
| fornecedor × pedido_compra | Id do fornecedor em formatos diferentes (`F1` na aba fornecedor, `1` no pedido) | 20 fornecedores | — (resolvido na carga: `F1` → 1) |

**Impacto nas consultas de fevereiro**
- Faturamento de fevereiro inclui R$ 3.241,24 de produtos sem cadastro (E01). Se o cliente disser que esses produtos não existem, o faturamento real cai para R$ 10.851,93.
- A lista de "requisitados e não recebidos" (Parte 2) mostra P19 e P20 como não recebidos, mas existem as NFs NFE19 e NFE20 desses produtos; o vínculo quebrou porque o pedido ficou com `ordem_compra = 0` (E06/E13). Precisa da confirmação do cliente.
