CREATE TABLE IF NOT EXISTS `dpn_evidence_cases` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `case_id` VARCHAR(64) NOT NULL UNIQUE,
  `title` VARCHAR(128) NOT NULL,
  `description` TEXT,
  `status` VARCHAR(32) DEFAULT 'open',
  `created_by` VARCHAR(64),
  `created_by_name` VARCHAR(128),
  `created_at` DATETIME,
  `updated_at` DATETIME,
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `dpn_evidence_items` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `evidence_id` VARCHAR(64) NOT NULL UNIQUE,
  `case_id` VARCHAR(64),
  `type` VARCHAR(32),
  `title` VARCHAR(128),
  `notes` TEXT,
  `metadata` LONGTEXT,
  `collected_by` VARCHAR(64),
  `collected_by_name` VARCHAR(128),
  `custody_holder` VARCHAR(64),
  `custody_holder_name` VARCHAR(128),
  `created_at` DATETIME,
  `updated_at` DATETIME,
  PRIMARY KEY (`id`),
  INDEX (`case_id`),
  INDEX (`evidence_id`)
);

CREATE TABLE IF NOT EXISTS `dpn_evidence_custody` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `evidence_id` VARCHAR(64) NOT NULL,
  `action` VARCHAR(32) NOT NULL,
  `from_holder` VARCHAR(128),
  `to_holder` VARCHAR(128),
  `officer_identifier` VARCHAR(64),
  `officer_name` VARCHAR(128),
  `notes` TEXT,
  `created_at` DATETIME,
  PRIMARY KEY (`id`),
  INDEX (`evidence_id`)
);

CREATE TABLE IF NOT EXISTS `dpn_evidence_case_notes` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `case_id` VARCHAR(64) NOT NULL,
  `officer_identifier` VARCHAR(64),
  `officer_name` VARCHAR(128),
  `note` TEXT,
  `created_at` DATETIME,
  PRIMARY KEY (`id`),
  INDEX (`case_id`)
);
