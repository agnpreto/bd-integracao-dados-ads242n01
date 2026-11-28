# Parte 1 — Documentação do Processo de Importação

## 1. Ferramentas Utilizadas

- **SGBDs:** PostgreSQL 16 (principal, via pgAdmin 4) e MySQL 8 (DDL de compatibilidade).
- **Linguagem / ETL:** Python 3 com bibliotecas `pandas`, `openpyxl` e `psycopg2-binary` (`scripts/importar.py`).

## 2. Estrutura da Planilha (`dados/base_teste.xlsx`)

A planilha contém 5 abas totalizando 122 registros:

| Aba                   | Linhas | Colunas Principais                                                                                                                                                                  | Observações Estruturais                                                                            |
| :-------------------- | :----: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------- |
| `fornecedor`          |   20   | `idfornecedor`, `razao_social`                                                                                                                                                      | IDs no formato texto (`F1`..`F20`).                                                                |
| `produtos_filial`     |   20   | `filial_id`, `idproduto`, `descricao`, `estoque`, `preco_unitario`, `preco_compra`, `preco_venda`, `idfornecedor`                                                                   | Coluna de produto chama-se `idproduto` na planilha e `produto_id` no banco.                        |
| `pedido_compra`       |   29   | `pedido_id`, `data_pedido`, `item`, `produto_id`, `descricao_produto`, `ordem_compra`, `qtde_pedida`, `filial_id`, `data_entrega`, `qtde_entregue`, `preco_compra`, `fornecedor_id` | Possui 11 colunas extras (`Unnamed: 12` a `Unnamed: 22`) com cópias deslocadas nas linhas 21 a 29. |
| `entradas_mercadoria` |   20   | `data_entrada`, `nro_nfe`, `item`, `produto_id`, `descricao_produto`, `ordem_compra`, `qtde_recebida`, `filial_id`, `custo_unitario`                                                | Liga-se a `pedido_compra` via `ordem_compra`.                                                      |
| `venda`               |   33   | `venda_id`, `data_emissao`, `horariomov`, `produto_id`, `qtde_vendida`, `valor_unitario`, `filial_id`, `item`, `unidade_medida`                                                     | Contém movimentos de janeiro, fevereiro e março de 2025.                                           |

## 3. Erros Encontrados no DDL Original (`sql/01_ddl_enunciado.sql`) e Correções

1. **Tabela `fornecedor`:**
   - **Erro:** Coluna escrita com erro de digitação (`idforncedor`), tipada como `varchar(25)` e chave primária referenciando uma coluna inexistente (`PRIMARY KEY (idforncedor, idproduto)`).
   - **Correção:** Renomeada para `idfornecedor`, alterada para `int4` (para compatibilidade com as FKs e com a trigger numérica da Parte 3) e definida como `PRIMARY KEY (idfornecedor)`.
2. **Tabela `produtos_filial`:**
   - **Erro:** Ausência de vírgula antes de `CONSTRAINT produtos_filial_pkey`; erros de grafia nas colunas (`decricao` e `idfonecedor`); coluna `filial_id` definida como `NULL` apesar de compor a PK; chave primária referenciando `idproduto` em vez de `produto_id`.
   - **Correção:** Adicionada a vírgula, corrigidos os nomes para `descricao` e `idfornecedor`, definido `filial_id int4 NOT NULL`, ajustada a PK para `(filial_id, produto_id)` e criada a chave estrangeira `fk_produtos_fornecedor`.
3. **Tabela `entradas_mercadoria`:**
   - **Erro:** A chave primária exigia a coluna `ordem_compra`, porém a coluna não havia sido declarada no `CREATE TABLE`.
   - **Correção:** Adicionada a coluna `ordem_compra int8 DEFAULT 0 NOT NULL`.
4. **Ordem de Criação e Tipagem:**
   - **Correção:** As tabelas mestras (`fornecedor` e `produtos_filial`) foram movidas para o topo do script para permitir a criação de chaves estrangeiras, e colunas monetárias foram padronizadas para `numeric(12, 4)` (PostgreSQL) / `DECIMAL(12, 4)` (MySQL).

## 4. Tratamentos e Correções no Script (`scripts/importar.py`)

- **Conversão de Datas (`excel_para_data`):** O script original assumia que datas do Excel chegavam apenas como números seriais inteiros (`int(valor)`). Como o `pandas` já interpreta células formatadas como `Timestamp`, a conversão falhava silenciosamente no `try/except` e inseria `NULL` em todas as datas. A função foi ajustada para aceitar `Timestamp`/`datetime`, strings (`YYYY-MM-DD` e `DD/MM/YYYY`) e seriais numéricos.
- **Normalização de `idfornecedor`:** Implementada a função `limpar_id_numerico()` para extrair o identificador numérico de strings como `'F8'` $\rightarrow$ `8`, garantindo integridade referencial entre `fornecedor`, `produtos_filial` e `pedido_compra`.
- **Descarte de Colunas Residuais:** Mantido o fatiamento `df.iloc[:, :12]` em `pedido_compra` para ignorar as colunas sem cabeçalho (`Unnamed: 12`..`22`).
- **Segurança de Credenciais:** Removida a senha hardcoded, utilizando `os.getenv("DB_PASSWORD", "sua_senha_aqui")`.

## 5. Conferência de Carga (`SELECT COUNT(*)`)

| Tabela                | Linhas na Planilha | Linhas no PostgreSQL |     Status     |
| :-------------------- | :----------------: | :------------------: | :------------: |
| `fornecedor`          |         20         |          20          | 100% importado |
| `produtos_filial`     |         20         |          20          | 100% importado |
| `pedido_compra`       |         29         |          29          | 100% importado |
| `entradas_mercadoria` |         20         |          20          | 100% importado |
| `venda`               |         33         |          33          | 100% importado |
