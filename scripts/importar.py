"""
Importação de dados da planilha dados/base_teste.xlsx para PostgreSQL 18.

- Lê as 5 abas respeitando a ordem das FKs
- Trata datas, nulos, colunas extras e duplicidades
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


def ler_aba(nome):
    df = pd.read_excel(XLSX_PATH, sheet_name=nome)
    df = df.dropna(how="all")
    df = df.loc[:, ~df.columns.str.startswith("Unnamed")]
    df = df.dropna(axis=1, how="all")
    df.columns = [str(c).strip().lower() for c in df.columns]
    return df


def importar_fornecedor(cur, df):
    cols = ["idfornecedor", "nome", "cnpj", "telefone", "email", "endereco"]
    df = df.reindex(columns=cols).drop_duplicates(subset=["idfornecedor"])
    execute_values(
        cur,
        "INSERT INTO fornecedor (idfornecedor, nome, cnpj, telefone, email, endereco) "
        "VALUES %s ON CONFLICT (idfornecedor) DO NOTHING",
        df.where(pd.notna(df), None).values.tolist(),
    )
    return len(df)


def importar_produtos_filial(cur, df):
    if "idproduto" in df.columns:
        df = df.rename(columns={"idproduto": "produto_id"})
    cols = ["filial_id", "produto_id", "descricao", "idfornecedor",
            "unidade_medida", "preco_unitario"]
    df = df.reindex(columns=cols)
    df["produto_id"] = df["produto_id"].astype(str)
    df = df.drop_duplicates(subset=["filial_id", "produto_id"])
    execute_values(
        cur,
        "INSERT INTO produtos_filial (filial_id, produto_id, descricao, idfornecedor, "
        "unidade_medida, preco_unitario) VALUES %s "
        "ON CONFLICT (filial_id, produto_id) DO NOTHING",
        df.where(pd.notna(df), None).values.tolist(),
    )
    return len(df)


def importar_pedido_compra(cur, df):
    cols = ["pedido_id", "fornecedor_id", "item", "produto_id",
            "qtde_pedida", "qtde_entregue", "data_pedido", "valor_unitario"]
    df = df.reindex(columns=cols)
    df["produto_id"] = df["produto_id"].astype(str)
    df["data_pedido"] = pd.to_datetime(df["data_pedido"]).dt.date
    df = df.drop_duplicates(subset=["pedido_id", "item"])
    execute_values(
        cur,
        "INSERT INTO pedido_compra (pedido_id, fornecedor_id, item, produto_id, "
        "qtde_pedida, qtde_entregue, data_pedido, valor_unitario) VALUES %s "
        "ON CONFLICT (pedido_id, item) DO NOTHING",
        df.where(pd.notna(df), None).values.tolist(),
    )
    return len(df)


def importar_entradas(cur, df):
    cols = ["filial_id", "fornecedor_id", "produto_id", "item",
            "ordem_compra", "data_entrada", "qtde_entregue", "valor_unitario"]
    df = df.reindex(columns=cols)
    df["produto_id"] = df["produto_id"].astype(str)
    df["data_entrada"] = pd.to_datetime(df["data_entrada"]).dt.date
    df = df.drop_duplicates(
        subset=["filial_id", "fornecedor_id", "produto_id", "item", "ordem_compra"]
    )
    execute_values(
        cur,
        "INSERT INTO entradas_mercadoria (filial_id, fornecedor_id, produto_id, item, "
        "ordem_compra, data_entrada, qtde_entregue, valor_unitario) VALUES %s "
        "ON CONFLICT (filial_id, fornecedor_id, produto_id, item, ordem_compra) DO NOTHING",
        df.where(pd.notna(df), None).values.tolist(),
    )
    return len(df)


def importar_venda(cur, df):
    cols = ["venda_id", "data_emissao", "horariomov", "produto_id",
            "qtde_vendida", "valor_unitario", "filial_id", "item", "unidade_medida"]
    df = df.reindex(columns=cols)
    df["produto_id"] = df["produto_id"].astype(str)
    df["data_emissao"] = pd.to_datetime(df["data_emissao"]).dt.date
    df = df.drop_duplicates(subset=["venda_id"])
    execute_values(
        cur,
        "INSERT INTO venda (venda_id, data_emissao, horariomov, produto_id, "
        "qtde_vendida, valor_unitario, filial_id, item, unidade_medida) VALUES %s "
        "ON CONFLICT (venda_id) DO NOTHING",
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
            df = ler_aba(aba)
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
