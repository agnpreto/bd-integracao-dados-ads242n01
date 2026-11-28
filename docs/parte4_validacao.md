# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

## 1. Pontos a validar

A ideia da reunião é sentar com o cliente e, antes de fechar qualquer número de fevereiro/2025, confirmar se o que está no banco bate com o que ele espera ver. Os pontos que eu levaria são:

1. **Os totais de venda do mês** — quanto foi vendido, em quantidade e em R$, por produto e por filial. É o número que mais importa pra ele, então é o primeiro que comparo com o relatório que ele já tem em mãos.
2. **Se todo produto vendido realmente existe no cadastro** (`produtos_filial`) — com descrição, preço e estoque. Pelo que vi no banco, não: tem produto sendo vendido sem nenhuma ficha cadastrada (Erro 1, abaixo).
3. **Se as quantidades vendidas fazem sentido**: um produto que é vendido "por unidade" não deveria aparecer com 37,11 unidades vendidas, por exemplo. Isso cheira a erro de digitação ou de conversão em algum ponto do processo (Erro 2).
4. **Se a linha do tempo dos pedidos de compra fecha**: a entrega não pode acontecer antes do pedido ser feito. Encontrei bastante pedido assim (Erro 3), e preciso entender com o cliente se é erro de data ou se o pedido foi lançado tarde no sistema.
5. **Se dá pra rastrear cada pedido até a nota fiscal de entrada dele** — e boa parte não dá, porque falta o número da ordem de compra (Erro 4).
6. **Qual fonte eu devo confiar quando o assunto é "quanto já chegou"**: o que o próprio pedido de compra diz que foi entregue, ou o que está registrado nas notas de entrada de mercadoria? Encontrei os dois números discordando sistematicamente (Erro 5), então esse é um ponto que não dá pra resolver sozinha — preciso perguntar ao cliente qual sistema ele considera a fonte da verdade.

## 2. Técnicas para garantir exatidão e precisão

- **Reconciliação de totais**: comparar contagens e somas do banco com a planilha original (já feito na Parte 1) e, aqui, com o relatório mensal que o cliente usa no dia a dia.
- **Integridade referencial**: todo produto vendido existe de fato no cadastro de produtos? Todo fornecedor referenciado existe na tabela de fornecedores? Uso `LEFT JOIN` com `WHERE ... IS NULL` pra achar justamente o que "deveria existir e não existe".
- **Faixa de valores plausíveis**: quantidade e preço não podem ser zero ou negativos; e quantidade vendida em unidade inteira não pode vir fracionada.
- **Consistência de datas**: entrega não pode vir antes do pedido, venda não pode estar fora do período que estou analisando.
- **Conferência cruzada entre tabelas**: quando duas tabelas guardam (ou deveriam guardar) a mesma informação por caminhos diferentes — tipo "quanto foi entregue" no pedido de compra e "quanto foi recebido" nas notas de entrada —, comparo uma com a outra. Se não batem, uma das duas está errada, ou pior, as duas.
- **Amostragem na própria reunião**: levo 2 ou 3 casos concretos (inclusive algum dos que deram erro) pra conferir ao vivo com o cliente, olhando a nota fiscal original. Isso ajuda a descobrir se o erro é do dado ou se eu que interpretei errado alguma regra do negócio dele.

## 3. Consultas preparadas para a reunião

Todas as consultas citadas aqui estão em `sql/04_validacao.sql`:

- Uma visão geral de vendas de fevereiro/2025, por produto e por filial (quantidade e R$) — é por onde eu começaria a conversa, deixando o cliente comparar com o que ele já tem.
- Uma consulta pra cada um dos cinco erros listados abaixo, sempre mostrando as linhas afetadas de verdade (não só a contagem), porque é mais fácil o cliente reconhecer o problema vendo o pedido ou a venda específica do que um número solto.
- A consulta de conferência cruzada entre `pedido_compra.qtde_entregue` e `entradas_mercadoria.qtde_recebida`, que é a base do Erro 5.

## Erros encontrados nos dados

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| venda | Produto vendido sem nenhum cadastro em `produtos_filial` (sem descrição, preço ou estoque) — inclui vendas nas filiais 2 e 3, que não têm produto algum cadastrado | 8 produtos (`P21`–`P28`), em 3 filiais | Bloco "ERRO 1" de `sql/04_validacao.sql` |
| venda | Quantidade vendida fracionada (`qtde_vendida`) num produto cuja unidade de medida é "UN" | 5 vendas | Bloco "ERRO 2" de `sql/04_validacao.sql` |
| pedido_compra | Data de entrega anterior à data do pedido — a mercadoria "chega" antes de ser pedida | 20 de 29 pedidos | Bloco "ERRO 3" de `sql/04_validacao.sql` |
| pedido_compra | Pedido sem número de ordem de compra (ficou com o valor padrão 0), o que torna impossível achar a nota de entrada correspondente | 11 de 29 pedidos | Bloco "ERRO 4" de `sql/04_validacao.sql` |
| pedido_compra / entradas_mercadoria | O que o pedido diz ter sido entregue não bate com o que está de fato registrado nas notas de entrada, pra a mesma ordem de compra | 18 de 18 pedidos com ordem de compra válida — ou seja, 100% dos casos que dava pra conferir | Consulta de "conferência cruzada" em `sql/04_validacao.sql` |

Por fim, dá pra agrupar esses achados em dois tipos: os erros 1 e 4 são de cadastro incompleto (falta produto, falta número de ordem de compra), e os erros 2, 3 e 5 são de inconsistência entre o que foi digitado e o que o processo de negócio permitiria. Antes de publicar qualquer número fechado de fevereiro/2025, vale a pena o cliente dizer, caso a caso, em qual fonte ele confia mais — porque, dependendo da resposta, a correção é no dado ou no processo que gera o dado.
