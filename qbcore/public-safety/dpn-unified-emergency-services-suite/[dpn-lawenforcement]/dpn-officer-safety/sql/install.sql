CREATE TABLE IF NOT EXISTS `dpn_officer_safety_alerts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(80) NOT NULL,
  `officer_name` VARCHAR(120) NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `priority` INT NOT NULL DEFAULT 1,
  `message` TEXT NULL,
  `coords` LONGTEXT NULL,
  `metadata` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_identifier` (`identifier`),
  KEY `idx_type` (`type`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
