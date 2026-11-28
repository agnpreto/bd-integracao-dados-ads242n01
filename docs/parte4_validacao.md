# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

## 1. Pontos a validar
1. **Volumetria e Completude da Carga:**
   - Conferir se o total de registros importados em cada tabela (`venda`, `pedido_compra`, `entradas_mercadoria`, `produtos_filial` e `fornecedor`) corresponde exatamente às linhas válidas da planilha original enviada pelo cliente.
2. **Fechamento Financeiro e Quantitativo de Fevereiro/2025:**
   - Validar o total de vendas distintas, o volume total de unidades vendidas e o faturamento bruto (`qtde_vendida * valor_unitario`) apurado no período de `01/02/2025` a `28/02/2025` por filial e por produto.
3. **Política de Preços e Descontos:**
   - Confirmar se as diferenças encontradas entre `valor_unitario` (na tabela `venda`) e `preco_venda` (na tabela `produtos_filial`) representam promoções/descontos autorizados no PDV ou erro de sincronização de tabela de preços.
4. **Fluxo de Compras e Recebimento (`ordem_compra`):**
   - Validar pedidos de compra em aberto (`qtde_pendente > 0` ou sem registro correspondente em `entradas_mercadoria`) para confirmar se estão aguardando entrega ou se houve esquecimento no lançamento da Nota Fiscal de entrada.
   - Revisar divergências onde `qtde_pedida - qtde_entregue` não bate com `qtde_pendente`.
5. **Cadastro de Produtos e Fornecedores:**
   - Validar itens vendidos ou movimentados sem cadastro completo em `produtos_filial`, produtos com estoque negativo e itens sem fornecedor associado (`idfornecedor`).

---
## 2. Técnicas para garantir exatidão e precisão
- **Reconciliação de Volumetria (Contagem Origem × Destino):** Comparação sistemática via `SELECT COUNT(*)` após a carga para garantir que nenhuma linha foi perdida ou duplicada silenciosamente.
- **Integridade Referencial e Restrições de Esquema (DDL):** Aplicação de chaves primárias compostas, chaves estrangeiras (`produtos_filial.idfornecedor -> fornecedor.idfornecedor`) e valores padrão (`DEFAULT`) para impedir registros órfãos.
- **Testes de Domínio e Regras de Negócio:** Verificação de intervalos válidos (quantidades maiores que zero, preços positivos, margem mínima e consistência cronológica entre `data_pedido`, `data_entrega` e `data_entrada`).
- **Auditoria Cruzada entre Tabelas (`LEFT JOIN` / `EXCEPT`):** Cruzamento entre vendas, cadastro de produtos, pedidos de compra e entradas de mercadoria via `ordem_compra` para isolar anomalias antes da virada para produção.
- **Padronização e Automação via Trigger:** Uso de `TRIGGER` em `produtos_filial` para garantir que todo novo produto receba um `idfornecedor` válido e vinculado à tabela `fornecedor`.

---
## 3. Consultas preparadas para a reunião

(As consultas ficam em `sql/04_validacao.sql`. Explique aqui o que cada uma mostra.)

Todas as consultas abaixo estão salvas em `sql/04_validacao.sql` e foram preparadas para execução em tempo real com o cliente:

1. **Resumo Executivo por Filial (Fevereiro/2025):** Apura quantidade de vendas distintas, volume de peças e faturamento bruto por loja (`filial_id`) para conciliação direta com o fechamento gerencial/ERP do cliente.
2. **Evolução Diária de Vendas (Fevereiro/2025):** Detalha o movimento dia a dia (`01/02/2025` a `28/02/2025`) para identificar dias sem operação, feriados ou possíveis falhas na importação diária.
3. **Ranking dos 15 Produtos Mais Vendidos (Curva A):** Lista os produtos líderes em faturamento e quantidade no mês para validação com a equipe comercial.
4. **Conciliação de Compras × Recebimentos (`ordem_compra`):** Cruza pedidos de compra com entradas de mercadoria e notas fiscais (`nro_nfe`) para evidenciar o que foi entregue, o que segue pendente e possíveis divergências de saldo.
5. **Posição de Estoque Crítico e Ruptura:** Lista produtos com saldo zerado ou negativo (`estoque <= 0`) por filial e o respetivo fornecedor vinculado para revisão operacional imediata.

