
# Parte 1 — Importação e implantação dos dados

## 1. Objetivo

Preparar a estrutura do banco de dados e realizar a importação dos dados disponibilizados para teste.

## 2. Fonte dos dados

Arquivo utilizado: `dados/base_teste.xlsx`.

A base disponibilizada contém a aba `venda`, com 33 registros e os seguintes campos:

- venda_id
- data_emissao
- horariomov
- produto_id
- qtde_vendida
- valor_unitario
- filial_id
- item
- unidade_medida

## 3. Limitação identificada

As abas `fornecedor`, `produtos_filial`, `pedido_compra` e `entradas_mercadoria` não possuem dados disponíveis no arquivo recebido.

Por esse motivo, não foi possível realizar a importação e a validação dessas quatro tabelas com dados reais.

## 4. Conferência da aba venda

Foram identificados 33 registros na aba `venda`.

Para fevereiro de 2025, foram identificadas 14 vendas, totalizando:

- Quantidade vendida: 173,22
- Valor total: R$ 14.093,17

## 5. Procedimento de importação

O script `scripts/importar.py` foi preparado para identificar as abas existentes e registrar quando uma aba não estiver disponível.

A importação deve ser conferida no PostgreSQL por meio de consultas de contagem de registros.

## 6. Conclusão

A base recebida permite trabalhar com os dados de vendas, mas não permite comprovar a importação integral das cinco tabelas previstas na atividade.

A ausência das demais abas foi registrada como limitação da fonte de dados, sem criação de registros fictícios.
