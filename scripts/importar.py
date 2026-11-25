import os
from pathlib import Path
from datetime import datetime, timedelta
from numbers import Real
import pandas as pd
import psycopg2
from psycopg2 import sql

ARQUIVO = Path(__file__).resolve().parents[1] / "dados" / "base_teste.xlsx"
DB = dict(host="localhost", port=5432, database="integracao_dados",
          user="postgres", password=os.environ["DB_PASSWORD"])

def excel_para_data(valor):
    if pd.isna(valor):
        return None
    if isinstance(valor, Real):
        return (datetime(1899, 12, 30) + timedelta(days=float(valor))).date()
    if isinstance(valor, datetime):
        return valor.date()
    return pd.to_datetime(valor, dayfirst=True, errors="raise").date()

def texto(v):
    return None if pd.isna(v) else str(v).strip()

def fornecedor(v):
    if pd.isna(v):
        return None
    if isinstance(v, Real) and float(v).is_integer():
        return f"F{int(v)}"
    return texto(v)

CONFIG = {
    "fornecedor": ("idfornecedor razao_social", "idfornecedor"),
    "produtos_filial": ("filial_id produto_id descricao estoque preco_unitario preco_compra preco_venda idfornecedor", "filial_id produto_id"),
    "pedido_compra": ("pedido_id data_pedido item produto_id descricao_produto ordem_compra qtde_pedida filial_id data_entrega qtde_entregue qtde_pendente preco_compra fornecedor_id", "pedido_id produto_id item"),
    "entradas_mercadoria": ("data_entrada nro_nfe item produto_id descricao_produto ordem_compra qtde_recebida filial_id custo_unitario", "ordem_compra item produto_id nro_nfe"),
    "venda": ("venda_id data_emissao horariomov produto_id qtde_vendida valor_unitario filial_id item unidade_medida", "filial_id venda_id data_emissao produto_id item horariomov"),
}
DATAS = {"data_pedido", "data_entrega", "data_entrada", "data_emissao"}
INTEIROS = {"filial_id", "venda_id", "pedido_id", "item", "ordem_compra"}
NUMEROS = {"estoque", "preco_unitario", "preco_compra", "preco_venda",
           "qtde_pedida", "qtde_entregue", "qtde_pendente", "qtde_recebida",
           "custo_unitario", "qtde_vendida", "valor_unitario"}

def preparar(tabela, df):
    df = df.copy()
    df.columns = df.columns.str.strip()
    if tabela == "produtos_filial":
        df = df.rename(columns={"idproduto": "produto_id"})
    if tabela == "pedido_compra":
        extras = [c for c in df.columns if c.startswith("Unnamed:")]
        if extras:
            afetados = df[extras].notna().any(axis=1)
            print("Pedidos com colunas sem cabecalho:", df.loc[afetados, "pedido_id"].tolist())
            print("Valores adicionais preservados na planilha original; requerem validacao.")
        df["qtde_pendente"] = df["qtde_pedida"] - df["qtde_entregue"]
    return df

def converter(coluna, valor):
    if pd.isna(valor):
        return None
    if coluna in DATAS:
        return excel_para_data(valor)
    if coluna in {"idfornecedor", "fornecedor_id"}:
        return fornecedor(valor)
    if coluna in INTEIROS:
        if not float(valor).is_integer():
            raise ValueError(f"Identificador nao inteiro: {coluna}={valor}")
        return int(valor)
    if coluna in NUMEROS:
        return float(valor)
    return texto(valor)

def importar(conn, tabela, df):
    df = preparar(tabela, df)
    campos, chaves = (x.split() for x in CONFIG[tabela])
    faltantes = set(campos) - set(df.columns)
    if faltantes:
        raise ValueError(f"{tabela}: colunas ausentes: {faltantes}")
    comando = sql.SQL("INSERT INTO public.{} ({}) VALUES ({}) ON CONFLICT ({}) DO NOTHING").format(
        sql.Identifier(tabela),
        sql.SQL(", ").join(map(sql.Identifier, campos)),
        sql.SQL(", ").join(sql.Placeholder() for _ in campos),
        sql.SQL(", ").join(map(sql.Identifier, chaves)))
    inseridos = conflitos = erros = 0
    with conn.cursor() as cur:
        for indice, row in df.iterrows():
            cur.execute("SAVEPOINT registro")
            try:
                valores = tuple(converter(c, row[c]) for c in campos)
                cur.execute(comando, valores)
                if cur.rowcount == 1:
                    inseridos += 1
                else:
                    conflitos += 1
                    print(f"{tabela}: conflito na linha Excel {indice + 2}")
            except Exception as e:
                cur.execute("ROLLBACK TO SAVEPOINT registro")
                erros += 1
                print(f"{tabela}: erro na linha Excel {indice + 2}: {e}")
            finally:
                cur.execute("RELEASE SAVEPOINT registro")
    conn.commit()
    return len(df), inseridos, conflitos, erros

def main():
    abas = pd.read_excel(ARQUIVO, sheet_name=None)
    conn = psycopg2.connect(**DB)
    resultados = {}
    try:
        for tabela in CONFIG:
            resultados[tabela] = importar(conn, tabela, abas[tabela])
        print(f"{'Tabela':23} {'Planilha':>8} {'Inseridos':>10} {'Conflitos':>10} {'Erros':>6}")
        for tabela, valores in resultados.items():
            print(f"{tabela:23}" + "".join(f"{v:10}" for v in valores))
        totais = [sum(v[i] for v in resultados.values()) for i in range(4)]
        print(f"{'TOTAL':23}" + "".join(f"{v:10}" for v in totais))
        print("Importacao com erros." if totais[3] else
              "Importacao com conflitos." if totais[2] else
              "Importacao concluida sem erros de insercao.")
    finally:
        conn.close()

if __name__ == "__main__":
    main()
