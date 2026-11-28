# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

PostgreSQL (e MySQL para validação do DDL compatível), Python 3 com bibliotecas de leitura de planilhas/banco (`scripts/importar.py`) e cliente SQL (DBeaver / `psql`) para execução dos scripts e conferência de registros.

## Estrutura da planilha

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| `fornecedor` | `idfornecedor`, `razao_social` | Texto (`varchar`) | Cadastro de fornecedores; PK única por `idfornecedor`[span_0](start_span)[span_0](end_span) |
| `produtos_filial` | `filial_id`, `produto_id`, `descricao_produto`, `estoque`, `preco_unitario`, `preco_compra`, `preco_venda`, `idfornecedor` | Inteiro, Texto e Numérico (`float8`) | Cadastro de produtos por filial; ligação com `fornecedor` via `idfornecedor`[span_1](start_span)[span_1](end_span) |
| `pedido_compra` | `pedido_id`, `data_pedido`, `item`, `produto_id`, `descricao_produto`, `ordem_compra`, `qtde_pedida`, `filial_id`, `data_entrega`, `qtde_entregue`, `qtde_pendente`, `preco_compra`, `fornecedor_id` | Numérico, Data (`date`) e Texto | Pedidos de compra emitidos; PK composta por `(pedido_id, produto_id, item)`[span_2](start_span)[span_2](end_span) |
| `entradas_mercadoria` | `ordem_compra`, `data_entrada`, `nro_nfe`, `item`, `produto_id`, `descricao_produto`, `qtde_recebida`, `filial_id`, `custo_unitario` | Numérico, Data (`date`) e Texto | Recebimentos físicos e notas fiscais; liga-se a `pedido_compra` por `ordem_compra`[span_3](start_span)[span_3](end_span) |
| `venda` | `venda_id`, `data_emissao`, `horariomov`, `produto_id`, `qtde_vendida`, `valor_unitario`, `filial_id`, `item`, `unidade_medida` | Inteiro, Data (`date`), Texto e Numérico | Movimentação de vendas por item/cupom nas filiais[span_4](start_span)[span_4](end_span) |

## Erros encontrados no DDL e como foram corrigidos

| Tabela | Erro | Correção |
| --- | --- | --- |
| `entradas_mercadoria` | A chave primária (`entradas_mercadoria_pkey`) referencia `ordem_compra`, mas a coluna não estava declarada na tabela[span_5](start_span)[span_5](end_span) | Adicionada a coluna `ordem_compra float8 NOT NULL DEFAULT 0` (e `DOUBLE` no MySQL) na definição da tabela[span_6](start_span)[span_6](end_span) |
| `produtos_filial` | Falta de vírgula após `idfonecedor int4 NULL` antes da declaração `CONSTRAINT produtos_filial_pkey`[span_7](start_span)[span_7](end_span) | Inserida a vírgula separadora antes da definição da chave primária[span_8](start_span)[span_8](end_span) |
| `produtos_filial` | Chave primária apontando para coluna inexistente `idproduto` e `filial_id` definido como `NULL`[span_9](start_span)[span_9](end_span) | Alterada a PK para `(filial_id, produto_id)` e definido `filial_id` como `NOT NULL`[span_10](start_span)[span_10](end_span) |
| `produtos_filial` | Grafia incorreta em `decricao` e `idfonecedor`, além de `DEFAULT '0'` como texto em colunas numéricas `float8`[span_11](start_span)[span_11](end_span) | Padronizados os nomes para `descricao_produto` e `idfornecedor`, e removidas as aspas dos `DEFAULT 0` numéricos[span_12](start_span)[span_12](end_span) |
| `fornecedor` | Chave primária incluindo `idproduto` (coluna inexistente na tabela) e grafia `idforncedor`[span_13](start_span)[span_13](end_span) | Padronizado o nome da coluna para `idfornecedor` e corrigida a PK para `PRIMARY KEY (idfornecedor)`[span_14](start_span)[span_14](end_span) |
| Todas as tabelas | Sintaxe exclusiva do PostgreSQL (`public.`, `int8`, `float8`, `::character varying`) incompatível com MySQL[span_15](start_span)[span_15](end_span) | Criado o arquivo `sql/01_ddl_mysql.sql` com tipos padrão SQL/MySQL (`BIGINT`, `INT`, `DOUBLE`, `DECIMAL`, `VARCHAR`)[span_16](start_span)[span_16](end_span) |

## Erros encontrados no script de importação e como foram corrigidos

| Erro | Efeito | Correção |
| --- | --- | --- |
| Mapeamento divergente entre nomes de colunas da planilha e do DDL corrigido (`decricao`/`idforncedor`) | Falha na inserção (`UndefinedColumn`) ou perda de colunas durante o mapeamento | Alinhado o mapeamento das colunas das 5 abas para os nomes padronizados em `01_ddl_postgres.sql`[span_17](start_span)[span_17](end_span) |
| Ordem de carga sem respeitar dependências entre tabelas (`produtos_filial` antes de `fornecedor`) | Violação de integridade referencial na chave estrangeira `fk_produtos_filial_fornecedor` | Definida a ordem de importação iniciando por `fornecedor` antes de `produtos_filial`[span_18](start_span)[span_18](end_span) |
| Credenciais de banco fixas ou expostas no código-fonte | Risco de segurança e exposição de senha no repositório GitHub | Substituídas credenciais fixas por variáveis de ambiente / valores de exemplo conforme exigido no README |

## Tratamentos aplicados aos dados

- **Conversão de tipos e datas:** Padronização de campos de data (`data_emissao`, `data_pedido`, `data_entrega`, `data_entrada`) para o formato ISO (`YYYY-MM-DD`) e conversão de colunas numéricas (`qtde_vendida`, `valor_unitario`, `estoque`, preços e quantidades de compra) substituindo valores nulos pelos respectivos padrões definidos no DDL (`DEFAULT 0`)[span_19](start_span)[span_19](end_span).
- **Normalização de chaves e textos:** Remoção de espaços extras (`TRIM`) em identificadores (`produto_id`, `idfornecedor`, `nro_nfe`) e conversão explícita para string (`varchar`) para evitar perda de zeros à esquerda ou conflito de tipos entre tabelas[span_20](start_span)[span_20](end_span).
- **Validação de integridade e duplicidades:** Verificação das chaves primárias compostas antes da gravação para evitar rejeição de lote por registros duplicados (`ON CONFLICT` / tratamento de duplicidade) e garantia de que todo `idfornecedor` em `produtos_filial` possua correspondência em `fornecedor`[span_21](start_span)[span_21](end_span).

## Conferência final

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor |  |  |
| produtos_filial |  |  |
| pedido_compra |  |  |
| entradas_mercadoria |  |  |
| venda |  |  |
