CREATE TABLE IF NOT EXISTS `dpn_digital_dispatch_calls` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `call_id` VARCHAR(64) NOT NULL,
  `call_type` VARCHAR(64) NOT NULL,
  `title` VARCHAR(128) NOT NULL,
  `description` TEXT NULL,
  `priority` TINYINT UNSIGNED NOT NULL DEFAULT 3,
  `status` VARCHAR(32) NOT NULL DEFAULT 'active',
  `coords` LONGTEXT NULL,
  `created_by` VARCHAR(80) NULL,
  `caller_name` VARCHAR(128) NULL,
  `assigned_units` LONGTEXT NULL,
  `departments` LONGTEXT NULL,
  `metadata` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `closed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dpn_digital_dispatch_call_id` (`call_id`),
  KEY `idx_dpn_digital_dispatch_status` (`status`),
  KEY `idx_dpn_digital_dispatch_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_digital_dispatch_units` (
  `identifier` VARCHAR(80) NOT NULL,
  `unit_number` VARCHAR(32) NOT NULL,
  `name` VARCHAR(128) NULL,
  `job` VARCHAR(64) NULL,
  `department` VARCHAR(32) NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT '10-8',
  `last_coords` LONGTEXT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`),
  KEY `idx_dpn_digital_dispatch_unit_department` (`department`),
  KEY `idx_dpn_digital_dispatch_unit_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
