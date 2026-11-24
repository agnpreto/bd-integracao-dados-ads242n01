# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

- **Banco:** PostgreSQL 16.16 (servidor instalado via Chocolatey; serviço `postgresql-x64-16`,
  porta 5432, usuário `postgres`, banco `atividade`).
- **Importação:** script Python `scripts/importar.py` (estagiário) **corrigido**,
  executado com a venv local `.venv/` (pandas 3.1.1, psycopg2 2.9.13, openpyxl 3.1.5).
- **Validação:** `sql/validar.sql` rodado via `psql`.
- **Análise da planilha:** pandas + openpyxl (leitura célula a célula), para não cair
  nas armadilhas de `read_excel` (amostra, conversão implícita).
- **Enunciado:** extraído de `docs/Atividade_Integracao_de_Dados.pdf` (3 páginas) com
  `pypdf` (o modelo não lê PDF diretamente).

## Estrutura da planilha (`dados/base_teste.xlsx`)

5 abas, 125 linhas no total. Todas as abas sem linhas duplicadas completas.

| Aba | Linhas | Colunas | Observação |
| --- | --- | --- | --- |
| `venda` | 33 | 9 | `venda_id` 1..33 único; `filial_id` 1..3; `horariomov` sempre `08:00:00`; `item` sempre 1; `unidade_medida` sempre `UN` |
| `pedido_compra` | 29 | **23** (12 + 11 extras) | `pedido_id` 1..29 único; `filial_id` sempre 1; ver anomalias |
| `entradas_mercadoria` | 20 | 9 | `nro_nfe` `NFE1..NFE20`; `ordem_compra` 1..20; `item` sempre 1; `filial_id` sempre 1 |
| `produtos_filial` | 20 | 8 | colunas reais: `filial_id, idproduto, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor`; `P1..P20`; `idfornecedor` `F7..F20` (17 distintos) |
| `fornecedor` | 20 | 2 | `idfornecedor` `F1..F20`, `razao_social` "Fornecedor N LTDA" |

Colunas e tipos (conforme lidos pelo openpyxl):

| Aba | Coluna | Tipo (Excel) | Observação |
| --- | --- | --- | --- |
| venda | venda_id | int | 1..33 |
| venda | data_emissao | datetime | 2025-01-03 .. 2025-03-28 |
| venda | horariomov | texto | sempre `08:00:00` |
| venda | produto_id | texto | `P1..P28` |
| venda | qtde_vendida | numérico (float) | 5 valores fracionários em `UN` |
| venda | valor_unitario | numérico (float) | ex. 78,93 (já numérico, sem vírgula no arquivo) |
| venda | filial_id | int | 1..3 |
| venda | item | int | sempre 1 |
| venda | unidade_medida | texto | sempre `UN` |
| pedido_compra | pedido_id | int | 1..29 |
| pedido_compra | data_pedido | datetime | 2025-01-02 .. 2025-03-01 |
| pedido_compra | item | int | sempre 1 |
| pedido_compra | produto_id | texto | `P1..P20` |
| pedido_compra | descricao_produto | texto | "Produto N" |
| pedido_compra | ordem_compra | int | `1..18` e `0` (11 linhas) |
| pedido_compra | qtde_pedida | int | 2..99 |
| pedido_compra | filial_id | int | sempre 1 |
| pedido_compra | data_entrega | datetime | 20 linhas anteriores a `data_pedido` |
| pedido_compra | qtde_entregue | int | 0..91 |
| pedido_compra | preco_compra | numérico (float) | 6,92 .. 85,04 |
| pedido_compra | fornecedor_id | int | 1..20 (texto `F1..F20` no banco) |
| pedido_compra | (colunas M..W) | misto | cópia deslocada de pedidos 12..20 (ver anomalias) |
| entradas_mercadoria | data_entrada | datetime | 2025-01-01 .. 2025-03-01 |
| entradas_mercadoria | nro_nfe | texto | `NFE1..NFE20` |
| entradas_mercadoria | item | int | sempre 1 |
| entradas_mercadoria | produto_id | texto | `P1..P20` |
| entradas_mercadoria | descricao_produto | texto | "Produto N" |
| entradas_mercadoria | ordem_compra | int | 1..20 |
| entradas_mercadoria | qtde_recebida | int | 4..95 |
| entradas_mercadoria | filial_id | int | sempre 1 |
| entradas_mercadoria | custo_unitario | numérico (float) | 16,66 .. 98,99 |
| produtos_filial | filial_id | int | sempre 1 |
| produtos_filial | idproduto | texto | `P1..P20` |
| produtos_filial | descricao | texto | "Produto N" |
| produtos_filial | estoque | int | 28..198 |
| produtos_filial | preco_unitario | numérico (float) | 42,65 .. 184,36 |
| produtos_filial | preco_compra | numérico (float) | 7,75 .. 149,50 |
| produtos_filial | preco_venda | numérico (float) | 40,79 .. 234,58 |
| produtos_filial | idfornecedor | texto | `F7..F20` (17 distintos) |
| fornecedor | idfornecedor | texto | `F1..F20` |
| fornecedor | razao_social | texto | "Fornecedor N LTDA" |

