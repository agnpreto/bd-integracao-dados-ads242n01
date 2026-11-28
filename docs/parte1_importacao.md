# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

- **Python 3** com `pandas` + `openpyxl` (leitura do `.xlsx`), `psycopg2` (PostgreSQL) e `pymysql` (MySQL).
- Script: `scripts/importar.py` (versão corrigida do script do estagiário).
- Bancos testados: **PostgreSQL 16** e **MariaDB 10.11** (compatível com MySQL; o DDL usa só sintaxe MySQL 8).
- DBeaver pode ser usado para conferir as tabelas, mas a carga é toda pelo script, para ser repetível.

Como rodar:

```bash
pip install pandas openpyxl psycopg2-binary pymysql
psql -d integracao -f sql/01_ddl_postgres.sql      # ou: mysql integracao < sql/01_ddl_mysql.sql
export DB_PASSWORD=sua_senha                        # senha fica fora do código
python scripts/importar.py --sgbd postgres          # ou --sgbd mysql
```

O script valida a planilha inteira **antes** de gravar, grava tudo em **uma transação** e no final faz `SELECT COUNT(*)` em cada tabela e compara com a planilha.

## Estrutura da planilha

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| fornecedor | idfornecedor | texto | Formato `F1`..`F20`. Convertido para número (`F8` → 8); o texto original fica em `codigo_origem` |
| fornecedor | razao_social | texto | |
| produtos_filial | filial_id | inteiro | Só existe filial 1 no cadastro |
| produtos_filial | idproduto | texto | `P1`..`P20`. No banco a coluna se chama `produto_id` |
| produtos_filial | descricao | texto | No DDL original estava `decricao` |
| produtos_filial | estoque | inteiro | |
| produtos_filial | preco_unitario, preco_compra, preco_venda | decimal | |
| produtos_filial | idfornecedor | texto | `F1`..`F20`; DDL original pedia int4 → erro na carga |
| pedido_compra | pedido_id, item, ordem_compra | inteiro | DDL original usava float8 |
| pedido_compra | data_pedido, data_entrega | data | Vêm como data do Excel (o pandas entrega `Timestamp`) |
| pedido_compra | produto_id, descricao_produto | texto | |
| pedido_compra | qtde_pedida, qtde_entregue | inteiro | |
| pedido_compra | filial_id, fornecedor_id | inteiro | `fornecedor_id` é numérico (1..20), diferente do `F1` da aba fornecedor |
| pedido_compra | preco_compra | decimal | |
| pedido_compra | *(colunas M a W, sem cabeçalho)* | misto | **Lixo**: 11 colunas sem nome, preenchidas nas linhas 22–30, com cópia de outros pedidos. Descartadas |
| pedido_compra | qtde_pendente | — | **Não existe na planilha**. No banco virou coluna calculada (`pedida - entregue`) |
| entradas_mercadoria | data_entrada | data | |
| entradas_mercadoria | nro_nfe, produto_id, descricao_produto | texto | |
| entradas_mercadoria | item, ordem_compra, qtde_recebida, filial_id | inteiro | `ordem_compra` não estava no DDL original |
| entradas_mercadoria | custo_unitario | decimal | |
| venda | venda_id, filial_id, item | inteiro | |
| venda | data_emissao | data | |
| venda | horariomov | hora | Texto `08:00:00` na planilha; no banco virou `time` |
| venda | produto_id, unidade_medida | texto | |
| venda | qtde_vendida | decimal | Tem valores fracionados (38,6) com unidade `UN` |
| venda | valor_unitario | decimal | |

## Erros encontrados no DDL e como foram corrigidos

Ao rodar `sql/01_ddl_enunciado.sql` no PostgreSQL, **só `venda` e `pedido_compra` foram criadas**. Erros devolvidos pelo banco:

```
entradas_mercadoria: ERROR: column "ordem_compra" named in key does not exist
produtos_filial:     ERROR: syntax error at or near "("   (falta vírgula antes do CONSTRAINT)
fornecedor:          ERROR: column "idproduto" named in key does not exist
```

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | PK usa `ordem_compra`, mas a coluna não foi declarada (e ela é o vínculo com o pedido) | Coluna `ordem_compra integer NOT NULL` adicionada |
| produtos_filial | Falta vírgula entre `idfonecedor int4 NULL` e `CONSTRAINT` | Vírgula adicionada |
| produtos_filial | PK usa `idproduto`, mas a coluna é `produto_id` (erro escondido pelo erro de sintaxe; aparece depois de pôr a vírgula) | PK `(filial_id, produto_id)` |
| produtos_filial | Erros de digitação: `decricao`, `idfonecedor` | `descricao`, `idfornecedor` |
| produtos_filial | `filial_id` declarado `NULL`, mas faz parte da PK | `NOT NULL` explícito |
| produtos_filial | `produto_id varchar(255)`, nas outras tabelas é `varchar(25)` | `varchar(25)` em todas |
| produtos_filial | `idfornecedor int4`, mas o dado vem `F8` → toda linha falha | Fornecedor passou a ter id numérico; `F8` é convertido para 8. FK para `fornecedor` |
| fornecedor | Digitação: `idforncedor` | `idfornecedor` |
| fornecedor | PK `(idforncedor, idproduto)`: `idproduto` não existe e não faz sentido na tabela de fornecedor | PK só `(idfornecedor)` |
| fornecedor | id texto (`F1`), mas `pedido_compra.fornecedor_id` é número: impossível relacionar | `idfornecedor integer` (identity/auto_increment) + `codigo_origem` guardando `F1` |
| pedido_compra | `pedido_id`, `item`, `ordem_compra` em `float8` (chave com ponto flutuante) | `integer` |
| todas | Quantidade e dinheiro em `float8` (soma de R$ com erro de arredondamento) | `numeric`/`DECIMAL` |
| pedido_compra | `qtde_pendente` pode ficar diferente de `pedida - entregue` | Coluna calculada `GENERATED ALWAYS AS (...) STORED` |
| todas | Nenhuma chave estrangeira | FK `produtos_filial → fornecedor` e `pedido_compra → fornecedor`. `venda → produtos_filial` **não** foi criada de propósito: há vendas de produtos não cadastrados e preferimos importar e mostrar o erro ao cliente (Parte 4) a perder vendas |
| venda | `horariomov varchar(8)` | `time` |
| venda | `filial_id int8`, nas outras é `int4`; PK com nome `pk_consumo` | `integer`; PK `venda_pkey` |
| venda | `DEFAULT ''` em `produto_id` (venda sem produto passaria) | Default removido |
| MySQL | `'00:00:00'::character varying` e `public.` só existem no PostgreSQL; `int8`/`float8` não são tipos do MySQL | Removidos/trocados no `01_ddl_mysql.sql` |

