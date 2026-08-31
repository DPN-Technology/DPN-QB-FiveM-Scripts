DROP PROCEDURE IF EXISTS `dpn_dispatch_add_column_if_missing`;
DELIMITER $$
CREATE PROCEDURE `dpn_dispatch_add_column_if_missing`(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition TEXT)
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table)
       AND NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table AND COLUMN_NAME = p_column) THEN
        SET @dpn_sql = CONCAT('ALTER TABLE `', REPLACE(p_table, '`', '``'), '` ADD COLUMN `', REPLACE(p_column, '`', '``'), '` ', p_definition);
        PREPARE dpn_stmt FROM @dpn_sql;
        EXECUTE dpn_stmt;
        DEALLOCATE PREPARE dpn_stmt;
    END IF;
END$$
DELIMITER ;
CALL `dpn_dispatch_add_column_if_missing`('dpn_digital_dispatch_calls', 'caller_name', 'VARCHAR(128) NULL AFTER `created_by`');
CALL `dpn_dispatch_add_column_if_missing`('dpn_digital_dispatch_calls', 'departments', 'LONGTEXT NULL AFTER `assigned_units`');
CALL `dpn_dispatch_add_column_if_missing`('dpn_digital_dispatch_calls', 'metadata', 'LONGTEXT NULL AFTER `departments`');
CALL `dpn_dispatch_add_column_if_missing`('dpn_digital_dispatch_units', 'department', 'VARCHAR(32) NULL AFTER `job`');
DROP PROCEDURE IF EXISTS `dpn_dispatch_add_column_if_missing`;
