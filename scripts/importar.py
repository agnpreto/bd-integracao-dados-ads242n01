"""Carga de dados/base_teste.xlsx no PostgreSQL ou no MySQL.

Versao corrigida do script do estagiario. O que estava errado e o que mudou
esta em docs/parte1_importacao.md.

Antes de rodar, crie as tabelas com sql/01_ddl_postgres.sql ou
sql/01_ddl_mysql.sql. Dependencias: pip install pandas openpyxl psycopg2-binary pymysql

A conexao vem de variaveis de ambiente (nenhuma senha real fica no codigo):

    DB_DIALECT    postgres | mysql       padrao: postgres
    DB_HOST       host do banco          padrao: localhost
    DB_PORT       porta                  padrao: 5432 (postgres) / 3306 (mysql)
    DB_NAME       nome do banco          padrao: base_teste
    DB_USER       usuario                padrao: postgres / root
    DB_PASSWORD   senha                  padrao: valor de exemplo 'troque-me'
    ARQUIVO_XLSX  caminho da planilha    padrao: dados/base_teste.xlsx

Exemplo (Linux/macOS):
    DB_DIALECT=postgres DB_PASSWORD=minhasenha python scripts/importar.py
Exemplo (PowerShell):
    $env:DB_DIALECT="mysql"; $env:DB_PASSWORD="minhasenha"; python scripts/importar.py

Codigo de saida: 0 se todas as tabelas conferem com a planilha, 1 caso contrario.
"""

import math
import os
import sys
from datetime import date, datetime, time, timedelta

# --------------------------------------------------------------------------
# Configuracao
# --------------------------------------------------------------------------
DIALETO = os.getenv("DB_DIALECT", "postgres").strip().lower()
PADROES = {
    "postgres": {"porta": 5432, "usuario": "postgres", "nome": "PostgreSQL"},
    "mysql": {"porta": 3306, "usuario": "root", "nome": "MySQL"},
}
ARQUIVO = os.getenv("ARQUIVO_XLSX", os.path.join("dados", "base_teste.xlsx"))


def config_banco():
    if DIALETO not in PADROES:
        sys.exit(f"DB_DIALECT invalido: {DIALETO!r}. Use 'postgres' ou 'mysql'.")
    porta = os.getenv("DB_PORT", str(PADROES[DIALETO]["porta"]))
    if not porta.isdigit():
        sys.exit(f"DB_PORT deve ser numerico: {porta!r}")
    return {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(porta),
        "database": os.getenv("DB_NAME", "base_teste"),
        "user": os.getenv("DB_USER", PADROES[DIALETO]["usuario"]),
        "password": os.getenv("DB_PASSWORD", "troque-me"),
    }


# --------------------------------------------------------------------------
# Conversores de valor (nao dependem do pandas, para poderem ser testados)
# --------------------------------------------------------------------------
def vazio(valor):
    """None, NaN e NaT contam como celula vazia (NaN e NaT sao != de si mesmos)."""
    if valor is None:
        return True
    try:
        return bool(valor != valor)
    except TypeError:  # pandas.NA: comparacao ambigua, tambem e vazio
        return True


def texto(valor):
    if vazio(valor):
        return None
    if isinstance(valor, float) and valor.is_integer():
        valor = int(valor)  # evita '123.0' em codigos numericos
    valor = str(valor).strip()
    return valor or None


def numero(valor):
    if vazio(valor):
        return None
    if isinstance(valor, str):
        valor = valor.strip()
        if not valor:
            return None
        if "," in valor:  # aceita '1.234,56' e '12,5'
            valor = valor.replace(".", "").replace(",", ".")
    convertido = float(valor)
    return None if math.isnan(convertido) else convertido


def inteiro(valor):
    convertido = numero(valor)
    if convertido is None:
        return None
    if not convertido.is_integer():
        raise ValueError(f"valor nao inteiro: {valor!r}")
    return int(convertido)


