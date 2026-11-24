# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

## 1. Objetivo da reunião

Validar os dados do mês de **fevereiro de 2025** com o cliente antes do fechamento,
garantindo que o que entrou no banco corresponde ao que aconteceu nas lojas:
vendas realizadas, pedidos feitos, mercadorias recebidas e cadastros de produto.
Consultas prontas em `sql/04_validacao.sql` (itens a–j).

## 2. Pontos a validar com o cliente

Lista objetiva (cada item é um achado dos dados, com consulta em `sql/04_validacao.sql`):

1. **11 pedidos com `ordem_compra = 0` (dados faltantes)** — pedidos 19..29 vieram
   sem número de ordem de compra. Sem esse número não é possível ligar o pedido à
   entrada de mercadoria. Consulta: `04_validacao.sql` §(e).
2. **2 entradas órfãs (ordens 19 e 20)** — NFE19 e NFE20 referenciam ordens cujos
   pedidos vieram com `ordem_compra = 0`. Consulta: §(d).
3. **9 pedidos duplicados (21..29 vs 12..20)** — mesmos produto, data e preço,
   mas quantidades diferentes. Precisa decidir se são pedidos distintos ou
   retrabalho de digitação. Consulta: §(i).
4. **13 vendas de produtos sem cadastro (P21..P28)** — vendas realizadas de
   produtos que não existem em `produtos_filial`. Consulta: §(g).
5. **5 quantidades fracionadas em unidade "UN"** (38,6; 20,04; 2,86; 37,11; 3,11)
   — UN não deveria ser fracionária. Consulta: §(f).
6. **20 entregas anteriores à data do pedido** (até 48 dias antes) — erro de
   digitação ou datas trocadas. Consulta: §(h).
7. **18 ordens com divergência de quantidade** entre `qtde_pedida` e a soma das
   entradas (`qtde_recebida`). Consulta: §(j).
8. **`horariomov` sempre `08:00:00`** em todas as 33 vendas (suspeito, mas pode
   ser padrão do sistema).
9. **Produtos requisitados e não recebidos (9 produtos, P12..P20)** — pedidos sem
   entrada correspondente. Consulta: §(c) / `02_consultas.sql` (b).

## 3. Técnicas para garantir a exatidão dos dados

- **Reconciliação de quantidades:** comparar `qtde_pedida` (pedido) com a soma de
  `qtde_recebida` (entradas) por `ordem_compra`, reportando a diferença
  (consulta §(j)). Diferença zero = reconciliado.
- **Conferência de datas:** garantir `data_pedido ≤ data_entrega` e que a venda
  ocorre após o recebimento, quando aplicável (consulta §(h)).
- **Validação de cadastro antes da venda:** toda venda deve referenciar um produto
  existente em `produtos_filial` (consulta §(g)); produtos sem cadastro entram em
  quarentena até o cliente confirmar.
- **Conferência de contagens:** linhas da planilha vs. linhas do banco por tabela
  (consulta `validar.sql` §1) — todas OK (20/20/29/20/33).
- **Detecção de duplicidades:** PK e chaves de negócio (`validar.sql` §3).
- **Faixas e nulos:** IDs e datas dentro de 2025, sem nulos indevidos
  (`validar.sql` §4 e §5.7).
- **Revisão com o cliente linha a linha** dos itens da seção 2, anotando a decisão
  (corrigir, manter como está ou descartar).
- **Constraint `NOT VALID`** em `fk_venda_produto`: documenta a relação sem bloquear
  a importação dos 13 órfãos; será validada quando os cadastros forem regularizados.

## 4. Consultas prontas (referência a `sql/04_validacao.sql`)

| Item | Consulta | O que mostra |
| --- | --- | --- |
| (a) | Total vendido em fev/2025 | Referência do fechamento (14 produtos) |
| (b) | Vendas fora de fev/2025 | 19 vendas fora do mês |
| (c) | Pedidos sem entrada | 11 pedidos (P12..P20) |
| (d) | Entradas órfãs | 2 (NFE19, NFE20) |
| (e) | Pedidos com `ordem_compra = 0` | 11 pedidos |
| (f) | Vendas fracionadas em UN | 5 vendas |
| (g) | Vendas sem produto cadastrado | 13 vendas (P21..P28) |
| (h) | Entregas antes do pedido | 20 pedidos |
| (i) | Pedidos duplicados | 9 pares (21..29 vs 12..20) |
| (j) | Divergência de quantidade | 18 ordens |

## 5. Lista de erros nos dados (com consulta de detecção)

| Erro | Consulta | Impacto | Ação recomendada |
| --- | --- | --- | --- |
| 11 pedidos com `ordem_compra = 0` | `04_validacao.sql` §(e) | Impossível ligar pedido à entrada; 2 entradas órfãs | Completar a ordem de compra no sistema de origem |
| 2 entradas órfãs (ordens 19, 20) | `04_validacao.sql` §(d) | Mercadoria recebida sem pedido associado | Associar ao pedido correto ou criar o pedido faltante |
| 9 pedidos duplicados (21..29 vs 12..20) | `04_validacao.sql` §(i) | Dobra quantidade pedida; relatórios inflados | Confirmar com o cliente se são pedidos distintos; remover se duplicata |
| 13 vendas de P21..P28 sem cadastro | `04_validacao.sql` §(g) | Venda sem descrição/preço de referência | Cadastrar os produtos ou reclassificar a venda |
| 5 quantidades fracionadas em UN | `04_validacao.sql` §(f) | Inconsistência de unidade de medida | Corrigir a unidade ou a quantidade |
| 20 entregas anteriores ao pedido | `04_validacao.sql` §(h) | Datas incoerentes para rastreio | Corrigir as datas (provável troca dia/mês) |
| 18 ordens com divergência de quantidade | `04_validacao.sql` §(j) | Estoque físico vs. sistema divergente | Recontar e ajustar `qtde_entregue`/entradas |
| `horariomov` sempre `08:00:00` | `validar.sql` §4 | Hora da venda não confiável | Verificar se o sistema grava a hora real |
| Bloco duplicado M..W em `pedido_compra` | leitura completa do xlsx | Cópia deslocada de pedidos 12..20 | Ignorar no banco; documentar como ruído da planilha |
| `fornecedor_id` numérico vs. texto | `validar.sql` §5.3 (0 após) | Incompatibilidade de tipo | Normalizado no script (1..20 → F1..F20) |
| `fk_venda_produto` NOT VALID | `pg_constraint` | Relação documentada mas não validada | Cadastrar P21..P28 e rodar `VALIDATE CONSTRAINT` |
| `fk_entradas_pedido` impossível | `04_validacao.sql` §(d)/(e) | Sem unicidade em `ordem_compra` | Padronizar `ordem_compra` (sem zeros) |
