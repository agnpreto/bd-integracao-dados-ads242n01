Parte 4 — Roteiro de Validação com o Cliente

Aluna: Franciane de Carvalho Nogueira
Disciplina: Banco de Dados
Período analisado: Fevereiro de 2025

1. Pontos a validar com o cliente

Durante a reunião, serão verificados:

A quantidade de registros importados em cada tabela.

Os produtos vendidos e os valores totais das vendas.

Os pedidos de compra realizados e as mercadorias recebidas.

A existência de produtos e fornecedores sem cadastro.

A presença de informações duplicadas, ausentes ou inconsistentes.

A correspondência entre os dados da planilha e os registros do banco.

2. Técnicas para garantir exatidão e precisão

Serão utilizadas consultas SQL para conferir a integridade dos dados.

As principais técnicas serão:

COUNT(*): contar os registros das tabelas.

SUM(): calcular quantidades e valores totais.

JOIN: relacionar informações de tabelas diferentes.

WHERE: filtrar registros de fevereiro de 2025.

GROUP BY: agrupar resultados por produto.

IS NULL: identificar informações ausentes.

HAVING: localizar grupos com registros repetidos ou que atendam a condições específicas.

Os resultados deverão ser comparados com a planilha original.

3. Consultas preparadas para a reunião

As consultas serão armazenadas no arquivo sql/04_validacao.sql.

Elas deverão permitir:

Conferir o total de registros por tabela.

Calcular as vendas de fevereiro de 2025.

Identificar vendas com quantidades ou preços inválidos.

Verificar pedidos com quantidades inconsistentes.

Localizar entradas de mercadorias sem pedidos correspondentes.

Identificar produtos com fornecedores inexistentes.

Verificar produtos vendidos sem cadastro na filial.

Investigar possíveis duplicidades.

Identificar datas de entrega anteriores às datas dos pedidos.

4. Erros identificados e verificações pendentes

Na análise do DDL original, foram identificados os seguintes problemas:

Tabela

Problema identificado

Correção proposta

entradas_mercadoria

Campo ordem_compra utilizado na chave primária sem ter sido declarado

Adicionar a coluna ordem_compra

produtos_filial

Coluna decricao escrita incorretamente

Corrigir para descricao

produtos_filial

Campo idfonecedor escrito incorretamente

Corrigir para idfornecedor

produtos_filial

Chave primária utiliza idproduto, não declarado

Utilizar produto_id

fornecedor

Campo idforncedor escrito incorretamente

Corrigir para idfornecedor

fornecedor

Chave primária referencia idproduto, inexistente

Utilizar idfornecedor como chave primária

Observação: Os problemas acima foram identificados pela leitura do código original. A quantidade de erros existentes nos dados ainda depende da execução das consultas no PostgreSQL.

5. Conclusão

A validação busca garantir que os dados de fevereiro de 2025 estejam completos, consistentes e corretamente relacionados.

Após a execução das consultas, os resultados deverão ser apresentados ao cliente para conferência, identificação de divergências e aprovação dos dados.

6. Resultados dos testes realizados no MySQL

Foram realizados testes no MySQL Workbench para verificar a quantidade de registros nas tabelas do banco de dados integracao_dados_fran.

Os testes confirmaram:

- fornecedor: 21 registros.
- produtos_filial: 0 registros.
- pedido_compra: 0 registros.
- entradas_mercadoria: consulta executada com sucesso.
- venda: 33 registros.

As consultas foram executadas, mas ainda é necessário conferir os dados importados e validar sua consistência.
