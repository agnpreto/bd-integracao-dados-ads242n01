"""
Importa dados/base_teste.xlsx para MySQL ou PostgreSQL.

Versão corrigida do script original (ver docs/parte1_importacao.md).

Configuração por variáveis de ambiente (nenhuma senha fica no código):
    DB_TIPO      mysql | postgres          (padrão: mysql)
    DB_HOST      (padrão: localhost)
    DB_PORT      (padrão: 3306 no MySQL, 5432 no PostgreSQL)
    DB_NAME      (padrão: integracao_dados)
    DB_USER      (padrão: root no MySQL, postgres no PostgreSQL)
    DB_PASSWORD  (obrigatória, exceto no modo SAIDA_SQL)
    ARQUIVO      (padrão: dados/base_teste.xlsx)
    SAIDA_SQL    se definida, NÃO conecta no banco: grava os INSERTs (sintaxe
                 MySQL) nesse arquivo, para abrir e executar no MySQL Workbench.
                 Ex.: SAIDA_SQL=sql/carga_mysql.sql python scripts/importar.py

Exemplo (Windows PowerShell):
    $env:DB_TIPO="mysql"; $env:DB_PASSWORD="sua_senha"; python scripts/importar.py
Exemplo (Linux/macOS):
    DB_TIPO=mysql DB_PASSWORD=sua_senha python scripts/importar.py

Dependências:
    pip install pandas openpyxl mysql-connector-python   (MySQL)
    pip install pandas openpyxl psycopg2-binary          (PostgreSQL)
"""
import os
import re
import sys
import unicodedata
from datetime import date, datetime, time, timedelta

import pandas as pd

# ── Configurações ──────────────────────────────────────────
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARQUIVO = os.environ.get("ARQUIVO", os.path.join(RAIZ, "dados", "base_teste.xlsx"))
DB_TIPO = os.environ.get("DB_TIPO", "mysql").lower()

if DB_TIPO not in ("mysql", "postgres"):
    sys.exit("DB_TIPO deve ser 'mysql' ou 'postgres'.")

DB = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": int(os.environ.get("DB_PORT", 3306 if DB_TIPO == "mysql" else 5432)),
    "database": os.environ.get("DB_NAME", "integracao_dados"),
    "user": os.environ.get("DB_USER", "root" if DB_TIPO == "mysql" else "postgres"),
    "password": os.environ.get("DB_PASSWORD"),
}
SAIDA_SQL = os.environ.get("SAIDA_SQL")
if SAIDA_SQL:
    DB_TIPO = "mysql"
if not DB["password"] and not SAIDA_SQL:
    sys.exit("Defina a variável de ambiente DB_PASSWORD (a senha não fica no código).")

# Prefixo de schema só existe no PostgreSQL
SCHEMA = "public." if DB_TIPO == "postgres" else ""

# Nomes alternativos encontrados/esperados na planilha → nome correto
APELIDOS = {
    "idproduto": "produto_id",
    "id_produto": "produto_id",
    "decricao": "descricao",
    "idforncedor": "idfornecedor",
    "idfonecedor": "idfornecedor",
}


# ── Funções de conversão ───────────────────────────────────
def vazio(v):
    if v is None:
        return True
    try:
        if pd.isna(v):
            return True
    except (TypeError, ValueError):
        pass
    return isinstance(v, str) and v.strip() == ""


def txt_id(v):
    """Códigos (produto, NF-e): evita o '12345.0' que o Excel gera em colunas numéricas."""
    if vazio(v):
        return None
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    s = str(v).strip()
    if re.fullmatch(r"\d+\.0+", s):
        s = s.split(".")[0]
    return s


def txt(v):
    return None if vazio(v) else str(v).strip()


def inteiro(v):
    if vazio(v):
        return None
    f = float(str(v).strip().replace(",", ".")) if isinstance(v, str) else float(v)
    if not f.is_integer():
        raise ValueError(f"valor não inteiro em campo de identificador: {v!r}")
    return int(f)


def numero(v):
    if vazio(v):
        return None
    if isinstance(v, str):
        s = v.strip().replace("R$", "").strip()
        if "," in s:  # formato brasileiro 1.234,56
            s = s.replace(".", "").replace(",", ".")
        return float(s)
    return float(v)


