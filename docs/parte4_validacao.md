
# Parte 4 — Validação dos Dados com o Cliente

## 1. Objetivo

A validação tem como objetivo verificar se os dados importados para o banco de dados estão corretos, completos e consistentes com as informações fornecidas pelo cliente.

Essa etapa é importante para identificar possíveis erros antes da utilização definitiva do banco.

## 2. Planejamento da reunião com o cliente

Durante a reunião, serão apresentados:

- A estrutura das tabelas do banco de dados.
- Os dados importados das planilhas.
- Os relacionamentos entre as tabelas.
- As inconsistências identificadas.
- As correções necessárias.

O cliente poderá confirmar se as informações armazenadas correspondem aos dados originais.

## 3. Técnicas de validação

Serão utilizadas as seguintes técnicas:

**Validação de completude:** verifica se existem campos ou registros ausentes.

**Validação de duplicidade:** identifica registros repetidos.

**Validação de integridade:** verifica se os relacionamentos entre as tabelas estão corretos.

**Validação de consistência:** identifica informações incompatíveis ou fora do padrão esperado.

**Validação de quantidade:** compara a quantidade de registros da origem com a quantidade armazenada no banco.

## 4. Consultas SQL de validação

O arquivo `sql/04_validacao.sql` contém dez consultas destinadas à identificação de problemas nos dados.

As verificações contemplam:

1. Identificação de registros com informações ausentes.
2. Verificação de possíveis duplicidades.
3. Conferência dos relacionamentos entre tabelas.
4. Identificação de produtos sem correspondência.
5. Verificação de fornecedores.
6. Conferência de pedidos.
7. Identificação de inconsistências nos recebimentos.
8. Verificação de valores inválidos.
9. Conferência da integridade dos registros.
10. Análise geral da qualidade dos dados.

## 5. Tratamento das inconsistências

Quando forem identificados problemas, será realizada uma análise para determinar sua origem.

As possíveis ações incluem:

- Corrigir informações incorretas.
- Identificar registros duplicados.
- Preencher informações ausentes quando houver confirmação da origem.
- Ajustar relacionamentos entre tabelas.
- Solicitar confirmação do cliente quando houver dúvidas.

Nenhuma informação será alterada sem verificar sua origem.

## 6. Critérios de aprovação

O banco será considerado validado quando:

- Os registros estiverem corretamente importados.
- Os relacionamentos entre as tabelas estiverem consistentes.
- Não existirem duplicidades indevidas.
- Os campos obrigatórios estiverem preenchidos.
- As informações estiverem de acordo com os dados originais.
- O cliente confirmar os resultados apresentados.

## 7. Conclusão

A etapa de validação permite avaliar a qualidade das informações armazenadas e identificar problemas que poderiam comprometer análises futuras.

As consultas SQL auxiliam na identificação das inconsistências e fornecem uma maneira organizada de verificar a integridade dos dados.

A aprovação definitiva depende da execução das consultas e da confirmação dos resultados pelo cliente.
