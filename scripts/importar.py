"""
Importa dados/base_teste.xlsx para PostgreSQL ou MySQL.

Versão corrigida do script do estagiário. Principais mudanças (detalhes em
docs/parte1_importacao.md):
  * Datas: o pandas já entrega as datas como Timestamp; a função antiga fazia
    int(Timestamp), dava erro, o "except" engolia e TODA data virava NULL.
  * Transação: o rollback dentro do laço desfazia as linhas boas anteriores.
    Agora cada tabela é validada antes e a carga inteira é uma transação só:
    ou entra tudo, ou nada (e o erro aparece).
  * Contagem: o script antigo imprimia len(planilha) como "inseridos".
    Agora confere com SELECT COUNT(*) no banco, no final.
  * Fornecedor: 'F8' vira o id numérico 8 (o DDL corrigido usa id numérico).
  * Senha fora do código: vem de variável de ambiente.
  * Funciona com PostgreSQL e MySQL (--sgbd).

Uso:
    pip install pandas openpyxl psycopg2-binary pymysql
    export DB_PASSWORD=sua_senha
    python scripts/importar.py --sgbd postgres
    python scripts/importar.py --sgbd mysql

Variáveis de ambiente (opcionais): DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD.
Rode antes o DDL corrigido (sql/01_ddl_postgres.sql ou sql/01_ddl_mysql.sql).
"""

import argparse
import os
import re
import sys
from datetime import date, datetime, time
from pathlib import Path

import pandas as pd

# Caminho da planilha relativo ao repositório, e não à pasta de onde o script é chamado
RAIZ = Path(__file__).resolve().parent.parent
ARQUIVO = RAIZ / "dados" / "base_teste.xlsx"

# Ordem importa por causa das chaves estrangeiras: fornecedor primeiro
TABELAS = ["fornecedor", "produtos_filial", "pedido_compra", "entradas_mercadoria", "venda"]


# ── Conexão ─────────────────────────────────────────────────
def conectar(sgbd):
    host = os.getenv("DB_HOST", "localhost")
    nome = os.getenv("DB_NAME", "integracao")
    usuario = os.getenv("DB_USER", "postgres" if sgbd == "postgres" else "root")
    senha = os.getenv("DB_PASSWORD", "")  # nunca deixar senha real no código
    if sgbd == "postgres":
        import psycopg2
        porta = int(os.getenv("DB_PORT", "5432"))
        return psycopg2.connect(host=host, port=porta, dbname=nome, user=usuario, password=senha)
    import pymysql
    porta = int(os.getenv("DB_PORT", "3306"))  # porta padrão do MySQL é 3306 (não 3006)
    return pymysql.connect(host=host, port=porta, database=nome, user=usuario,
                           password=senha, autocommit=False)


# ── Conversores ─────────────────────────────────────────────
def para_data(valor):
    """Aceita Timestamp/datetime (o normal no .xlsx), serial do Excel ou texto."""
    if valor is None or pd.isna(valor):
        return None
    if isinstance(valor, (pd.Timestamp, datetime)):
        return valor.date()
    if isinstance(valor, date):
        return valor
    if isinstance(valor, (int, float)):  # serial do Excel (dias desde 30/12/1899)
        return (pd.Timestamp("1899-12-30") + pd.Timedelta(days=int(valor))).date()
    return pd.to_datetime(str(valor).strip(), dayfirst=True).date()


def para_hora(valor):
    if valor is None or pd.isna(valor):
        return "00:00:00"
    if isinstance(valor, time):
        return valor.strftime("%H:%M:%S")
    return str(valor).strip()


def para_num(valor, padrao=None):
    return padrao if valor is None or pd.isna(valor) else float(valor)


def para_int(valor, padrao=None):
    if valor is None or pd.isna(valor):
        return padrao
    if float(valor) != int(float(valor)):
        raise ValueError(f"valor {valor} deveria ser inteiro")
    return int(float(valor))


def para_texto(valor):
    if valor is None or pd.isna(valor):
        return None
    texto = str(valor).strip()
    return texto or None


def codigo_fornecedor_para_id(codigo):
    """'F8' -> 8. Se vier fora do padrão, falha em vez de gravar lixo."""
    if codigo is None or pd.isna(codigo):
        return None
    m = re.fullmatch(r"[Ff]?(\d+)", str(codigo).strip())
    if not m:
        raise ValueError(f"código de fornecedor fora do padrão: {codigo!r}")
    return int(m.group(1))


