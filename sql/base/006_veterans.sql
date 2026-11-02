-- 006_veterans.sql  (database: warband_characters)
-- After the first playtest: every tavern batch has free recruits a few levels below the roster, and
-- paid veterans at the roster's level with better (blue) starting gear and a second good trait.
-- Adds those fields to recruits and heroes. Safe to re-run: columns are only added if missing.

DROP PROCEDURE IF EXISTS `wb_add_column`;
DELIMITER //
CREATE PROCEDURE `wb_add_column`(IN tbl VARCHAR(64), IN col VARCHAR(64), IN def VARCHAR(255))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND COLUMN_NAME = col) THEN
        SET @sql := CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', def);
        PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    END IF;
END //
DELIMITER ;

CALL `wb_add_column`('warband_recruits', 'trait_pos2', 'VARCHAR(24) NOT NULL DEFAULT '''' AFTER `trait_pos`');
CALL `wb_add_column`('warband_recruits', 'gear_quality', 'TINYINT UNSIGNED NOT NULL DEFAULT 2');
CALL `wb_add_column`('warband_recruits', 'veteran', 'TINYINT UNSIGNED NOT NULL DEFAULT 0');
CALL `wb_add_column`('warband_heroes', 'trait_pos2', 'VARCHAR(24) NOT NULL DEFAULT '''' AFTER `trait_pos`');
CALL `wb_add_column`('warband_heroes', 'gear_quality', 'TINYINT UNSIGNED NOT NULL DEFAULT 2');

DROP PROCEDURE `wb_add_column`;
