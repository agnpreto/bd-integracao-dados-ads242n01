# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

Usei o próprio `scripts/importar.py`, corrigido, em vez de importar pelo DBeaver.
O script fica versionado, pode ser repetido do zero e confere a carga sozinho.

| Item | Versão / detalhe |
| --- | --- |
| Linguagem | Python 3 |
| Bibliotecas | `pandas` + `openpyxl` (leitura do .xlsx), `psycopg2-binary` (PostgreSQL), `pymysql` (MySQL) |
| SGBDs alvo | PostgreSQL (10 ou superior) e MySQL 8 |
| Conferência manual | DBeaver ou `psql`/`mysql`, com as consultas de `sql/04_validacao.sql` (bloco A) |

Passo a passo:

```bash
pip install pandas openpyxl psycopg2-binary pymysql

# PostgreSQL
createdb -U postgres base_teste
psql -U postgres -d base_teste -f sql/01_ddl_postgres.sql
DB_DIALECT=postgres DB_USER=postgres DB_PASSWORD=<sua senha> python scripts/importar.py

# MySQL
mysql -u root -p -e "CREATE DATABASE base_teste CHARACTER SET utf8mb4"
mysql -u root -p base_teste < sql/01_ddl_mysql.sql
DB_DIALECT=mysql DB_USER=root DB_PASSWORD=<sua senha> python scripts/importar.py
```

