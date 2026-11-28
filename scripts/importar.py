"""Importa base_teste.xlsx para MySQL 8+ ou PostgreSQL.

Dependências:
  pip install pandas openpyxl psycopg2-binary mysql-connector-python
Configuração por variáveis de ambiente:
  DB_ENGINE=postgres|mysql (padrão postgres)
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, XLSX_PATH
Execute primeiro o DDL e as triggers correspondentes em sql/.
A importação limpa as tabelas-alvo na ordem segura e carrega os dados novamente.
"""
import os, json, math
from datetime import date, datetime
import pandas as pd

ENGINE = os.getenv('DB_ENGINE', 'postgres').lower()
XLSX = os.getenv('XLSX_PATH', 'base_teste.xlsx')
CFG = dict(host=os.getenv('DB_HOST','localhost'), user=os.getenv('DB_USER','postgres'),
           password=os.getenv('DB_PASSWORD',''), database=os.getenv('DB_NAME','integracao_dados'))
if ENGINE == 'postgres':
    import psycopg2
    CFG['port'] = int(os.getenv('DB_PORT','5432'))
    conn = psycopg2.connect(**CFG)
elif ENGINE == 'mysql':
    import mysql.connector
    CFG['port'] = int(os.getenv('DB_PORT','3306'))
    conn = mysql.connector.connect(**CFG)
else:
    raise ValueError('DB_ENGINE deve ser postgres ou mysql')

cur = conn.cursor()

def clean(v):
    if pd.isna(v): return None
    if isinstance(v, pd.Timestamp): return v.date()
    if hasattr(v, 'item'):
        try: v=v.item()
        except Exception: pass
    if isinstance(v, float) and not math.isfinite(v): return None
    return v

def s(v):
    v=clean(v)
    return None if v is None else str(v).strip()

def n(v, default=None):
    v=clean(v)
    return default if v is None else int(v)

def dec(v, default=None):
    v=clean(v)
    return default if v is None else float(v)

def execute_many_insert(table, cols, rows):
    marks=','.join(['%s']*len(cols))
    names=','.join(cols)
    cur.executemany(f'INSERT INTO {table} ({names}) VALUES ({marks})', rows)

try:
    # Apaga dependentes primeiro para permitir uma nova carga completa.
    for t in ['venda','entradas_mercadoria','pedido_compra_extras','pedido_compra','produtos_filial','fornecedor']:
        cur.execute(f'DELETE FROM {t}')
    conn.commit()

    # Fornecedor: extrai o número de F1...F20 e o grava explicitamente como PK.
    df=pd.read_excel(XLSX, sheet_name='fornecedor')
    rows=[]
    for _,r in df.iterrows():
        code=s(r['idfornecedor'])
        if not code or not code.upper().startswith('F') or not code[1:].isdigit():
            raise ValueError(f'Código de fornecedor inválido: {code}')
        rows.append((int(code[1:]), code, s(r['razao_social'])))
    execute_many_insert('fornecedor',['idfornecedor','codigo_fornecedor','razao_social'],rows)
    counts={'fornecedor':len(rows)}; conn.commit()

    # Produtos: a trigger procura codigo_fornecedor e preenche idfornecedor.
    df=pd.read_excel(XLSX, sheet_name='produtos_filial')
    rows=[]
    for _,r in df.iterrows():
        rows.append((n(r['filial_id']),s(r['idproduto']),s(r['descricao']),dec(r['estoque'],0),
                     dec(r['preco_unitario'],0),dec(r['preco_compra'],0),dec(r['preco_venda'],0),s(r['idfornecedor'])))
    execute_many_insert('produtos_filial',['filial_id','produto_id','descricao','estoque','preco_unitario','preco_compra','preco_venda','codigo_fornecedor'],rows)
    counts['produtos_filial']=len(rows); conn.commit()

    # Pedidos: as 12 colunas nomeadas alimentam a tabela; qtde_pendente é calculada.
    df=pd.read_excel(XLSX, sheet_name='pedido_compra')
    rows=[]; extras=[]
    for ix,r in df.iterrows():
        ped=dec(r['qtde_pedida']); ent=dec(r['qtde_entregue'],0)
        pend=max((ped or 0)-ent,0)
        rows.append((n(r['pedido_id']),clean(r['data_pedido']),n(r['item'],0),s(r['produto_id']),s(r['descricao_produto']),
                     n(r['ordem_compra'],0),ped,n(r['filial_id']),clean(r['data_entrega']),ent,pend,
                     dec(r['preco_compra'],0),n(r['fornecedor_id'])))
        extra={str(c):clean(r[c]) for c in df.columns[12:] if clean(r[c]) is not None}
        if extra:
            for k,v in list(extra.items()):
                if isinstance(v,(date,datetime)): extra[k]=v.isoformat()
            extras.append((int(ix)+2,json.dumps(extra,ensure_ascii=False,default=str)))
    execute_many_insert('pedido_compra',['pedido_id','data_pedido','item','produto_id','descricao_produto','ordem_compra','qtde_pedida','filial_id','data_entrega','qtde_entregue','qtde_pendente','preco_compra','fornecedor_id'],rows)
    if extras: execute_many_insert('pedido_compra_extras',['linha_excel','dados_extras'],extras)
    counts['pedido_compra']=len(rows); counts['pedido_compra_extras']=len(extras); conn.commit()

    df=pd.read_excel(XLSX, sheet_name='entradas_mercadoria')
    rows=[]
    for _,r in df.iterrows():
        rows.append((clean(r['data_entrada']),s(r['nro_nfe']),n(r['item'],0),s(r['produto_id']),s(r['descricao_produto']),
                     n(r['ordem_compra'],0),dec(r['qtde_recebida']),n(r['filial_id']),dec(r['custo_unitario'],0)))
    execute_many_insert('entradas_mercadoria',['data_entrada','nro_nfe','item','produto_id','descricao_produto','ordem_compra','qtde_recebida','filial_id','custo_unitario'],rows)
    counts['entradas_mercadoria']=len(rows); conn.commit()

    df=pd.read_excel(XLSX, sheet_name='venda')
    rows=[]
    for _,r in df.iterrows():
        hora=s(r['horariomov']) or '00:00:00'
        rows.append((n(r['venda_id']),clean(r['data_emissao']),hora,s(r['produto_id']),dec(r['qtde_vendida']),
                     dec(r['valor_unitario'],0),n(r['filial_id'],1),n(r['item'],0),s(r['unidade_medida'])))
    execute_many_insert('venda',['venda_id','data_emissao','horariomov','produto_id','qtde_vendida','valor_unitario','filial_id','item','unidade_medida'],rows)
    counts['venda']=len(rows); conn.commit()

    if ENGINE=='postgres':
        cur.execute("SELECT setval(pg_get_serial_sequence('fornecedor','idfornecedor'), COALESCE((SELECT MAX(idfornecedor) FROM fornecedor),1), true)")
        conn.commit()
    print('Importação concluída. Linhas inseridas:', counts)
except Exception:
    conn.rollback()
    raise
finally:
    cur.close(); conn.close()
