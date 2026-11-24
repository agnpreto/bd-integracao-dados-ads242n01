# Parte 1 — Documentação do Processo de Importação

## 1. Objetivo

Analisar a planilha `dados/base_teste.xlsx`, preparar a estrutura do banco de dados em PostgreSQL 18, importar os registros das cinco abas e documentar os tratamentos aplicados aos dados e as correções realizadas no DDL original.

## 2. Ferramentas utilizadas

- **PostgreSQL 18** — ambiente de teste da estrutura e das consultas SQL.
- **Python 3** (pandas, openpyxl, psycopg2) — leitura da planilha e script de importação (`scripts/importar.py`).
- **SQL** — criação das tabelas, inserção e conferência dos registros.
- **Excel** — inspeção manual da planilha recebida.
- **MySQL 8** — teste de compatibilidade da estrutura alternativa.

## 3. Estrutura da planilha recebida

O arquivo `base_teste.xlsx` contém as cinco abas descritas no enunciado:

| Aba | Registros |
|---|---:|
| fornecedor | 20 |
| produtos_filial | 20 |
| pedido_compra | 29 |
| entradas_mercadoria | 20 |
| venda | 33 |
| **Total** | **122** |

### Tipos de dados por aba

- **fornecedor**: `idfornecedor` (int), `nome`, `cnpj`, `telefone`, `email`, `endereco` (texto).
- **produtos_filial**: `filial_id` (int), `idproduto` → `produto_id` (texto), `descricao` (texto), `idfornecedor` (int), `unidade_medida` (texto), `preco_unitario` (decimal).
- **pedido_compra**: `pedido_id` (int), `fornecedor_id` (int), `item` (int), `produto_id` (texto), `qtde_pedida` e `qtde_entregue` (numérico), `data_pedido` (data), `valor_unitario` (decimal).
- **entradas_mercadoria**: `filial_id` (int), `fornecedor_id` (int), `produto_id` (texto), `item` (int), `ordem_compra` (int), `data_entrada` (data), `qtde_entregue` (numérico), `valor_unitario` (decimal).
- **venda**: `venda_id` (int), `data_emissao` (data), `horariomov` (hora), `produto_id` (texto), `qtde_vendida` (numérico), `valor_unitario` (decimal), `filial_id` (int), `item` (int), `unidade_medida` (texto).

## 4. Tratamentos e correções aplicados

### 4.1 Correções no DDL original

O DDL fornecido apresentava erros intencionais, que foram corrigidos:

- **Nomes de colunas**: `idforncedor` → `idfornecedor`; `decricao` → `descricao`; `idfonecedor` → `idfornecedor`.
- **Chave primária de `fornecedor`**: removida a coluna inexistente `idproduto` da PK; mantido apenas `idfornecedor`.
- **Chave primária de `produtos_filial`**: substituída por `(filial_id, produto_id)`, com `filial_id NOT NULL`.
- **Coluna ausente em `entradas_mercadoria`**: adicionada a coluna `ordem_compra`, usada na PK e no relacionamento com `pedido_compra`.
- **Tipos de dados incorretos**: identificadores e números de item estavam como `float8` / `DOUBLE PRECISION` e foram convertidos para `INTEGER` (`pedido_id`, `item`, `ordem_compra`).
- **Chave primária de `venda`**: simplificada para `venda_id` (chave natural), eliminando a PK composta redundante do DDL original.
- **Chaves estrangeiras adicionadas**:
  - `produtos_filial.idfornecedor → fornecedor.idfornecedor`
  - `pedido_compra.fornecedor_id → fornecedor.idfornecedor`
  - `entradas_mercadoria.ordem_compra → pedido_compra.pedido_id`
  - `entradas_mercadoria.(filial_id, produto_id) → produtos_filial.(filial_id, produto_id)`
  - `venda.(filial_id, produto_id) → produtos_filial.(filial_id, produto_id)`

### 4.2 Tratamentos nos dados

- **Datas** (`data_pedido`, `data_entrada`, `data_emissao`) convertidas para `DATE`.
- **Horário** (`horariomov`) convertido para `TIME`.
- **Códigos de produto** mantidos como texto (`VARCHAR`), preservando zeros à esquerda.
- **Quantidades e valores** convertidos para `NUMERIC`, evitando erros de ponto flutuante.
- **Colunas extras vazias** descartadas (ex.: colunas `Unnamed` em `pedido_compra`).
- **Registros duplicados** tratados com `ON CONFLICT DO NOTHING` sobre as PKs.
- **Quantidade pendente** (em `pedido_compra`) calculada como `qtde_pedida - qtde_entregue`.

### 4.3 Boas práticas adotadas

- Credenciais do banco via **variáveis de ambiente**, sem senha no código-fonte.
- Importação em **transação única**, com `COMMIT`/`ROLLBACK`, garantindo atomicidade.
- Ordem de importação respeita as FKs: `fornecedor → produtos_filial → pedido_compra → entradas_mercadoria → venda`.

## 5. Conferência da importação

A quantidade efetivamente gravada é verificada com a consulta:

```sql
SELECT 'fornecedor'          AS tabela, COUNT(*) FROM fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*) FROM produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*) FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*) FROM venda;
