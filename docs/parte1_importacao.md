# Parte 1 — Documentação do Processo de Importação

## 1. Objetivo

Analisar a planilha `dados/base_teste.xlsx`, preparar a estrutura do banco em PostgreSQL 18, importar os registros das cinco abas e documentar os tratamentos aplicados e as inconsistências identificadas na origem.

## 2. Ferramentas utilizadas

| Ferramenta | Uso |
|---|---|
| PostgreSQL 18 | Criação da estrutura, importação e conferência |
| Python 3 (pandas, openpyxl, psycopg2) | Leitura da planilha e script `scripts/importar.py` |
| Excel | Inspeção manual do arquivo |
| SQL | Consultas de validação (`sql/04_validacao.sql`) |

## 3. Estrutura da planilha recebida

O arquivo `dados/base_teste.xlsx` contém **5 abas** e **122 registros**:

| Aba | Registros |
|---|---:|
| fornecedor | 20 |
| produtos_filial | 20 |
| pedido_compra | 29 |
| entradas_mercadoria | 20 |
| venda | 33 |
| **Total** | **122** |

### Colunas observadas

| Aba | Colunas |
|---|---|
| fornecedor | idfornecedor, razao_social |
| produtos_filial | filial_id, idproduto, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor |
| pedido_compra | pedido_id, data_pedido, item, produto_id, descricao_produto, ordem_compra, qtde_pedida, filial_id, data_entrega, qtde_entregue, preco_compra, fornecedor_id |
| entradas_mercadoria | data_entrada, nro_nfe, item, produto_id, descricao_produto, ordem_compra, qtde_recebida, filial_id, custo_unitario |
| venda | venda_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario, filial_id, item, unidade_medida |

## 4. Tratamentos e correções aplicados

### 4.1 Schema

O DDL foi reescrito para casar com as colunas reais da planilha. Correções sobre o DDL original:

| Item | Correção |
|---|---|
| Nomes de colunas | `idforncedor` → `idfornecedor`, `decricao` → `descricao` |
| PK de `fornecedor` | Apenas `idfornecedor` (removida coluna inexistente `idproduto`) |
| PK de `produtos_filial` | `(filial_id, produto_id)` |
| Coluna `ordem_compra` em `entradas_mercadoria` | Adicionada |
| `float8` em IDs e itens | Convertidos para `INTEGER` |
| PK de `venda` | Simplificada para `venda_id` |
| FKs | Adicionadas como `NOT VALID` (a base contém violações intencionais — ver Parte 4) |

### 4.2 Dados

| Tratamento | Detalhe |
|---|---|
| Datas (`data_emissao`, `data_pedido`, `data_entrega`, `data_entrada`) | Convertidas para `DATE` |
| Horário (`horariomov`) | Normalizado para `TIME` |
| Decimais com vírgula | Substituída por ponto antes de converter |
| `fornecedor_id` numérico (1–20) em `pedido_compra` | Convertido para texto `F1`–`F20` (compatível com `fornecedor.idfornecedor`) |
| `idproduto` em `produtos_filial` | Renomeado para `produto_id` |
| Colunas extras M–W em `pedido_compra` | Descartadas (`Unnamed`) |
| Duplicidades | Tratadas com `ON CONFLICT DO NOTHING` |

### 4.3 Boas práticas

| Prática | Aplicação |
|---|---|
| Credenciais via ambiente | `DB_HOST`, `DB_USER`, `DB_PASSWORD` |
| Transação única | `COMMIT` / `ROLLBACK` |
| Ordem de importação | `fornecedor → produtos_filial → pedido_compra → entradas_mercadoria → venda` |

## 5. Conferência da importação

Contagem via `SELECT COUNT(*)` após `python scripts/importar.py`:

| Tabela | Planilha | Banco | Situação |
|---|---:|---:|---|
| fornecedor | 20 | 20 | ✅ |
| produtos_filial | 20 | 20 | ✅ |
| pedido_compra | 29 | 29 | ✅ |
| entradas_mercadoria | 20 | 20 | ✅ |
| venda | 33 | 33 | ✅ |
| **Total** | **122** | **122** | ✅ |

Consulta usada:

```sql
SELECT 'fornecedor' AS tabela, COUNT(*) FROM fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*) FROM produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*) FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*) FROM venda;
