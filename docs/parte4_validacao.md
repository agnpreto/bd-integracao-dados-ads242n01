
# Parte 4 — Reunião de validação dos dados

## 1. Objetivo da reunião

Validar a qualidade dos dados utilizados no projeto, verificando integridade, consistência, duplicidade, preenchimento e valores incompatíveis.

## 2. Pontos discutidos

- Conferência da quantidade de registros importados.
- Verificação de campos obrigatórios.
- Identificação de registros duplicados.
- Verificação de quantidades e valores negativos ou zerados.
- Conferência das datas das vendas.
- Análise das quantidades vendidas por produto.
- Conferência dos registros por filial.

## 3. Técnicas de validação

Foram preparadas consultas SQL para:

1. Contar os registros da tabela de vendas.
2. Localizar campos obrigatórios sem preenchimento.
3. Identificar identificadores duplicados.
4. Encontrar quantidades e valores inválidos.
5. Localizar quantidades fracionadas com unidade de medida UN.
6. Conferir datas fora do período de 2025.
7. Agrupar vendas por produto.
8. Conferir os totais de fevereiro de 2025.
9. Agrupar registros por filial.
10. Conferir as unidades de medida.

As consultas estão registradas em `sql/04_validacao.sql`.

## 4. Inconsistências identificadas para investigação

Na análise dos registros fornecidos, foram observadas quantidades fracionadas associadas à unidade de medida UN.

Exemplos:
- Produto P4: 38,6 unidades.
- Produto P8: 20,04 unidades.
- Produto P12: 2,86 unidades.
- Produto P16: 37,11 unidades.
- Produto P26: 3,11 unidades.

Esses registros devem ser conferidos com a origem dos dados para determinar se representam erro de preenchimento ou uma característica legítima do produto.

## 5. Limitações da validação

A base disponibilizada contém somente a aba `venda`, com 33 registros.

Não foi possível validar com dados reais as tabelas de fornecedores, produtos por filial, pedidos de compra e entradas de mercadoria, pois seus dados não foram disponibilizados.

As consultas foram preparadas para execução no PostgreSQL. Os resultados de execução devem ser registrados após a conferência no banco.

## 6. Conclusão

A validação preparada permite investigar problemas de preenchimento, duplicidade, valores e consistência dos registros de vendas.

A conclusão da validação integral depende da disponibilização das demais abas e da execução das consultas no banco de dados.