No PowerShell, troque `VAR=valor comando` por `$env:VAR="valor"; comando`.
O script não tem senha real no código: tudo vem de variáveis de ambiente
(`DB_DIALECT`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`,
`ARQUIVO_XLSX`).

## Estrutura da planilha

`dados/base_teste.xlsx` tem 5 abas. Contando só as linhas com dados (o Excel
marca até a linha 1000 como usada):

| Aba | Linhas de dados | Colunas |
| --- | --- | --- |
| fornecedor | 20 | 2 |
| produtos_filial | 20 | 8 |
| pedido_compra | 29 | 12 (+ 11 células soltas sem cabeçalho, ver abaixo) |
| entradas_mercadoria | 20 | 9 |
| venda | 33 | 9 |

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| fornecedor | idfornecedor | texto | `F1`..`F20`. Convertido para inteiro (1..20) |
| fornecedor | razao_social | texto | `Fornecedor N LTDA` |
| produtos_filial | filial_id | inteiro | Só a filial 1 |
| produtos_filial | idproduto | texto | `P1`..`P20`. No banco a coluna se chama `produto_id` |
| produtos_filial | descricao | texto | `Produto N` |
| produtos_filial | estoque | número | |
| produtos_filial | preco_unitario / preco_compra / preco_venda | número | 4 produtos com preço de venda abaixo do de compra (Parte 4) |
| produtos_filial | idfornecedor | texto | `F8`, `F9`... Mesmo formato da aba fornecedor, convertido para inteiro |
| pedido_compra | pedido_id | inteiro | 1..29 |
| pedido_compra | data_pedido | data | Formato de célula `yyyy-mm-dd` |
| pedido_compra | item | inteiro | Sempre 1 |
| pedido_compra | produto_id / descricao_produto | texto | |
| pedido_compra | ordem_compra | inteiro | 1..18 e **0** nos pedidos 19..29 |
| pedido_compra | qtde_pedida | número | |
| pedido_compra | filial_id | inteiro | Sempre 1 |
| pedido_compra | data_entrega | data | Em 20 pedidos é anterior a `data_pedido` |
| pedido_compra | qtde_entregue | número | Não bate com as notas de entrada (Parte 4) |
| pedido_compra | preco_compra | número | |
| pedido_compra | fornecedor_id | inteiro | 1..20. **Aqui o id é numérico, sem o `F`** |
| pedido_compra | *(sem nome)* M..W | vários | Células preenchidas nas linhas 22..30 sem cabeçalho (erro E11) |
| entradas_mercadoria | data_entrada | data | Formato de célula `yyyy-mm-dd` |
| entradas_mercadoria | nro_nfe | texto | `NFE1`..`NFE20` |
| entradas_mercadoria | item / produto_id / descricao_produto | | |
| entradas_mercadoria | ordem_compra | inteiro | 1..20. As ordens 19 e 20 não existem nos pedidos |
| entradas_mercadoria | qtde_recebida / filial_id / custo_unitario | | |
| venda | venda_id | inteiro | 1..33 |
| venda | data_emissao | data | Formato de célula `m/d/yyyy` (americano). 03/01/2025 a 28/03/2025 |
| venda | horariomov | texto | Sempre `08:00:00` |
| venda | produto_id | texto | Inclui P21..P28, que não estão no cadastro |
| venda | qtde_vendida | número | 5 valores fracionados em unidade `UN` |
| venda | valor_unitario | número | |
| venda | filial_id | inteiro | 1, 2 e 3 |
| venda | item | inteiro | |
| venda | unidade_medida | texto | Sempre `UN` |

**Células sem cabeçalho na aba `pedido_compra`.** As linhas 22 a 30 têm 11
valores nas colunas M a W. Eles são uma cópia dos pedidos 12 a 20 (mesma data,
produto e preço), com a `ordem_compra` preenchida (12..20) e uma coluna a mais
igual a `qtde_pedida - qtde_entregue`, ou seja, a `qtde_pendente`. O script do
estagiário escondia isso com `df.iloc[:, :12]`. O meu descarta essas colunas
por não terem nome, mas avisa na saída. O assunto foi para a reunião com o
cliente (Parte 4, erro E11), porque esse bloco sugere que os pedidos 19 e 20
tinham originalmente as ordens 19 e 20, justamente as das notas "órfãs".

## Erros encontrados no DDL e como foram corrigidos

Rodando `sql/01_ddl_enunciado.sql` num banco PostgreSQL vazio, `venda` e
`pedido_compra` são criadas, e as outras três falham:

```
ERROR:  column "ordem_compra" named in key does not exist
ERROR:  syntax error at or near "("
LINE 6:  CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, idp...
ERROR:  column "idproduto" named in key does not exist
```

A segunda mensagem aparece porque, sem a vírgula, o PostgreSQL lê
`idfonecedor int4 NULL CONSTRAINT produtos_filial_pkey PRIMARY KEY` como uma
restrição da própria coluna e estranha o `(` seguinte. Corrigindo isso aparecem
os outros erros da mesma tabela. A lista completa:

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | A PK usa `ordem_compra`, mas a coluna não foi declarada (e é ela que liga entrada a pedido) | Coluna `ordem_compra bigint NOT NULL DEFAULT 0` criada |
| produtos_filial | Falta a vírgula entre `idfonecedor int4 NULL` e `CONSTRAINT` | Vírgula incluída |
| produtos_filial | Coluna `decricao` (erro de digitação) | `descricao`, como na planilha e no script |
| produtos_filial | Coluna `idfonecedor` (erro de digitação) | `idfornecedor` |
| produtos_filial | PK `(filial_id, idproduto)`: `idproduto` não existe | PK `(filial_id, produto_id)` |
| produtos_filial | `filial_id ... NULL` em coluna que faz parte da PK | `NOT NULL` |
| produtos_filial | `produto_id varchar(255)`, mas nas outras tabelas é `varchar(25)` | `varchar(25)` em todas |
| fornecedor | Coluna `idforncedor` (erro de digitação) | `idfornecedor` |
| fornecedor | PK `(idforncedor, idproduto)`: `idproduto` não existe e não faz sentido em fornecedor | PK só `(idfornecedor)` |
| fornecedor | `idfornecedor varchar(25)`, mas `pedido_compra.fornecedor_id` e `produtos_filial.idfornecedor` são `int4`: o relacionamento não fecha | `integer` nas três. Identidade iniciando em 21 para a trigger da Parte 3 |
| pedido_compra | `fornecedor_id ... DEFAULT 0`: o fornecedor 0 não existe | Sem default. FK para `fornecedor` |
| pedido_compra | `pedido_id`, `item` e `ordem_compra` como `float8` (identificador não é ponto flutuante: 3 pode virar 2.9999...) | `bigint` / `integer` |
| entradas_mercadoria | `item float8` | `integer` |
| produtos_filial | Defaults `float8 DEFAULT '0'` (texto como default numérico) | `DEFAULT 0` |
| todas | Nenhuma FK entre as tabelas | FKs `produtos_filial.idfornecedor` e `pedido_compra.fornecedor_id` → `fornecedor`. Índices na ligação pedido × entrada e na data da venda |
| todas (MySQL) | O DDL é PostgreSQL puro: `int8`, `float8`, `public.`, `'...'::character varying` | `sql/01_ddl_mysql.sql` com `BIGINT`, `DOUBLE`, `DECIMAL`, `InnoDB`, `utf8mb4` e `AUTO_INCREMENT = 21` |

**FKs que deixei de fora de propósito:** `venda.produto_id → produtos_filial` e
`entradas_mercadoria.ordem_compra → pedido_compra`. A base tem vendas de produtos
sem cadastro e entradas de ordens inexistentes. Com essas FKs, a carga rejeitaria
13 vendas e 2 entradas, e esses dados sumiriam antes da reunião com o cliente.
Preferi carregar tudo e listar as ocorrências (Parte 4, E01, E02 e E05).

## Erros encontrados no script de importação e como foram corrigidos

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` faz `int(valor)`, mas as células de data têm formato de data, e o pandas entrega `Timestamp`. O `int()` falha e o `except:` devolve `None` | **Todas as datas viram NULL.** Em `venda`, `data_emissao` é `NOT NULL`, e as 33 vendas são rejeitadas. Em pedidos e entradas a data some sem nenhum aviso | `data()` aceita `datetime`/`Timestamp`, `date`, número serial do Excel e texto `DD/MM/AAAA` ou `AAAA-MM-DD`. Formato desconhecido gera erro, não `None` |
| `conn.rollback()` dentro do `except` de cada linha | Uma linha ruim desfaz também todas as linhas boas da tabela que ainda não tinham sido confirmadas | Cada linha roda num `SAVEPOINT`. O erro desfaz só aquela linha e é registrado |
| Mensagem `"{len(df)} registros inseridos"` | Mostra o total da planilha mesmo quando nada entrou: o estagiário achou que tinha dado certo | O script conta o `rowcount` de cada INSERT e faz `SELECT COUNT(*)` no banco, comparando com a planilha. Sai com código 1 se houver divergência |
| `idfornecedor` gravado como `'F8'` em coluna inteira | `invalid input syntax for type integer` em todos os produtos | `id_fornecedor()` converte `F8` → 8 (e mantém 8 → 8) |
| INSERT usa `descricao`/`idfornecedor`, e o DDL tinha `decricao`/`idfonecedor`. As tabelas `produtos_filial` e `fornecedor` nem eram criadas | Todas as linhas dessas duas tabelas falhavam | Nomes alinhados com o DDL corrigido |
| `ON CONFLICT` só existe no PostgreSQL. O script também só conecta via `psycopg2` | O enunciado pede MySQL e PostgreSQL | `DB_DIALECT=postgres|mysql`. No MySQL, `ON DUPLICATE KEY UPDATE` (sem alterar nada) e sem o prefixo `public.` |
| Senha `"1234"` e banco `"postgres"` fixos no código | Credencial no repositório. Carga no banco errado | Variáveis de ambiente com valores de exemplo |
| Comentário "porta do MySQL 3006" | Quem seguisse o comentário não conectaria | Porta padrão correta: 3306 |
| `df.iloc[:, :12]` e renomeação por posição em `pedido_compra` | Funcionava por acaso. Se uma coluna mudar de lugar, os dados entram trocados sem erro. E escondia as células soltas em M..W | Leitura **por nome** de coluna. Colunas sem cabeçalho são descartadas com aviso. Coluna esperada ausente aborta a carga |
| `float(pedido_id)`, `float(item)`, `float(ordem_compra)` | Identificadores gravados como ponto flutuante | `inteiro()`, que recusa valor não inteiro |
| `except:` sem tipo (pega até `Ctrl+C`) e erro só impresso | Difícil saber o que falhou | Erros por linha guardados e listados no final com o número da linha da planilha |
| Fornecedor gravado com ids 1..20, mas a identidade não sabe disso | O primeiro INSERT automático (trigger) tentaria o id 1 e daria chave duplicada | O DDL já começa a identidade em 21, e o script ainda roda `setval` no PostgreSQL. No MySQL o `AUTO_INCREMENT` se ajusta sozinho |

## Tratamentos aplicados aos dados

1. **Leitura por nome de coluna**, com `dtype=object` (o pandas não "adivinha"
   tipos). Linhas totalmente vazias são descartadas (a planilha vai até a linha 1000).
2. **Texto:** `strip()` e vazio vira `NULL`. Número inteiro lido como `12.0` vira `'12'`.
3. **Número:** aceita `12,5` e `1.234,56` além de `12.5`. `NaN` vira `NULL`, ou o
   default do DDL (`0`) nas colunas `NOT NULL`.
4. **Datas:** convertidas para `date`. Como as células são datas de verdade
   (serial do Excel), não há ambiguidade DD/MM × MM/DD, mesmo com a aba `venda`
   exibindo `m/d/yyyy`.
5. **Hora:** `horariomov` normalizada para `HH:MM:SS`, `00:00:00` se vazia (default do DDL).
6. **Fornecedor:** `F1`..`F20` → 1..20, para fechar com `pedido_compra.fornecedor_id`.
7. **`qtde_pendente`:** não existe na planilha. Calculada como `qtde_pedida - qtde_entregue`.
8. **Idempotência:** rodar o script de novo não duplica nada (`ON CONFLICT DO NOTHING`
   / `ON DUPLICATE KEY UPDATE`). A segunda execução mostra 0 inseridas.
9. **Erros de negócio não foram corrigidos na carga.** Datas invertidas, produtos
   sem cadastro, ordens 0 etc. entram como vieram. Corrigir sem falar com o
   cliente esconderia o problema. Eles estão listados em `docs/parte4_validacao.md`.

## Conferência final

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |

Saída do script (a mesma tabela aparece no final de cada execução):

```
tabela                 planilha  inseridas  no banco  situacao
fornecedor                   20         20        20  OK
produtos_filial              20         20        20  OK
pedido_compra                29         29        29  OK
entradas_mercadoria          20         20        20  OK
venda                        33         33        33  OK

Avisos (1):
  - aba pedido_compra: 11 colunas sem cabecalho tem dados nas linhas 22, 23, 24, 25, 26, 27, 28, 29, 30 da planilha; foram ignoradas (ver docs/parte4_validacao.md)
```

Conferências extras depois da carga (`sql/04_validacao.sql`, V01 e V15):

- nenhuma data nula em `venda`, `pedido_compra` e `entradas_mercadoria`;
- vendas de 03/01/2025 a 28/03/2025, sendo 14 em fevereiro, que somam R$ 14.093,17;
- ids de fornecedor de 1 a 20, nenhum produto ou pedido apontando para fornecedor inexistente;
- `qtde_pendente = qtde_pedida - qtde_entregue` em todos os pedidos.