def data(valor):
    """O original fazia int(valor) num Timestamp, caia no except e devolvia None.

    Aqui aceitamos datetime/Timestamp (o que o pandas entrega), date, o numero
    serial do Excel e texto em DD/MM/AAAA ou AAAA-MM-DD.
    """
    if vazio(valor):
        return None
    if isinstance(valor, datetime):  # pandas.Timestamp herda de datetime
        return valor.date()
    if isinstance(valor, date):
        return valor
    if isinstance(valor, (int, float)):
        return date(1899, 12, 30) + timedelta(days=int(valor))
    bruto = str(valor).strip()
    for formato in ("%d/%m/%Y", "%Y-%m-%d", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(bruto, formato).date()
        except ValueError:
            continue
    raise ValueError(f"data invalida: {valor!r}")


def hora(valor):
    if vazio(valor):
        return "00:00:00"
    if isinstance(valor, (datetime, time)):
        return valor.strftime("%H:%M:%S")
    if isinstance(valor, float):  # fracao de dia do Excel
        segundos = round(valor * 86400) % 86400
        return f"{segundos // 3600:02d}:{segundos % 3600 // 60:02d}:{segundos % 60:02d}"
    return texto(valor)


def id_fornecedor(valor):
    """'F8' -> 8 e 8 -> 8: a planilha usa os dois formatos para o mesmo id."""
    if vazio(valor):
        return None
    if isinstance(valor, str):
        valor = valor.strip().upper().removeprefix("F")
    return inteiro(valor)


def com_padrao(conversor, padrao):
    """Para colunas NOT NULL com DEFAULT no DDL."""

    def converter(valor):
        resultado = conversor(valor)
        return padrao if resultado is None else resultado

    return converter


def coluna(nome_planilha, conversor):
    def extrair(linha):
        return conversor(linha.get(nome_planilha))

    extrair.origem = nome_planilha  # usado para validar se a aba tem a coluna
    return extrair


def pendente(linha):
    """qtde_pendente nao existe na planilha: e o que falta entregar."""
    return (numero(linha.get("qtde_pedida")) or 0) - (numero(linha.get("qtde_entregue")) or 0)


# --------------------------------------------------------------------------
# Mapeamento aba -> tabela. Ordem respeita as FKs (fornecedor primeiro).
# Cada coluna: (coluna no banco, funcao que extrai o valor da linha).
# --------------------------------------------------------------------------
CARGAS = [
    {
        "tabela": "fornecedor",
        "chave": ["idfornecedor"],
        "colunas": [
            ("idfornecedor", coluna("idfornecedor", id_fornecedor)),
            ("razao_social", coluna("razao_social", texto)),
        ],
    },
    {
        "tabela": "produtos_filial",
        "chave": ["filial_id", "produto_id"],
        "colunas": [
            ("filial_id", coluna("filial_id", inteiro)),
            ("produto_id", coluna("idproduto", texto)),  # na planilha: idproduto
            ("descricao", coluna("descricao", texto)),
            ("estoque", coluna("estoque", com_padrao(numero, 0))),
            ("preco_unitario", coluna("preco_unitario", com_padrao(numero, 0))),
            ("preco_compra", coluna("preco_compra", com_padrao(numero, 0))),
            ("preco_venda", coluna("preco_venda", com_padrao(numero, 0))),
            ("idfornecedor", coluna("idfornecedor", id_fornecedor)),
        ],
    },
    {
        "tabela": "pedido_compra",
        "chave": ["pedido_id", "produto_id", "item"],
        "colunas": [
            ("pedido_id", coluna("pedido_id", inteiro)),
            ("data_pedido", coluna("data_pedido", data)),
            ("item", coluna("item", com_padrao(inteiro, 0))),
            ("produto_id", coluna("produto_id", texto)),
            ("descricao_produto", coluna("descricao_produto", texto)),
            ("ordem_compra", coluna("ordem_compra", com_padrao(inteiro, 0))),
            ("qtde_pedida", coluna("qtde_pedida", numero)),
            ("filial_id", coluna("filial_id", inteiro)),
            ("data_entrega", coluna("data_entrega", data)),
            ("qtde_entregue", coluna("qtde_entregue", com_padrao(numero, 0))),
            ("qtde_pendente", pendente),
            ("preco_compra", coluna("preco_compra", com_padrao(numero, 0))),
            ("fornecedor_id", coluna("fornecedor_id", id_fornecedor)),
        ],
    },
    {
        "tabela": "entradas_mercadoria",
        "chave": ["ordem_compra", "item", "produto_id", "nro_nfe"],
        "colunas": [
            ("data_entrada", coluna("data_entrada", data)),
            ("nro_nfe", coluna("nro_nfe", texto)),
            ("item", coluna("item", com_padrao(inteiro, 0))),
            ("produto_id", coluna("produto_id", texto)),
            ("descricao_produto", coluna("descricao_produto", texto)),
            ("ordem_compra", coluna("ordem_compra", com_padrao(inteiro, 0))),
            ("qtde_recebida", coluna("qtde_recebida", numero)),
            ("filial_id", coluna("filial_id", inteiro)),
            ("custo_unitario", coluna("custo_unitario", com_padrao(numero, 0))),
        ],
    },
    {
        "tabela": "venda",
        "chave": ["filial_id", "venda_id", "data_emissao", "produto_id", "item", "horariomov"],
        "colunas": [
            ("venda_id", coluna("venda_id", inteiro)),
            ("data_emissao", coluna("data_emissao", data)),
            ("horariomov", coluna("horariomov", hora)),
            ("produto_id", coluna("produto_id", texto)),
            ("qtde_vendida", coluna("qtde_vendida", numero)),
            ("valor_unitario", coluna("valor_unitario", com_padrao(numero, 0))),
            ("filial_id", coluna("filial_id", com_padrao(inteiro, 1))),
            ("item", coluna("item", com_padrao(inteiro, 0))),
            ("unidade_medida", coluna("unidade_medida", texto)),
        ],
    },
]


# --------------------------------------------------------------------------
# SQL por dialeto
# --------------------------------------------------------------------------
def nome_tabela(tabela):
    return f"public.{tabela}" if DIALETO == "postgres" else tabela


def montar_insert(carga):
    colunas = [nome for nome, _ in carga["colunas"]]
    marcadores = ", ".join(["%s"] * len(colunas))
    sql = f"INSERT INTO {nome_tabela(carga['tabela'])} ({', '.join(colunas)}) VALUES ({marcadores})"
    if DIALETO == "postgres":
        return f"{sql} ON CONFLICT ({', '.join(carga['chave'])}) DO NOTHING"
    primeira = carga["chave"][0]  # no MySQL: ignora a duplicata sem mudar nada
    return f"{sql} ON DUPLICATE KEY UPDATE {primeira} = {primeira}"


def conectar(cfg):
    if DIALETO == "postgres":
        import psycopg2

        return psycopg2.connect(
            host=cfg["host"], port=cfg["port"], dbname=cfg["database"],
            user=cfg["user"], password=cfg["password"], connect_timeout=10,
        )
    import pymysql

    return pymysql.connect(
        host=cfg["host"], port=cfg["port"], database=cfg["database"],
        user=cfg["user"], password=cfg["password"], charset="utf8mb4",
        connect_timeout=10, autocommit=False,
    )


# --------------------------------------------------------------------------
# Leitura da planilha
# --------------------------------------------------------------------------
def ler_aba(aba, colunas_esperadas, avisos):
    """Le a aba pelo NOME das colunas (o original usava posicao: df.iloc[:, :12]).

    Colunas sem cabecalho ('Unnamed: N') sao descartadas, mas se tiverem dados
    isso vira um aviso: na aba pedido_compra ha um bloco de valores em M..W.
    """
    import pandas as pd

    df = pd.read_excel(ARQUIVO, sheet_name=aba, dtype=object)
    df = df.dropna(how="all")
    df.columns = [str(c).strip() for c in df.columns]

    sem_cabecalho = [c for c in df.columns if c.startswith("Unnamed")]
    com_dados = df[sem_cabecalho].dropna(how="all") if sem_cabecalho else df.iloc[0:0]
    if len(com_dados):
        linhas = ", ".join(str(i + 2) for i in com_dados.index)
        avisos.append(
            f"aba {aba}: {len(sem_cabecalho)} colunas sem cabecalho tem dados nas "
            f"linhas {linhas} da planilha; foram ignoradas (ver docs/parte4_validacao.md)"
        )
    df = df.drop(columns=sem_cabecalho)

    faltando = sorted(set(colunas_esperadas) - set(df.columns))
    if faltando:
        sys.exit(f"Aba {aba}: colunas ausentes na planilha: {faltando}")
    return df


def colunas_lidas(carga):
    """Nomes de coluna da planilha que a carga usa (para validar a aba)."""
    return [e.origem for _, e in carga["colunas"] if hasattr(e, "origem")]


# --------------------------------------------------------------------------
# Carga
# --------------------------------------------------------------------------
def inserir_linha(cur, sql, valores):
    """Cada linha roda num SAVEPOINT: um erro desfaz so aquela linha.

    O original chamava conn.rollback() a cada erro, o que apagava tambem as
    linhas boas ainda nao confirmadas.
    """
    cur.execute("SAVEPOINT linha")
    try:
        cur.execute(sql, valores)
        inseridas = max(cur.rowcount, 0)  # ler antes do RELEASE, que zera o rowcount
    except Exception:
        cur.execute("ROLLBACK TO SAVEPOINT linha")
        raise
    finally:
        cur.execute("RELEASE SAVEPOINT linha")
    return inseridas


def carregar(cur, carga, avisos, rejeitadas):
    df = ler_aba(carga["tabela"], colunas_lidas(carga), avisos)
    sql = montar_insert(carga)
    inseridas = 0
    for indice, registro in df.iterrows():
        linha = registro.to_dict()
        rotulo = f"{carga['tabela']} linha {indice + 2}"
        try:
            valores = tuple(extrair(linha) for _, extrair in carga["colunas"])
            inseridas += inserir_linha(cur, sql, valores)
        except Exception as erro:  # registra e segue para a proxima linha
            rejeitadas.append(f"{rotulo}: {str(erro).strip()}")
    return len(df), inseridas


def ajustar_sequencia(cur):
    """Os ids 1..20 foram gravados explicitamente; a identidade precisa saber disso."""
    if DIALETO != "postgres":
        return  # no MySQL o AUTO_INCREMENT se ajusta sozinho
    cur.execute(
        "SELECT setval(pg_get_serial_sequence('public.fornecedor', 'idfornecedor'), "
        "GREATEST((SELECT COALESCE(MAX(idfornecedor), 0) FROM public.fornecedor), 20))"
    )


def main():
    cfg = config_banco()
    if not os.path.exists(ARQUIVO):
        sys.exit(f"Planilha nao encontrada: {ARQUIVO}")

    banco = PADROES[DIALETO]["nome"]
    print(f"Planilha: {ARQUIVO}")
    print(f"Destino:  {banco} {cfg['user']}@{cfg['host']}:{cfg['port']}/{cfg['database']}\n")

    try:
        conn = conectar(cfg)
    except Exception as erro:
        sys.exit(f"Nao foi possivel conectar no {banco}: {erro}")

    avisos, rejeitadas, resumo = [], [], []
    try:
        with conn.cursor() as cur:
            for carga in CARGAS:
                na_planilha, inseridas = carregar(cur, carga, avisos, rejeitadas)
                cur.execute(f"SELECT COUNT(*) FROM {nome_tabela(carga['tabela'])}")
                no_banco = cur.fetchone()[0]
                resumo.append((carga["tabela"], na_planilha, inseridas, no_banco))
            ajustar_sequencia(cur)
        conn.commit()
    except Exception as erro:
        conn.rollback()
        sys.exit(f"Importacao abortada, nada foi gravado: {erro}")
    finally:
        conn.close()

    # Conferencia: o original imprimia len(df) como "inseridos", mesmo com erro.
    print(f"{'tabela':<22}{'planilha':>9}{'inseridas':>11}{'no banco':>10}  situacao")
    divergente = False
    for tabela, na_planilha, inseridas, no_banco in resumo:
        ok = na_planilha == no_banco
        divergente |= not ok
        print(f"{tabela:<22}{na_planilha:>9}{inseridas:>11}{no_banco:>10}  {'OK' if ok else 'DIVERGENTE'}")

    for titulo, itens in (("Avisos", avisos), ("Linhas rejeitadas", rejeitadas)):
        if itens:
            print(f"\n{titulo} ({len(itens)}):")
            for item in itens:
                print(f"  - {item}")

    if divergente or rejeitadas:
        print("\nImportacao terminou com pendencias.")
        sys.exit(1)
    print("\nImportacao concluida: todas as tabelas conferem com a planilha.")


if __name__ == "__main__":
    main()