## Erros encontrados no DDL e como foram corrigidos

DDL original executado em banco vazio (`enunciado_teste`) com `psql -f sql/01_ddl_enunciado.sql`.
Erros reais capturados (PostgreSQL 16):

| Tabela | Erro (psql) | Causa | Correção |
| --- | --- | --- | --- |
| `entradas_mercadoria` | `ERRO: não existe a coluna "ordem_compra" indicada na chave` (linha 27) | a PK citava `ordem_compra`, que não era coluna da tabela | coluna `ordem_compra bigint NOT NULL` declarada; PK mantida |
| `produtos_filial` | `ERRO: erro de sintaxe em ou próximo a "("` (linha 33) | faltava vírgula antes de `CONSTRAINT`; PK citava `idproduto` inexistente | vírgula adicionada; PK = `(filial_id, produto_id)`; `decricao`→`descricao`; `idfonecedor`→`idfornecedor`; `preco_unitario float8 DEFAULT '0'`→`numeric(12,4) DEFAULT 0` |
| `fornecedor` | `ERRO: não existe a coluna "idproduto" indicada na chave` (linha 36) | PK citava `idproduto` inexistente; coluna `idforncedor` (typo) | PK = `(idfornecedor)`; `idforncedor`→`idfornecedor` |
| `venda` | criada, mas modelagem errada | PK nome `pk_consumo` enganoso; `horariomov varchar(8)`; `qtde_vendida float8`; `filial_id int8` | PK renomeada `pk_venda`; `horariomov time`; `qtde_vendida numeric(12,3)`; `filial_id integer` |
| `pedido_compra` | criada, mas modelagem errada | `pedido_id/ordem_compra/item float8`; `fornecedor_id int4` incompatível com `fornecedor.idfornecedor` varchar; sem FK | `bigint/integer`; `fornecedor_id varchar(25)`; FK para `fornecedor` |

Tabelas criadas com sucesso pelo enunciado: `venda`, `pedido_compra` (2 de 5).
Correção aplicada em `sql/01_ddl_postgres.sql` (PostgreSQL) e `sql/01_ddl_mysql.sql`
(MySQL 8+, InnoDB, `DECIMAL` no lugar de `NUMERIC`/`FLOAT`). As 5 tabelas são criadas.

Decisões de modelagem documentadas no DDL:
- `entradas_mercadoria` não tem FK para `pedido_compra`: `ordem_compra` não é único
  (11 pedidos vieram com 0) e 2 entradas ficam órfãs (ordens 19 e 20).
- `venda` não tem FK para `produtos_filial`: existem vendas de `P21..P28` sem cadastro.
- `produtos_filial.idfornecedor` e `pedido_compra.fornecedor_id` têm FK para `fornecedor`
  (dados válidos após a normalização 1..20 → F1..F20).
- `fk_venda_produto` criada como `NOT VALID` (pós-importação) porque 13 vendas
  referenciam P21..P28 inexistentes em `produtos_filial`.
- `fk_entradas_pedido` não pode ser criada: requer `UNIQUE(ordem_compra, item, produto_id)`,
  violada por 2 grupos (`(0,1,P19)` e `(0,1,P20)`).

## Erros encontrados no script de importação e como foram corrigidos

