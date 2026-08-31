CREATE TABLE IF NOT EXISTS `dpn_incidents` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `incident_uid` VARCHAR(64) NOT NULL,
  `title` VARCHAR(120) NOT NULL,
  `incident_type` VARCHAR(60) NOT NULL DEFAULT 'general',
  `priority` VARCHAR(20) NOT NULL DEFAULT 'medium',
  `status` VARCHAR(30) NOT NULL DEFAULT 'active',
  `commander` VARCHAR(80) NOT NULL,
  `commander_identifier` VARCHAR(80) NOT NULL,
  `coords` LONGTEXT NULL,
  `notes` LONGTEXT NULL,
  `created_by` VARCHAR(120) NOT NULL,
  `created_identifier` VARCHAR(80) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `archived_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_dpn_incident_uid` (`incident_uid`),
  KEY `idx_dpn_incident_status` (`status`),
  KEY `idx_dpn_incident_priority` (`priority`),
  KEY `idx_dpn_incident_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_incident_units` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `incident_uid` VARCHAR(64) NOT NULL,
  `unit_name` VARCHAR(80) NOT NULL,
  `identifier` VARCHAR(80) NOT NULL,
  `role` VARCHAR(80) NOT NULL DEFAULT 'Assigned Unit',
  `division` VARCHAR(80) NOT NULL DEFAULT 'Operations',
  `status` VARCHAR(30) NOT NULL DEFAULT 'assigned',
  `source_id` INT NULL,
  `assigned_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_incident_unit_incident` (`incident_uid`),
  KEY `idx_dpn_incident_unit_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_incident_markers` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `incident_uid` VARCHAR(64) NOT NULL,
  `marker_uid` VARCHAR(64) NOT NULL,
  `marker_type` VARCHAR(50) NOT NULL DEFAULT 'staging',
  `label` VARCHAR(120) NOT NULL,
  `coords` LONGTEXT NOT NULL,
  `created_by` VARCHAR(120) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_dpn_incident_marker_uid` (`marker_uid`),
  KEY `idx_dpn_incident_marker_incident` (`incident_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_incident_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `incident_uid` VARCHAR(64) NOT NULL,
  `actor` VARCHAR(120) NOT NULL,
  `action` VARCHAR(80) NOT NULL,
  `details` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_incident_log_incident` (`incident_uid`),
  KEY `idx_dpn_incident_log_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
