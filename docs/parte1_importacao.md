# Parte 1: Documentação do processo de importação

**Aluno:** João Gustavo Gonçalves Vasconcelos (2408298), GitHub `SukitaAM`

## Ferramenta utilizada

- **Python 3 + pandas + psycopg2** (`scripts/importar.py`, versão corrigida), carregando `dados/base_teste.xlsx` no **PostgreSQL 16**.
- O DDL corrigido foi criado com `psql -f sql/01_ddl_postgres.sql`; a versão MySQL (`sql/01_ddl_mysql.sql`) foi executada em um servidor MariaDB local (compatível com MySQL) apenas para validar a sintaxe.
- Antes de corrigir, rodei o DDL e o script originais para registrar os erros (ver tabelas abaixo).

## Estrutura da planilha

| Aba | Coluna | Tipo (pandas) | Observação |
| --- | --- | --- | --- |
| venda (33 linhas) | venda_id, filial_id, item | inteiro | filial 1, 2 e 3 |
| | data_emissao | data | período jan a mar/2025 |
| | horariomov | texto | sempre `08:00:00` |
| | produto_id | texto | P1 a P28 |
| | qtde_vendida, valor_unitario | decimal | há quantidades fracionadas (38,6; 20,04...) |
| | unidade_medida | texto | sempre `UN` |
| pedido_compra (29 linhas) | pedido_id, item, ordem_compra, filial_id | inteiro | `ordem_compra` = 0 em 11 linhas |
| | data_pedido, data_entrega | data | |
| | produto_id, descricao_produto | texto | |
| | qtde_pedida, qtde_entregue | inteiro | |
| | preco_compra, fornecedor_id | decimal / inteiro | `fornecedor_id` numérico (1 a 20) |
| | colunas M:W (sem cabeçalho, "Unnamed") | misto | **lixo**: 9 linhas que repetem os pedidos 21 a 29 com `qtde_pendente` calculada; não pertencem à tabela |
| entradas_mercadoria (20 linhas) | data_entrada | data | |
| | nro_nfe, produto_id, descricao_produto | texto | NFE1 a NFE20 |
| | item, ordem_compra, qtde_recebida, filial_id | inteiro | |
| | custo_unitario | decimal | |
| produtos_filial (20 linhas) | filial_id | inteiro | só filial 1 |
| | **idproduto** (no DDL é `produto_id`), descricao | texto | |
| | estoque | inteiro | |
| | preco_unitario, preco_compra, preco_venda | decimal | |
| | idfornecedor | texto (`F8`) | no DDL é numérico |
| fornecedor (20 linhas) | idfornecedor | texto (`F1`..`F20`) | virou numérico (1..20) |
| | razao_social | texto | |

## Erros encontrados no DDL e como foram corrigidos

Resultado de rodar o DDL original no PostgreSQL: só `venda` e `pedido_compra` foram criadas; as outras três tabelas deram erro.

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | A PK usa `ordem_compra`, que não existe na tabela (`column "ordem_compra" named in key does not exist`). É justamente o campo que liga a entrada ao pedido. | Coluna `ordem_compra int8 NOT NULL` criada. |
| produtos_filial | Falta vírgula depois de `idfonecedor int4 NULL` (erro de sintaxe). | Vírgula adicionada. |
| produtos_filial | PK usa `idproduto`, mas a coluna se chama `produto_id`. Além disso, `filial_id` era `NULL` e fazia parte da PK. | PK `(filial_id, produto_id)`; `filial_id NOT NULL`. |
| produtos_filial | Nomes com erro de digitação: `decricao` e `idfonecedor`. A planilha e o script usam `descricao` e `idfornecedor`. | Renomeadas. |
| fornecedor | `idforncedor` (digitação) e PK `(idforncedor, idproduto)`: a coluna `idproduto` não existe, e fornecedor não tem produto. | `idfornecedor` como PK simples. |
| fornecedor / produtos_filial / pedido_compra | `idfornecedor` era `varchar` em uma tabela e `int4` nas outras: tipos incompatíveis, nenhuma FK possível. | Tudo `int4`; `fornecedor.idfornecedor` é IDENTITY/AUTO_INCREMENT; a planilha `F8` vira `8`. |
| Todas | Nenhuma chave estrangeira entre as tabelas. | FK `produtos_filial.idfornecedor -> fornecedor`. `pedido_compra.fornecedor_id` ficou sem FK porque o `DEFAULT 0` não existe em fornecedor; a integridade é checada na Parte 4. |
| pedido_compra | `pedido_id`, `item` e `ordem_compra` como `float8` (chave primária e vínculo com número decimal inexato). | `int8`/`int4`. |
| pedido_compra | `qtde_pendente NOT NULL` não existe na planilha. | Mantida e calculada na importação (`qtde_pedida - qtde_entregue`). |
| venda, pedido_compra, entradas, produtos | Quantidades e preços em `float8` (erro de arredondamento em dinheiro). | `numeric(14,3)` para quantidades, `numeric(12,4)` para valores. |
| venda | A PK se chama `pk_consumo` (nome de outra tabela). | Renomeada para `pk_venda`. |
| venda | `qtde_vendida` aceita `NULL`. Mantido, mas apontado na validação (V3/A5). | Sem mudança de estrutura. |

