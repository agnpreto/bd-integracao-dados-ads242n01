
# ============================================================
# IMPORTACAO COMPLETA DOS DADOS - POSTGRESQL
# Projeto: Integracao de Dados - ADS242N01
# Alunas: Franciane de Carvalho Nogueira e John Erik
# ============================================================

import os
import pandas as pd
import psycopg2

from datetime import datetime, date, timedelta, time


# ------------------------------------------------------------
# CONFIGURACOES
# ------------------------------------------------------------

ARQUIVO = "dados/base_teste.xlsx"

DB = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 5432)),
    "database": os.getenv("DB_NAME", "postgres"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "exemplo")
}


# ------------------------------------------------------------
# FUNCOES DE CONVERSAO
# ------------------------------------------------------------

def vazio(valor):
    return pd.isna(valor)


def texto(valor):
    if vazio(valor):
        return None

    if isinstance(valor, float) and valor.is_integer():
        return str(int(valor))

    return str(valor).strip()


def numero(valor, padrao=None):
    if vazio(valor):
        return padrao

    return float(valor)


def inteiro(valor, padrao=None):
    if vazio(valor):
        return padrao

    return int(float(valor))


def excel_para_data(valor):
    if vazio(valor):
        return None

    if isinstance(valor, (datetime, date)):
        return valor.date() if isinstance(valor, datetime) else valor

    if isinstance(valor, (int, float)):
        return (
            datetime(1899, 12, 30)
            + timedelta(days=float(valor))
        ).date()

    data = pd.to_datetime(valor, errors="coerce")

    if pd.isna(data):
        return None

    return data.date()


def normalizar_hora(valor):
    if vazio(valor):
        return "00:00:00"

    if isinstance(valor, (datetime, time)):
        return valor.strftime("%H:%M:%S")

    if isinstance(valor, (int, float)):
        segundos = int(float(valor) * 86400) % 86400
        horas = segundos // 3600
        minutos = (segundos % 3600) // 60
        segundos = segundos % 60

        return f"{horas:02d}:{minutos:02d}:{segundos:02d}"

    return str(valor).strip()[:8]


# ------------------------------------------------------------
# IMPORTACAO COM CONTROLE DE RESULTADOS
# ------------------------------------------------------------

def importar_aba(conn, nome, consulta, converter):
    print(f"\nImportando {nome}...")

    df = pd.read_excel(ARQUIVO, sheet_name=nome)
    df.columns = df.columns.str.strip()

    inseridos = 0
    duplicados = 0
    erros = 0

    with conn.cursor() as cur:
        for indice, linha in df.iterrows():

            cur.execute("SAVEPOINT linha_importacao")

            try:
                dados = converter(linha)

                cur.execute(consulta, dados)

                if cur.rowcount == 1:
                    inseridos += 1
                else:
                    duplicados += 1

                cur.execute("RELEASE SAVEPOINT linha_importacao")

            except Exception as erro:
                cur.execute("ROLLBACK TO SAVEPOINT linha_importacao")
                cur.execute("RELEASE SAVEPOINT linha_importacao")

                erros += 1

                print(
                    f"Erro em {nome}, linha {indice + 2}: {erro}"
                )

    conn.commit()

    print(f"Linhas na planilha: {len(df)}")
    print(f"Inseridos: {inseridos}")
    print(f"Duplicados ignorados: {duplicados}")
    print(f"Erros: {erros}")

    return {
        "planilha": nome,
        "total": len(df),
        "inseridos": inseridos,
        "duplicados": duplicados,
        "erros": erros
    }


# ------------------------------------------------------------
# 1. FORNECEDOR
# ------------------------------------------------------------

def converter_fornecedor(row):
    return (
        texto(row["idfornecedor"]),
        texto(row["razao_social"])
    )


SQL_FORNECEDOR = """
    INSERT INTO public.fornecedor
        (idfornecedor, razao_social)
    VALUES (%s, %s)
    ON CONFLICT (idfornecedor) DO NOTHING
"""


# ------------------------------------------------------------
# 2. PRODUTOS_FILIAL
# ------------------------------------------------------------

def converter_produto(row):
    return (
        inteiro(row["filial_id"]),
        texto(row["idproduto"]),
        texto(row["descricao"]),
        numero(row["estoque"], 0),
        numero(row["preco_unitario"], 0),
        numero(row["preco_compra"], 0),
        numero(row["preco_venda"], 0),
        texto(row["idfornecedor"])
    )


SQL_PRODUTOS = """
    INSERT INTO public.produtos_filial
        (filial_id, produto_id, descricao, estoque,
         preco_unitario, preco_compra, preco_venda, idfornecedor)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT (filial_id, produto_id) DO NOTHING
"""


# ------------------------------------------------------------
# 3. PEDIDO_COMPRA
# ------------------------------------------------------------