Script original testado contra o schema corrigido (`script_original`), sem alterar o arquivo
original. Resultado real do teste: `fornecedor 20`, `produtos_filial 20`, `pedido_compra 0`,
`entradas_mercadoria 20`, `venda 0` (e mensagem "33 registros inseridos" falsa).

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data(int(Timestamp))` | `int()` de `Timestamp` lança exceção → `except: return None` → **todas as datas viram NULL**; `venda.data_emissao` é `NOT NULL` → 0 vendas | conversor por tipo: `Timestamp`/`datetime`/`date`, serial do Excel, texto ISO, M/D/AAAA e D/M/AAAA |
| `conn.rollback()` no `except` | desfaz o **lote inteiro** já executado; `pedido_compra` ficou com 0 linhas | `SAVEPOINT sp_linha` por linha + `ROLLBACK TO SAVEPOINT` (só a linha falha é desfeita) |
| `int(row["fornecedor_id"])` | insere `1..20` (int) em coluna `varchar(25)` com FK → 29 violações de FK → 0 pedidos | `normalizar_fornecedor`: `1..20` → `F1..F20`; mantém `F1..F20` |
| `produtos_filial` usa `idproduto`/`decricao` | nomes divergentes do DDL corrigido | `rename` para `produto_id`/`descricao`/`idfornecedor` (tolerante a `decricao`) |
| `df.iloc[:, :12]` em `pedido_compra` | descartava silenciosamente as 11 colunas extras (bloco duplicado) | mantido `[:12]`, mas com `AVISO` listando as colunas ignoradas |
| contador imprime `len(df)` | mentia: "33 registros inseridos" com 0 reais | `cur.rowcount` por linha; relatório final de inseridos/rejeitados |
| `horariomov` como texto | dependia de cast implícito para `TIME` | `converter_hora` → `datetime.time` |
| vírgula decimal | `float("78,93")` falharia | `converter_decimal` trata `78,93` e `1.234,56` |
| datas M/D/YYYY | risco se lidas como texto | `excel_para_data` trata M/D/AAAA, D/M/AAAA e ISO |
| print final com acentos | `UnicodeEncodeError` no Windows (cp1252) | (não alterado; executar com terminal UTF-8) |

## Tratamentos aplicados aos dados

- Conversão de datas: serial do Excel, `Timestamp`, `datetime`, `date` e texto (ISO, M/D/AAAA,
  D/M/AAAA) → `datetime.date`.
- Conversão de decimais: aceita `.` e `,` como separador decimal e milhar (`78,93`,
  `1.234,56`); usa `Decimal` para evitar arredondamento binário.
- Conversão de inteiros: tolerante a `3`, `3.0` e `"3"`; devolve `None` quando não dá.
- Conversão de hora: texto `HH:MM:SS`/`HH:MM`, `datetime.time`, `datetime` ou fração do dia →
  `datetime.time` (coluna `TIME`).
- Normalização de fornecedor: `1..20` → `F1..F20`; mantém `F1..F20`.
- Nomes de coluna: `idproduto`→`produto_id`, `decricao`→`descricao`,
  `idfonecedor`/`idfornecedor`→`idfornecedor`.
- `qtde_pendente` recalculado como `qtde_pedida - qtde_entregue` (não confiar no valor
  implícito da planilha).
- `SAVEPOINT` por linha + contagem real de inserções.
- Credenciais via variáveis de ambiente (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`,
  `PGPASSWORD`); senha padrão `1234` é apenas exemplo local.

## Conferência final

Importação executada em `atividade` (2026): 0 linhas rejeitadas.

| Tabela | Linhas na planilha | Linhas no banco | Status |
| --- | --- | --- | --- |
| fornecedor | 20 | 20 | OK |
| produtos_filial | 20 | 20 | OK |
| pedido_compra | 29 | 29 | OK |
| entradas_mercadoria | 20 | 20 | OK |
| venda | 33 | 33 | OK |

## Lista de erros encontrados nos dados (com consulta de detecção)

Detalhes e consultas em `sql/validar.sql`.

1. **Bloco duplicado em `pedido_compra` (colunas M..W).** Linhas 22..30 do Excel
   contêm uma cópia deslocada dos pedidos 12..20 (mesmas datas, produto, preço e
   quantidade pendente). Não importado; detectado por leitura completa (`23 colunas`).
   Consulta de detecção: `SELECT * FROM planilha` (fora do SQL; ver `inspecionar.py`).
2. **`ordem_compra = 0` em 11 pedidos (19..29).** Impede a ligação com entradas.
   Consulta: `validar.sql` §5.1.
3. **`data_entrega < data_pedido` em 20 pedidos** (até 48 dias antes).
   Consulta: `validar.sql` §5.2.
4. **Vendas sem produto cadastrado:** 13 vendas, 8 produtos (`P21..P28`).
   Consulta: `validar.sql` §2.2.
5. **Entradas sem pedido:** 2 (ordens 19 e 20, cujos pedidos vieram com `ordem_compra = 0`).
   Consulta: `validar.sql` §2.1.
6. **Pedidos duplicados** (mesmo `produto_id`, `data_pedido`, `preco_compra`): 9 grupos
   (pedidos 21..29 repetem 12..20). Consulta: `validar.sql` §3.3.
7. **Quantidade fracionada em unidade `UN`:** 5 linhas (38,6; 20,04; 2,86; 37,11; 3,11).
   Consulta: `validar.sql` §5.4.
8. **`qtde_entregue` diverge da soma das entradas** em 18 das 18 ordens comparáveis.
   Consulta: `validar.sql` §5.5.
9. **`fornecedor_id` numérico (1..20) em `pedido_compra`** vs. texto `F1..F20` em
   `fornecedor` (normalizado no script). Consulta: `validar.sql` §5.3 (esperado 0 após).
10. **`horariomov` sempre `08:00:00`** em todas as 33 vendas (suspeito, mas não erro).
    Consulta: `validar.sql` §4.
11. **`venda` não tem FK para `produtos_filial`** e **`entradas_mercadoria` não tem FK
    para `pedido_compra`** por causa dos itens 2, 4 e 5; as FKs válidas
    (`produtos_filial`→`fornecedor`, `pedido_compra`→`fornecedor`) foram criadas.
    `fk_venda_produto` foi adicionada como `NOT VALID` (pós-importação); `fk_entradas_pedido`
    não pode ser criada por falta de unicidade em `ordem_compra`.
