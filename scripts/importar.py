import os
import re
from datetime import datetime, timedelta
import pandas as pd
import psycopg2

# ── Configurações (sem senha real hardcoded) ───────────────
ARQUIVO = os.getenv("ARQUIVO_PLANILHA", "dados/base_teste.xlsx")
DB = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "database": os.getenv("DB_NAME", "postgres"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "SUA_SENHA_AQUI"),
}


def converter_data(valor):
    if pd.isna(valor):
        return None
    if isinstance(valor, (datetime, pd.Timestamp)):
        return valor.date()
    try:
        return (datetime(1899, 12, 30) + timedelta(days=int(float(valor)))).date()
    except Exception:
        parsed = pd.to_datetime(valor, errors="coerce")
        return None if pd.isna(parsed) else parsed.date()


def extrair_numero_fornecedor(valor):
    if pd.isna(valor):
        return None
    match = re.search(r"(\d+)", str(valor))
    return int(match.group(1)) if match else None


def conectar():
    print("Conectando no PostgreSQL...")
    conn = psycopg2.connect(**DB)
    print("Conectado!\n")
    return conn


def importar_tudo():
    conn = conectar()
    cur = conn.cursor()

    try:
        # 1. FORNECEDOR (20 linhas)
        print("Importando fornecedor...")
        df_forn = pd.read_excel(ARQUIVO, sheet_name="fornecedor")
        df_forn.columns = df_forn.columns.str.strip()
        ins_forn = 0
        for _, row in df_forn.iterrows():
            id_forn = str(row["idfornecedor"]).strip()
            id_num = extrair_numero_fornecedor(id_forn)
            razao = str(row["razao_social"]).strip()
            cur.execute(
                """
                INSERT INTO public.fornecedor (idfornecedor, idfornecedor_num, razao_social)
                VALUES (%s, %s, %s)
                ON CONFLICT (idfornecedor) DO UPDATE
                SET idfornecedor_num = EXCLUDED.idfornecedor_num,
                    razao_social = EXCLUDED.razao_social
                """,
                (id_forn, id_num, razao),
            )
            ins_forn += 1
        conn.commit()
        print(f"  {ins_forn} registros processados em fornecedor\n")

        # 2. PRODUTOS_FILIAL (20 linhas; na planilha a coluna vem como 'idproduto')
        print("Importando produtos_filial...")
        df_prod = pd.read_excel(ARQUIVO, sheet_name="produtos_filial")
        df_prod.columns = df_prod.columns.str.strip()
        ins_prod = 0
        for _, row in df_prod.iterrows():
            id_forn = str(row["idfornecedor"]).strip() if pd.notna(row["idfornecedor"]) else None
            id_num = extrair_numero_fornecedor(id_forn)
            cur.execute(
                """
                INSERT INTO public.produtos_filial
                    (filial_id, produto_id, descricao, estoque,
                     preco_unitario, preco_compra, preco_venda, idfornecedor, idfornecedor_num)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (filial_id, produto_id) DO NOTHING
                """,
                (
                    int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
                    str(row["idproduto"]).strip(),
                    str(row["descricao"]).strip(),
                    float(row["estoque"]) if pd.notna(row["estoque"]) else 0.0,
                    float(row["preco_unitario"]) if pd.notna(row["preco_unitario"]) else 0.0,
                    float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0.0,
                    float(row["preco_venda"]) if pd.notna(row["preco_venda"]) else 0.0,
                    id_forn,
                    id_num,
                ),
            )
            ins_prod += 1
        conn.commit()
        print(f"  {ins_prod} registros processados em produtos_filial\n")

        # 3. PEDIDO_COMPRA (29 linhas; ignora colunas extras Unnamed: 12..22)
        print("Importando pedido_compra...")
        df_pc = pd.read_excel(ARQUIVO, sheet_name="pedido_compra")
        df_pc = df_pc.iloc[:, :12].copy()
        df_pc.columns = [
            "pedido_id", "data_pedido", "item", "produto_id", "descricao_produto",
            "ordem_compra", "qtde_pedida", "filial_id", "data_entrega",
            "qtde_entregue", "preco_compra", "fornecedor_id",
        ]
        ins_pc = 0
        for _, row in df_pc.iterrows():
            qtde_ped = float(row["qtde_pedida"]) if pd.notna(row["qtde_pedida"]) else 0.0
            qtde_ent = float(row["qtde_entregue"]) if pd.notna(row["qtde_entregue"]) else 0.0
            cur.execute(
                """
                INSERT INTO public.pedido_compra
                    (pedido_id, data_pedido, item, produto_id, descricao_produto,
                     ordem_compra, qtde_pedida, filial_id, data_entrega,
                     qtde_entregue, qtde_pendente, preco_compra, fornecedor_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (pedido_id, produto_id, item) DO NOTHING
                """,
                (
                    float(row["pedido_id"]),
                    converter_data(row["data_pedido"]),
                    float(row["item"]),
                    str(row["produto_id"]).strip(),
                    str(row["descricao_produto"]).strip() if pd.notna(row["descricao_produto"]) else None,
                    float(row["ordem_compra"]) if pd.notna(row["ordem_compra"]) else 0.0,
                    qtde_ped,
                    int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
                    converter_data(row["data_entrega"]),
                    qtde_ent,
                    max(qtde_ped - qtde_ent, 0.0),
                    float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0.0,
                    int(row["fornecedor_id"]) if pd.notna(row["fornecedor_id"]) else None,
                ),
            )
            ins_pc += 1
        conn.commit()
        print(f"  {ins_pc} registros processados em pedido_compra\n")

        # 4. ENTRADAS_MERCADORIA (20 linhas)
        print("Importando entradas_mercadoria...")
        df_em = pd.read_excel(ARQUIVO, sheet_name="entradas_mercadoria")
        df_em.columns = df_em.columns.str.strip()
        ins_em = 0
        for _, row in df_em.iterrows():
            cur.execute(
                """
                INSERT INTO public.entradas_mercadoria
                    (ordem_compra, data_entrada, nro_nfe, item, produto_id,
                     descricao_produto, qtde_recebida, filial_id, custo_unitario)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (ordem_compra, item, produto_id, nro_nfe) DO NOTHING
                """,
                (
                    float(row["ordem_compra"]) if pd.notna(row["ordem_compra"]) else 0.0,
                    converter_data(row["data_entrada"]),
                    str(row["nro_nfe"]).strip(),
                    float(row["item"]),
                    str(row["produto_id"]).strip(),
                    str(row["descricao_produto"]).strip() if pd.notna(row["descricao_produto"]) else None,
                    float(row["qtde_recebida"]) if pd.notna(row["qtde_recebida"]) else 0.0,
                    int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
                    float(row["custo_unitario"]) if pd.notna(row["custo_unitario"]) else 0.0,
                ),
            )
            ins_em += 1
        conn.commit()
        print(f"  {ins_em} registros processados em entradas_mercadoria\n")

        # 5. VENDA (33 linhas)
        print("Importando venda...")
        df_venda = pd.read_excel(ARQUIVO, sheet_name="venda")
        df_venda.columns = df_venda.columns.str.strip()
        ins_venda = 0
        for _, row in df_venda.iterrows():
            cur.execute(
                """
                INSERT INTO public.venda
                    (venda_id, data_emissao, horariomov, produto_id,
                     qtde_vendida, valor_unitario, filial_id, item, unidade_medida)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (filial_id, venda_id, data_emissao, produto_id, item, horariomov) DO NOTHING
                """,
                (
                    int(row["venda_id"]),
                    converter_data(row["data_emissao"]),
                    str(row["horariomov"]).strip() if pd.notna(row["horariomov"]) else "00:00:00",
                    str(row["produto_id"]).strip(),
                    float(row["qtde_vendida"]) if pd.notna(row["qtde_vendida"]) else 0.0,
                    float(row["valor_unitario"]) if pd.notna(row["valor_unitario"]) else 0.0,
                    int(row["filial_id"]) if pd.notna(row["filial_id"]) else 1,
                    int(row["item"]) if pd.notna(row["item"]) else 0,
                    str(row["unidade_medida"]).strip() if pd.notna(row["unidade_medida"]) else None,
                ),
            )
            ins_venda += 1
        conn.commit()
        print(f"  {ins_venda} registros processados em venda\n")

        print("=" * 40)
        print("Importação concluída com sucesso!")
        print("=" * 40)
    except Exception as erro:
        conn.rollback()
        print(f"Erro na importação: {erro}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    importar_tudo()
