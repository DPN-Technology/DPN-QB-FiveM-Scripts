CREATE TABLE IF NOT EXISTS `dpn_drone_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(64) DEFAULT NULL,
  `action` varchar(128) NOT NULL,
  `data` longtext DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
