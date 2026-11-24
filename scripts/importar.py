import os
from datetime import datetime, date, time, timedelta
from decimal import Decimal, InvalidOperation

import pandas as pd
import psycopg2

# ── Configurações ──────────────────────────────────────────
ARQUIVO = os.environ.get("ARQUIVO_XLSX", "dados/base_teste.xlsx")  #trocar caminho do dataset dos Senhores
# Credenciais via variável de ambiente. O valor "1234" é apenas exemplo local;
# NUNCA commite a senha real. Ex.: set PGPASSWORD=suasenha
DB = {
    "host": os.environ.get("PGHOST", "localhost"),      #de acordo com o host do SGBD dos Senhores
    "port": int(os.environ.get("PGPORT", "5432")),      #porta padrão do PostgreSQL (MySQL: 3306)
    "database": os.environ.get("PGDATABASE", "postgres"),  #nome da data base dos Senhores
    "user": os.environ.get("PGUSER", "postgres"),       #utilizador dos senhores
    "password": os.environ.get("PGPASSWORD", "1234"),   #senha do utilizador (variável de ambiente)
}


# ── Conversores tolerantes a dados sujos ───────────────────

def vazio(valor):
    """True para None, NaN, NaT e string vazia."""
    if valor is None:
        return True
    if isinstance(valor, str):
        return valor.strip() == ""
    try:
        return bool(pd.isna(valor))
    except (TypeError, ValueError):
        return False


def excel_para_data(valor):
    """Converte serial do Excel, Timestamp, datetime ou texto para date.

    Corrige o bug original: int(Timestamp) lançava exceção e o except devolvia
    None, zerando TODAS as datas. Agora cada tipo é tratado explicitamente.
    """
    if vazio(valor):
        return None
    if isinstance(valor, datetime):
        return valor.date()
    if isinstance(valor, date):
        return valor
    if isinstance(valor, pd.Timestamp):
        return valor.date()
    if isinstance(valor, (int, float)):
        try:
            return (datetime(1899, 12, 30) + timedelta(days=float(valor))).date()
        except (OverflowError, ValueError):
            return None
    texto = str(valor).strip()
    # Formatos: AAAA-MM-DD, DD/MM/AAAA e M/D/AAAA (padrão americano do arquivo).
    for formato in ("%Y-%m-%d", "%d/%m/%Y", "%Y/%m/%d", "%d-%m-%Y"):
        try:
            return datetime.strptime(texto[:10], formato).date()
        except ValueError:
            pass
    partes = texto.replace("-", "/").split("/")
    if len(partes) == 3 and all(p.isdigit() for p in partes):
        a, b, c = (int(p) for p in partes)
        if len(partes[0]) == 4:          # AAAA/M/D
            return date(a, b, c)
        if a > 12:                        # D/M/AAAA
            return date(c, b, a)
        return date(c, a, b)              # M/D/AAAA (padrão da planilha)
    return None


def converter_decimal(valor):
    """Converte número ou texto com vírgula decimal ('78,93' / '1.234,56')."""
    if vazio(valor):
        return None
    if isinstance(valor, Decimal):
        return valor
    if isinstance(valor, (int, float)):
        return Decimal(str(valor))
    texto = str(valor).strip().replace(" ", "").replace("R$", "")
    if "," in texto and "." in texto:
        texto = texto.replace(".", "").replace(",", ".")
    else:
        texto = texto.replace(",", ".")
    try:
        return Decimal(texto)
    except (InvalidOperation, ValueError):
        return None


