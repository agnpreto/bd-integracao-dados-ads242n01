Parte 1 — Documentação do Processo de Importação

Aluna: Franciane de Carvalho Nogueira
Disciplina: Banco de Dados
Atividade: Integração de Dados

1. Ferramentas e tecnologias

O projeto utiliza PostgreSQL como banco de dados principal, MySQL como alternativa e Python para a importação dos dados.

O repositório contém os scripts SQL, o programa de importação e a planilha fornecida para a atividade.

Situação: a execução da importação no banco de dados ainda precisa ser confirmada.

2. Estrutura da planilha

A planilha base_teste.xlsx contém cinco abas:

Aba

Finalidade

fornecedor

Cadastro de fornecedores

produtos_filial

Produtos cadastrados por filial

pedido_compra

Pedidos realizados

entradas_mercadoria

Mercadorias recebidas

venda

Vendas realizadas

3. Erros identificados no DDL original

Durante a análise do código SQL fornecido, foram identificados os seguintes problemas:

Tabela

Erro identificado

Correção proposta

entradas_mercadoria

Campo ordem_compra utilizado sem declaração

Adicionar a coluna

produtos_filial

Coluna decricao

Corrigir para descricao

produtos_filial

Coluna idfonecedor

Corrigir para idfornecedor

produtos_filial

Chave primária utiliza idproduto inexistente

Utilizar produto_id

fornecedor

Coluna idforncedor

Corrigir para idfornecedor

fornecedor

Chave primária referencia idproduto inexistente

Utilizar idfornecedor

As versões corrigidas do DDL estão previstas nos arquivos 01_ddl_postgres.sql e 01_ddl_mysql.sql.

4. Problemas identificados no script de importação

A análise do arquivo scripts/importar.py identificou pontos que exigem atenção:

A senha do banco está escrita diretamente no código, devendo ser substituída por uma variável de ambiente.

A conversão de datas precisa considerar diferentes formatos utilizados no Excel.

A importação deve tratar valores ausentes e possíveis duplicidades.

O uso de ON CONFLICT DO NOTHING pode ignorar registros duplicados, exigindo conferência das quantidades.

As mensagens de quantidade importada devem refletir os registros realmente inseridos, não apenas as linhas lidas da planilha.

A operação rollback pode desfazer registros anteriores ainda não confirmados, exigindo controle adequado das transações.

Esses pontos foram identificados pela leitura do script e ainda precisam de validação prática.

5. Tratamentos necessários

Antes de considerar a importação concluída, deverão ser verificados:

Os tipos de dados das colunas.

A conversão correta das datas.

A integridade das chaves primárias.

O relacionamento entre pedidos e entradas pela coluna ordem_compra.

A existência de fornecedores relacionados aos produtos.

A correspondência entre os registros da planilha e do banco.

6. Conferência final

Tabela

Linhas na planilha

Linhas no banco

fornecedor

A conferir

A conferir

produtos_filial

A conferir

A conferir

pedido_compra

A conferir

A conferir

entradas_mercadoria

A conferir

A conferir

venda

A conferir

A conferir

Observação: Os totais não foram preenchidos porque a importação e a contagem dos registros ainda não foram comprovadas por execução no banco.

7. Conclusão

A análise inicial permitiu identificar problemas estruturais no DDL e pontos de melhoria no script de importação.

A conclusão definitiva da implantação depende da execução dos scripts, da importação da planilha e da comparação das quantidades de registros entre o arquivo original e o banco de dados.

