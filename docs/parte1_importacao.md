# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

Foi adotado o **DBeaver** para criar e administrar os bancos localmente, executando o DDL correspondente ao SGBD. Para automatizar a carga da planilha foi preparado o script `importar.py`, em Python, com `pandas` para leitura do Excel e driver `psycopg2` (PostgreSQL) ou `mysql-connector-python` (MySQL). O script permite escolher o mecanismo pela variável `DB_ENGINE`.

> A estrutura e os arquivos foram preparados e revisados a partir dos anexos. A carga efetiva depende de configurar o servidor, usuário e senha locais; portanto, os números abaixo são as quantidades de origem/esperadas, não uma declaração de que um banco remoto foi executado.

## Estrutura da planilha

A pasta `base_teste.xlsx` contém cinco abas. Os tipos abaixo são os tipos observados pelo pandas na leitura do arquivo; datas são datas Excel e os códigos são tratados como texto para preservar letras e zeros.

| Aba | Colunas | Tipos observados / tratamento | Linhas |
|---|---|---|---:|
| fornecedor | `idfornecedor`, `razao_social` | texto, texto | 20 |
| produtos_filial | `filial_id`, `idproduto`, `descricao`, `estoque`, `preco_unitario`, `preco_compra`, `preco_venda`, `idfornecedor` | inteiro, texto, texto, inteiro, decimal, decimal, decimal, texto | 20 |
| pedido_compra | `pedido_id`, `data_pedido`, `item`, `produto_id`, `descricao_produto`, `ordem_compra`, `qtde_pedida`, `filial_id`, `data_entrega`, `qtde_entregue`, `preco_compra`, `fornecedor_id` + 11 colunas extras sem cabeçalho | inteiros/datas/textos/decimais conforme campo; colunas extras preservadas em tabela de auditoria | 29 |
| entradas_mercadoria | `data_entrada`, `nro_nfe`, `item`, `produto_id`, `descricao_produto`, `ordem_compra`, `qtde_recebida`, `filial_id`, `custo_unitario` | data, texto, inteiro, texto, texto, inteiro, inteiro, inteiro, decimal | 20 |
| venda | `venda_id`, `data_emissao`, `horariomov`, `produto_id`, `qtde_vendida`, `valor_unitario`, `filial_id`, `item`, `unidade_medida` | inteiro, data, texto/hora, texto, decimal, decimal, inteiro, inteiro, texto | 33 |

## Erros encontrados no DDL e como foram corrigidos

| Tabela | Erro identificado no DDL original | Correção aplicada |
|---|---|---|
| venda | O DDL veio com casts e tipos próprios do PostgreSQL (`int8`, `float8`, `::character varying`), incompatíveis com MySQL. | Criadas versões específicas para PostgreSQL e MySQL; mantida a chave composta informada. |
| entradas_mercadoria | A PK usa `ordem_compra`, mas a coluna não foi declarada. | Incluída `ordem_compra` antes da PK. |
| produtos_filial | `decricao` e `idfonecedor` são grafias inconsistentes; a PK usa `idproduto`, enquanto a coluna declarada é `produto_id`; falta vírgula antes da constraint. | Padronizados `descricao`, `codigo_fornecedor` e `idfornecedor`; PK definida por `(filial_id, produto_id)`; corrigida a sintaxe. |
| fornecedor | `idforncedor` está grafado incorretamente e a PK referencia uma coluna inexistente (`idproduto`). | Criada PK numérica `idfornecedor` e coluna única `codigo_fornecedor` para guardar códigos originais F1...F20. |
| pedido_compra | A planilha possui 12 colunas principais, mas o DDL inclui `qtde_pendente`; não havia regra de cálculo. | Incluída `qtde_pendente`, calculada como `GREATEST(qtde_pedida - qtde_entregue, 0)` durante a carga. |

## Erros encontrados no script de importação e como foram corrigidos

| Erro no script original | Efeito | Correção aplicada |
|---|---|---|
| Caminho fixo `dados/base_teste.xlsx` e conexão fixa em PostgreSQL. | Falha se o arquivo ou SGBD estiver em outro local. | Caminho e conexão configuráveis; seleção PostgreSQL/MySQL por `DB_ENGINE`. |
| Conversão de nulos com `str(valor)`. | Valores ausentes podem virar texto `'nan'`. | Função de normalização retorna `None` para nulos e preserva códigos como texto. |
| `df.iloc[:, :12]` na aba `pedido_compra`. | Descarta 11 colunas extras presentes nas linhas 21–29. | Colunas extras são preservadas em `pedido_compra_extras` como JSON textual, aguardando validação do cliente. |
| O script informava `len(df)` como inseridos mesmo com conflitos/erros. | Contagem apresentada poderia não refletir a carga. | Contadores incrementados somente após cada INSERT bem-sucedido; erros interrompem a transação e são registrados. |
| `rollback()` dentro do loop sem controle claro de lote. | Pode desfazer operações anteriores do mesmo lote. | Carga em transação controlada por tabela, com falha explícita e rollback do lote. |
| `qtde_pendente` calculada sem limitar saldo negativo. | Pode produzir saldo negativo se recebido superar pedido. | Saldo calculado com `max(qtde_pedida - qtde_entregue, 0)`; casos de excesso são sinalizados para validação. |

## Tratamentos aplicados aos dados

- Datas foram convertidas para `date` (não texto), preservando o calendário da planilha.
- Quantidades e preços foram convertidos para tipos numéricos decimais no banco.
- Identificadores alfanuméricos (`P1`, `F1`, `NFE1`) foram mantidos como texto.
- Campos vazios foram convertidos para `NULL`, em vez de `'nan'` ou string vazia indevida.
- `idfornecedor` numérico é obtido a partir do código F1...F20 na tabela `fornecedor`; o código original fica em `codigo_fornecedor`.
- A trigger relaciona automaticamente o produto ao fornecedor pelo código e rejeita código inexistente.
- Os 11 campos extras sem cabeçalho na aba `pedido_compra` (linhas Excel 21–29) são preservados em tabela de auditoria e não misturados às colunas operacionais sem confirmação.
- Não foram corrigidos automaticamente os `ordem_compra = 0`, pois não há informação suficiente para deduzir o número correto.

## Conferência final

| Tabela | Linhas na planilha | Linhas esperadas no banco após carga limpa |
|---|---:|---:|
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |
| pedido_compra_extras (auditoria) | 9 linhas com conteúdo extra | 9 |

Total das cinco abas principais: **122 linhas**. A tabela de extras é auxiliar e guarda os dados adicionais sem cabeçalho de nove linhas da aba de pedidos.