## Erros encontrados nos dados

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| `venda` | Vendas em fev/2025 com quantidade nula, zerada ou negativa (`qtde_vendida <= 0`) | A apurar na execução | `sql/04_validacao.sql` (Consulta Erro A) |
| `venda` | Vendas em fev/2025 com valor unitário zerado ou negativo (`valor_unitario <= 0`) | A apurar na execução | `sql/04_validacao.sql` (Consulta Erro B) |
| `venda` / `produtos_filial` | Produtos vendidos sem cadastro correspondente na filial | A apurar na execução | `sql/04_validacao.sql` (Consulta Erro C) |
| `venda` / `produtos_filial` | Divergência entre o preço unitário praticado na venda e o preço de cadastro | A apurar na execução | `sql/04_validacao.sql` (Consulta Erro D) |
| `entradas_mercadoria` | Entradas vinculadas a `ordem_compra` inexistente em `pedido_compra` | A apurar na execução | `sql/04_validacao.sql` (Consulta Erro E) |
| `pedido_compra` | Divergência matemática de saldo (`qtde_pedida - qtde_entregue <> qtde_pendente`) | A apurar na execução | `sql/04_validacao.sql` (Consulta Erro F) |
| `pedido_compra` / `entradas_mercadoria` | Data de entrega ou entrada anterior à data do pedido (`data_pedido`) | A apurar na execução | `sql/04_validacao.sql` (Consulta Erro G) |
| `produtos_filial` | Estoque negativo ou preço de venda menor que o preço de compra | A apurar na execução | `sql/04_validacao.sql` (Consulta Erro H) |
| `produtos_filial` / `fornecedor` | Produtos sem fornecedor vinculado (`idfornecedor` nulo ou inválido) | A apurar na execução | `sql/04_validacao.sql` (Consulta Erro I) |

## Erros encontrados nos dados
1. **Inconsistências estruturais corrigidas antes da carga (DDL e Planilha):**
   - Falta da coluna `ordem_compra` na definição de `entradas_mercadoria` (exigida na chave primária e na ligação com `pedido_compra`).
   - Referência a colunas inexistentes nas chaves primárias (`idproduto` em `produtos_filial` e `fornecedor`) e erro de grafia em `decricao` e `idfonecedor`.
   - Tipos incompatíveis de chave entre `produtos_filial.idfornecedor` (`int4`) e `fornecedor.idfornecedor` (`varchar(25)`).
2. **Vendas com quantidade inválida (`qtde_vendida <= 0` ou `NULL`):**
   - *Consulta:* Seção `Erro A` em `sql/04_validacao.sql`.
3. **Vendas com preço unitário zerado ou negativo (`valor_unitario <= 0`):**
   - *Consulta:* Seção `Erro B` em `sql/04_validacao.sql`.
4. **Itens vendidos sem cadastro correspondente em `produtos_filial`:**
   - *Consulta:* Seção `Erro C` em `sql/04_validacao.sql`.
5. **Divergência entre preço praticado na venda e preço de tabela:**
   - *Consulta:* Seção `Erro D` em `sql/04_validacao.sql`.
6. **Entradas de mercadoria sem pedido de compra correspondente (`ordem_compra` órfã):**
   - *Consulta:* Seção `Erro E` em `sql/04_validacao.sql`.
7. **Inconsistência matemática nos saldos de compra (`qtde_pedida - qtde_entregue <> qtde_pendente`):**
   - *Consulta:* Seção `Erro F` em `sql/04_validacao.sql`.
8. **Anomalias cronológicas (`data_entrega` ou `data_entrada` anterior a `data_pedido`):**
   - *Consulta:* Seção `Erro G` em `sql/04_validacao.sql`.
9. **Estoque negativo ou preço de venda inferior ao preço de compra:**
   - *Consulta:* Seção `Erro H` em `sql/04_validacao.sql`.
10. **Produtos sem fornecedor vinculado (`idfornecedor` nulo ou inexistente):**
    - *Consulta:* Seção `Erro I` em `sql/04_validacao.sql`.
| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
|  |  |  |  |