def data(v):
    """Aceita data do Excel já convertida, número serial do Excel ou texto."""
    if vazio(v):
        return None
    if isinstance(v, pd.Timestamp):
        return v.date()
    if isinstance(v, datetime):
        return v.date()
    if isinstance(v, date):
        return v
    if isinstance(v, (int, float)):
        return (datetime(1899, 12, 30) + timedelta(days=int(v))).date()
    s = str(v).strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%Y-%m-%d %H:%M:%S", "%d-%m-%Y", "%d/%m/%y"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            pass
    raise ValueError(f"data inválida: {v!r}")


def hora(v):
    """Devolve sempre HH:MM:SS (o campo é varchar(8))."""
    if vazio(v):
        return "00:00:00"
    if isinstance(v, (datetime, pd.Timestamp)):
        return v.strftime("%H:%M:%S")
    if isinstance(v, time):
        return v.strftime("%H:%M:%S")
    if isinstance(v, (int, float)) and 0 <= v < 1:  # fração de dia do Excel
        seg = round(v * 86400)
        return f"{seg // 3600:02d}:{seg % 3600 // 60:02d}:{seg % 60:02d}"
    s = str(v).strip()
    m = re.fullmatch(r"(\d{1,2}):(\d{2})(?::(\d{2}))?", s)
    if not m:
        raise ValueError(f"horário inválido: {v!r}")
    h, mi, se = int(m.group(1)), int(m.group(2)), int(m.group(3) or 0)
    return f"{h:02d}:{mi:02d}:{se:02d}"


# ── Leitura da planilha ────────────────────────────────────
def normaliza_coluna(c):
    c = unicodedata.normalize("NFKD", str(c)).encode("ascii", "ignore").decode()
    c = re.sub(r"\s+", "_", c.strip().lower())
    return APELIDOS.get(c, c)


def ler_aba(nome):
    df = pd.read_excel(ARQUIVO, sheet_name=nome)
    df.columns = [normaliza_coluna(c) for c in df.columns]
    df = df.dropna(how="all")  # descarta linhas totalmente vazias
    # Colunas sem cabeçalho (ex.: M:W da aba pedido_compra) não são importadas,
    # mas são avisadas para entrarem no relatório de validação.
    sem_nome = [c for c in df.columns if c.startswith("unnamed")]
    if sem_nome:
        com_dado = df[sem_nome].dropna(how="all")
        print(f"  [aviso] {len(sem_nome)} coluna(s) sem cabeçalho ignoradas; "
              f"{len(com_dado)} linha(s) têm dados nelas (planilhas linhas "
              f"{[i + 2 for i in com_dado.index]})")
        df = df.drop(columns=sem_nome)
    print(f"  Colunas: {list(df.columns)}")
    return df


def exige(df, colunas, aba):
    falta = [c for c in colunas if c not in df.columns]
    if falta:
        sys.exit(f"Aba '{aba}': colunas obrigatórias ausentes: {falta}")


# ── Conexão ────────────────────────────────────────────────
def conectar():
    if SAIDA_SQL:
        return ConexaoArquivo(SAIDA_SQL)
    if DB_TIPO == "postgres":
        import psycopg2
        return psycopg2.connect(**DB)
    try:
        import mysql.connector
        return mysql.connector.connect(**DB)
    except ImportError:
        import pymysql
        cfg = dict(DB)
        cfg["db"] = cfg.pop("database")
        return pymysql.connect(**cfg)


class ConexaoArquivo:
    """Modo SAIDA_SQL: em vez de executar, escreve os comandos num arquivo .sql."""

    def __init__(self, caminho):
        self.f = open(caminho, "w", encoding="utf-8")
        self.f.write("-- Carga gerada por scripts/importar.py a partir de dados/base_teste.xlsx\n"
                     "-- Rode antes o sql/01_ddl_mysql.sql. Depois execute este arquivo inteiro.\n"
                     "USE integracao_dados;\nSTART TRANSACTION;\n")

    @staticmethod
    def literal(v):
        if v is None:
            return "NULL"
        if isinstance(v, (int, float)):
            return repr(v)
        if isinstance(v, date):
            return "'" + v.isoformat() + "'"
        return "'" + str(v).replace("\\", "\\\\").replace("'", "''") + "'"

    def cursor(self):
        conexao = self

        class Cursor:
            def execute(self, sql, valores=None):
                conexao.execute(sql, valores)

            def close(self):
                pass

        return Cursor()

    def execute(self, sql, valores=None):
        if "SAVEPOINT" in sql:
            return
        if valores:
            sql = sql.replace("%s", "{}").format(*[self.literal(v) for v in valores])
        self.f.write(sql + ";\n")

    def commit(self):
        pass

    def close(self):
        self.f.write("COMMIT;\n")
        self.f.close()


