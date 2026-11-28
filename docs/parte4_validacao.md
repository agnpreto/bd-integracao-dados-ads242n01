# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

**Aluno:** João Gustavo Gonçalves Vasconcelos (2408298), GitHub `SukitaAM`

Objetivo da reunião: que o cliente saia sabendo (1) o que foi carregado, (2) que os números de fevereiro batem com o sistema dele e (3) quais problemas da origem ele precisa decidir. Todas as consultas estão em `sql/04_validacao.sql`.

## 1. Pontos a validar

1. **Completude da carga:** 20 fornecedores, 20 produtos, 29 pedidos, 20 entradas e 33 vendas, igual à planilha (consulta A1).
2. **Período:** a base não tem só fevereiro: tem 12 vendas de janeiro, 14 de fevereiro e 7 de março (A3). Confirmar que o escopo é fevereiro e que janeiro/março podem ser ignorados.
3. **Totais de fevereiro:** 14 linhas de venda, 173,22 unidades e R$ 14.093,17 (A2). O cliente confere com o relatório do sistema dele.
4. **Cadastro de produtos:** 8 produtos vendidos (P21 a P28) não existem no cadastro e 4 vendas são de filiais 2 e 3 que não têm produtos cadastrados (V1, V2). Em fevereiro isso é parte relevante do faturamento (C2).
5. **Regras de preço:** qual é o preço oficial (`preco_unitario` ou `preco_venda`)? Por que o preço vendido nunca bate com o cadastro (V5, V17)? Por que 4 produtos têm preço de venda abaixo do custo (V16)?
6. **Quantidades:** unidade "UN" com quantidade fracionada (V3): é erro de digitação ou a unidade correta é kg/litro?
7. **Compras:** o que significa `ordem_compra = 0` (V8), por que há pedidos duplicados para o mesmo produto (V9), e quais datas estão invertidas (V7, V13).
8. **Recebimento:** a quantidade entregue do pedido não bate com a das notas (V10, V14), o custo da nota difere do preço do pedido (V15) e duas notas não têm pedido (V12).
9. **Fornecedores:** o fornecedor do pedido difere do fornecedor do cadastro em 22 pedidos (V11).
10. **Definições:** "produto requisitado e não recebido" = pedido sem entrada pela `ordem_compra`; "mais de 10 vezes" = quantidade requisitada > 10 (Parte 3). O cliente precisa concordar.

## 2. Técnicas para garantir exatidão e precisão

- **Reconciliação de totais:** contagem de linhas e soma de quantidade/valor na origem x banco (A1, A2). Se baterem, a carga não perdeu nem duplicou dados.
- **Tipos exatos:** `numeric` em vez de `float` para dinheiro e quantidade, evitando erro de arredondamento.
- **Integridade referencial:** PKs, FK e consultas de órfãos (V1, V2, V11, V12) para achar registros sem "pai".
- **Regras de negócio:** consultas de consistência (data de entrega >= data do pedido, recebido <= pedido, preço de venda >= custo).
- **Duplicidade:** chaves e registros repetidos (A4, V9).
- **Amostragem manual:** o cliente escolhe 5 a 10 vendas e confere uma a uma no sistema dele.
- **Comparação de duas formas:** o mesmo total calculado por produto e por dia deve dar o mesmo resultado.
- **Rastreabilidade:** nada foi corrigido em silêncio. Os dados entraram como vieram da planilha; as correções serão aplicadas só após a decisão do cliente, com registro (o que, quando, por quê).
- **Repetibilidade:** a carga é um script que mostra planilha x banco; pode ser rodada de novo quando o cliente corrigir a origem.

## 3. Consultas preparadas para a reunião

(As consultas ficam em `sql/04_validacao.sql`.)

| Bloco | O que mostra |
| --- | --- |
| A1 | Linhas por tabela, para comparar com a planilha |
| A2 | Quantidade, valor e datas de fevereiro: o número que o cliente confere |
| A3 | Vendas por mês, mostrando que a base mistura janeiro, fevereiro e março |
| A4 / A5 | Chaves duplicadas e campos vazios (esperado: nenhum) |
| V1 a V18 | Uma consulta por problema encontrado (tabela abaixo) |
| C1 | Top 5 produtos de fevereiro |
| C2 | Quanto do faturamento de fevereiro é de produto sem cadastro |

## Erros encontrados nos dados

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| venda | Produto vendido que não existe no cadastro (P21 a P28) | 13 linhas (8 produtos) | V1 |
| venda | Vendas em filiais 2 e 3, sem produtos cadastrados nelas | 4 linhas | V2 |
| venda | Quantidade fracionada com unidade `UN` | 5 linhas | V3 |
| venda | Mesmo valor unitário em produtos diferentes (valores copiados, ex.: 61,85 em P13 e P21) | 21 linhas | V4 |
| venda | Valor vendido diferente do `preco_venda` do cadastro | 20 de 20 vendas com cadastro | V5 |
| venda | Horário igual (`08:00:00`) em todas: é o valor padrão, não o horário real | 33 linhas | V6 |
| venda | Base mistura meses (jan 12, mar 7, além de fev 14) | 19 linhas fora de fevereiro | A3 |
| pedido_compra | Data de entrega anterior à data do pedido | 20 linhas | V7 |
| pedido_compra | `ordem_compra = 0` (sem vínculo com entrada) | 11 linhas (pedidos 19 a 29) | V8 |
| pedido_compra | Pedidos repetidos para o mesmo produto, mesmas datas e preço (pedidos 21 a 29 copiam P12 a P20) | 9 linhas | V9 |
| pedido_compra | `qtde_entregue` diferente do total das entradas da mesma ordem | 18 linhas | V10 |
| pedido_compra | Fornecedor do pedido diferente do fornecedor do cadastro | 22 linhas | V11 |
| pedido_compra (planilha) | Colunas M:W sem cabeçalho com dados duplicados dos pedidos 21 a 29 (lixo; descartadas na carga) | 9 linhas x 11 colunas | só na planilha: o arquivo `.xlsx` (não é importado) |
| entradas_mercadoria | Entrada sem pedido correspondente pela `ordem_compra` (NFE19, NFE20) | 2 linhas | V12 |
| entradas_mercadoria | Mercadoria recebida antes da data do pedido | 9 linhas | V13 |
| entradas_mercadoria | Quantidade recebida maior que a pedida | 7 linhas | V14 |
| entradas_mercadoria | Custo da nota diferente do preço do pedido | 18 linhas | V15 |
| produtos_filial | Preço de venda menor que o preço de compra (prejuízo) | 4 linhas | V16 |
| produtos_filial | `preco_unitario` diferente de `preco_venda` (dois preços para o mesmo produto) | 20 linhas | V17 |
| produtos_filial / fornecedor | Fornecedores sem produto (F14, F15, F16): informativo | 3 linhas | V18 |
| produtos_filial / fornecedor | `idfornecedor` em texto (`F8`) na planilha, numérico no DDL | 20 + 20 linhas (tratado na carga) | conversão em `importar.py` |

## Decisões que o cliente precisa tomar após a reunião

Os dados foram carregados exatamente como vieram da planilha. Nenhum valor foi alterado sem aprovação. Para cada problema, a decisão que preciso do cliente:

| Problema (consulta) | Decisão necessária | Opções |
| --- | --- | --- |
| Produtos P21 a P28 vendidos e sem cadastro (V1) | Cadastrar os produtos ou excluir as vendas? | Incluir em `produtos_filial` / manter como "sem cadastro" nos relatórios |
| Filiais 2 e 3 sem produtos (V2) | As filiais existem? | Cadastrar os produtos nas filiais / corrigir o `filial_id` das vendas |
| Quantidade fracionada em `UN` (V3) | Qual é a unidade correta? | Trocar a unidade (kg, L) / corrigir a quantidade |
| `ordem_compra = 0` (V8) e entradas NFE19 e NFE20 sem pedido (V12) | Qual ordem pertence a cada pedido? | Informar as ordens corretas para refazer o vínculo |
| Pedidos 21 a 29 repetidos (V9) | São duplicatas ou pedidos novos? | Excluir as duplicatas / manter com ordem válida |
| Datas invertidas (V7, V13) | Qual data está errada? | Corrigir `data_pedido` ou `data_entrega` |
| Dois preços no cadastro (V17) e preço abaixo do custo (V16) | Qual é o preço oficial de venda? | Definir `preco_venda` e descontinuar `preco_unitario`, ou o contrário |
| Custo da nota diferente do pedido (V15) | O preço mudou depois do pedido? | Aceitar a nota / pedir ajuste ao fornecedor |

Cada correção aprovada será aplicada por um script `UPDATE` revisado, com registro do que mudou, a data e o motivo, e as consultas V1 a V18 serão rodadas de novo para provar que o problema sumiu.
