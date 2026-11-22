# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

- **Banco:** MySQL 8, administrado pelo **MySQL Workbench**. O DDL também foi corrigido para PostgreSQL (`sql/01_ddl_postgres.sql`) e testado nele.
- **Importação:** script Python `scripts/importar.py` (pandas + openpyxl para ler a planilha), corrigido a partir do script do estagiário.
- O script funciona de dois jeitos:
  1. **Gerando um arquivo SQL** (usado com o Workbench): `SAIDA_SQL=sql/carga_mysql.sql python scripts/importar.py` cria o arquivo `sql/carga_mysql.sql` com os 122 `INSERT`s. Depois é só abrir esse arquivo no Workbench e executar. Não precisa de driver de banco nem de senha.
  2. **Conectando direto no banco:** `DB_TIPO=mysql DB_PASSWORD=... python scripts/importar.py` (ou `DB_TIPO=postgres`). A senha vem de variável de ambiente e não fica no código.

**Ordem de execução no Workbench:** `sql/01_ddl_mysql.sql` → `sql/carga_mysql.sql` → `sql/02_consultas.sql` → `sql/03_transformacoes.sql` → `sql/04_validacao.sql`.

## Estrutura da planilha

`dados/base_teste.xlsx`, 5 abas, 122 linhas de dados no total.

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| fornecedor (20 linhas) | idfornecedor | texto | códigos "F1" a "F20" (o DDL original dizia varchar, mas `produtos_filial` usava int) |
| | razao_social | texto | |
| produtos_filial (20 linhas) | filial_id | inteiro | só a filial 1 |
| | **idproduto** | texto | cabeçalho com nome diferente do banco (`produto_id`) |
| | descricao | texto | |
| | estoque | inteiro | |
| | preco_unitario, preco_compra, preco_venda | decimal | |
| | idfornecedor | texto | "F8", "F9"...: não cabe no `int4` do DDL original |
| pedido_compra (29 linhas) | pedido_id, item, ordem_compra, filial_id, fornecedor_id | inteiro | ordem_compra = 0 em 11 linhas |
| | data_pedido, data_entrega | data | o Excel guarda como data e o pandas lê como `Timestamp` |
| | produto_id, descricao_produto | texto | |
| | qtde_pedida, qtde_entregue | inteiro | **não existe coluna qtde_pendente**: é calculada |
| | preco_compra | decimal | |
| | colunas M a W (sem cabeçalho) | misto | 9 linhas (planilha 22 a 30) com dados soltos fora da tabela; não importadas (ver Parte 4) |
| entradas_mercadoria (20 linhas) | data_entrada | data | |
| | nro_nfe, produto_id, descricao_produto | texto | "NFE1"... |
| | item, ordem_compra, qtde_recebida, filial_id | inteiro | ordem_compra é a ligação com o pedido |
| | custo_unitario | decimal | |
| venda (33 linhas) | venda_id, filial_id, item | inteiro | filiais 1, 2 e 3 |
| | data_emissao | data | 02/01/2025 a 28/03/2025 |
| | horariomov | texto | sempre "08:00:00" |
| | produto_id, unidade_medida | texto | P1 a P28; unidade sempre "UN" |
| | qtde_vendida, valor_unitario | decimal | 5 quantidades fracionadas com unidade "UN" |

## Erros encontrados no DDL e como foram corrigidos

Rodando o `01_ddl_enunciado.sql`: no PostgreSQL, 3 das 5 tabelas não são criadas. No MySQL, nenhuma é criada, porque a primeira já falha com `::character varying`.

