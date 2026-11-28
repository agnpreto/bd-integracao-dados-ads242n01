import os
import re
import pandas as pd
import psycopg2
from datetime import datetime, timedelta

# ── Configurações (sem senha hardcoded) ────────────────────
ARQUIVO = "dados/base_teste.xlsx"
DB = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 5432)),
    "database": os.getenv("DB_NAME", "postgres"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "sua_senha_aqui")
}

# ── Converte Timestamp, string ou serial do Excel para date ─
def excel_para_data(valor):
    try:
        if pd.isna(valor):
            return None
        if isinstance(valor, (pd.Timestamp, datetime)):
            return valor.date()
        if isinstance(valor, str):
            for fmt in ("%Y-%m-%d", "%d/%m/%Y"):
                try:
                    return datetime.strptime(valor.strip(), fmt).date()
                except ValueError:
                    continue
        return (datetime(1899, 12, 30) + timedelta(days=int(float(valor)))).date()
    except Exception:
        return None

# ── Extrai ID numérico de strings como 'F8' -> 8 ───────────
def limpar_id_numerico(valor):
    if pd.isna(valor):
        return None
    digitos = re.sub(r"\D", "", str(valor))
    return int(digitos) if digitos else None

# ── Conecta no banco ───────────────────────────────────────
print("Conectando no PostgreSQL...")
conn = psycopg2.connect(**DB)
cur = conn.cursor()
print("Conectado!\n")

# 1. FORNECEDOR
print("Importando fornecedor...")
df = pd.read_excel(ARQUIVO, sheet_name="fornecedor")
df.columns = df.columns.str.strip()

inseridos = 0
for idx, row in df.iterrows():
    try:
        cur.execute("""
            INSERT INTO public.fornecedor (idfornecedor, razao_social)
            VALUES (%s, %s)
            ON CONFLICT (idfornecedor) DO NOTHING
        """, (
            limpar_id_numerico(row["idfornecedor"]),
            str(row["razao_social"]).strip()
        ))
        inseridos += cur.rowcount
    except Exception as e:
        print(f"  Erro fornecedor linha {idx}: {e}")
        conn.rollback()

conn.commit()
print(f"  Planilha: {len(df)} | Inseridos: {inseridos}\n")

# 2. PRODUTOS_FILIAL
print("Importando produtos_filial...")
df = pd.read_excel(ARQUIVO, sheet_name="produtos_filial")
df.columns = df.columns.str.strip()

inseridos = 0
for idx, row in df.iterrows():
    try:
        cur.execute("""
            INSERT INTO public.produtos_filial
                (filial_id, produto_id, descricao, estoque,
                 preco_unitario, preco_compra, preco_venda, idfornecedor)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (filial_id, produto_id) DO NOTHING
        """, (
            int(row["filial_id"]) if pd.notna(row["filial_id"]) else 1,
            str(row["idproduto"]).strip(),
            str(row["descricao"]).strip(),
            float(row["estoque"]) if pd.notna(row["estoque"]) else 0,
            float(row["preco_unitario"]) if pd.notna(row["preco_unitario"]) else 0,
            float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0,
            float(row["preco_venda"]) if pd.notna(row["preco_venda"]) else 0,
            limpar_id_numerico(row["idfornecedor"])
        ))
        inseridos += cur.rowcount
    except Exception as e:
        print(f"  Erro produtos_filial linha {idx}: {e}")
        conn.rollback()

conn.commit()
print(f"  Planilha: {len(df)} | Inseridos: {inseridos}\n")

# 3. PEDIDO_COMPRA
print("Importando pedido_compra...")
df = pd.read_excel(ARQUIVO, sheet_name="pedido_compra")
df.columns = df.columns.str.strip()
df = df.iloc[:, :12]  # Descarta colunas Unnamed: 12..22 com lixo deslocado
df.columns = [
    "pedido_id", "data_pedido", "item", "produto_id", "descricao_produto",
    "ordem_compra", "qtde_pedida", "filial_id", "data_entrega",
    "qtde_entregue", "preco_compra", "fornecedor_id"
]

