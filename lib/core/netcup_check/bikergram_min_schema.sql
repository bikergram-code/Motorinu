-- Minimal-Schema (MySQL) für Bikergram Drafts + Users.
-- Import in phpMyAdmin (SQL tab) – vorher DB auswählen.

-- 1) Drafts (Wizard-Zwischenstand)
CREATE TABLE IF NOT EXISTS bg_profile_drafts (
  id VARCHAR(64) PRIMARY KEY,
  device_id VARCHAR(128) NULL,
  last_completed_step INT NOT NULL DEFAULT 0,
  steps_json JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  submitted_at TIMESTAMP NULL,
  INDEX idx_device_id (device_id),
  INDEX idx_submitted (submitted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2) Users (finales Profil)
CREATE TABLE IF NOT EXISTS bg_users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  biker_name VARCHAR(64) NOT NULL,
  email VARCHAR(190) NULL,
  password_hash VARCHAR(255) NULL,
  postal_code VARCHAR(16) NULL,
  age INT NULL,
  riding_years INT NULL,
  bike_count INT NULL,
  track_experience TINYINT(1) NOT NULL DEFAULT 0,
  diy_skills_json JSON NULL,
  profile_image_url TEXT NULL,
  xp_total INT NOT NULL DEFAULT 0,
  badges_json JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_biker_name (biker_name),
  UNIQUE KEY uq_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3) Name-Reservierungen (für bikername_*.php)
CREATE TABLE IF NOT EXISTS bg_bikername_reservations (
  biker_name VARCHAR(64) PRIMARY KEY,
  client_token VARCHAR(128) NOT NULL,
  reserved_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NULL,
  INDEX idx_client_token (client_token),
  INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
