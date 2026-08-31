-- DPN Medical Records v5.0.1 compatibility migration
-- Safe for fresh installs and legacy tables. Existing data is preserved.

CREATE TABLE IF NOT EXISTS `dpn_medical_records` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `patient_cid` VARCHAR(64) NULL,
  `entry_type` VARCHAR(64) NULL DEFAULT 'note',
  `author_cid` VARCHAR(64) NULL,
  `entry_data` LONGTEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_records_patient` (`patient_cid`),
  KEY `idx_records_type` (`entry_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP PROCEDURE IF EXISTS `dpn_migrate_medical_records_v501`;
DELIMITER $$
CREATE PROCEDURE `dpn_migrate_medical_records_v501`()
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'patient_cid'
  ) THEN
    ALTER TABLE `dpn_medical_records` ADD COLUMN `patient_cid` VARCHAR(64) NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'entry_type'
  ) THEN
    ALTER TABLE `dpn_medical_records` ADD COLUMN `entry_type` VARCHAR(64) NULL DEFAULT 'note';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'author_cid'
  ) THEN
    ALTER TABLE `dpn_medical_records` ADD COLUMN `author_cid` VARCHAR(64) NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'entry_data'
  ) THEN
    ALTER TABLE `dpn_medical_records` ADD COLUMN `entry_data` LONGTEXT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'created_at'
  ) THEN
    ALTER TABLE `dpn_medical_records` ADD COLUMN `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP;
  END IF;

  -- Backfill from common legacy schemas.
  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'citizenid'
  ) THEN
    UPDATE `dpn_medical_records`
    SET `patient_cid` = CAST(`citizenid` AS CHAR)
    WHERE (`patient_cid` IS NULL OR `patient_cid` = '') AND `citizenid` IS NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'patient_identifier'
  ) THEN
    UPDATE `dpn_medical_records`
    SET `patient_cid` = CAST(`patient_identifier` AS CHAR)
    WHERE (`patient_cid` IS NULL OR `patient_cid` = '') AND `patient_identifier` IS NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'type'
  ) THEN
    UPDATE `dpn_medical_records`
    SET `entry_type` = CAST(`type` AS CHAR)
    WHERE (`entry_type` IS NULL OR `entry_type` = '') AND `type` IS NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'record_type'
  ) THEN
    UPDATE `dpn_medical_records`
    SET `entry_type` = CAST(`record_type` AS CHAR)
    WHERE (`entry_type` IS NULL OR `entry_type` = '') AND `record_type` IS NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'author'
  ) THEN
    UPDATE `dpn_medical_records`
    SET `author_cid` = CAST(`author` AS CHAR)
    WHERE (`author_cid` IS NULL OR `author_cid` = '') AND `author` IS NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'created_by'
  ) THEN
    UPDATE `dpn_medical_records`
    SET `author_cid` = CAST(`created_by` AS CHAR)
    WHERE (`author_cid` IS NULL OR `author_cid` = '') AND `created_by` IS NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'data'
  ) THEN
    UPDATE `dpn_medical_records`
    SET `entry_data` = CAST(`data` AS CHAR)
    WHERE (`entry_data` IS NULL OR `entry_data` = '') AND `data` IS NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'record_data'
  ) THEN
    UPDATE `dpn_medical_records`
    SET `entry_data` = CAST(`record_data` AS CHAR)
    WHERE (`entry_data` IS NULL OR `entry_data` = '') AND `record_data` IS NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND COLUMN_NAME = 'details'
  ) THEN
    UPDATE `dpn_medical_records`
    SET `entry_data` = CAST(`details` AS CHAR)
    WHERE (`entry_data` IS NULL OR `entry_data` = '') AND `details` IS NOT NULL;
  END IF;

  UPDATE `dpn_medical_records` SET `entry_type` = 'note' WHERE `entry_type` IS NULL OR `entry_type` = '';
  UPDATE `dpn_medical_records` SET `entry_data` = '{}' WHERE `entry_data` IS NULL OR `entry_data` = '';

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND INDEX_NAME = 'idx_records_patient'
  ) THEN
    ALTER TABLE `dpn_medical_records` ADD INDEX `idx_records_patient` (`patient_cid`);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dpn_medical_records' AND INDEX_NAME = 'idx_records_type'
  ) THEN
    ALTER TABLE `dpn_medical_records` ADD INDEX `idx_records_type` (`entry_type`);
  END IF;
END$$
DELIMITER ;

CALL `dpn_migrate_medical_records_v501`();
DROP PROCEDURE IF EXISTS `dpn_migrate_medical_records_v501`;
