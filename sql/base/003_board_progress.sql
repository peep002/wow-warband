-- 003_board_progress.sql  (database: warband_characters)
-- Phase 4: act progress on the company, and the mission board's current offers.
-- Safe to re-run: the column is only added if missing, the table only created if missing.

-- Main missions completed in the current act (the gate opens after Config.acts[act].mains_before_gate).
SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'warband_company' AND COLUMN_NAME = 'progress');
SET @sql := IF(@has = 0,
    'ALTER TABLE `warband_company` ADD COLUMN `progress` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''main missions done this act'' AFTER `act`',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- The contracts on a company's board right now (kept until the next mission ends, so they don't
-- change every time the window opens or the server restarts).
CREATE TABLE IF NOT EXISTS `warband_board` (
    `company`     INT UNSIGNED     NOT NULL,
    `slot`        TINYINT UNSIGNED NOT NULL,
    `mission_key` VARCHAR(48)      NOT NULL,
    PRIMARY KEY (`company`, `slot`)
) COMMENT = 'Warband: contracts on each company''s mission board';
