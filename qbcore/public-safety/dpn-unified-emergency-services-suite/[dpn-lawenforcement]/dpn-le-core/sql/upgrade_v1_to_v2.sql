-- Run only when upgrading an existing v1 installation.
DROP PROCEDURE IF EXISTS `dpn_core_add_column_if_missing`;
DELIMITER $$
CREATE PROCEDURE `dpn_core_add_column_if_missing`(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition TEXT)
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
CALL `dpn_core_add_column_if_missing`('dpn_le_officer_logs', 'action', 'VARCHAR(32) NOT NULL DEFAULT ''UPDATE'' AFTER `status`');
DROP PROCEDURE IF EXISTS `dpn_core_add_column_if_missing`;

-- Then run ../../../install/legacy-v2/dpn-lawenforcement-v2.sql to create any missing v2 tables.
