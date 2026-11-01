-- 002_roster_tables.sql  (database: warband_characters)
-- Phase 3: heroes on a company's roster, and the recruits waiting in its tavern.
-- Safe to re-run: tables are only created if missing.

-- A hero is a character on the hero account (Config.heroes.account) that a company has hired.
CREATE TABLE IF NOT EXISTS `warband_heroes` (
    `guid`      INT UNSIGNED     NOT NULL PRIMARY KEY COMMENT 'the hero character',
    `company`   INT UNSIGNED     NOT NULL COMMENT 'warband_company.guid',
    `spec_no`   TINYINT UNSIGNED NOT NULL COMMENT 'playerbots premade spec number',
    `role`      VARCHAR(8)       NOT NULL COMMENT 'tank, healer or dps',
    `trait_pos` VARCHAR(24)      NOT NULL DEFAULT '',
    `trait_neg` VARCHAR(24)      NOT NULL DEFAULT '',
    `backstory` VARCHAR(255)     NOT NULL DEFAULT '',
    `status`    VARCHAR(8)       NOT NULL DEFAULT 'alive' COMMENT 'alive, dead, retired',
    `in_party`  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = called to the commander''s group',
    `set_up`    TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = level, spells, talents and gear given',
    `start_level` TINYINT UNSIGNED NOT NULL DEFAULT 10 COMMENT 'level given when first set up',
    `missions`  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `hired`     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `company` (`company`, `status`)
) COMMENT = 'Warband: heroes hired by companies';

-- Recruits offered by a company's tavern; unhired ones are replaced after each mission.
CREATE TABLE IF NOT EXISTS `warband_recruits` (
    `company`   INT UNSIGNED     NOT NULL,
    `guid`      INT UNSIGNED     NOT NULL COMMENT 'a character on the hero account',
    `spec_no`   TINYINT UNSIGNED NOT NULL,
    `role`      VARCHAR(8)       NOT NULL,
    `trait_pos` VARCHAR(24)      NOT NULL DEFAULT '',
    `trait_neg` VARCHAR(24)      NOT NULL DEFAULT '',
    `backstory` VARCHAR(255)     NOT NULL DEFAULT '',
    `level`     TINYINT UNSIGNED NOT NULL,
    `cost`      INT UNSIGNED     NOT NULL COMMENT 'gold; 0 for free founding recruits',
    `founding`  TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`company`, `guid`),
    UNIQUE KEY `guid` (`guid`)
) COMMENT = 'Warband: recruits waiting in each company''s tavern';