| Tabela | Erro | Correção |
| --- | --- | --- |
| venda | `DEFAULT ''::character varying` e `'00:00:00'::character varying` são sintaxe só do PostgreSQL e dão erro no MySQL | No MySQL ficou só `DEFAULT ''` / `DEFAULT '00:00:00'` |
| venda | A chave primária se chama `pk_consumo`, que não corresponde à tabela | Renomeada para `venda_pkey` |
| venda | `qtde_vendida float8` | `DECIMAL(12,3)` |
| pedido_compra | `pedido_id`, `item` e `ordem_compra` são `float8`: identificador com casa decimal aceita valores como 10.5 e dá problema em comparação e junção | `BIGINT` / `INT` |
| pedido_compra | Quantidades e preço em `float8` (erro de arredondamento em dinheiro) | `DECIMAL(12,3)` e `DECIMAL(12,4)` |
| pedido_compra | Sem índice no campo que liga o pedido à entrada | Índice em `ordem_compra` |
| entradas_mercadoria | A PK usa `ordem_compra`, mas a coluna **não existe** na tabela (erro: *column "ordem_compra" named in key does not exist*). Sem ela não há como ligar a entrada ao pedido | Coluna `ordem_compra BIGINT NOT NULL` criada |
| entradas_mercadoria | `item float8` | `INT` |
| Todas | Prefixo `public.` só existe no PostgreSQL | Removido na versão MySQL |
| produtos_filial | Falta a vírgula depois de `idfonecedor int4 NULL` (erro: *syntax error at or near "("*) | Vírgula colocada |
| produtos_filial | Nomes digitados errado: `decricao` e `idfonecedor` | `descricao` e `idfornecedor` |
| produtos_filial | A PK usa `idproduto`, coluna que não existe | Trocada por `produto_id` |
| produtos_filial | `filial_id NULL` dentro da PK (erro 1171 no MySQL) | `NOT NULL` |
| produtos_filial | `produto_id varchar(255)`, diferente das outras tabelas (`varchar(25)`) | Padronizado em `varchar(25)` |
| produtos_filial | `DEFAULT '0'` (texto) em colunas numéricas | `DEFAULT 0` |
| produtos_filial | `idfornecedor int4`, mas o código do fornecedor é texto ("F8") | `VARCHAR(25)` com chave estrangeira para `fornecedor` (o número fica na coluna gerada pela trigger da Parte 3) |
| fornecedor | Nome digitado errado: `idforncedor` | `idfornecedor` |
| fornecedor | A PK usa `idproduto`, que não existe (*column "idproduto" named in key does not exist*). Além disso, fornecedor não depende de produto | PK só em `idfornecedor` |

Decisão de projeto: `venda`, `pedido_compra` e `entradas_mercadoria` **não** têm chave estrangeira para `produtos_filial`. A planilha tem vendas de produtos não cadastrados (P21 a P28), e com FK essas linhas seriam rejeitadas, deixando o faturamento menor do que o real. Elas são importadas e apontadas na validação (Parte 4).

## Erros encontrados no script de importação e como foram corrigidos

