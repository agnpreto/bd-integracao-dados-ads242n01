-- 03_trigger_mysql.sql | execute após 01_ddl_mysql.sql
DELIMITER $$
CREATE TRIGGER trg_produtos_fornecedor_bi
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.codigo_fornecedor IS NULL OR TRIM(NEW.codigo_fornecedor) = '' THEN
        SET NEW.idfornecedor = NULL;
    ELSE
        SET NEW.idfornecedor = (
            SELECT idfornecedor FROM fornecedor
            WHERE codigo_fornecedor = TRIM(NEW.codigo_fornecedor)
            LIMIT 1
        );
        IF NEW.idfornecedor IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Código de fornecedor não cadastrado';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_produtos_fornecedor_bu
BEFORE UPDATE ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.codigo_fornecedor IS NULL OR TRIM(NEW.codigo_fornecedor) = '' THEN
        SET NEW.idfornecedor = NULL;
    ELSE
        SET NEW.idfornecedor = (
            SELECT idfornecedor FROM fornecedor
            WHERE codigo_fornecedor = TRIM(NEW.codigo_fornecedor)
            LIMIT 1
        );
        IF NEW.idfornecedor IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Código de fornecedor não cadastrado';
        END IF;
    END IF;
END$$
DELIMITER ;
