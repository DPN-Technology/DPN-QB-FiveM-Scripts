CREATE TABLE IF NOT EXISTS `dpn_intel_reports` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `report_id` VARCHAR(64) NOT NULL,
  `title` VARCHAR(160) NOT NULL,
  `narrative` LONGTEXT NOT NULL,
  `classification` VARCHAR(64) NOT NULL DEFAULT 'law-enforcement-sensitive',
  `status` VARCHAR(32) NOT NULL DEFAULT 'active',
  `created_by` VARCHAR(80) NOT NULL,
  `created_by_name` VARCHAR(128) NOT NULL,
  `metadata` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dpn_intel_report_id` (`report_id`),
  FULLTEXT KEY `ft_dpn_intel_report` (`title`,`narrative`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_intel_watchlists` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `subject_type` VARCHAR(32) NOT NULL,
  `subject_key` VARCHAR(80) NOT NULL,
  `label` VARCHAR(160) NOT NULL,
  `reason` TEXT NOT NULL,
  `priority` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(80) NOT NULL,
  `created_by_name` VARCHAR(128) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dpn_intel_watch_subject` (`subject_type`,`subject_key`),
  KEY `idx_dpn_intel_watch_active` (`active`,`priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_intel_links` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `report_id` VARCHAR(64) NOT NULL,
  `entity_type` VARCHAR(32) NOT NULL,
  `entity_key` VARCHAR(80) NOT NULL,
  `relationship` VARCHAR(128) NOT NULL,
  `created_by` VARCHAR(80) NOT NULL,
  `created_by_name` VARCHAR(128) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_intel_link_report` (`report_id`),
  KEY `idx_dpn_intel_link_entity` (`entity_type`,`entity_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_intel_audit` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `officer_cid` VARCHAR(80) NOT NULL,
  `officer_name` VARCHAR(128) NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  `details` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_intel_audit_officer` (`officer_cid`),
  KEY `idx_dpn_intel_audit_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
