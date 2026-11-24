# Integração de Dados — ADS242N01

**Dupla:** Franciane Nogueira e John Erik

## Integrantes

| Integrante | GitHub |
|---|---|
| Franciane Nogueira | [@francinogueira0611-ctrl](https://github.com/francinogueira0611-ctrl) |
| John Erik | [@jaserik](https://github.com/jaserik) |

## Sobre o projeto

Este projeto foi desenvolvido para a atividade de Integração de Dados da disciplina ADS242N01.

O objetivo é realizar a integração dos dados de uma planilha Excel para um banco de dados PostgreSQL 18, utilizando Python para automatizar a leitura, o tratamento e a importação dos registros.

A planilha `dados/base_teste.xlsx` possui cinco abas, totalizando 122 registros, distribuídos entre fornecedores, produtos por filial, pedidos de compra, entradas de mercadoria e vendas.

O processo contempla a criação da estrutura relacional, importação dos dados, execução de consultas SQL, transformações e validação das informações.

## Estrutura do repositório

```text
bd-integracao-dados-ads242n01/
├── dados/
│   └── base_teste.xlsx
├── scripts/
│   └── importar.py
├── sql/
│   ├── 01_ddl_postgres.sql
│   ├── 02_consultas.sql
│   ├── 03_transformacoes.sql
│   └── 04_validacao.sql
├── docs/
│   ├── parte1_importacao.md
│   └── parte4_validacao.md
└── README.md
```

## Tecnologias utilizadas

- PostgreSQL 18: gerenciamento e armazenamento dos dados.
- Python: execução do processo de importação.
- pandas: leitura e manipulação dos dados.
- openpyxl: leitura das planilhas Excel.
- psycopg2: conexão entre Python e PostgreSQL.
- SQL: criação de tabelas, consultas, transformações e validações.

## Como executar

### 1. Criar o banco de dados

No PostgreSQL, execute:

```sql
CREATE DATABASE bd_integracao;
```

### 2. Instalar as dependências

Com o Python instalado, execute:

```bash
pip install pandas openpyxl psycopg2-binary
```

### 3. Configurar as variáveis de ambiente

Configure as informações de conexão com o PostgreSQL:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bd_integracao
DB_USER=postgres
DB_PASSWORD=sua_senha
```

Substitua `sua_senha` pela senha configurada no PostgreSQL.

### 4. Criar as tabelas

Conecte-se ao banco `bd_integracao` e execute o arquivo `sql/01_ddl_postgres.sql`.

### 5. Executar a importação

Na raiz do repositório, execute:

```bash
python scripts/importar.py
```

O script realiza a leitura das cinco abas da planilha, aplica os tratamentos necessários e importa os registros para as respectivas tabelas do PostgreSQL.

## Resultado da importação

A importação contempla os 122 registros presentes na planilha, distribuídos entre as cinco tabelas do banco de dados.

| Tabela | Registros na planilha | Registros no banco |
|---|---:|---:|
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |
| **Total** | **122** | **122** |

## Consultas e transformações

Os arquivos SQL estão organizados da seguinte maneira:

- `01_ddl_postgres.sql`: criação da estrutura do banco de dados e definição dos relacionamentos.
- `02_consultas.sql`: consultas para análise dos dados.
- `03_transformacoes.sql`: transformações e tratamentos dos dados.
- `04_validacao.sql`: consultas para identificação de inconsistências e validação dos registros.

## Validação dos dados

A validação tem como objetivo verificar a integridade e a consistência dos dados importados, identificando possíveis problemas nos registros e relacionamentos entre as tabelas.

Os resultados detalhados, incluindo as consultas utilizadas, as contagens de registros com inconsistências e os indicadores analisados, estão documentados em:

[`docs/parte4_validacao.md`](docs/parte4_validacao.md)

## Prazo de entrega

**24/11/2026**
