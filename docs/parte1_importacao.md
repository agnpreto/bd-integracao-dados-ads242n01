# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

- **PostgreSQL 18** local (serviço `postgresql-x64-18`), administrado via `psql`.
- **Python 3.14** com `pandas` + `openpyxl` (leitura do `.xlsx`) e `psycopg2` (conexão com o PostgreSQL), através do script `scripts/importar.py`.
- Também foi criada e testada a versão do DDL para **MySQL 8.0** (`sql/01_ddl_mysql.sql`), rodada localmente via `mysql` CLI, para garantir que a estrutura é portável — a importação dos dados em si, porém, foi feita no PostgreSQL (o script usa `psycopg2`).

## Estrutura da planilha

| Aba | Coluna | Tipo (pandas) | Observação |
| --- | --- | --- | --- |
| venda | venda_id | int64 | chave, sem nulos |
| venda | data_emissao | datetime64 | lida pelo pandas já como data, não como serial numérico |
| venda | horariomov | string | formato `HH:MM:SS` |
| venda | produto_id | string | ex.: `P1` |
| venda | qtde_vendida | float64 | |
| venda | valor_unitario | float64 | |
| venda | filial_id | int64 | |
| venda | item | int64 | |
| venda | unidade_medida | string | ex.: `UN` |
| pedido_compra | pedido_id..fornecedor_id | (12 colunas nomeadas) | mesmas 12 colunas esperadas pelo script |
| pedido_compra | `Unnamed: 12` a `Unnamed: 22` | vazias | 11 colunas extras sem cabeçalho e sem dados, sobra de formatação do Excel; não usadas (o script já as descarta com `df.iloc[:, :12]`) |
| entradas_mercadoria | data_entrada, nro_nfe, item, produto_id, descricao_produto, ordem_compra, qtde_recebida, filial_id, custo_unitario | — | bate com a tabela; `ordem_compra` é o campo que liga a entrada ao pedido de compra |
| produtos_filial | filial_id, **idproduto**, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor | — | a coluna de produto na planilha chama-se `idproduto` (não `produto_id`); `idfornecedor` é texto (`F1`, `F8`...), não numérico |
| fornecedor | idfornecedor, razao_social | string | `idfornecedor` é texto (`F1`, `F2`...) |

## Erros encontrados no DDL e como foram corrigidos

Rodei `sql/01_ddl_enunciado.sql` exatamente como veio no enunciado contra um banco PostgreSQL vazio. Resultado: só `venda` e `pedido_compra` foram criadas; as outras três tabelas falharam.

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | PK usa `ordem_compra`, mas essa coluna não existia na tabela (erro do Postgres: *"coluna ordem_compra indicada na chave não existe"*) | Adicionada a coluna `ordem_compra float8 DEFAULT 0 NOT NULL` — é o campo que liga a entrada ao pedido de compra |
| produtos_filial | Faltava vírgula antes de `CONSTRAINT` → erro de sintaxe, tabela nem chegava a ser criada | Vírgula adicionada |
| produtos_filial | Colunas com erro de digitação: `decricao` e `idfonecedor` | Renomeadas para `descricao` e `idfornecedor`, batendo com o que o script de importação e a planilha usam |
| produtos_filial | PK declarada como `(filial_id, idproduto)`, mas a coluna da tabela chama-se `produto_id` (`idproduto` não existe) | PK corrigida para `(filial_id, produto_id)` |
| produtos_filial | `idfornecedor` declarado como `int4`, mas os ids de fornecedor na planilha são texto (`F1`, `F8`...) e `fornecedor.idfornecedor` é `varchar(25)` — ao tentar criar a FK entre as tabelas, o Postgres acusa tipos incompatíveis | Coluna alterada para `varchar(25)` |
| produtos_filial | `filial_id` declarado `NULL`, mas é parte da chave primária. O PostgreSQL aceita e força `NOT NULL` silenciosamente, mas o **MySQL rejeita** (*"All parts of a PRIMARY KEY must be NOT NULL"*) | Coluna alterada para `NOT NULL` |
| fornecedor | Coluna com erro de digitação: `idforncedor` | Renomeada para `idfornecedor` |
| fornecedor | PK declarada como `(idforncedor, idproduto)`, mas a tabela não tem (e não precisa de) coluna de produto — quem referencia o fornecedor é `produtos_filial` | PK corrigida para `(idfornecedor)`; adicionada a FK `produtos_filial.idfornecedor → fornecedor.idfornecedor` |

