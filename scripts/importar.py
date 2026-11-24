"""
Importação de dados da planilha dados/base_teste.xlsx para PostgreSQL 18.

- Lê as 5 abas (venda, pedido_compra, entradas_mercadoria, produtos_filial, fornecedor)
- Trata datas, horários, vírgula decimal, colunas extras e duplicidades
- Converte fornecedor_id numérico (1-20) para o formato F1-F20 de fornecedor
- Executa em transação única com COMMIT/ROLLBACK
- Credenciais via variáveis de ambiente
"""
import os
import sys
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", "5432")),
    "dbname":   os.getenv("DB_NAME", "bd_integracao"),
    "user":     os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
}

XLSX_PATH = os.path.join("dados", "base_teste.xlsx")


def limpar_df(df):
    df = df.dropna(how="all")
    df = df.loc[:, ~df.columns.str.startswith("Unnamed")]
    df = df.dropna(axis=1, how="all")
    df.columns = [str(c).strip().lower() for c in df.columns]
    return df


def _to_date(v):
    return pd.to_datetime(v).date() if pd.notna(v) else None


def _to_time_str(v):
    if pd.isna(v):
        return None
    s = str(v).strip()
    if " " in s:
        s = s.split(" ")[-1]
    return s


def _to_float(v):
    if pd.isna(v):
        return None
    return float(str(v).replace(",", "."))


def _num_to_f(v):
    if pd.isna(v):
        return None
    s = str(v).strip()
    if s.upper().startswith("F"):
        return s.upper()
    try:
        return f"F{int(float(s))}"
    except ValueError:
        return s


# --------------------------------------------------------------
# Importadores por tabela
# --------------------------------------------------------------
def importar_fornecedor(cur, df):
    df = df.reindex(columns=["idfornecedor", "razao_social"])
    df["idfornecedor"] = df["idfornecedor"].astype(str)
    df = df.drop_duplicates(subset=["idfornecedor"])
    df = df[df["idfornecedor"].notna()]
    execute_values(
        cur,
        "INSERT INTO fornecedor (idfornecedor, razao_social) VALUES %s "
        "ON CONFLICT (idfornecedor) DO NOTHING",
        df.where(pd.notna(df), None).values.tolist(),
    )
    return len(df)


def importar_produtos_filial(cur, df):
    if "idproduto" in df.columns:
        df = df.rename(columns={"idproduto": "produto_id"})
    cols = ["filial_id", "produto_id", "descricao", "estoque",
            "preco_unitario", "preco_compra", "preco_venda", "idfornecedor"]
    df = df.reindex(columns=cols)
    df["produto_id"] = df["produto_id"].astype(str)
    df["idfornecedor"] = df["idfornecedor"].apply(_num_to_f)
    for c in ["preco_unitario", "preco_compra", "preco_venda"]:
        df[c] = df[c].apply(_to_float)
    df = df.drop_duplicates(subset=["filial_id", "produto_id"])
    execute_values(
        cur,
        "INSERT INTO produtos_filial (filial_id, produto_id, descricao, estoque, "
        "preco_unitario, preco_compra, preco_venda, idfornecedor) VALUES %s "
        "ON CONFLICT (filial_id, produto_id) DO NOTHING",
        df.where(pd.notna(df), None).values.tolist(),
    )
    return len(df)


def importar_pedido_compra(cur, df):
    cols = ["pedido_id", "item", "data_pedido", "produto_id",
            "descricao_produto", "ordem_compra", "qtde_pedida",
            "filial_id", "data_entrega", "qtde_entregue",
            "preco_compra", "fornecedor_id"]
    df = df.reindex(columns=cols)
    df["produto_id"] = df["produto_id"].astype(str)
    df["data_pedido"] = df["data_pedido"].apply(_to_date)
    df["data_entrega"] = df["data_entrega"].apply(_to_date)
    df["preco_compra"] = df["preco_compra"].apply(_to_float)
    df["fornecedor_id"] = df["fornecedor_id"].apply(_num_to_f)
    df = df.drop_duplicates(subset=["pedido_id", "item"])
    execute_values(
        cur,
        "INSERT INTO pedido_compra (pedido_id, item, data_pedido, produto_id, "
        "descricao_produto, ordem_compra, qtde_pedida, filial_id, data_entrega, "
        "qtde_entregue, preco_compra, fornecedor_id) VALUES %s "
        "ON CONFLICT (pedido_id, item) DO NOTHING",
        df.where(pd.notna(df), None).values.tolist(),
    )
    return len(df)


def importar_entradas(cur, df):
    cols = ["nro_nfe", "item", "data_entrada", "produto_id",
            "descricao_produto", "ordem_compra", "qtde_recebida",
            "filial_id", "custo_unitario"]
    df = df.reindex(columns=cols)
    df["nro_nfe"] = df["nro_nfe"].astype(str)
    df["produto_id"] = df["produto_id"].astype(str)
    df["data_entrada"] = df["data_entrada"].apply(_to_date)
    df["custo_unitario"] = df["custo_unitario"].apply(_to_float)
    df = df.drop_duplicates(subset=["nro_nfe", "item"])
    execute_values(
        cur,
        "INSERT INTO entradas_mercadoria (nro_nfe, item, data_entrada, produto_id, "
        "descricao_produto, ordem_compra, qtde_recebida, filial_id, custo_unitario) "
        "VALUES %s ON CONFLICT (nro_nfe, item) DO NOTHING",
        df.where(pd.notna(df), None).values.tolist(),
    )
    return len(df)


def importar_venda(cur, df):
    cols = ["venda_id", "data_emissao", "horariomov", "produto_id",
            "qtde_vendida", "valor_unitario", "filial_id", "item", "unidade_medida"]
    df = df.reindex(columns=cols)
    df["produto_id"] = df["produto_id"].astype(str)
    df["data_emissao"] = df["data_emissao"].apply(_to_date)
    df["horariomov"] = df["horariomov"].apply(_to_time_str)
    df["valor_unitario"] = df["valor_unitario"].apply(_to_float)
    df = df.drop_duplicates(subset=["venda_id"])
    execute_values(
        cur,
        "INSERT INTO venda (venda_id, data_emissao, horariomov, produto_id, "
        "qtde_vendida, valor_unitario, filial_id, item, unidade_medida) "
        "VALUES %s ON CONFLICT (venda_id) DO NOTHING",
        df.where(pd.notna(df), None).values.tolist(),
    )
    return len(df)


def main():
    if not os.path.exists(XLSX_PATH):
        sys.exit(f"Arquivo não encontrado: {XLSX_PATH}")

    abas = pd.ExcelFile(XLSX_PATH).sheet_names
    print("Abas encontradas:", abas)

    ordem = [
        ("fornecedor",          importar_fornecedor),
        ("produtos_filial",     importar_produtos_filial),
        ("pedido_compra",       importar_pedido_compra),
        ("entradas_mercadoria", importar_entradas),
        ("venda",               importar_venda),
    ]

    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False
    cur = conn.cursor()

    try:
        totais = {}
        for aba, func in ordem:
            if aba not in abas:
                print(f"[!] aba '{aba}' ausente — pulando")
                totais[aba] = 0
                continue
            df = limpar_df(pd.read_excel(XLSX_PATH, sheet_name=aba))
            n = func(cur, df)
            totais[aba] = n
            print(f"[ok] {aba}: {n} registros")

        conn.commit()
        print("\nImportação concluída.")
        for k, v in totais.items():
            print(f"  {k:22s} {v}")
    except Exception as e:
        conn.rollback()
        print("ERRO — rollback executado:", e)
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
