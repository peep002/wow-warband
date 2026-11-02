-- 005_armory.sql  (database: warband_characters)
-- Phase 6: the shared armory. Every item the company loots is stored here instead of in someone's
-- bags; heroes and the commander are equipped from it in the hamlet. Safe to re-run.

CREATE TABLE IF NOT EXISTS `warband_armory` (
    `id`      INT UNSIGNED      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `company` INT UNSIGNED      NOT NULL,
    `entry`   INT UNSIGNED      NOT NULL COMMENT 'item_template entry',
    `count`   SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    `prop`    INT UNSIGNED      NOT NULL DEFAULT 0 COMMENT 'random property id ("of the Bear"), 0 = none',
    `suffix`  INT UNSIGNED      NOT NULL DEFAULT 0 COMMENT 'random suffix id, 0 = none',
    `added`   TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `company` (`company`)
) COMMENT = 'Warband: items in each company''s shared armory';