As versões corrigidas ficaram em `sql/01_ddl_postgres.sql` e `sql/01_ddl_mysql.sql` (mesmas correções, com a sintaxe/tipos adaptados ao MySQL). Ambas foram executadas do zero, sem erros, nos respectivos SGBDs locais.

## Erros encontrados no script de importação e como foram corrigidos

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data()` assumia que a data vinha como número serial do Excel (`int(valor)` + cálculo a partir de 1899-12-30). Mas o `pandas`/`openpyxl` já devolve as datas como `Timestamp`, e `int(Timestamp)` lança exceção | A função sempre caía no `except` e retornava `None` — **todas as datas do banco ficavam nulas**. Em `venda`, `data_emissao` é `NOT NULL`, então **toda linha de venda falhava ao inserir** (0 de 33 linhas entravam, embora o script imprimisse "33 registros inseridos") | Função ajustada para tratar `Timestamp`/`date` diretamente (`valor.date()`), mantendo o cálculo do serial como alternativa |
| `conn.commit()` só era chamado uma vez, no final do laço `for` de cada tabela. Enquanto isso, qualquer erro em uma linha chamava `conn.rollback()` | Como o PostgreSQL mantém tudo em uma única transação até o commit, o `rollback()` desfazia **todas as inserções anteriores daquela tabela feitas desde o último commit**, não só a linha com erro | Passou a fazer `conn.commit()` logo após cada `INSERT` bem-sucedido, dentro do laço, para que um erro isolado não apague o que já havia entrado |
| O print final de cada bloco mostrava `len(df)` (tamanho da planilha), e não a contagem real de linhas inseridas | Mascarava os dois problemas acima — o script "reportava sucesso" mesmo quando nada tinha sido gravado | Passou a contar e imprimir as inserções reais (`inseridos/total`) |
| Senha e dados de conexão fixos no código (`"password": "1234"`) | Expõe credencial real no repositório, contrariando a própria orientação do enunciado | Configuração passou a vir de variáveis de ambiente (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`), com valores de exemplo como *fallback* |
| Comentário incorreto: "porta... do MySQL 3006" | Nenhum (é só comentário), mas induzia a erro | Corrigido para 3306 |

## Tratamentos aplicados aos dados

- Conversão de datas: `Timestamp`/`date` do pandas → `datetime.date` do Python (ver correção acima).
- Conversão de tipos numéricos (`int`, `float`) com tratamento de valores ausentes (`pd.notna`), aplicando um valor padrão (0 ou `None`) quando a planilha vem em branco, igual ao padrão já usado pelo DDL.
- Textos (`produto_id`, `idfornecedor`, `razao_social` etc.) normalizados com `.strip()`.
- As 11 colunas vazias (`Unnamed: 12` a `Unnamed: 22`) da aba `pedido_compra` são descartadas antes da importação.
- `qtde_pendente` de `pedido_compra` é calculada no próprio script (`qtde_pedida - qtde_entregue`), já que não vem pronta na planilha.
- `ON CONFLICT ... DO NOTHING` em todos os `INSERT`s, para que rodar o script mais de uma vez não duplique linhas (idempotência).

## Conferência final

Banco recriado do zero com `sql/01_ddl_postgres.sql` e `scripts/importar.py` executado uma única vez. Contagem no banco (`SELECT COUNT(*) ...`) comparada com o número de linhas de dados de cada aba da planilha:

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |

Todas as linhas da planilha entraram no banco, e uma conferência manual das datas (`SELECT data_emissao, data_pedido, data_entrega, data_entrada ...`) confirma que elas batem com os valores da planilha (antes da correção, todas ficavam `NULL`).