def converter_pedido(row):
    pedida = numero(row["qtde_pedida"])
    entregue = numero(row["qtde_entregue"], 0)

    pendente = (
        pedida - entregue
        if pedida is not None
        else 0
    )

    return (
        numero(row["pedido_id"], 0),
        excel_para_data(row["data_pedido"]),
        numero(row["item"], 0),
        texto(row["produto_id"]),
        texto(row["descricao_produto"]),
        numero(row["ordem_compra"], 0),
        pedida,
        inteiro(row["filial_id"]),
        excel_para_data(row["data_entrega"]),
        entregue,
        pendente,
        numero(row["preco_compra"], 0),
        inteiro(row["fornecedor_id"], 0)
    )


SQL_PEDIDO = """
    INSERT INTO public.pedido_compra
        (pedido_id, data_pedido, item, produto_id,
         descricao_produto, ordem_compra, qtde_pedida,
         filial_id, data_entrega, qtde_entregue,
         qtde_pendente, preco_compra, fornecedor_id)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s)
    ON CONFLICT (pedido_id, produto_id, item) DO NOTHING
"""


# ------------------------------------------------------------
# 4. ENTRADAS_MERCADORIA
# ------------------------------------------------------------

def converter_entrada(row):
    return (
        excel_para_data(row["data_entrada"]),
        texto(row["nro_nfe"]),
        numero(row["item"], 0),
        texto(row["produto_id"]),
        texto(row["descricao_produto"]),
        numero(row["ordem_compra"], 0),
        numero(row["qtde_recebida"]),
        inteiro(row["filial_id"]),
        numero(row["custo_unitario"], 0)
    )


SQL_ENTRADA = """
    INSERT INTO public.entradas_mercadoria
        (data_entrada, nro_nfe, item, produto_id,
         descricao_produto, ordem_compra, qtde_recebida,
         filial_id, custo_unitario)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT (ordem_compra, item, produto_id, nro_nfe)
    DO NOTHING
"""


# ------------------------------------------------------------
# 5. VENDA
# ------------------------------------------------------------

def converter_venda(row):
    return (
        inteiro(row["venda_id"]),
        excel_para_data(row["data_emissao"]),
        normalizar_hora(row["horariomov"]),
        texto(row["produto_id"]),
        numero(row["qtde_vendida"]),
        numero(row["valor_unitario"], 0),
        inteiro(row["filial_id"], 1),
        inteiro(row["item"], 0),
        texto(row["unidade_medida"])
    )


SQL_VENDA = """
    INSERT INTO public.venda
        (venda_id, data_emissao, horariomov, produto_id,
         qtde_vendida, valor_unitario, filial_id, item,
         unidade_medida)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT
        (filial_id, venda_id, data_emissao,
         produto_id, item, horariomov)
    DO NOTHING
"""


# ------------------------------------------------------------
# EXECUCAO PRINCIPAL
# ------------------------------------------------------------

def main():

    if not os.path.exists(ARQUIVO):
        raise FileNotFoundError(
            f"Planilha nao encontrada: {ARQUIVO}"
        )

    print("=" * 55)
    print("INICIO DA IMPORTACAO DE DADOS")
    print("=" * 55)

    conn = None
    resultados = []

    try:
        print("\nConectando ao PostgreSQL...")

        conn = psycopg2.connect(**DB)

        print("Conexao estabelecida!")

        etapas = [
            ("fornecedor", SQL_FORNECEDOR, converter_fornecedor),
            ("produtos_filial", SQL_PRODUTOS, converter_produto),
            ("pedido_compra", SQL_PEDIDO, converter_pedido),
            ("entradas_mercadoria", SQL_ENTRADA, converter_entrada),
            ("venda", SQL_VENDA, converter_venda)
        ]

        for nome, consulta, conversor in etapas:
            resultado = importar_aba(
                conn, nome, consulta, conversor
            )

            resultados.append(resultado)

        print("\n" + "=" * 55)
        print("RESUMO GERAL DA IMPORTACAO")
        print("=" * 55)

        for resultado in resultados:
            print(
                f"{resultado['planilha']}: "
                f"{resultado['inseridos']} inseridos, "
                f"{resultado['duplicados']} duplicados, "
                f"{resultado['erros']} erros"
            )

        total_inseridos = sum(
            r["inseridos"] for r in resultados
        )

        total_erros = sum(
            r["erros"] for r in resultados
        )

        print("-" * 55)
        print(f"Total realmente inserido: {total_inseridos}")
        print(f"Total de erros: {total_erros}")

        if total_erros > 0:
            print("IMPORTACAO CONCLUIDA COM PENDENCIAS.")
        else:
            print("PROCESSAMENTO FINALIZADO SEM ERROS.")

    except Exception as erro:
        print(f"\nERRO NA IMPORTACAO: {erro}")

        if conn:
            conn.rollback()

        raise

    finally:
        if conn:
            conn.close()
            print("\nConexao encerrada.")


if __name__ == "__main__":
    main()
