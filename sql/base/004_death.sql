-- 004_death.sql  (database: warband_characters)
-- Phase 5: wounds and the memorial wall. Safe to re-run: columns are only added if missing,
-- the table only created if missing.

-- 1 = wounded: -10% max health until treated, or (heroes) after sitting out a mission.
SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'warband_heroes' AND COLUMN_NAME = 'wounded');
SET @sql := IF(@has = 0,
    'ALTER TABLE `warband_heroes` ADD COLUMN `wounded` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `status`',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'warband_company' AND COLUMN_NAME = 'wounded');
SET @sql := IF(@has = 0,
    'ALTER TABLE `warband_company` ADD COLUMN `wounded` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''the commander is wounded'' AFTER `state`',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Everyone a company has lost, and how.
CREATE TABLE IF NOT EXISTS `warband_memorial` (
    `id`          INT UNSIGNED      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company`     INT UNSIGNED      NOT NULL,
    `guid`        INT UNSIGNED      NOT NULL COMMENT 'the hero character',
    `name`        VARCHAR(12)       NOT NULL,
    `class`       TINYINT UNSIGNED  NOT NULL,
    `race`        TINYINT UNSIGNED  NOT NULL,
    `level`       TINYINT UNSIGNED  NOT NULL,
    `missions`    SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'missions survived',
    `cause`       VARCHAR(160)      NOT NULL COMMENT 'how they died, in words',
    `mission_key` VARCHAR(48)       NOT NULL DEFAULT '',
    `died`        TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `company` (`company`)
) COMMENT = 'Warband: the memorial wall';
