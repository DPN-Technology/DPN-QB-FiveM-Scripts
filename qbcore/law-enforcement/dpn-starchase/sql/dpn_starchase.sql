CREATE TABLE IF NOT EXISTS `dpn_starchase_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `tracker_id` VARCHAR(64) DEFAULT NULL,
    `action` VARCHAR(40) NOT NULL,
    `source` INT DEFAULT NULL,
    `citizenid` VARCHAR(80) DEFAULT NULL,
    `officer_name` VARCHAR(120) DEFAULT NULL,
    `job` VARCHAR(80) DEFAULT NULL,
    `plate` VARCHAR(16) DEFAULT NULL,
    `target_net_id` INT DEFAULT NULL,
    `coords` LONGTEXT DEFAULT NULL,
    `extra` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `tracker_id` (`tracker_id`),
    INDEX `action` (`action`),
    INDEX `plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
