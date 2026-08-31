CREATE TABLE IF NOT EXISTS `dpn_network_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `event_id` VARCHAR(64) NOT NULL,
  `source_system` VARCHAR(64) NOT NULL,
  `event_type` VARCHAR(64) NOT NULL,
  `severity` TINYINT UNSIGNED NOT NULL DEFAULT 3,
  `title` VARCHAR(180) NOT NULL,
  `message` TEXT NULL,
  `actor_cid` VARCHAR(64) NULL,
  `actor_name` VARCHAR(120) NULL,
  `actor_job` VARCHAR(64) NULL,
  `department` VARCHAR(32) NULL,
  `coords` LONGTEXT NULL,
  `payload` LONGTEXT NULL,
  `dispatch_call_id` VARCHAR(64) NULL,
  `incident_id` VARCHAR(64) NULL,
  `evidence_reference` VARCHAR(64) NULL,
  `status` ENUM('open','acknowledged','resolved','archived') NOT NULL DEFAULT 'open',
  `acknowledged_by` VARCHAR(64) NULL,
  `acknowledged_at` DATETIME NULL,
  `resolved_by` VARCHAR(64) NULL,
  `resolution` TEXT NULL,
  `resolved_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dpn_network_event_id` (`event_id`),
  KEY `idx_dpn_network_events_status` (`status`,`severity`),
  KEY `idx_dpn_network_events_system` (`source_system`,`event_type`),
  KEY `idx_dpn_network_events_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_network_record_links` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `link_id` VARCHAR(64) NOT NULL,
  `left_system` VARCHAR(64) NOT NULL,
  `left_type` VARCHAR(64) NOT NULL,
  `left_id` VARCHAR(96) NOT NULL,
  `right_system` VARCHAR(64) NOT NULL,
  `right_type` VARCHAR(64) NOT NULL,
  `right_id` VARCHAR(96) NOT NULL,
  `relationship` VARCHAR(80) NOT NULL DEFAULT 'related',
  `metadata` LONGTEXT NULL,
  `created_by_cid` VARCHAR(64) NULL,
  `created_by_name` VARCHAR(120) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dpn_network_link_id` (`link_id`),
  KEY `idx_dpn_network_left` (`left_system`,`left_type`,`left_id`),
  KEY `idx_dpn_network_right` (`right_system`,`right_type`,`right_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_network_resource_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `logical_system` VARCHAR(64) NOT NULL,
  `resource_name` VARCHAR(96) NULL,
  `previous_state` VARCHAR(32) NULL,
  `new_state` VARCHAR(32) NOT NULL,
  `details` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_network_history_system` (`logical_system`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dpn_network_audit` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `actor_cid` VARCHAR(64) NULL,
  `actor_name` VARCHAR(120) NULL,
  `action` VARCHAR(80) NOT NULL,
  `reference_id` VARCHAR(96) NULL,
  `details` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dpn_network_audit_action` (`action`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
