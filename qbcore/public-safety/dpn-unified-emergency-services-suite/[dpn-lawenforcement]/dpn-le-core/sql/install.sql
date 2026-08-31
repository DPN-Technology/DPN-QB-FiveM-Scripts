CREATE TABLE IF NOT EXISTS `dpn_le_officer_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(80) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `job` VARCHAR(60) NOT NULL,
  `unit` VARCHAR(20) DEFAULT NULL,
  `status` VARCHAR(20) NOT NULL,
  `action` VARCHAR(32) NOT NULL DEFAULT 'UPDATE',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_le_officer_identifier` (`identifier`),
  KEY `idx_dpn_le_officer_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_le_action_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `officer_cid` VARCHAR(80) NOT NULL,
  `officer_name` VARCHAR(120) NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  `target_cid` VARCHAR(80) DEFAULT NULL,
  `target_name` VARCHAR(120) DEFAULT NULL,
  `details` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_le_action_officer` (`officer_cid`),
  KEY `idx_dpn_le_action_target` (`target_cid`),
  KEY `idx_dpn_le_action_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_le_citations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citation_id` VARCHAR(64) NOT NULL,
  `citizenid` VARCHAR(80) NOT NULL,
  `citizen_name` VARCHAR(120) NOT NULL,
  `officer_cid` VARCHAR(80) NOT NULL,
  `officer_name` VARCHAR(120) NOT NULL,
  `amount` INT UNSIGNED NOT NULL DEFAULT 0,
  `reason` VARCHAR(255) NOT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'issued',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `paid_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dpn_le_citation_id` (`citation_id`),
  KEY `idx_dpn_le_citation_citizen` (`citizenid`),
  KEY `idx_dpn_le_citation_officer` (`officer_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_le_bookings` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `booking_id` VARCHAR(64) NOT NULL,
  `citizenid` VARCHAR(80) NOT NULL,
  `citizen_name` VARCHAR(120) NOT NULL,
  `officer_cid` VARCHAR(80) NOT NULL,
  `officer_name` VARCHAR(120) NOT NULL,
  `charges` TEXT NOT NULL,
  `sentence_minutes` INT UNSIGNED NOT NULL DEFAULT 0,
  `fine` INT UNSIGNED NOT NULL DEFAULT 0,
  `notes` TEXT DEFAULT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'booked',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `released_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dpn_le_booking_id` (`booking_id`),
  KEY `idx_dpn_le_booking_citizen` (`citizenid`),
  KEY `idx_dpn_le_booking_officer` (`officer_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
