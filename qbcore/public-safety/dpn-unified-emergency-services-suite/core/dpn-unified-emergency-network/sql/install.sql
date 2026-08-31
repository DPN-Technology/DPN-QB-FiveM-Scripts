CREATE TABLE IF NOT EXISTS dpn_unes_incidents (
  id INT AUTO_INCREMENT PRIMARY KEY,
  incident_id VARCHAR(64) UNIQUE NOT NULL,
  type VARCHAR(64),
  title VARCHAR(255),
  description TEXT,
  priority INT DEFAULT 3,
  status VARCHAR(64),
  agencies LONGTEXT,
  created_by LONGTEXT,
  coords LONGTEXT,
  postal VARCHAR(64),
  history LONGTEXT,
  payload LONGTEXT,
  created_at TIMESTAMP NULL,
  updated_at TIMESTAMP NULL,
  INDEX(status), INDEX(priority), INDEX(type), INDEX(incident_id)
);

CREATE TABLE IF NOT EXISTS dpn_unes_assignments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  incident_id VARCHAR(64) NOT NULL,
  citizenid VARCHAR(64),
  callsign VARCHAR(64),
  agency VARCHAR(64),
  unit_name VARCHAR(128),
  assigned_at TIMESTAMP NULL,
  cleared_at TIMESTAMP NULL,
  INDEX(incident_id), INDEX(citizenid), INDEX(agency)
);

CREATE TABLE IF NOT EXISTS dpn_unes_links (
  id INT AUTO_INCREMENT PRIMARY KEY,
  incident_id VARCHAR(64) NOT NULL,
  system_name VARCHAR(64),
  record_type VARCHAR(64),
  record_id VARCHAR(128),
  metadata LONGTEXT,
  created_at TIMESTAMP NULL,
  INDEX(incident_id), INDEX(system_name), INDEX(record_type)
);

CREATE TABLE IF NOT EXISTS dpn_unes_bolos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  bolo_id VARCHAR(64) UNIQUE NOT NULL,
  title VARCHAR(255),
  description TEXT,
  vehicle VARCHAR(128),
  plate VARCHAR(64),
  suspect VARCHAR(128),
  priority INT DEFAULT 3,
  last_seen VARCHAR(255),
  threat TEXT,
  tags LONGTEXT,
  payload LONGTEXT,
  active TINYINT DEFAULT 1,
  created_by LONGTEXT,
  created_at TIMESTAMP NULL,
  archived_at TIMESTAMP NULL,
  INDEX(active), INDEX(plate), INDEX(priority)
);

CREATE TABLE IF NOT EXISTS dpn_unes_audit (
  id INT AUTO_INCREMENT PRIMARY KEY,
  source INT,
  citizenid VARCHAR(64),
  callsign VARCHAR(64),
  agency VARCHAR(64),
  action VARCHAR(128),
  target VARCHAR(128),
  details LONGTEXT,
  created_at TIMESTAMP NULL,
  INDEX(citizenid), INDEX(action), INDEX(target), INDEX(agency)
);

CREATE TABLE IF NOT EXISTS dpn_unes_agency_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  event_id VARCHAR(64) UNIQUE,
  incident_id VARCHAR(64),
  agency VARCHAR(64),
  event_type VARCHAR(64),
  payload LONGTEXT,
  created_at TIMESTAMP NULL,
  INDEX(incident_id), INDEX(agency), INDEX(event_type)
);
