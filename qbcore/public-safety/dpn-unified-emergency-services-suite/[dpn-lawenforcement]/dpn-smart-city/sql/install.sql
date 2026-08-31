CREATE TABLE IF NOT EXISTS `dpn_smartcity_bolos` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `plate` VARCHAR(16) NOT NULL,
  `reason` LONGTEXT NOT NULL,
  `priority` VARCHAR(16) NOT NULL DEFAULT 'medium',
  `created_by` VARCHAR(80) NOT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_smartcity_bolo_plate` (`plate`),
  KEY `idx_dpn_smartcity_bolo_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_smartcity_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `event_type` VARCHAR(64) NOT NULL,
  `title` VARCHAR(160) NOT NULL,
  `details` LONGTEXT NULL,
  `plate` VARCHAR(16) NULL,
  `coords` LONGTEXT NULL,
  `created_by` VARCHAR(80) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_smartcity_event_type` (`event_type`),
  KEY `idx_dpn_smartcity_event_plate` (`plate`),
  KEY `idx_dpn_smartcity_event_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
