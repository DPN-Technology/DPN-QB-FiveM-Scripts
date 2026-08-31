CREATE TABLE IF NOT EXISTS `dpn_medical_admin_audit` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `actor_cid` VARCHAR(64) NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  `target` VARCHAR(64) NULL,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_med_admin_actor` (`actor_cid`),
  KEY `idx_dpn_med_admin_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
