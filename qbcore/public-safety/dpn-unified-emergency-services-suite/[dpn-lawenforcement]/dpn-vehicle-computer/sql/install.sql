CREATE TABLE IF NOT EXISTS `dpn_vehicle_computer_notes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `officer` VARCHAR(128) NOT NULL,
  `officer_cid` VARCHAR(80) DEFAULT NULL,
  `text` TEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_vc_notes_officer` (`officer_cid`),
  KEY `idx_dpn_vc_notes_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_vehicle_hotlist` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `plate` VARCHAR(16) NOT NULL,
  `reason` VARCHAR(255) NOT NULL,
  `added_by` VARCHAR(128) DEFAULT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dpn_vehicle_hotlist_plate` (`plate`),
  KEY `idx_dpn_vehicle_hotlist_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