def eh_duplicado(e):
    msg = str(e).lower()
    return "duplicate" in msg or "duplicad" in msg or "unique" in msg or "1062" in msg


def importar(conn, tabela, colunas, linhas):
    """
    Insere linha a linha usando SAVEPOINT: um erro desfaz só aquela linha.
    (O script original chamava conn.rollback(), que apagava TODAS as linhas
    já inseridas desde o último commit.)
    """
    cur = conn.cursor()
    sql = (f"INSERT INTO {SCHEMA}{tabela} ({', '.join(colunas)}) "
           f"VALUES ({', '.join(['%s'] * len(colunas))})")
    ok = dup = erro = 0
    for n_linha, valores in linhas:
        cur.execute("SAVEPOINT sp_linha")
        try:
            cur.execute(sql, valores)
            cur.execute("RELEASE SAVEPOINT sp_linha")
            ok += 1
        except Exception as e:
            cur.execute("ROLLBACK TO SAVEPOINT sp_linha")
            if eh_duplicado(e):
                dup += 1
                print(f"  [duplicado] linha {n_linha} da planilha: {valores}")
            else:
                erro += 1
                print(f"  [erro] linha {n_linha} da planilha: {e}")
    conn.commit()
    cur.close()
    return ok, dup, erro


def preparar(df, aba, montar):
    """Converte cada linha; linhas com dado inválido são relatadas, não inventadas."""
    linhas, invalidas = [], 0
    for i, row in df.iterrows():
        n_linha = i + 2  # +1 do cabeçalho, +1 porque o Excel começa em 1
        try:
            linhas.append((n_linha, montar(row)))
        except Exception as e:
            invalidas += 1
            print(f"  [inválida] {aba} linha {n_linha}: {e}")
    return linhas, invalidas


def obrigatorio(v, campo):
    if v is None:
        raise ValueError(f"campo obrigatório vazio: {campo}")
    return v


# ── Montagem de cada tabela ────────────────────────────────
def m_fornecedor(r):
    return (
        obrigatorio(txt_id(r["idfornecedor"]), "idfornecedor"),
        obrigatorio(txt(r["razao_social"]), "razao_social"),
    )


def m_produtos(r):
    return (
        obrigatorio(inteiro(r["filial_id"]), "filial_id"),
        obrigatorio(txt_id(r["produto_id"]), "produto_id"),
        obrigatorio(txt(r["descricao"]), "descricao"),
        numero(r.get("estoque")) or 0,
        numero(r.get("preco_unitario")) or 0,
        numero(r.get("preco_compra")) or 0,
        numero(r.get("preco_venda")) or 0,
        txt_id(r.get("idfornecedor")),  # código texto: "F8"
    )


def m_pedido(r):
    pedida = numero(r.get("qtde_pedida"))
    entregue = numero(r.get("qtde_entregue")) or 0
    if "qtde_pendente" in r.index and not vazio(r["qtde_pendente"]):
        pendente = numero(r["qtde_pendente"])
    else:
        pendente = max((pedida or 0) - entregue, 0)
    return (
        obrigatorio(inteiro(r["pedido_id"]), "pedido_id"),
        data(r.get("data_pedido")),
        obrigatorio(inteiro(r["item"]), "item"),
        obrigatorio(txt_id(r["produto_id"]), "produto_id"),
        txt(r.get("descricao_produto")),
        obrigatorio(inteiro(r["ordem_compra"]), "ordem_compra"),
        pedida,
        inteiro(r.get("filial_id")),
        data(r.get("data_entrega")),
        entregue,
        pendente,
        numero(r.get("preco_compra")) or 0,
        inteiro(r.get("fornecedor_id")),
    )


