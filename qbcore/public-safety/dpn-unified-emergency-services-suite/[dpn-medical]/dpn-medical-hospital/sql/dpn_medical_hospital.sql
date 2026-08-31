CREATE TABLE IF NOT EXISTS `dpn_hospital_admissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(64) NOT NULL,
  `patient_name` varchar(128) DEFAULT NULL,
  `hospital` varchar(64) NOT NULL,
  `bed_id` varchar(64) DEFAULT NULL,
  `ward` varchar(32) DEFAULT 'er',
  `status` varchar(32) DEFAULT 'admitted',
  `reason` text DEFAULT NULL,
  `admitted_by` varchar(64) DEFAULT NULL,
  `assigned_doctor` varchar(64) DEFAULT NULL,
  `severity` int(11) DEFAULT 0,
  `recovery_minutes` int(11) DEFAULT 0,
  `remaining_minutes` int(11) DEFAULT 0,
  `bill_amount` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT current_timestamp(),
  `updated_at` timestamp DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `discharged_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`),
  KEY `status` (`status`),
  KEY `idx_citizen_status` (`citizenid`, `status`),
  KEY `idx_hospital_bed_status` (`hospital`, `bed_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_hospital_bed_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bed_id` varchar(64) NOT NULL,
  `hospital` varchar(64) NOT NULL,
  `citizenid` varchar(64) DEFAULT NULL,
  `action` varchar(32) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `bed_id` (`bed_id`),
  KEY `idx_bed_created` (`bed_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
