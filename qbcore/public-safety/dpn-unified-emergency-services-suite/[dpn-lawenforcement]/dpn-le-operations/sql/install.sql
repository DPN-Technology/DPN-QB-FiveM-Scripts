CREATE TABLE IF NOT EXISTS `dpn_le_shifts` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `shift_id` VARCHAR(64) NOT NULL,
  `identifier` VARCHAR(80) NOT NULL,
  `officer_name` VARCHAR(120) NOT NULL,
  `job` VARCHAR(50) NOT NULL,
  `grade` INT NOT NULL DEFAULT 0,
  `calls_handled` INT NOT NULL DEFAULT 0,
  `citations` INT NOT NULL DEFAULT 0,
  `arrests` INT NOT NULL DEFAULT 0,
  `searches` INT NOT NULL DEFAULT 0,
  `force_reports` INT NOT NULL DEFAULT 0,
  `notes` LONGTEXT NULL,
  `started_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ended_at` DATETIME NULL,
  `end_reason` VARCHAR(80) NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_shift_id` (`shift_id`), KEY `idx_shift_identifier` (`identifier`), KEY `idx_shift_open` (`ended_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_le_operational_units` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `unit_id` VARCHAR(64) NOT NULL,
  `unit_code` VARCHAR(24) NOT NULL,
  `unit_name` VARCHAR(120) NOT NULL,
  `role` VARCHAR(40) NOT NULL DEFAULT 'patrol',
  `department` VARCHAR(40) NOT NULL DEFAULT 'law',
  `leader_identifier` VARCHAR(80) NOT NULL,
  `members` LONGTEXT NULL,
  `metadata` LONGTEXT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'active',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `closed_at` DATETIME NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_operational_unit_id` (`unit_id`), KEY `idx_operational_unit_code` (`unit_code`), KEY `idx_operational_unit_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_le_warrants` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `warrant_id` VARCHAR(64) NOT NULL,
  `warrant_type` VARCHAR(40) NOT NULL,
  `subject_type` VARCHAR(24) NOT NULL,
  `subject_key` VARCHAR(100) NOT NULL,
  `subject_name` VARCHAR(160) NOT NULL,
  `charges` LONGTEXT NOT NULL,
  `probable_cause` LONGTEXT NOT NULL,
  `risk_level` VARCHAR(24) NOT NULL DEFAULT 'standard',
  `requester_cid` VARCHAR(80) NOT NULL,
  `requester_name` VARCHAR(120) NOT NULL,
  `reviewer_cid` VARCHAR(80) NULL,
  `reviewer_name` VARCHAR(120) NULL,
  `review_notes` LONGTEXT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'pending',
  `expires_at` DATETIME NULL,
  `served_by_cid` VARCHAR(80) NULL,
  `served_by_name` VARCHAR(120) NULL,
  `served_at` DATETIME NULL,
  `metadata` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_warrant_id` (`warrant_id`), KEY `idx_warrant_subject` (`subject_type`,`subject_key`), KEY `idx_warrant_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_le_warrant_actions` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `warrant_id` VARCHAR(64) NOT NULL,
  `actor_cid` VARCHAR(80) NOT NULL,
  `actor_name` VARCHAR(120) NOT NULL,
  `action` VARCHAR(40) NOT NULL,
  `notes` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_warrant_action_id` (`warrant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_le_pursuits` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `pursuit_id` VARCHAR(64) NOT NULL,
  `primary_cid` VARCHAR(80) NOT NULL,
  `primary_name` VARCHAR(120) NOT NULL,
  `vehicle_plate` VARCHAR(24) NOT NULL,
  `vehicle_model` VARCHAR(80) NULL,
  `vehicle_net_id` INT NULL,
  `stage` VARCHAR(24) NOT NULL DEFAULT 'active',
  `risk_level` VARCHAR(24) NOT NULL DEFAULT 'standard',
  `reason` LONGTEXT NOT NULL,
  `units` LONGTEXT NULL,
  `authorizations` LONGTEXT NULL,
  `last_coords` LONGTEXT NULL,
  `max_speed` DECIMAL(8,2) NOT NULL DEFAULT 0,
  `dispatch_call_id` VARCHAR(64) NULL,
  `incident_id` VARCHAR(64) NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'active',
  `disposition` VARCHAR(80) NULL,
  `termination_notes` LONGTEXT NULL,
  `review_status` VARCHAR(24) NOT NULL DEFAULT 'pending',
  `reviewer_cid` VARCHAR(80) NULL,
  `reviewer_name` VARCHAR(120) NULL,
  `review_finding` VARCHAR(40) NULL,
  `review_notes` LONGTEXT NULL,
  `reviewed_at` DATETIME NULL,
  `started_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ended_at` DATETIME NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_pursuit_id` (`pursuit_id`), KEY `idx_pursuit_status` (`status`), KEY `idx_pursuit_plate` (`vehicle_plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_le_force_reports` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `report_id` VARCHAR(64) NOT NULL,
  `officer_cid` VARCHAR(80) NOT NULL,
  `officer_name` VARCHAR(120) NOT NULL,
  `officer_job` VARCHAR(50) NOT NULL,
  `subject_cid` VARCHAR(80) NULL,
  `subject_name` VARCHAR(160) NULL,
  `force_level` VARCHAR(40) NOT NULL,
  `reason` VARCHAR(255) NOT NULL,
  `weapons_used` LONGTEXT NULL,
  `injuries` LONGTEXT NULL,
  `medical_aid` LONGTEXT NULL,
  `bodycam_reference` VARCHAR(255) NULL,
  `case_reference` VARCHAR(100) NULL,
  `narrative` LONGTEXT NULL,
  `coords` LONGTEXT NULL,
  `automatic_draft` TINYINT(1) NOT NULL DEFAULT 0,
  `status` VARCHAR(24) NOT NULL DEFAULT 'pending',
  `reviewer_cid` VARCHAR(80) NULL,
  `reviewer_name` VARCHAR(120) NULL,
  `review_finding` VARCHAR(40) NULL,
  `review_notes` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` DATETIME NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_force_report_id` (`report_id`), KEY `idx_force_officer` (`officer_cid`), KEY `idx_force_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_le_fleet_checkouts` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `checkout_id` VARCHAR(64) NOT NULL,
  `officer_cid` VARCHAR(80) NOT NULL,
  `officer_name` VARCHAR(120) NOT NULL,
  `vehicle_plate` VARCHAR(24) NOT NULL,
  `vehicle_model` VARCHAR(80) NULL,
  `vehicle_net_id` INT NULL,
  `starting_body` DECIMAL(8,2) NULL,
  `starting_engine` DECIMAL(8,2) NULL,
  `starting_fuel` DECIMAL(8,2) NULL,
  `ending_body` DECIMAL(8,2) NULL,
  `ending_engine` DECIMAL(8,2) NULL,
  `ending_fuel` DECIMAL(8,2) NULL,
  `damage_notes` LONGTEXT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'active',
  `checked_out_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `returned_at` DATETIME NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_fleet_checkout_id` (`checkout_id`), KEY `idx_fleet_officer` (`officer_cid`), KEY `idx_fleet_status` (`status`), KEY `idx_fleet_plate` (`vehicle_plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_le_armory_checkouts` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `checkout_id` VARCHAR(64) NOT NULL,
  `officer_cid` VARCHAR(80) NOT NULL,
  `officer_name` VARCHAR(120) NOT NULL,
  `catalog_id` VARCHAR(80) NOT NULL,
  `item_name` VARCHAR(100) NOT NULL,
  `item_label` VARCHAR(160) NOT NULL,
  `quantity` INT NOT NULL DEFAULT 1,
  `serial_number` VARCHAR(100) NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'active',
  `issued_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `returned_at` DATETIME NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_armory_checkout_id` (`checkout_id`), KEY `idx_armory_officer` (`officer_cid`), KEY `idx_armory_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_le_supervisor_tasks` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `task_id` VARCHAR(64) NOT NULL,
  `task_type` VARCHAR(40) NOT NULL,
  `reference_id` VARCHAR(64) NOT NULL,
  `title` VARCHAR(180) NOT NULL,
  `priority` INT NOT NULL DEFAULT 3,
  `assigned_job` VARCHAR(50) NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'open',
  `metadata` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` DATETIME NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_supervisor_task_id` (`task_id`), KEY `idx_supervisor_task_status` (`status`), KEY `idx_supervisor_task_type` (`task_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_le_operational_audit` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `actor_cid` VARCHAR(80) NOT NULL,
  `actor_name` VARCHAR(120) NOT NULL,
  `action` VARCHAR(80) NOT NULL,
  `reference_id` VARCHAR(64) NULL,
  `details` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_ops_audit_actor` (`actor_cid`), KEY `idx_ops_audit_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
