# Parte 1 — Importação e implantação dos dados

## 1. Objetivo

Preparar a estrutura do banco de dados e realizar a importação dos dados disponibilizados para teste.

## 2. Fonte dos dados

Arquivo utilizado: `dados/base_teste.xlsx`.

A base disponibilizada contém somente a aba `venda`, com 33 registros e os seguintes campos:

- `venda_id`
- `data_emissao`
- `horariomov`
- `produto_id`
- `qtde_vendida`
- `valor_unitario`
- `filial_id`
- `item`
- `unidade_medida`

## 3. Limitação identificada

As abas `fornecedor`, `produtos_filial`, `pedido_compra` e `entradas_mercadoria`, previstas no enunciado, não estavam disponíveis no arquivo recebido.

Por esse motivo, não foi possível importar nem validar essas quatro tabelas com dados reais.

Nenhum registro fictício foi criado para simular uma importação completa.

## 4. Conferência da fonte de dados

| Tabela | Registros na planilha | Situação |
| --- | ---: | --- |
| venda | 33 | Dados disponíveis |
| fornecedor | Não disponível | Aba ausente |
| produtos_filial | Não disponível | Aba ausente |
| pedido_compra | Não disponível | Aba ausente |
| entradas_mercadoria | Não disponível | Aba ausente |

A quantidade efetivamente inserida no PostgreSQL deve ser confirmada por meio de `SELECT COUNT(*)`. Não foi registrada uma contagem do banco sem comprovação da execução.

## 5. Conferência das vendas de fevereiro de 2025

Na aba `venda`, foram identificados 14 registros referentes a fevereiro de 2025.

- Quantidade vendida: 173,22.
- Valor total: R$ 14.093,17.

Esses valores foram calculados a partir dos dados disponibilizados na planilha.

## 6. Procedimento de importação

O script `scripts/importar.py` foi preparado para:

- verificar a existência do arquivo Excel;
- identificar as abas disponíveis;
- informar quando uma aba estiver ausente;
- validar as colunas obrigatórias da tabela `venda`;
- utilizar variáveis de ambiente para as configurações de conexão;
- importar os registros disponíveis para o PostgreSQL.

A execução deve ser conferida por consultas de contagem de registros no banco de dados.

## 7. Conclusão

A base recebida permite trabalhar com os dados de vendas, mas não permite comprovar a importação integral das cinco tabelas previstas na atividade.

A ausência das demais abas foi documentada como limitação da fonte de dados, preservando a integridade das informações e sem criação de registros fictícios.