## Erros encontrados no script de importação e como foram corrigidos

Resultado de rodar o script original: **0 linhas em `venda` e 0 em `pedido_compra`**; as demais tabelas nem existiam por causa do DDL.

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` faz `int(valor)` em um `Timestamp` (o pandas já converte a data) e tem `except:` genérico | Dava erro silencioso e devolvia `None`: **todas as datas viravam NULL**. Como `venda.data_emissao` é `NOT NULL`, nenhuma venda entrava. | Função `data()` aceita Timestamp, serial do Excel e texto. |
| `conn.rollback()` dentro do `except` com `commit` só no fim | Um erro em uma linha **desfazia todas as linhas anteriores da tabela**. | `SAVEPOINT` por linha: o erro desfaz só aquela linha. |
| Mensagem `len(df) registros inseridos` | Mostrava linhas **lidas**, não inseridas; dava a impressão de sucesso mesmo sem nada no banco. | Usa `cur.rowcount` e, no fim, `SELECT COUNT(*)` comparado com a planilha. |
| `ON CONFLICT ... DO NOTHING` sem aviso | Duplicatas sumiam sem registro. | Duplicadas são contadas e exibidas. |
| Colunas `idfornecedor`, `descricao` e `ON CONFLICT (filial_id, produto_id)` não batiam com o DDL | Erro "column does not exist" em todas as linhas. | Alinhado ao DDL corrigido. |
| `idfornecedor` lido como texto (`F8`) | Não cabe em coluna numérica. | `id_fornecedor()` remove o prefixo `F`. |
| `pedido_compra`: `iloc[:, :12]` e renomeação posicional | Frágil: depende da posição; as colunas "Unnamed" M:W eram descartadas sem aviso. | Seleção por nome das 12 colunas e documentação de que M:W são lixo. |
| Senha `1234` no código; comentário "MySQL 3006" | Senha exposta no GitHub (o README proíbe); a porta do MySQL é 3306. | Credenciais por variáveis de ambiente (`PGHOST`, `PGPASSWORD`...). |
| Só funciona com PostgreSQL | O enunciado pede também MySQL. | DDL MySQL separado; para carga no MySQL, usar o DBeaver ou adaptar o driver. |

## Tratamentos aplicados aos dados

- **Datas:** convertidas para `date` (Timestamp, serial ou texto).
- **Tipos:** quantidades e valores como `numeric`; ids como inteiros; `item`, `ordem_compra` convertidos de float para inteiro.
- **Fornecedor:** `F8` -> `8` em `fornecedor` e `produtos_filial`; a sequência IDENTITY foi ajustada (`setval`) para o próximo id ser 21.
- **qtde_pendente:** calculada como `qtde_pedida - qtde_entregue`.
- **Espaços:** `strip()` em todos os textos; nulos viram `0` nos campos numéricos `NOT NULL`.
- **Colunas M:W de `pedido_compra`:** descartadas (lixo duplicado); os 29 pedidos reais foram todos importados.
- **Não corrigi os dados "errados"** (ex.: produto P21 sem cadastro, datas invertidas): carreguei como vieram e documentei na Parte 4 para o cliente decidir.

## Conferência final

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |
