-- 008_stress.sql  (database: warband_characters)
-- Phase 8: every hero has a stress meter (0-200) and, after a resolve check at 100, an affliction or
-- a virtue (`resolve`, a key from Config.resolves; '' = none). `resolve_left` = missions a virtue
-- still lasts (afflictions last until relieved). Safe to re-run: columns are only added if missing.

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

CALL `wb_add_column`('warband_heroes', 'stress', 'SMALLINT UNSIGNED NOT NULL DEFAULT 0');
CALL `wb_add_column`('warband_heroes', 'resolve', 'VARCHAR(16) NOT NULL DEFAULT ''''');
CALL `wb_add_column`('warband_heroes', 'resolve_left', 'TINYINT UNSIGNED NOT NULL DEFAULT 0');

DROP PROCEDURE `wb_add_column`;