# ── Leitura e preparação de cada aba ────────────────────────
def ler_aba(nome):
    df = pd.read_excel(ARQUIVO, sheet_name=nome)
    df.columns = [str(c).strip() for c in df.columns]
    df = df.dropna(how="all")  # linhas totalmente vazias
    return df


def preparar(nome):
    """Devolve (colunas_do_banco, linhas, avisos)."""
    df = ler_aba(nome)
    avisos = []

    if nome == "fornecedor":
        colunas = ["idfornecedor", "codigo_origem", "razao_social"]
        linhas = [(codigo_fornecedor_para_id(r["idfornecedor"]), para_texto(r["idfornecedor"]),
                   para_texto(r["razao_social"])) for _, r in df.iterrows()]

    elif nome == "produtos_filial":
        # Na planilha a coluna chama "idproduto"; no banco, produto_id
        colunas = ["filial_id", "produto_id", "descricao", "estoque", "preco_unitario",
                   "preco_compra", "preco_venda", "idfornecedor"]
        linhas = [(para_int(r["filial_id"]), para_texto(r["idproduto"]), para_texto(r["descricao"]),
                   para_num(r["estoque"], 0), para_num(r["preco_unitario"], 0),
                   para_num(r["preco_compra"], 0), para_num(r["preco_venda"], 0),
                   codigo_fornecedor_para_id(r["idfornecedor"])) for _, r in df.iterrows()]

    elif nome == "pedido_compra":
        # A aba tem 11 colunas sem cabeçalho à direita (M:W), preenchidas nas linhas 22-30.
        # São uma cópia de outros pedidos e não pertencem à tabela: são descartadas e avisadas.
        extras = [c for c in df.columns if c.startswith("Unnamed")]
        sujas = int(df[extras].notna().any(axis=1).sum()) if extras else 0
        if sujas:
            avisos.append(f"{len(extras)} colunas sem cabeçalho descartadas ({sujas} linhas tinham conteúdo nelas)")
        # qtde_pendente NÃO é importada: no banco é coluna calculada (pedida - entregue)
        colunas = ["pedido_id", "data_pedido", "item", "produto_id", "descricao_produto", "ordem_compra",
                   "qtde_pedida", "filial_id", "data_entrega", "qtde_entregue", "preco_compra", "fornecedor_id"]
        linhas = [(para_int(r["pedido_id"]), para_data(r["data_pedido"]), para_int(r["item"], 0),
                   para_texto(r["produto_id"]), para_texto(r["descricao_produto"]),
                   para_int(r["ordem_compra"], 0), para_num(r["qtde_pedida"]), para_int(r["filial_id"]),
                   para_data(r["data_entrega"]), para_num(r["qtde_entregue"], 0),
                   para_num(r["preco_compra"], 0), para_int(r["fornecedor_id"]))
                  for _, r in df.iterrows()]

    elif nome == "entradas_mercadoria":
        colunas = ["data_entrada", "nro_nfe", "item", "produto_id", "descricao_produto", "ordem_compra",
                   "qtde_recebida", "filial_id", "custo_unitario"]
        linhas = [(para_data(r["data_entrada"]), para_texto(r["nro_nfe"]), para_int(r["item"], 0),
                   para_texto(r["produto_id"]), para_texto(r["descricao_produto"]),
                   para_int(r["ordem_compra"]), para_num(r["qtde_recebida"]), para_int(r["filial_id"]),
                   para_num(r["custo_unitario"], 0)) for _, r in df.iterrows()]

    elif nome == "venda":
        colunas = ["venda_id", "data_emissao", "horariomov", "produto_id", "qtde_vendida",
                   "valor_unitario", "filial_id", "item", "unidade_medida"]
        linhas = [(para_int(r["venda_id"]), para_data(r["data_emissao"]), para_hora(r["horariomov"]),
                   para_texto(r["produto_id"]), para_num(r["qtde_vendida"]), para_num(r["valor_unitario"], 0),
                   para_int(r["filial_id"], 1), para_int(r["item"], 0), para_texto(r["unidade_medida"]))
                  for _, r in df.iterrows()]
    else:
        raise ValueError(nome)

    return colunas, linhas, avisos


