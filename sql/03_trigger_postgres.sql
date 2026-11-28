-- 03_trigger_postgres.sql | execute após 01_ddl_postgres.sql
CREATE OR REPLACE FUNCTION preencher_idfornecedor_produto()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.codigo_fornecedor IS NULL OR BTRIM(NEW.codigo_fornecedor) = '' THEN
        NEW.idfornecedor := NULL;
    ELSE
        SELECT f.idfornecedor INTO NEW.idfornecedor
        FROM fornecedor f
        WHERE f.codigo_fornecedor = BTRIM(NEW.codigo_fornecedor);
        IF NEW.idfornecedor IS NULL THEN
            RAISE EXCEPTION 'Fornecedor % não cadastrado', NEW.codigo_fornecedor;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_produtos_fornecedor
BEFORE INSERT OR UPDATE OF codigo_fornecedor ON produtos_filial
FOR EACH ROW EXECUTE FUNCTION preencher_idfornecedor_produto();
