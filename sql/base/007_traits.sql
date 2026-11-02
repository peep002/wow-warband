-- 007_traits.sql  (database: warband_characters)
-- Phase 7: a Greedy hero sometimes pockets a drop on its way to the armory. The item stays in the
-- armory table, marked with the hero who has it (`pocket`); it doesn't show or count until it comes
-- back (when that hero dies for good). Safe to re-run: the column is only added if missing.

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

CALL `wb_add_column`('warband_armory', 'pocket', 'INT UNSIGNED NOT NULL DEFAULT 0');

DROP PROCEDURE `wb_add_column`;