def m_entrada(r):
    return (
        data(r.get("data_entrada")),
        obrigatorio(txt_id(r["nro_nfe"]), "nro_nfe"),
        obrigatorio(inteiro(r["item"]), "item"),
        obrigatorio(txt_id(r["produto_id"]), "produto_id"),
        txt(r.get("descricao_produto")),
        obrigatorio(inteiro(r["ordem_compra"]), "ordem_compra"),
        numero(r.get("qtde_recebida")),
        inteiro(r.get("filial_id")),
        numero(r.get("custo_unitario")) or 0,
    )


def m_venda(r):
    return (
        obrigatorio(inteiro(r["venda_id"]), "venda_id"),
        obrigatorio(data(r["data_emissao"]), "data_emissao"),
        hora(r.get("horariomov")),
        obrigatorio(txt_id(r["produto_id"]), "produto_id"),
        numero(r.get("qtde_vendida")),
        numero(r.get("valor_unitario")) or 0,
        obrigatorio(inteiro(r["filial_id"]), "filial_id"),
        inteiro(r.get("item")) or 0,
        txt(r.get("unidade_medida")),
    )


# Ordem respeita as chaves estrangeiras: fornecedor → produtos → pedido → entrada; venda
TABELAS = [
    ("fornecedor", "fornecedor", m_fornecedor,
     ["idfornecedor", "razao_social"]),
    ("produtos_filial", "produtos_filial", m_produtos,
     ["filial_id", "produto_id", "descricao", "estoque",
      "preco_unitario", "preco_compra", "preco_venda", "idfornecedor"]),
    ("pedido_compra", "pedido_compra", m_pedido,
     ["pedido_id", "data_pedido", "item", "produto_id", "descricao_produto",
      "ordem_compra", "qtde_pedida", "filial_id", "data_entrega",
      "qtde_entregue", "qtde_pendente", "preco_compra", "fornecedor_id"]),
    ("entradas_mercadoria", "entradas_mercadoria", m_entrada,
     ["data_entrada", "nro_nfe", "item", "produto_id", "descricao_produto",
      "ordem_compra", "qtde_recebida", "filial_id", "custo_unitario"]),
    ("venda", "venda", m_venda,
     ["venda_id", "data_emissao", "horariomov", "produto_id",
      "qtde_vendida", "valor_unitario", "filial_id", "item", "unidade_medida"]),
]

OBRIGATORIAS = {
    "fornecedor": ["idfornecedor", "razao_social"],
    "produtos_filial": ["filial_id", "produto_id", "descricao"],
    "pedido_compra": ["pedido_id", "item", "produto_id", "ordem_compra"],
    "entradas_mercadoria": ["nro_nfe", "item", "produto_id", "ordem_compra"],
    "venda": ["venda_id", "data_emissao", "produto_id", "filial_id"],
}


def main():
    if SAIDA_SQL:
        print(f"Modo arquivo: gerando {SAIDA_SQL} (sem conectar no banco)")
    print(f"Conectando no {DB_TIPO} ({DB['host']}:{DB['port']}/{DB['database']})...")
    conn = conectar()
    print("Conectado!\n")

    resumo = []
    for aba, tabela, montar, colunas in TABELAS:
        print(f"Importando {tabela}...")
        df = ler_aba(aba)
        exige(df, OBRIGATORIAS[tabela], aba)
        linhas, invalidas = preparar(df, aba, montar)
        ok, dup, erro = importar(conn, tabela, colunas, linhas)
        resumo.append((tabela, len(df), ok, dup, erro + invalidas))
        print(f"  {ok} inseridas | {dup} duplicadas | {erro + invalidas} com erro\n")

    conn.close()

    print("=" * 66)
    print(f"{'Tabela':<22}{'Planilha':>10}{'Inseridas':>11}{'Duplic.':>10}{'Erros':>9}")
    for t, total, ok, dup, err in resumo:
        print(f"{t:<22}{total:>10}{ok:>11}{dup:>10}{err:>9}")
    print("=" * 66)
    falhas = sum(r[3] + r[4] for r in resumo)
    if falhas:
        print(f"Importação concluída com {falhas} linha(s) não inserida(s). Veja o log acima.")
    else:
        print("Importação concluída sem perdas.")
    print("Confira no banco: SELECT COUNT(*) FROM <tabela>;")


if __name__ == "__main__":
    main()