# Colunas obrigatórias (NOT NULL sem default) e chave primária de cada tabela
OBRIGATORIAS = {
    "fornecedor": ["idfornecedor", "razao_social"],
    "produtos_filial": ["filial_id", "produto_id", "descricao"],
    "pedido_compra": ["pedido_id", "produto_id"],
    "entradas_mercadoria": ["nro_nfe", "produto_id", "ordem_compra"],
    "venda": ["venda_id", "data_emissao", "produto_id"],
}
PK = {
    "fornecedor": ["idfornecedor"],
    "produtos_filial": ["filial_id", "produto_id"],
    "pedido_compra": ["pedido_id", "produto_id", "item"],
    "entradas_mercadoria": ["ordem_compra", "item", "produto_id", "nro_nfe"],
    "venda": ["filial_id", "venda_id", "data_emissao", "produto_id", "item", "horariomov"],
}


def validar(nome, colunas, linhas):
    """Valida antes de gravar: campos obrigatórios e chave duplicada. Devolve lista de erros."""
    erros = []
    idx = {c: i for i, c in enumerate(colunas)}
    vistos = {}
    for n, linha in enumerate(linhas, start=2):  # linha 1 da planilha é o cabeçalho
        for c in OBRIGATORIAS[nome]:
            if linha[idx[c]] is None:
                erros.append(f"{nome} linha {n}: campo obrigatório '{c}' vazio")
        chave = tuple(linha[idx[c]] for c in PK[nome])
        if chave in vistos:
            erros.append(f"{nome} linha {n}: chave {chave} repetida (já está na linha {vistos[chave]})")
        vistos.setdefault(chave, n)
    return erros


def main():
    ap = argparse.ArgumentParser(description="Importa base_teste.xlsx")
    ap.add_argument("--sgbd", choices=["postgres", "mysql"], default="postgres")
    ap.add_argument("--manter", action="store_true",
                    help="não apaga os dados atuais antes de importar (padrão: apaga e recarrega)")
    args = ap.parse_args()

    # 1) Lê e valida TUDO antes de tocar no banco
    preparados, erros = {}, []
    for t in TABELAS:
        colunas, linhas, avisos = preparar(t)
        for a in avisos:
            print(f"  aviso {t}: {a}")
        erros += validar(t, colunas, linhas)
        preparados[t] = (colunas, linhas)
    if erros:
        print("Planilha com problemas, nada foi gravado:")
        for e in erros:
            print("  -", e)
        sys.exit(1)

    # 2) Grava em uma única transação
    print(f"Conectando no {args.sgbd}...")
    conn = conectar(args.sgbd)
    cur = conn.cursor()
    try:
        if not args.manter:  # deixa a carga repetível: rodar 2x não duplica nem "pula" linhas
            for t in reversed(TABELAS):
                cur.execute(f"DELETE FROM {t}")
        for t in TABELAS:
            colunas, linhas = preparados[t]
            sql = f"INSERT INTO {t} ({', '.join(colunas)}) VALUES ({', '.join(['%s'] * len(colunas))})"
            cur.executemany(sql, linhas)
            print(f"  {t}: {len(linhas)} linhas enviadas")
        if args.sgbd == "postgres":
            # ids de fornecedor foram informados à mão; acerta a sequência para a trigger da Parte 3
            cur.execute("SELECT setval(pg_get_serial_sequence('fornecedor', 'idfornecedor'), "
                        "(SELECT COALESCE(MAX(idfornecedor), 1) FROM fornecedor))")
        conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"ERRO, nada foi gravado: {e}")
        sys.exit(1)

    # 3) Confere no banco, e não no que o script acha que fez
    print("\nConferência (planilha x banco):")
    ok = True
    for t in TABELAS:
        cur.execute(f"SELECT COUNT(*) FROM {t}")
        no_banco = cur.fetchone()[0]
        na_planilha = len(preparados[t][1])
        status = "OK" if no_banco == na_planilha else "DIVERGENTE"
        ok &= no_banco == na_planilha
        print(f"  {t:<20} planilha={na_planilha:<4} banco={no_banco:<4} {status}")
    cur.close()
    conn.close()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
