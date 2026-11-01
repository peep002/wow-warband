-- 001_hamlet.sql  (database: warband_world)
-- Phase 2: the hamlet at Raven Hill, Duskwood.
--   * Hides the few NPCs living in Raven Hill village, so the hamlet starts empty and safe for
--     both factions (Jitters is Alliance and would attack Horde commanders; Bliztik is a vendor,
--     and the closed economy only allows the hamlet's own vendor). Reversible: each creature's
--     original spawnMask is saved first, then set to 0 (= never spawns).
--     Undo: sql/undo/001_hamlet_undo.sql
--   * Adds Sergeant Marlow (9100000), who keeps the mission board, standing where Jitters stood.
-- Safe to run more than once. Needs a worldserver restart (creature spawns load at startup).

-- Hide Raven Hill's own NPCs ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `warband_hidden_creature` (
    `guid`      INT UNSIGNED     NOT NULL PRIMARY KEY,
    `spawnMask` TINYINT UNSIGNED NOT NULL
) COMMENT = 'Warband: original spawnMask of creatures hidden by sql/updates/001_hamlet.sql';

-- Jitters (288), Bliztik (2481) and the invisible Unseen (3094) within 180 yards of the hamlet.
INSERT IGNORE INTO `warband_hidden_creature` (`guid`, `spawnMask`)
SELECT `guid`, `spawnMask` FROM `creature`
WHERE `map` = 0 AND `id` IN (288, 2481, 3094) AND `spawnMask` <> 0
  AND SQRT(POW(`position_x` + 10742.2, 2) + POW(`position_y` - 330.574, 2)) < 180;

UPDATE `creature` c JOIN `warband_hidden_creature` h ON h.`guid` = c.`guid` SET c.`spawnMask` = 0;

-- Sergeant Marlow, keeper of the mission board -----------------------------------------------
DELETE FROM `creature`                WHERE `guid` = 9100000;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 9100000;
DELETE FROM `creature_template`       WHERE `entry` = 9100000;
DELETE FROM `npc_text`                WHERE `ID` = 9100000;

-- Copied from an existing armoured human NPC (68, Stormwind City Guard) so every column is
-- valid, then made neutral: gossip only (1), friendly to everyone (35), no scripts of its own.
DROP TEMPORARY TABLE IF EXISTS `wb_tmp_template`;
CREATE TEMPORARY TABLE `wb_tmp_template` AS SELECT * FROM `creature_template` WHERE `entry` = 68;
DROP TEMPORARY TABLE IF EXISTS `wb_tmp_model`;
CREATE TEMPORARY TABLE `wb_tmp_model` AS SELECT * FROM `creature_template_model` WHERE `CreatureID` = 68;
UPDATE `wb_tmp_template` SET `entry` = 9100000, `name` = 'Sergeant Marlow', `subname` = 'Mission Board',
    `npcflag` = 1, `faction` = 35, `gossip_menu_id` = 0, `ScriptName` = '', `AIName` = '',
    `minlevel` = 30, `maxlevel` = 30;
INSERT INTO `creature_template` SELECT * FROM `wb_tmp_template`;
UPDATE `wb_tmp_model` SET `CreatureID` = 9100000;
INSERT INTO `creature_template_model` SELECT * FROM `wb_tmp_model`;
DROP TEMPORARY TABLE `wb_tmp_template`;
DROP TEMPORARY TABLE `wb_tmp_model`;

-- Where Jitters stood, in the middle of the village, facing the road in.
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`,
    `MovementType`, `Comment`)
VALUES (9100000, 9100000, 0, 0, 0, 1, 1, -10731.4, 337.138, 38.4686, 3.6, 300, 0, 0,
    'Warband: Sergeant Marlow (mission board)');

-- The text above the menu ($n = the player's name).
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `Probability0`) VALUES
(9100000, 'Contracts are posted, Commander $n. Pick one, pick your four, and we march.',
          'Contracts are posted, Commander $n. Pick one, pick your four, and we march.', 1);