def converter_inteiro(valor):
    """int() tolerante: aceita 3, 3.0, '3' e devolve None quando não dá."""
    if vazio(valor):
        return None
    try:
        return int(float(str(valor).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return None


def converter_hora(valor, padrao="00:00:00"):
    """Texto/hora/fração do dia -> datetime.time (coluna TIME no PostgreSQL)."""
    if vazio(valor):
        return datetime.strptime(padrao, "%H:%M:%S").time()
    if isinstance(valor, time):
        return valor
    if isinstance(valor, datetime):
        return valor.time()
    if isinstance(valor, (int, float)) and 0 <= float(valor) < 1:
        segundos = round(float(valor) * 86400)
        return (datetime.min + timedelta(seconds=segundos)).time()
    texto = str(valor).strip()
    for formato in ("%H:%M:%S", "%H:%M"):
        try:
            return datetime.strptime(texto, formato).time()
        except ValueError:
            pass
    return datetime.strptime(padrao, "%H:%M:%S").time()


def normalizar_fornecedor(valor):
    """1..20 -> 'F1'..'F20'; mantém 'F1'..'F20' como estão."""
    if vazio(valor):
        return None
    texto = str(valor).strip()
    if texto.upper().startswith("F"):
        return texto.upper()
    numero = converter_inteiro(texto)
    return f"F{numero}" if numero is not None else texto


def texto_ou_none(valor):
    return None if vazio(valor) else str(valor).strip()


# ── Controle de erros por linha (SAVEPOINT) ───────────────
ERROS = []


def inserir_linha(cur, tabela, sql, params, linha):
    """Executa um INSERT dentro de um SAVEPOINT.

    Corrige o bug original: conn.rollback() no except desfazia o lote inteiro.
    Aqui só a linha com erro é desfeita; as anteriores permanecem.
    """
    cur.execute("SAVEPOINT sp_linha")
    try:
        cur.execute(sql, params)
        afetadas = cur.rowcount  # ler ANTES do RELEASE, que zera o rowcount
        cur.execute("RELEASE SAVEPOINT sp_linha")
        return afetadas  # 1 = inseriu, 0 = conflito (DO NOTHING)
    except Exception as e:
        cur.execute("ROLLBACK TO SAVEPOINT sp_linha")
        ERROS.append((tabela, linha, str(e).strip()))
        print(f"  Erro {tabela} linha {linha}: {str(e).strip()}")
        return -1


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
for pos, row in df.iterrows():
    inseridos += max(inserir_linha(cur, "fornecedor", """
        INSERT INTO public.fornecedor (idfornecedor, razao_social)
        VALUES (%s, %s)
        ON CONFLICT (idfornecedor) DO NOTHING
    """, (
        normalizar_fornecedor(row["idfornecedor"]),
        texto_ou_none(row["razao_social"])
    ), pos + 2), 0)

conn.commit()
print(f"  {inseridos} de {len(df)} registros inseridos em fornecedor \n")


# 2. PRODUTOS_FILIAL

print("Importando produtos_filial...")
df = pd.read_excel(ARQUIVO, sheet_name="produtos_filial")
df.columns = df.columns.str.strip()
# Nomes da planilha -> nomes do DDL corrigido (decricao/idfonecedor são typos do original)
df = df.rename(columns={
    "idproduto": "produto_id",
    "decricao": "descricao",
    "idfonecedor": "idfornecedor",
})

inseridos = 0
for pos, row in df.iterrows():
    inseridos += max(inserir_linha(cur, "produtos_filial", """
        INSERT INTO public.produtos_filial
            (filial_id, produto_id, descricao, estoque,
             preco_unitario, preco_compra, preco_venda, idfornecedor)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (filial_id, produto_id) DO NOTHING
    """, (
        converter_inteiro(row["filial_id"]),
        texto_ou_none(row["produto_id"]),
        texto_ou_none(row["descricao"]),
        converter_decimal(row["estoque"]) or Decimal("0"),
        converter_decimal(row["preco_unitario"]) or Decimal("0"),
        converter_decimal(row["preco_compra"]) or Decimal("0"),
        converter_decimal(row["preco_venda"]) or Decimal("0"),
        normalizar_fornecedor(row["idfornecedor"])
    ), pos + 2), 0)

conn.commit()
print(f"  {inseridos} de {len(df)} registros inseridos em produtos_filial \n")


# 3. PEDIDO_COMPRA

print("Importando pedido_compra...")
df_bruto = pd.read_excel(ARQUIVO, sheet_name="pedido_compra")
df_bruto.columns = df_bruto.columns.str.strip()

# A planilha tem 12 campos declarados + um bloco extra (colunas M..W) que é uma
# CÓPIA dos pedidos 12..20. Não importar as colunas extras; apenas avisar.
extras = [c for c in df_bruto.columns[12:] if df_bruto[c].notna().any()]
if extras:
    print(f"  AVISO: {len(extras)} colunas extras ignoradas (bloco duplicado): {extras}")

df = df_bruto.iloc[:, :12]
df.columns = ["pedido_id","data_pedido","item","produto_id","descricao_produto",
              "ordem_compra","qtde_pedida","filial_id","data_entrega",
              "qtde_entregue","preco_compra","fornecedor_id"]

inseridos = 0
for pos, row in df.iterrows():
    qtde_pedida = converter_decimal(row["qtde_pedida"])
    qtde_entregue = converter_decimal(row["qtde_entregue"]) or Decimal("0")
    inseridos += max(inserir_linha(cur, "pedido_compra", """
        INSERT INTO public.pedido_compra
            (pedido_id, data_pedido, item, produto_id, descricao_produto,
             ordem_compra, qtde_pedida, filial_id, data_entrega,
             qtde_entregue, qtde_pendente, preco_compra, fornecedor_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (pedido_id, produto_id, item) DO NOTHING
    """, (
        converter_inteiro(row["pedido_id"]),
        excel_para_data(row["data_pedido"]),
        converter_inteiro(row["item"]),
        texto_ou_none(row["produto_id"]),
        texto_ou_none(row["descricao_produto"]),
        converter_inteiro(row["ordem_compra"]) or 0,
        qtde_pedida,
        converter_inteiro(row["filial_id"]),
        excel_para_data(row["data_entrega"]),
        qtde_entregue,
        (qtde_pedida - qtde_entregue) if qtde_pedida is not None else Decimal("0"),
        converter_decimal(row["preco_compra"]) or Decimal("0"),
        normalizar_fornecedor(row["fornecedor_id"])
    ), pos + 2), 0)

conn.commit()
print(f"  {inseridos} de {len(df)} registros inseridos em pedido_compra \n")


# 4. ENTRADAS_MERCADORIA

print("Importando entradas_mercadoria...")
df = pd.read_excel(ARQUIVO, sheet_name="entradas_mercadoria")
df.columns = df.columns.str.strip()

inseridos = 0
for pos, row in df.iterrows():
    inseridos += max(inserir_linha(cur, "entradas_mercadoria", """
        INSERT INTO public.entradas_mercadoria
            (data_entrada, nro_nfe, item, produto_id, descricao_produto,
             ordem_compra, qtde_recebida, filial_id, custo_unitario)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (ordem_compra, item, produto_id, nro_nfe) DO NOTHING
    """, (
        excel_para_data(row["data_entrada"]),
        texto_ou_none(row["nro_nfe"]),
        converter_inteiro(row["item"]),
        texto_ou_none(row["produto_id"]),
        texto_ou_none(row["descricao_produto"]),
        converter_inteiro(row["ordem_compra"]),
        converter_decimal(row["qtde_recebida"]),
        converter_inteiro(row["filial_id"]),
        converter_decimal(row["custo_unitario"]) or Decimal("0")
    ), pos + 2), 0)

conn.commit()
print(f"  {inseridos} de {len(df)} registros inseridos em entradas_mercadoria \n")


# 5. VENDA

print("Importando venda...")
df = pd.read_excel(ARQUIVO, sheet_name="venda")
df.columns = df.columns.str.strip()

inseridos = 0
for pos, row in df.iterrows():
    inseridos += max(inserir_linha(cur, "venda", """
        INSERT INTO public.venda
            (venda_id, data_emissao, horariomov, produto_id,
             qtde_vendida, valor_unitario, filial_id, item, unidade_medida)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (filial_id, venda_id, data_emissao, produto_id, item, horariomov) DO NOTHING
    """, (
        converter_inteiro(row["venda_id"]),
        excel_para_data(row["data_emissao"]),
        converter_hora(row["horariomov"], padrao="00:00:00"),
        texto_ou_none(row["produto_id"]),
        converter_decimal(row["qtde_vendida"]),
        converter_decimal(row["valor_unitario"]) or Decimal("0"),
        converter_inteiro(row["filial_id"]) or 1,
        converter_inteiro(row["item"]) or 0,
        texto_ou_none(row["unidade_medida"])
    ), pos + 2), 0)

conn.commit()
print(f"  {inseridos} de {len(df)} registros inseridos em venda \n")


# ── Conferência no banco (contra a planilha) ──────────────
print("Conferindo contagens no banco...")
for tabela in ("fornecedor", "produtos_filial", "pedido_compra",
               "entradas_mercadoria", "venda"):
    cur.execute(f"SELECT COUNT(*) FROM public.{tabela}")
    print(f"  {tabela}: {cur.fetchone()[0]} linhas")

if ERROS:
    print(f"\n{len(ERROS)} linha(s) rejeitada(s):")
    for tabela, linha, msg in ERROS:
        print(f"  - {tabela} linha {linha}: {msg}")
else:
    print("\nNenhuma linha rejeitada.")

cur.close()
conn.close()
print("=" * 40)
print("Importação concluída! ")
print("=" * 40)
