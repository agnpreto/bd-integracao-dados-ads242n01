
import os
import pandas as pd
import psycopg2

ARQUIVO = os.path.join("dados", "base_teste.xlsx")

ABAS = [
    "fornecedor",
    "produtos_filial",
    "pedido_compra",
    "entradas_mercadoria",
    "venda",
]


def conectar():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "postgres"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", ""),
    )


def importar():
    if not os.path.exists(ARQUIVO):
        raise FileNotFoundError(f"Arquivo não encontrado: {ARQUIVO}")

    planilha = pd.ExcelFile(ARQUIVO)
    print("Abas encontradas:", planilha.sheet_names)

    abas_ausentes = [aba for aba in ABAS if aba not in planilha.sheet_names]

    if abas_ausentes:
        print("Abas ausentes:", ", ".join(abas_ausentes))
        print("Nenhum dado será inventado ou importado dessas abas.")

    if "venda" not in planilha.sheet_names:
        raise ValueError("A planilha não contém a aba obrigatória: venda")

    dados = pd.read_excel(ARQUIVO, sheet_name="venda")
    dados.columns = [str(c).strip().lower() for c in dados.columns]

    obrigatorias = [
        "venda_id", "data_emissao", "horariomov",
        "produto_id", "qtde_vendida", "valor_unitario",
        "filial_id", "item", "unidade_medida"
    ]

    faltantes = [c for c in obrigatorias if c not in dados.columns]

    if faltantes:
        raise ValueError(f"Colunas ausentes em venda: {faltantes}")

    if dados[obrigatorias].isnull().any().any():
        raise ValueError("Existem campos obrigatórios vazios na aba venda.")

    conexao = conectar()

    try:
        with conexao.cursor() as cursor:
            inseridos = 0

            for _, linha in dados.iterrows():
                cursor.execute("""
                    INSERT INTO venda (
                        venda_id, data_emissao, horariomov,
                        produto_id, qtde_vendida, valor_unitario,
                        filial_id, item, unidade_medida
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT DO NOTHING
                """, (
                    int(linha["venda_id"]),
                    pd.to_datetime(linha["data_emissao"]).date(),
                    str(linha["horariomov"]),
                    str(linha["produto_id"]),
                    float(linha["qtde_vendida"]),
                    float(str(linha["valor_unitario"]).replace(",", ".")),
                    int(linha["filial_id"]),
                    int(linha["item"]),
                    str(linha["unidade_medida"])
                ))

                inseridos += cursor.rowcount

        conexao.commit()

        print(f"Registros encontrados em venda: {len(dados)}")
        print(f"Registros efetivamente inseridos: {inseridos}")
        print("Importação da aba venda finalizada.")

    except Exception:
        conexao.rollback()
        raise
    finally:
        conexao.close()


if __name__ == "__main__":
    importar()
