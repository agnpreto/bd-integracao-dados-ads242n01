"""
importar.py (versão corrigida)
Autor: João Gustavo Gonçalves Vasconcelos (2408298)

Importa dados/base_teste.xlsx para o PostgreSQL (tabelas criadas por sql/01_ddl_postgres.sql).

Uso:
    export PGHOST=localhost PGPORT=5432 PGDATABASE=postgres PGUSER=postgres PGPASSWORD=sua_senha
    python scripts/importar.py [caminho_da_planilha]

Correções em relação ao script do estagiário (detalhes em docs/parte1_importacao.md):
  1. Datas: o pandas já devolve Timestamp; a função antiga fazia int(Timestamp), caía no
     "except:" e devolvia None, então TODAS as datas viravam NULL (e venda.data_emissao é NOT NULL,
     então nenhuma venda entrava).
  2. conn.rollback() no except desfazia TODAS as linhas ainda não "commitadas" da tabela (o commit só
     ocorria no fim). Agora cada linha usa SAVEPOINT: um erro desfaz só aquela linha.
  3. O contador impresso era len(df) (linhas lidas), não as linhas realmente inseridas.
     Agora usa cur.rowcount e, no fim, confere com SELECT COUNT(*).
  4. ON CONFLICT ... DO NOTHING escondia duplicatas; agora elas são contadas e avisadas.
  5. Nomes de colunas alinhados ao DDL corrigido (idfornecedor, descricao, idproduto -> produto_id).
  6. idfornecedor: na planilha vem como texto ('F8'); no banco é numérico (8).
  7. pedido_compra: as colunas M:W da aba são lixo (cópia de uma linha com cabeçalho "Unnamed");
     agora são selecionadas só as 12 colunas pelo NOME (antes era iloc[:, :12] + renomeação posicional).
  8. Senha não fica mais no código (variáveis de ambiente) e a porta do MySQL é 3306 (não 3006).
  9. Quantidades passaram a aceitar decimais (a planilha tem 38,6; 20,04...).
"""
import os
import sys

import pandas as pd
import psycopg2

ARQUIVO = sys.argv[1] if len(sys.argv) > 1 else "dados/base_teste.xlsx"

DB = {
    "host": os.getenv("PGHOST", "localhost"),
    "port": int(os.getenv("PGPORT", "5432")),   # PostgreSQL 5432 (MySQL usa 3306)
    "dbname": os.getenv("PGDATABASE", "postgres"),
    "user": os.getenv("PGUSER", "postgres"),
    "password": os.getenv("PGPASSWORD", ""),  # valor de exemplo
}


# ── Helpers ────────────────────────────────────────────────
def data(v):
    """Converte Timestamp/datetime/serial do Excel/texto para date; vazio vira None."""
    if pd.isna(v):
        return None
    if isinstance(v, (int, float)):  # serial do Excel
        return (pd.Timestamp("1899-12-30") + pd.Timedelta(days=float(v))).date()
    return pd.to_datetime(v).date()


def num(v, default=None):
    return default if pd.isna(v) else float(v)


def inteiro(v, default=None):
    return default if pd.isna(v) else int(v)


def texto(v, default=None):
    return default if pd.isna(v) else str(v).strip()


def id_fornecedor(v):
    """'F8' -> 8 ; 8 -> 8 ; vazio -> None."""
    if pd.isna(v):
        return None
    s = str(v).strip().upper().lstrip("F")
    return int(float(s))


def ler(aba, colunas=None):
    df = pd.read_excel(ARQUIVO, sheet_name=aba)
    df.columns = df.columns.str.strip()
    if colunas:
        df = df[colunas]          # seleciona pelo nome e descarta colunas "Unnamed"
    return df


def carregar(cur, nome, df, sql, montar):
    """Insere linha a linha com SAVEPOINT; devolve (inseridas, ignoradas, erros)."""
    ok = dup = err = 0
    for i, row in df.iterrows():
        cur.execute("SAVEPOINT linha")
        try:
            cur.execute(sql, montar(row))
            if cur.rowcount == 1:
                ok += 1
            else:
                dup += 1
            cur.execute("RELEASE SAVEPOINT linha")
        except Exception as e:  # erro só desta linha
            cur.execute("ROLLBACK TO SAVEPOINT linha")
            err += 1
            print(f"  [ERRO] {nome} linha {i + 2} da planilha: {e}".strip())
    print(f"  {nome}: lidas={len(df)} inseridas={ok} duplicadas_ignoradas={dup} com_erro={err}\n")
    return ok, dup, err


# ── Execução ───────────────────────────────────────────────
print("Conectando no PostgreSQL...")
conn = psycopg2.connect(**DB)
cur = conn.cursor()
print("Conectado!\n")

resumo = {}

