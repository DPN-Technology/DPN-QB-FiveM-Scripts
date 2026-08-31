CREATE TABLE IF NOT EXISTS `dpn_academy_records` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `session_id` VARCHAR(64) NOT NULL,
  `identifier` VARCHAR(80) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `course_id` VARCHAR(80) NOT NULL,
  `course_label` VARCHAR(160) NOT NULL,
  `score` INT NOT NULL DEFAULT 0,
  `passed` TINYINT(1) NOT NULL DEFAULT 0,
  `notes` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_identifier` (`identifier`),
  KEY `idx_course` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_academy_certs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(80) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `cert_id` VARCHAR(80) NOT NULL,
  `cert_label` VARCHAR(160) NOT NULL,
  `score` INT NOT NULL DEFAULT 0,
  `issued_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_identifier_cert` (`identifier`, `cert_id`),
  KEY `idx_cert` (`cert_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_academy_audit` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(80) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `action` VARCHAR(80) NOT NULL,
  `details` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_identifier` (`identifier`),
  KEY `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
