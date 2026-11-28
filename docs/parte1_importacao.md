# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

Utilizou-se o script Python (`scripts/importar.py`) com as bibliotecas `pandas` e `psycopg2` para leitura da planilha `dados/base_teste.xlsx` e carga no PostgreSQL, além do DBeaver para execução dos scripts DDL, inspeção das tabelas e conferência final da quantidade de registros (`SELECT COUNT(*)`).

## Estrutura da planilha

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| fornecedor | idfornecedor, razao_social | string | 20 linhas (`F1` a `F20`), sem valores nulos |
| produtos_filial | filial_id, idproduto, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor | int, string, float | 20 linhas (`P1` a `P20`); a coluna vem como `idproduto` na planilha, enquanto o DDL usa `produto_id` |
| pedido_compra | pedido_id, data_pedido, item, produto_id, descricao_produto, ordem_compra, qtde_pedida, filial_id, data_entrega, qtde_entregue, preco_compra, fornecedor_id | int/float, data, string | 29 linhas; possui 11 colunas extras não nomeadas (`Unnamed: 12` a `Unnamed: 22`) com dados deslocados nas linhas 22 a 30 do Excel |
| entradas_mercadoria | data_entrada, nro_nfe, item, produto_id, descricao_produto, ordem_compra, qtde_recebida, filial_id, custo_unitario | data, string, int/float | 20 linhas; valores de `ordem_compra` de `1` a `20` |
| venda | venda_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario, filial_id, item, unidade_medida | int, data, string, float | 33 linhas; datas em janeiro, fevereiro e março de 2025, sem valores nulos |

## Erros encontrados no DDL e como foram corrigidos

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | A restrição `PRIMARY KEY` referenciava `ordem_compra`, mas a coluna não estava declarada na definição da tabela. | Adicionada a coluna `ordem_compra` na estrutura da tabela antes da chave primária. |
| produtos_filial | Faltava vírgula após `idfonecedor int4 NULL`, coluna `decricao` escrita incorretamente, `filial_id` aceitando `NULL` mesmo fazendo parte da PK e `PRIMARY KEY` apontando para `idproduto` inexistente. | Corrigida a pontuação, padronizada a coluna `descricao`, alterado `filial_id` para `NOT NULL` e ajustada a PK para `(filial_id, produto_id)`. |
| fornecedor | Coluna `idforncedor` com erro de digitação e `PRIMARY KEY (idforncedor, idproduto)` referenciando `idproduto`, que não pertence à tabela. | Corrigido o nome da coluna para `idfornecedor`, ajustada a PK para `(idfornecedor)` e criada a coluna numérica `idfornecedor_num` para o relacionamento exigido na Parte 3. |

## Erros encontrados no script de importação e como foram corrigidos

| Erro | Efeito | Correção |
| --- | --- | --- |
| Senha fixa (`"1234"`) exposta no código-fonte. | Risco de segurança ao publicar no repositório GitHub. | Substituída a senha fixa por leitura via variável de ambiente (`os.getenv("DB_PASSWORD", "SUA_SENHA_AQUI")`). |
| Função `excel_para_data` tratava apenas números inteiros (serial do Excel). | Quando o `pandas` lia células já formatadas como `datetime`, a função retornava `None`, causando falha em colunas `NOT NULL` como `venda.data_emissao`. | Implementada a função `converter_data` que aceita tanto objetos `datetime`/`Timestamp` quanto seriais numéricos e strings de data. |
| Ausência de tratamento para colunas extras e cálculo de `qtde_pendente`. | Colunas `Unnamed: 12`..`Unnamed: 22` em `pedido_compra` podiam gerar inconsistência na leitura. | Mantido o recorte explícito das 12 colunas oficiais (`df_pc.iloc[:, :12]`) e garantido valor não negativo em `qtde_pendente`. |

## Tratamentos aplicados aos dados

* Remoção de espaços extras nas extremidades de nomes de colunas e campos de texto com `.strip()`.
* Padronização de datas para o tipo `DATE` do banco de dados a partir de células `datetime` ou seriais do Excel.
* Mapeamento da coluna `idproduto` da aba `produtos_filial` para a coluna `produto_id` da tabela no banco.
* Extração da parte numérica de `idfornecedor` (`F1`..`F20` $\rightarrow$ `1`..`20`) para popular `idfornecedor_num` e manter a integridade referencial com `fornecedor`.

## Conferência final

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |
