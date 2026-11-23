# Parte 4 — Roteiro de Validação com o Cliente (Fevereiro de 2025)

## 1. Principais Pontos de Validação na Reunião com o Cliente

Para transmitir segurança operacional e garantir que o sistema reflita a realidade financeira e logística da rede de lojas no fechamento de **fevereiro de 2025**, a reunião será conduzida em quatro eixos:

1. **Fechamento Financeiro e Volumetria de Vendas (Fev/2025):**
   - Conferir com o financeiro se o faturamento bruto de fevereiro/2025 (**R$ 14.693,17** distribuídos em **173,22 unidades** vendidas em 14 produtos) bate com os relatórios fiscais/PDV da rede.
   - Validar a ocorrência de vendas fracionadas (`37,11` unidades de `P16` e `3,11` de `P26`) mesmo com unidade de medida cadastrada como `UN`.
2. **Saneamento do Cadastro de Produtos e Filiais:**
   - Confirmar o motivo de haver vendas registradas para os códigos **`P21` a `P28`** sem cadastro correspondente na tabela `produtos_filial`, bem como movimentações nas filiais `2` e `3` (`P27` e `P28`) enquanto o catálogo enviado contém apenas a `filial_id = 1`.
3. **Fluxo de Compras vs. Recebimento Físico (NF-e):**
   - Alinhar a regra de negócio para os **11 pedidos com `ordem_compra = 0`** (`pedido_id` 19 a 29): verificar se são requisições ainda aguardando aprovação ou duplicidades geradas na exportação da planilha original.
   - Esclarecer por que as quantidades baixadas em `pedido_compra.qtde_entregue` não coincidem com as quantidades faturadas em `entradas_mercadoria.qtde_recebida` (e por que algumas notas entregaram mais itens do que o pedido original).
4. **Política de Precificação e Margem:**
   - Validar a tabela de preços de `produtos_filial`, onde 4 itens (`P1`, `P8`, `P15` e `P18`) possuem `preco_venda` inferior ao `preco_compra` e divergem do `preco_unitario`.

---

## 2. Técnicas Utilizadas para Garantir Exatidão e Precisão dos Dados

- **Reconciliação de Totais (Batimento Contábil):** Comparação automatizada de contagem de registros (`COUNT`), soma de volumes (`SUM(qtde)`) e montantes financeiros (`SUM(qtde * valor)`) entre a planilha origem e as tabelas SQL antes e depois da carga.
- **Integridade Referencial e Constraints no SGBD:** Implementação de chaves primárias (`PRIMARY KEY`), chaves estrangeiras (`FOREIGN KEY` entre produtos, pedidos e fornecedores) e automação via `TRIGGER` para impedir registros órfãos.
- **Auditoria de Regras de Negócio e Domínio:** Execução de consultas SQL diagnósticas para detectar anomalias temporais (`data_entrega < data_pedido`), divergências entre documentos vinculados (`ordem_compra`) e margens negativas.
- **Normalização e Tipagem Estrita no ETL:** Padronização de datas (`DATE`), tipos monetários exatos (`NUMERIC(12,4)`) para evitar erros de arredondamento de ponto flutuante e limpeza de colunas residuais durante a importação.

---

## 3. Lista Completa de Erros Encontrados nos Dados e Consultas de Apoio

Todas as consultas abaixo estão salvas e comentadas no arquivo **`sql/04_validacao.sql`**:

|   #   | Anomalia / Erro Identificado                                                                                                                                                  | Impacto no Negócio                                                                                       | Consulta no `sql/04_validacao.sql`                        |
| :---: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------- |
| **1** | **Vendas de produtos não cadastrados (`P21` a `P28`)** e filiais `2` e `3` ausentes em `produtos_filial`.                                                                     | Relatórios por categoria/descrição ficam incompletos e impossibilitam a baixa automática de estoque.     | Consulta 2 (`LEFT JOIN venda x produtos_filial`)          |
| **2** | **19 pedidos com `data_entrega` anterior à `data_pedido`** (ex.: Pedido 6 emitido em `22/02/2025` com entrega em `05/01/2025`).                                               | Distorce o cálculo de _lead time_ dos fornecedores e indicadores de prazo de entrega.                    | Consulta 3 (`WHERE data_entrega < data_pedido`)           |
| **3** | **9 notas fiscais com `data_entrada` anterior à `data_pedido`** (ex.: `NFE6` entrou em `08/02/2025` para pedido de `22/02/2025`).                                             | Indica lançamento retroativo ou inversão de datas no sistema legado.                                     | Consulta 4 (`WHERE em.data_entrada < pc.data_pedido`)     |
| **4** | **Divergência de quantidades entre `pedido_compra` e `entradas_mercadoria`** nas 18 ordens vinculadas (ex.: `OC 1` teve baixa de `10` un. no pedido, mas `77` un. na `NFE1`). | Risco de pagamento indevido a fornecedores e furo de inventário físico vs. contábil.                     | Consulta 5 (`WHERE pc.qtde_entregue <> em.qtde_recebida`) |
| **5** | **11 pedidos sem ordem de compra (`ordem_compra = 0`)**, sendo os pedidos `21` a `29` cópias parciais dos pedidos `12` a `20` (com colunas deslocadas na planilha original).  | Pode gerar compras em duplicidade ou inflar artificialmente o volume de pendências.                      | Consulta 6 (`WHERE ordem_compra = 0`)                     |
| **6** | **Preços de venda abaixo do custo (`P1`, `P8`, `P15`, `P18`)** e divergência entre `preco_unitario` e `preco_venda` em todo o catálogo.                                       | Venda com prejuízo bruto direto caso o sistema utilize o cadastro de `produtos_filial` para faturamento. | Consulta 7 (`WHERE preco_venda < preco_compra`)           |
