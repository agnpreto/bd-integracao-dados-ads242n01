
import os
from datetime import date, datetime, timedelta

import pandas as pd
import psycopg2


ARQUIVO = os.path.join("dados", "base_teste.xlsx")

DB = {
    "host": os.getenv("PGHOST", "localhost"),
    "port": int(os.getenv("PGPORT", "5432")),
    "database": os.getenv("PGDATABASE", "bd_integracao"),
    "user": os.getenv("PGUSER", "postgres"),
    "password": os.getenv("PGPASSWORD", ""),
}


def converter_data(valor):
    if pd.isna(valor):
        return None

    if isinstance(valor, (datetime, pd.Timestamp)):
        return valor.date()

    if isinstance(valor, date):
        return valor

    return (
        datetime(1899, 12, 30) + timedelta(days=float(valor))
    ).date()


def numero(valor, padrao=None):
    if pd.isna(valor):
        return padrao
    return float(valor)


def texto(valor, padrao=None):
    if pd.isna(valor):
        return padrao
    return str(valor).strip()


def importar_tabela(cursor, conexao, nome, dados, comando, converter):
    inseridos = 0

    for indice, linha in dados.iterrows():
        try:
            valores = converter(linha)
            cursor.execute(comando, valores)
            inseridos += cursor.rowcount
            conexao.commit()

        except Exception as erro:
            conexao.rollback()
            print(f"Erro em {nome}, linha {indice + 2}: {erro}")

    print(f"{nome}: {inseridos}/{len(dados)} registros inseridos.")


def importar():
    if not os.path.isfile(ARQUIVO):
        raise FileNotFoundError(f"Arquivo não encontrado: {ARQUIVO}")

    planilha = pd.ExcelFile(ARQUIVO)

    abas = [
        "fornecedor",
        "produtos_filial",
        "pedido_compra",
        "entradas_mercadoria",
        "venda",
    ]

    ausentes = [aba for aba in abas if aba not in planilha.sheet_names]

    if ausentes:
        raise ValueError(f"Abas ausentes na planilha: {ausentes}")

    print("Abas encontradas:", planilha.sheet_names)
    print("Conectando ao PostgreSQL...")

    conexao = psycopg2.connect(**DB)

    try:
        with conexao.cursor() as cursor:

            # 1. FORNECEDOR
            df = pd.read_excel(ARQUIVO, sheet_name="fornecedor")
            df.columns = df.columns.str.strip()

            importar_tabela(
                cursor, conexao, "fornecedor", df,
                """
                INSERT INTO fornecedor (idfornecedor, razao_social)
                VALUES (%s, %s)
                ON CONFLICT (idfornecedor) DO NOTHING
                """,
                lambda r: (
                    texto(r["idfornecedor"]),
                    texto(r["razao_social"], "")
                )
            )

            # 2. PRODUTOS_FILIAL
            df = pd.read_excel(ARQUIVO, sheet_name="produtos_filial")
            df.columns = df.columns.str.strip()

            importar_tabela(
                cursor, conexao, "produtos_filial", df,
                """
                INSERT INTO produtos_filial (
                    filial_id, produto_id, descricao, estoque,
                    preco_unitario, preco_compra, preco_venda, idfornecedor
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (filial_id, produto_id) DO NOTHING
                """,
                lambda r: (
                    int(r["filial_id"]),
                    texto(r["idproduto"]),
                    texto(r["descricao"], ""),
                    numero(r["estoque"], 0),
                    numero(r["preco_unitario"], 0),
                    numero(r["preco_compra"], 0),
                    numero(r["preco_venda"], 0),
                    texto(r["idfornecedor"])
                )
            )

            # 3. PEDIDO_COMPRA
            df = pd.read_excel(ARQUIVO, sheet_name="pedido_compra")
            df = df.iloc[:, :12]
            df.columns = [
                "pedido_id", "data_pedido", "item", "produto_id",
                "descricao_produto", "ordem_compra", "qtde_pedida",
                "filial_id", "data_entrega", "qtde_entregue",
                "preco_compra", "fornecedor_id"
            ]

            importar_tabela(
                cursor, conexao, "pedido_compra", df,
                """
                INSERT INTO pedido_compra (
                    pedido_id, data_pedido, item, produto_id,
                    descricao_produto, ordem_compra, qtde_pedida,
                    filial_id, data_entrega, qtde_entregue,
                    qtde_pendente, preco_compra, fornecedor_id
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s, %s)
                ON CONFLICT (pedido_id, produto_id, item) DO NOTHING
                """,
                lambda r: (
                    numero(r["pedido_id"], 0),
                    converter_data(r["data_pedido"]),
                    numero(r["item"], 0),
                    texto(r["produto_id"], "0"),
                    texto(r["descricao_produto"]),
                    numero(r["ordem_compra"], 0),
                    numero(r["qtde_pedida"]),
                    int(r["filial_id"]) if pd.notna(r["filial_id"]) else None,
                    converter_data(r["data_entrega"]),
                    numero(r["qtde_entregue"], 0),
                    (
                        numero(r["qtde_pedida"], 0)
                        - numero(r["qtde_entregue"], 0)
                    ),
                    numero(r["preco_compra"], 0),
                    int(r["fornecedor_id"])
                    if pd.notna(r["fornecedor_id"]) else None
                )
            )

            # 4. ENTRADAS_MERCADORIA
            df = pd.read_excel(ARQUIVO, sheet_name="entradas_mercadoria")
            df.columns = df.columns.str.strip()

            importar_tabela(
                cursor, conexao, "entradas_mercadoria", df,
                """
                INSERT INTO entradas_mercadoria (
                    data_entrada, nro_nfe, item, produto_id,
                    descricao_produto, ordem_compra, qtde_recebida,
                    filial_id, custo_unitario
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (
                    ordem_compra, item, produto_id, nro_nfe
                ) DO NOTHING
                """,
                lambda r: (
                    converter_data(r["data_entrada"]),
                    texto(r["nro_nfe"]),
                    numero(r["item"], 0),
                    texto(r["produto_id"], "0"),
                    texto(r["descricao_produto"]),
                    numero(r["ordem_compra"], 0),
                    numero(r["qtde_recebida"]),
                    int(r["filial_id"]) if pd.notna(r["filial_id"]) else None,
                    numero(r["custo_unitario"], 0)
                )
            )

            # 5. VENDA
            df = pd.read_excel(ARQUIVO, sheet_name="venda")
            df.columns = df.columns.str.strip()

            importar_tabela(
                cursor, conexao, "venda", df,
                """
                INSERT INTO venda (
                    venda_id, data_emissao, horariomov, produto_id,
                    qtde_vendida, valor_unitario, filial_id, item,
                    unidade_medida
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (
                    filial_id, venda_id, data_emissao,
                    produto_id, item, horariomov
                ) DO NOTHING
                """,
                lambda r: (
                    int(r["venda_id"]),
                    converter_data(r["data_emissao"]),
                    texto(r["horariomov"], "00:00:00"),
                    texto(r["produto_id"], ""),
                    numero(r["qtde_vendida"]),
                    numero(r["valor_unitario"], 0),
                    int(r["filial_id"]) if pd.notna(r["filial_id"]) else 1,
                    int(r["item"]) if pd.notna(r["item"]) else 0,
                    texto(r["unidade_medida"])
                )
            )

        print("\nImportação finalizada.")
        print("Confira as contagens no banco antes de considerar concluída.")

    finally:
        conexao.close()


if __name__ == "__main__":
    importar()
