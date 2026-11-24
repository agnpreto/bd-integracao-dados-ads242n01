importar.py - importa dados/base_teste.xlsx para o PostgreSQL (versao corrigida).

Uso:
    export DB_PASSWORD='sua_senha'        # Windows (PowerShell): $env:DB_PASSWORD='sua_senha'
    python scripts/importar.py

Pre-requisito: rodar sql/01_ddl_postgres.sql ANTES.
Ordem de carga: fornecedor -> produtos_filial -> pedido_compra -> entradas_mercadoria -> venda.
Rode a trigger (sql/03_transformacoes.sql, item 3.4) DEPOIS da importacao, senao ela cria
fornecedores "A DEFINIR" para todo produto importado sem idfornecedor.
Para MySQL use outra ferramenta (DBeaver) ou adapte: INSERT IGNORE e mysql-connector.
"""
import csv
import os
import re
import sys
from datetime import datetime, timedelta

import pandas as pd
import psycopg2

# ── Configuracoes (senha por variavel de ambiente, nunca no codigo) ─────────
ARQUIVO = os.environ.get("ARQUIVO_XLSX", "dados/base_teste.xlsx")
DB = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": int(os.environ.get("DB_PORT", 5432)),  # PostgreSQL 5432 | MySQL 3306
    "database": os.environ.get("DB_NAME", "postgres"),
    "user": os.environ.get("DB_USER", "postgres"),
    "password": os.environ.get("DB_PASSWORD", "sua_senha_aqui"),
}
ARQUIVO_REJEITADOS = "importacao_rejeitados.csv"


# ── Conversores: valor vazio vira None; valor invalido levanta ValueError ───
def vazio(v):
    return v is None or (isinstance(v, float) and pd.isna(v)) or str(v).strip().lower() in ("", "nan", "nat")


def txt(v):
    return None if vazio(v) else str(v).strip()


def ident(v):
    """Codigos (produto, nfe...) como texto. Tira o '.0' que o Excel/pandas poe em numeros."""
    t = txt(v)
    return None if t is None else re.sub(r"\.0+$", "", t)


def numero(v):
    t = txt(v)
    if t is None:
        return None
    if "," in t:  # 1.234,56 -> 1234.56
        t = t.replace(".", "").replace(",", ".")
    return float(t)


def inteiro(v):
    n = numero(v)
    if n is None:
        return None
    if n != int(n):
        raise ValueError(f"valor nao inteiro: {v}")
    return int(n)


def data(v):
    """Aceita serial do Excel, AAAA-MM-DD (com ou sem hora) e DD/MM/AAAA."""
    t = txt(v)
    if t is None:
        return None
    if re.fullmatch(r"\d+(\.\d+)?", t):
        serial = float(t)
        if not 20000 <= serial <= 80000:
            raise ValueError(f"data invalida: {t}")
        return (datetime(1899, 12, 30) + timedelta(days=int(serial))).date()
    m = re.match(r"\d{4}-\d{2}-\d{2}", t)
    if m:
        return datetime.strptime(m.group(0), "%Y-%m-%d").date()
    m = re.match(r"\d{1,2}/\d{1,2}/\d{4}", t)
    if m:
        return datetime.strptime(m.group(0), "%d/%m/%Y").date()
    raise ValueError(f"data invalida: {t}")


def hora(v):
    """Devolve HH:MM:SS. Vazio -> '00:00:00' (default do DDL, a coluna faz parte da PK)."""
    t = txt(v)
    if t is None:
        return "00:00:00"
    m = re.search(r"(\d{1,2}):(\d{2})(?::(\d{2}))?", t)
    if m:
        return f"{int(m.group(1)):02d}:{m.group(2)}:{m.group(3) or '00'}"
    if re.fullmatch(r"\d*\.\d+", t) and float(t) < 1:  # fracao do dia do Excel
        s = round(float(t) * 86400)
        return f"{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d}"
    raise ValueError(f"horario invalido: {t}")


def obrig(valor, nome):
    if valor is None:
        raise ValueError(f"{nome} vazio")
    return valor


def pega(row, *nomes):
    for n in nomes:
        if n in row.index:
            return row[n]
    raise KeyError(f"coluna ausente: {nomes}")


# ── Leitura da planilha ──────────────────────────────────────────────────────
def ler(aba, exigidas):
    # dtype=str: evita o pandas transformar codigos em float (12345 -> 12345.0)
    df = pd.read_excel(ARQUIVO, sheet_name=aba, dtype=str)
    df.columns = df.columns.str.strip().str.lower()
    for grupo in exigidas:
        if not any(n in df.columns for n in grupo):
            sys.exit(f"Aba '{aba}': falta a coluna {grupo}. Colunas encontradas: {list(df.columns)}")
    return df


# ── Banco ────────────────────────────────────────────────────────────────────
print("Conectando no PostgreSQL...")
conn = psycopg2.connect(**DB)
cur = conn.cursor()
print("Conectado!\n")

resumo = {}
rejeitados = []


def carregar(tabela, aba, exigidas, sql, montar):
    print(f"Importando {tabela}...")
    df = ler(aba, exigidas)
    ins = dup = err = 0
    for i, row in df.iterrows():
        linha = i + 2  # linha na planilha (cabecalho = linha 1)
        try:
            params = montar(row)
        except Exception as e:
            err += 1
            rejeitados.append((tabela, linha, f"dado invalido: {e}"))
            continue
        # SAVEPOINT: uma linha ruim nao desfaz as linhas boas ja inseridas
        cur.execute("SAVEPOINT sp")
        try:
            cur.execute(sql, params)
            n = cur.rowcount
            cur.execute("RELEASE SAVEPOINT sp")
            if n == 1:
                ins += 1
            else:
                dup += 1
                rejeitados.append((tabela, linha, "chave duplicada (ignorada)"))
        except Exception as e:
            cur.execute("ROLLBACK TO SAVEPOINT sp")
            err += 1
            rejeitados.append((tabela, linha, f"erro do banco: {str(e).strip()}"))
    conn.commit()
    cur.execute(f"SELECT COUNT(*) FROM public.{tabela}")
    no_banco = cur.fetchone()[0]
    resumo[tabela] = (len(df), ins, dup, err, no_banco)
    print(f"  planilha={len(df)} inseridas={ins} duplicadas={dup} com_erro={err} no_banco={no_banco}\n")


# 1. FORNECEDOR
carregar(
    "fornecedor", "fornecedor",
    [("idfornecedor", "idforncedor", "fornecedor_id"), ("razao_social",)],
    """INSERT INTO public.fornecedor (idfornecedor, razao_social)
       VALUES (%s, %s) ON CONFLICT (idfornecedor) DO NOTHING""",
    lambda r: (
        obrig(inteiro(pega(r, "idfornecedor", "idforncedor", "fornecedor_id")), "idfornecedor"),
        obrig(txt(pega(r, "razao_social")), "razao_social"),
    ),
)

# 2. PRODUTOS_FILIAL
carregar(
    "produtos_filial", "produtos_filial",
    [("filial_id",), ("produto_id", "idproduto"), ("descricao", "decricao")],
    """INSERT INTO public.produtos_filial
           (filial_id, produto_id, descricao, estoque, preco_unitario,
            preco_compra, preco_venda, idfornecedor)
       VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
       ON CONFLICT (filial_id, produto_id) DO NOTHING""",
    lambda r: (
        obrig(inteiro(pega(r, "filial_id")), "filial_id"),
        obrig(ident(pega(r, "produto_id", "idproduto")), "produto_id"),
        obrig(txt(pega(r, "descricao", "decricao")), "descricao"),
        numero(r.get("estoque")) or 0,
        numero(r.get("preco_unitario")) or 0,
        numero(r.get("preco_compra")) or 0,
        numero(r.get("preco_venda")) or 0,
        inteiro(pega(r, "idfornecedor", "idfonecedor")) if any(
            n in r.index for n in ("idfornecedor", "idfonecedor")) else None,
    ),
)


# 3. PEDIDO_COMPRA  (colunas lidas PELO NOME, nao pela posicao)
def montar_pedido(r):
    pedida = numero(r.get("qtde_pedida"))
    entregue = numero(r.get("qtde_entregue")) or 0
    if "qtde_pendente" in r.index and not vazio(r["qtde_pendente"]):
        pendente = numero(r["qtde_pendente"])
    else:
        pendente = (pedida or 0) - entregue
    return (
        obrig(inteiro(pega(r, "pedido_id")), "pedido_id"),
        data(r.get("data_pedido")),
        obrig(inteiro(pega(r, "item")), "item"),
        obrig(ident(pega(r, "produto_id")), "produto_id"),
        txt(r.get("descricao_produto")),
        obrig(inteiro(pega(r, "ordem_compra")), "ordem_compra"),
        pedida,
        inteiro(r.get("filial_id")),
        data(r.get("data_entrega")),
        entregue,
        pendente,
        numero(r.get("preco_compra")) or 0,
        inteiro(r.get("fornecedor_id")),
    )


carregar(
    "pedido_compra", "pedido_compra",
    [("pedido_id",), ("item",), ("produto_id",), ("ordem_compra",)],
    """INSERT INTO public.pedido_compra
           (pedido_id, data_pedido, item, produto_id, descricao_produto,
            ordem_compra, qtde_pedida, filial_id, data_entrega,
            qtde_entregue, qtde_pendente, preco_compra, fornecedor_id)
       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
       ON CONFLICT (pedido_id, produto_id, item) DO NOTHING""",
    montar_pedido,
)

# 4. ENTRADAS_MERCADORIA
carregar(
    "entradas_mercadoria", "entradas_mercadoria",
    [("nro_nfe",), ("item",), ("produto_id",), ("ordem_compra",)],
    """INSERT INTO public.entradas_mercadoria
           (data_entrada, nro_nfe, ordem_compra, item, produto_id,
            descricao_produto, qtde_recebida, filial_id, custo_unitario)
       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
       ON CONFLICT (ordem_compra, item, produto_id, nro_nfe) DO NOTHING""",
    lambda r: (
        data(r.get("data_entrada")),
        obrig(ident(pega(r, "nro_nfe")), "nro_nfe"),
        obrig(inteiro(pega(r, "ordem_compra")), "ordem_compra"),
        obrig(inteiro(pega(r, "item")), "item"),
        obrig(ident(pega(r, "produto_id")), "produto_id"),
        txt(r.get("descricao_produto")),
        numero(r.get("qtde_recebida")),
        inteiro(r.get("filial_id")),
        numero(r.get("custo_unitario")) or 0,
    ),
)

# 5. VENDA
carregar(
    "venda", "venda",
    [("venda_id",), ("data_emissao",), ("produto_id",), ("filial_id",)],
    """INSERT INTO public.venda
           (venda_id, data_emissao, horariomov, produto_id, qtde_vendida,
            valor_unitario, filial_id, item, unidade_medida)
       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
       ON CONFLICT (filial_id, venda_id, data_emissao, produto_id, item, horariomov) DO NOTHING""",
    lambda r: (
        obrig(inteiro(pega(r, "venda_id")), "venda_id"),
        obrig(data(pega(r, "data_emissao")), "data_emissao"),
        hora(r.get("horariomov")),
        obrig(ident(pega(r, "produto_id")), "produto_id"),
        numero(r.get("qtde_vendida")),
        numero(r.get("valor_unitario")) or 0,
        obrig(inteiro(pega(r, "filial_id")), "filial_id"),  # nao assume mais filial 1
        inteiro(r.get("item")) or 0,
        txt(r.get("unidade_medida")),
    ),
)

# ── Ajusta a sequencia do idfornecedor (ids foram inseridos manualmente) ────
cur.execute("""SELECT setval(pg_get_serial_sequence('public.fornecedor', 'idfornecedor'),
                      COALESCE((SELECT MAX(idfornecedor) FROM public.fornecedor), 1))""")
conn.commit()

# ── Relatorio final: conferir com a planilha ────────────────────────────────
if rejeitados:
    with open(ARQUIVO_REJEITADOS, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["tabela", "linha_na_planilha", "motivo"])
        w.writerows(rejeitados)

cur.close()
conn.close()

print("=" * 60)
print(f"{'tabela':<22}{'planilha':>9}{'inseridas':>10}{'duplic.':>8}{'erro':>6}{'banco':>7}")
for t, (p, i, d, e, b) in resumo.items():
    print(f"{t:<22}{p:>9}{i:>10}{d:>8}{e:>6}{b:>7}")
print("=" * 60)
if rejeitados:
    print(f"ATENCAO: {len(rejeitados)} linhas nao entraram. Detalhes em {ARQUIVO_REJEITADOS}")
else:
    print("Todas as linhas da planilha foram importadas.")