inseridos = 0
for idx, row in df.iterrows():
    try:
        qtde_pedida = float(row["qtde_pedida"]) if pd.notna(row["qtde_pedida"]) else 0
        qtde_entregue = float(row["qtde_entregue"]) if pd.notna(row["qtde_entregue"]) else 0
        qtde_pendente = qtde_pedida - qtde_entregue

        cur.execute("""
            INSERT INTO public.pedido_compra
                (pedido_id, data_pedido, item, produto_id, descricao_produto,
                 ordem_compra, qtde_pedida, filial_id, data_entrega,
                 qtde_entregue, qtde_pendente, preco_compra, fornecedor_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (pedido_id, produto_id, item) DO NOTHING
        """, (
            int(row["pedido_id"]),
            excel_para_data(row["data_pedido"]),
            int(row["item"]),
            str(row["produto_id"]).strip(),
            str(row["descricao_produto"]).strip() if pd.notna(row["descricao_produto"]) else None,
            int(row["ordem_compra"]) if pd.notna(row["ordem_compra"]) else 0,
            qtde_pedida,
            int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
            excel_para_data(row["data_entrega"]),
            qtde_entregue,
            qtde_pendente,
            float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0,
            limpar_id_numerico(row["fornecedor_id"])
        ))
        inseridos += cur.rowcount
    except Exception as e:
        print(f"  Erro pedido_compra linha {idx}: {e}")
        conn.rollback()

conn.commit()
print(f"  Planilha: {len(df)} | Inseridos: {inseridos}\n")

# 4. ENTRADAS_MERCADORIA
print("Importando entradas_mercadoria...")
df = pd.read_excel(ARQUIVO, sheet_name="entradas_mercadoria")
df.columns = df.columns.str.strip()

inseridos = 0
for idx, row in df.iterrows():
    try:
        cur.execute("""
            INSERT INTO public.entradas_mercadoria
                (data_entrada, nro_nfe, item, produto_id, descricao_produto,
                 ordem_compra, qtde_recebida, filial_id, custo_unitario)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (ordem_compra, item, produto_id, nro_nfe) DO NOTHING
        """, (
            excel_para_data(row["data_entrada"]),
            str(row["nro_nfe"]).strip(),
            int(row["item"]),
            str(row["produto_id"]).strip(),
            str(row["descricao_produto"]).strip() if pd.notna(row["descricao_produto"]) else None,
            int(row["ordem_compra"]) if pd.notna(row["ordem_compra"]) else 0,
            float(row["qtde_recebida"]) if pd.notna(row["qtde_recebida"]) else None,
            int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
            float(row["custo_unitario"]) if pd.notna(row["custo_unitario"]) else 0
        ))
        inseridos += cur.rowcount
    except Exception as e:
        print(f"  Erro entradas_mercadoria linha {idx}: {e}")
        conn.rollback()

conn.commit()
print(f"  Planilha: {len(df)} | Inseridos: {inseridos}\n")

# 5. VENDA
print("Importando venda...")
df = pd.read_excel(ARQUIVO, sheet_name="venda")
df.columns = df.columns.str.strip()

inseridos = 0
for idx, row in df.iterrows():
    try:
        cur.execute("""
            INSERT INTO public.venda
                (venda_id, data_emissao, horariomov, produto_id,
                 qtde_vendida, valor_unitario, filial_id, item, unidade_medida)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (filial_id, venda_id, data_emissao, produto_id, item, horariomov) DO NOTHING
        """, (
            int(row["venda_id"]),
            excel_para_data(row["data_emissao"]),
            str(row["horariomov"]).strip() if pd.notna(row["horariomov"]) else "00:00:00",
            str(row["produto_id"]).strip(),
            float(row["qtde_vendida"]) if pd.notna(row["qtde_vendida"]) else None,
            float(row["valor_unitario"]) if pd.notna(row["valor_unitario"]) else 0,
            int(row["filial_id"]) if pd.notna(row["filial_id"]) else 1,
            int(row["item"]) if pd.notna(row["item"]) else 0,
            str(row["unidade_medida"]).strip() if pd.notna(row["unidade_medida"]) else None
        ))
        inseridos += cur.rowcount
    except Exception as e:
        print(f"  Erro venda linha {idx}: {e}")
        conn.rollback()

conn.commit()
print(f"  Planilha: {len(df)} | Inseridos: {inseridos}\n")

cur.close()
conn.close()
print("=" * 40)
print("Importação concluída com sucesso!")
print("=" * 40)