# 1. FORNECEDOR
print("Importando fornecedor...")
df = ler("fornecedor")
resumo["fornecedor"] = len(df)
carregar(cur, "fornecedor", df, """
    INSERT INTO public.fornecedor (idfornecedor, razao_social)
    OVERRIDING SYSTEM VALUE VALUES (%s, %s)
    ON CONFLICT (idfornecedor) DO NOTHING
""", lambda r: (id_fornecedor(r["idfornecedor"]), texto(r["razao_social"])))
# alinha a sequência da coluna identity com os ids importados
cur.execute("""SELECT setval(pg_get_serial_sequence('public.fornecedor','idfornecedor'),
               COALESCE((SELECT MAX(idfornecedor) FROM public.fornecedor), 1))""")
conn.commit()

# 2. PRODUTOS_FILIAL
print("Importando produtos_filial...")
df = ler("produtos_filial")
resumo["produtos_filial"] = len(df)
carregar(cur, "produtos_filial", df, """
    INSERT INTO public.produtos_filial
        (filial_id, produto_id, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT (filial_id, produto_id) DO NOTHING
""", lambda r: (
    inteiro(r["filial_id"]), texto(r["idproduto"]), texto(r["descricao"]),
    num(r["estoque"], 0), num(r["preco_unitario"], 0), num(r["preco_compra"], 0),
    num(r["preco_venda"], 0), id_fornecedor(r["idfornecedor"]),
))
conn.commit()

# 3. PEDIDO_COMPRA  (colunas M:W da aba são lixo e ficam de fora)
print("Importando pedido_compra...")
COLS_PEDIDO = ["pedido_id", "data_pedido", "item", "produto_id", "descricao_produto",
               "ordem_compra", "qtde_pedida", "filial_id", "data_entrega",
               "qtde_entregue", "preco_compra", "fornecedor_id"]
df = ler("pedido_compra", COLS_PEDIDO)
resumo["pedido_compra"] = len(df)
carregar(cur, "pedido_compra", df, """
    INSERT INTO public.pedido_compra
        (pedido_id, data_pedido, item, produto_id, descricao_produto, ordem_compra,
         qtde_pedida, filial_id, data_entrega, qtde_entregue, qtde_pendente,
         preco_compra, fornecedor_id)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT (pedido_id, produto_id, item) DO NOTHING
""", lambda r: (
    inteiro(r["pedido_id"]), data(r["data_pedido"]), inteiro(r["item"]), texto(r["produto_id"]),
    texto(r["descricao_produto"]), inteiro(r["ordem_compra"], 0), num(r["qtde_pedida"]),
    inteiro(r["filial_id"]), data(r["data_entrega"]), num(r["qtde_entregue"], 0),
    # qtde_pendente não existe na planilha: calculada = pedida - entregue
    (num(r["qtde_pedida"], 0) - num(r["qtde_entregue"], 0)),
    num(r["preco_compra"], 0), inteiro(r["fornecedor_id"]),
))
conn.commit()

# 4. ENTRADAS_MERCADORIA
print("Importando entradas_mercadoria...")
df = ler("entradas_mercadoria")
resumo["entradas_mercadoria"] = len(df)
carregar(cur, "entradas_mercadoria", df, """
    INSERT INTO public.entradas_mercadoria
        (data_entrada, nro_nfe, item, produto_id, descricao_produto,
         ordem_compra, qtde_recebida, filial_id, custo_unitario)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT (ordem_compra, item, produto_id, nro_nfe) DO NOTHING
""", lambda r: (
    data(r["data_entrada"]), texto(r["nro_nfe"]), inteiro(r["item"]), texto(r["produto_id"]),
    texto(r["descricao_produto"]), inteiro(r["ordem_compra"], 0), num(r["qtde_recebida"]),
    inteiro(r["filial_id"]), num(r["custo_unitario"], 0),
))
conn.commit()

# 5. VENDA
print("Importando venda...")
df = ler("venda")
resumo["venda"] = len(df)
carregar(cur, "venda", df, """
    INSERT INTO public.venda
        (venda_id, data_emissao, horariomov, produto_id, qtde_vendida,
         valor_unitario, filial_id, item, unidade_medida)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT (filial_id, venda_id, data_emissao, produto_id, item, horariomov) DO NOTHING
""", lambda r: (
    inteiro(r["venda_id"]), data(r["data_emissao"]), texto(r["horariomov"], "00:00:00"),
    texto(r["produto_id"]), num(r["qtde_vendida"]), num(r["valor_unitario"], 0),
    inteiro(r["filial_id"], 1), inteiro(r["item"], 0), texto(r["unidade_medida"]),
))
conn.commit()

# ── Conferência: planilha x banco ──────────────────────────
print("=" * 52)
print(f"{'tabela':<22}{'planilha':>10}{'banco':>10}  status")
tudo_ok = True
for tabela, n_planilha in resumo.items():
    cur.execute(f"SELECT COUNT(*) FROM public.{tabela}")
    n_banco = cur.fetchone()[0]
    ok = n_banco == n_planilha
    tudo_ok &= ok
    print(f"{tabela:<22}{n_planilha:>10}{n_banco:>10}  {'OK' if ok else 'DIVERGE'}")
print("=" * 52)

cur.close()
conn.close()
print("Importação concluída." if tudo_ok else "ATENÇÃO: há divergência de contagem, veja os avisos acima.")
