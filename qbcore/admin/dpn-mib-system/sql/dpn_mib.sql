CREATE TABLE IF NOT EXISTS `dpn_mib_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `case_id` varchar(64) DEFAULT NULL,
  `agent_source` int(11) DEFAULT NULL,
  `agent_name` varchar(128) DEFAULT NULL,
  `target_source` int(11) DEFAULT NULL,
  `action` varchar(128) NOT NULL,
  `reason` text DEFAULT NULL,
  `coords` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_mib_cases` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `case_id` varchar(64) NOT NULL,
  `title` varchar(255) NOT NULL,
  `threat` varchar(32) DEFAULT 'green',
  `status` varchar(32) DEFAULT 'open',
  `owner` varchar(128) DEFAULT NULL,
  `data` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `case_id` (`case_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `dpn_mib_memory_wipes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `agent_source` int(11) DEFAULT NULL,
  `target_source` int(11) DEFAULT NULL,
  `wipe_minutes` int(11) DEFAULT 0,
  `reason` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Compatibility tables used by legacy logger code in this resource
CREATE TABLE IF NOT EXISTS `dpn_mib_action_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `case_code` varchar(64) DEFAULT NULL,
  `agent_citizenid` varchar(64) DEFAULT NULL,
  `target_citizenid` varchar(64) DEFAULT NULL,
  `action` varchar(128) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `coords` varchar(128) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `dpn_mib_memory_wipes`
  ADD COLUMN IF NOT EXISTS `target_citizenid` varchar(64) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `target_name` varchar(128) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `agent_citizenid` varchar(64) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `duration_minutes` int(11) DEFAULT 0;