## Erros encontrados no script de importação e como foram corrigidos

Teste feito: DDL com os erros de sintaxe corrigidos + script original. O script imprimiu "20 registros inseridos em produtos_filial" e "33 registros inseridos em venda", mas o `SELECT COUNT(*)` mostrou:

| Tabela | Script disse | Banco tinha de verdade |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | **0** |
| pedido_compra | 29 | 29 (todas com **data NULL**) |
| entradas_mercadoria | 20 | 20 (todas com **data NULL**) |
| venda | 33 | **0** |

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` faz `int(valor)`, mas o pandas já entrega a data como `Timestamp` → dá erro, o `except:` vazio engole e devolve `None` | **Todas** as datas viram NULL. Em `venda` (`data_emissao NOT NULL`) todas as 33 linhas são rejeitadas | `para_data()` trata `Timestamp`, `datetime`, número serial do Excel e texto |
| `except:` sem tipo na conversão de data | Esconde o erro acima | Removido; erro de conversão para a carga e aparece |
| `conn.rollback()` dentro do laço, com `commit()` só no final | Um erro numa linha desfaz **todas as linhas boas anteriores** da tabela, sem aviso | Validação antes de gravar + uma transação para a carga toda: entra tudo ou nada |
| Mensagem `print(f"{len(df)} registros inseridos")` | Mostra o tamanho da planilha, não o que entrou. Mentiu nos 2 casos acima | Conferência final com `SELECT COUNT(*)` no banco |
| `ON CONFLICT ... DO NOTHING` + contador `inseridos += 1` | Linha duplicada é ignorada em silêncio e ainda conta como inserida | Validação de chave duplicada antes de gravar; carga apaga e recarrega (rodar 2x dá o mesmo resultado) |
| `idfornecedor` `F8` enviado para coluna `int4` | Todas as 20 linhas de produtos falham | Conversão `F8` → 8 |
| Coluna `idfornecedor`/`descricao` no INSERT, mas DDL original tinha `idforncedor`/`decricao` | Fornecedor e produtos não entram com o DDL original | Nomes alinhados no DDL corrigido |
| Senha `"1234"` no código | Senha vai parar no GitHub | Variáveis de ambiente (`DB_PASSWORD` etc.) |
| Caminho `"dados/base_teste.xlsx"` relativo à pasta atual | Só funciona rodando da raiz do repositório | Caminho calculado a partir da pasta do script |
| Só funciona com PostgreSQL; comentário diz que a porta do MySQL é 3006 | Não atende a carga no MySQL; porta errada (é 3306) | Parâmetro `--sgbd postgres|mysql` |
| `qtde_pendente` calculado no Python | Pode ficar diferente do banco se alguém editar `qtde_entregue` | Calculado pelo banco (coluna gerada) |

## Tratamentos aplicados aos dados

- **Datas**: `Timestamp` do pandas → `date`. Também aceita número serial do Excel e texto `DD/MM/AAAA`.
- **Hora** (`horariomov`): `time` ou texto → `HH:MM:SS`; vazio vira `00:00:00` (default da tabela).
- **Fornecedor**: `F8` → `8` (regex `F?<número>`; código fora do padrão faz a carga parar). Código original guardado em `codigo_origem`.
- **Textos**: `strip()` dos espaços; texto vazio vira NULL.
- **Inteiros**: checa se o valor é inteiro de verdade (ex.: `item = 1.5` gera erro em vez de virar 1 calado).
- **Aba pedido_compra**: as 11 colunas sem cabeçalho (M a W) são descartadas, com aviso. O script informa: `11 colunas sem cabeçalho descartadas (9 linhas tinham conteúdo nelas)`.
- **Validação antes da carga**: campos obrigatórios vazios e chave primária repetida. Se houver erro, nada é gravado e a lista de problemas é exibida.
- **Erros de negócio não são "consertados" na carga** (produto inexistente, data de entrega antes do pedido etc.). Os dados entram como o cliente mandou e os problemas vão para a reunião de validação (Parte 4). Corrigir sozinho seria inventar dado do cliente.

## Conferência final

Resultado do `scripts/importar.py` (igual no PostgreSQL e no MySQL):

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |

Conferência extra: faturamento de fevereiro/2025 calculado direto na planilha (pandas) = **R$ 14.093,17**; no banco (`sql/04_validacao.sql`, A2) = **R$ 14.093,17**.
