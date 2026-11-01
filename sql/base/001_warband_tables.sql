-- 001_warband_tables.sql  (database: warband_characters)
-- Warband's own tables for campaign state. Safe to re-run: tables are only created if missing,
-- and nothing existing is changed or deleted. Removing Warband = leave these tables alone.

-- One row per company. A company belongs to one commander character (one company per commander).
CREATE TABLE IF NOT EXISTS `warband_company` (
    `guid`      INT UNSIGNED     NOT NULL PRIMARY KEY COMMENT 'commander character guid',
    `account`   INT UNSIGNED     NOT NULL,
    `act`       TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `gold`      INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT 'company gold, in gold pieces',
    `renown`    INT UNSIGNED     NOT NULL DEFAULT 0,
    `materials` INT UNSIGNED     NOT NULL DEFAULT 0,
    `threat`    TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'threat clock for the current act',
    `tier`      TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'difficulty tier',
    `ironman`   TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `state`     TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 in the hamlet, 1 on a mission',
    `created`   TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `account` (`account`)
) COMMENT = 'Warband: one company (campaign) per commander';

-- Every mission a company starts: the active one (status active) and its history.
CREATE TABLE IF NOT EXISTS `warband_missions` (
    `id`          INT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company`     INT UNSIGNED  NOT NULL COMMENT 'warband_company.guid',
    `mission_key` VARCHAR(48)   NOT NULL COMMENT 'key in wb_config.lua missions',
    `status`      VARCHAR(12)   NOT NULL DEFAULT 'active' COMMENT 'active, done, abandoned, failed',
    `started`     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ended`       TIMESTAMP     NULL DEFAULT NULL,
    KEY `company` (`company`, `status`)
) COMMENT = 'Warband: missions started, active and past';

-- Important events, so bugs can be traced without a perfect description.
CREATE TABLE IF NOT EXISTS `warband_log` (
    `id`      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `at`      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `company` INT UNSIGNED    NOT NULL DEFAULT 0,
    `event`   VARCHAR(32)     NOT NULL,
    `detail`  VARCHAR(255)    NOT NULL DEFAULT '',
    KEY `company` (`company`, `at`)
) COMMENT = 'Warband: event log (missions, deaths, loot...)';
