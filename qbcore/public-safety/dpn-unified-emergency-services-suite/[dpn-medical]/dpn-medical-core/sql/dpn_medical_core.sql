CREATE TABLE IF NOT EXISTS `dpn_medical_states` (
  `citizenid` varchar(64) NOT NULL,
  `state` longtext NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_medical_events` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(64) NOT NULL,
  `event_type` varchar(64) NOT NULL,
  `event_data` longtext NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`), KEY `idx_medical_events_citizen` (`citizenid`), KEY `idx_medical_events_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_medical_modules` (
  `resource_name` varchar(64) NOT NULL,
  `version` varchar(32) NOT NULL,
  `capabilities` longtext NULL,
  `last_seen` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`resource_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