Teste do script original contra o banco corrigido: ele terminou dizendo *"33 registros inseridos em venda"* e *"Importação concluída com sucesso!"*, mas **a tabela venda ficou com 0 linhas**, e as 29 datas de pedido ficaram todas NULL.

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` faz `int(valor)`, mas o pandas já lê as datas como `Timestamp`. O `int()` falha e o `except:` sem tipo devolve `None` sem avisar | **Todas as datas viram NULL.** Em `venda`, `data_emissao` é NOT NULL, então as 33 vendas são rejeitadas. Em pedidos e entradas, as datas somem sem aviso | Função `data()` aceita `Timestamp`, `date`, número serial do Excel e texto (DD/MM/AAAA ou AAAA-MM-DD). Data inválida gera erro relatado, não `None` silencioso |
| `conn.rollback()` dentro do laço, a cada erro | O rollback desfaz **todas** as linhas já inseridas desde o último commit, não só a linha com erro | `SAVEPOINT` por linha: um erro desfaz só aquela linha |
| A mensagem final usa `len(df)` (linhas da planilha), não as linhas realmente gravadas | Diz "20/33 registros inseridos" mesmo quando nada entrou | Conta inseridas, duplicadas e com erro separadamente e mostra um quadro planilha × banco no final |
| "Importação concluída com sucesso!" sempre | Esconde falhas | A mensagem final diz quantas linhas não entraram |
| `ON CONFLICT ... DO NOTHING` | Duplicadas são descartadas sem aviso. Além disso, é sintaxe só do PostgreSQL e dá erro no MySQL | INSERT simples. Duplicada é contada e listada |
| Usa só `psycopg2` (PostgreSQL) | Não funciona com o MySQL/Workbench | `DB_TIPO=mysql` ou `postgres`, mais o modo `SAIDA_SQL`, que gera o arquivo de carga para o Workbench |
| Senha `"1234"` escrita no código | Senha vai para o GitHub | Senha lida da variável de ambiente `DB_PASSWORD` |
| Comentário diz que a porta do MySQL é "3006" | Porta errada | O padrão é **3306** e é definido automaticamente pelo `DB_TIPO` |
| fornecedor: `str(row["idfornecedor"])` em coluna que o DDL corrigido define como texto, mas `produtos_filial` gravava num `int4` | 20 produtos rejeitados ("F8" não é número) | Código do fornecedor tratado como texto nas duas tabelas |
| IDs convertidos com `float()` (`pedido_id`, `item`, `ordem_compra`) | Identificador com casa decimal | Conversão com `inteiro()`, que recusa valor não inteiro |
| Códigos convertidos com `str()` puro | Se a coluna vier numérica do Excel, "12345" vira "12345.0" e não bate entre as tabelas | `txt_id()` remove o ".0" |
| `filial_id` vazio em venda vira 1, e `ordem_compra` vazio vira 0 | Inventa dado: venda atribuída à filial errada | Campo obrigatório vazio rejeita a linha e mostra no log |
| `pedido_compra`: `df.iloc[:, :12]` e renomeação das colunas pela **posição** | Se a ordem das colunas mudar, os dados vão para as colunas erradas sem aviso | Colunas lidas pelo **nome**. Colunas sem cabeçalho (M:W) são avisadas e ignoradas |
| `except:` sem tipo | Esconde qualquer erro, até de digitação | Exceções específicas, com a linha da planilha no log |
| `qtde_pendente = pedida - entregue` só quando as duas existem; senão 0 | Pedido sem entrega registrada aparecia sem pendência | Se `qtde_entregue` está vazio, usa 0; pendente = pedida − entregue (mínimo 0) |

## Tratamentos aplicados aos dados

- **Datas:** convertidas de `Timestamp` do pandas (ou serial do Excel/texto) para `DATE`.
- **Horário:** normalizado para `HH:MM:SS` (o campo é `varchar(8)` e faz parte da PK da venda).
- **Códigos** (produto, NF-e, fornecedor): texto, sem espaços nas pontas e sem ".0".
- **Números:** aceitam vírgula decimal e "R$". Preços e quantidades gravados como `DECIMAL`.
- **Nomes de colunas:** convertidos para minúsculas, sem acento, e apelidos mapeados (`idproduto` → `produto_id`, `decricao` → `descricao`, `idforncedor`/`idfonecedor` → `idfornecedor`).
- **qtde_pendente:** calculada como `qtde_pedida − qtde_entregue`, porque a planilha não tem essa coluna.
- **Linhas vazias:** descartadas. **Colunas sem cabeçalho:** ignoradas e avisadas no log.
- **Validações:** campos da chave primária obrigatórios. Linha inválida é relatada com o número da linha na planilha, e o script nunca preenche um valor inventado.
- **Ordem de carga:** fornecedor → produtos_filial (FK para fornecedor) → pedido_compra → entradas_mercadoria → venda.
- Os dados com inconsistência de negócio (produto não cadastrado, ordem de compra 0, datas trocadas etc.) **foram importados como vieram** e estão listados em `docs/parte4_validacao.md` para decisão do cliente. Corrigir esses dados sem falar com o cliente seria inventar informação.

## Conferência final

Contagem com `SELECT COUNT(*)` em cada tabela, depois da carga:

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |
