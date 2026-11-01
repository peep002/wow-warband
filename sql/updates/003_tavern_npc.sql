-- 003_tavern_npc.sql  (database: warband_world)
-- Phase 3: Maude Ashby (9100001), who runs the tavern in Raven Hill, standing on the west side of
-- the village. Copied from an existing NPC (68) like Sergeant Marlow, then made neutral.
-- Safe to run more than once. Needs a worldserver restart.

DELETE FROM `creature`                WHERE `guid` = 9100001;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 9100001;
DELETE FROM `creature_template`       WHERE `entry` = 9100001;
DELETE FROM `npc_text`                WHERE `ID` = 9100001;

DROP TEMPORARY TABLE IF EXISTS `wb_tmp_template`;
CREATE TEMPORARY TABLE `wb_tmp_template` AS SELECT * FROM `creature_template` WHERE `entry` = 68;
DROP TEMPORARY TABLE IF EXISTS `wb_tmp_model`;
-- An innkeeper's look instead of the guard's (copied from Innkeeper Allison, 6740).
CREATE TEMPORARY TABLE `wb_tmp_model` AS SELECT * FROM `creature_template_model` WHERE `CreatureID` = 6740;
UPDATE `wb_tmp_template` SET `entry` = 9100001, `name` = 'Maude Ashby', `subname` = 'Tavern',
    `npcflag` = 1, `faction` = 35, `gossip_menu_id` = 0, `ScriptName` = '', `AIName` = '',
    `minlevel` = 30, `maxlevel` = 30;
INSERT INTO `creature_template` SELECT * FROM `wb_tmp_template`;
UPDATE `wb_tmp_model` SET `CreatureID` = 9100001;
INSERT INTO `creature_template_model` SELECT * FROM `wb_tmp_model`;
DROP TEMPORARY TABLE `wb_tmp_template`;
DROP TEMPORARY TABLE `wb_tmp_model`;

INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`,
    `MovementType`, `Comment`)
VALUES (9100001, 9100001, 0, 0, 0, 1, 1, -10759.6, 343.884, 38.4286, 6.0, 300, 0, 0,
    'Warband: Maude Ashby (tavern)');

INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `Probability0`) VALUES
(9100001, 'Looking for blades, Commander $n? I''ve got a few who''ll sign for coin and a warm meal.',
          'Looking for blades, Commander $n? I''ve got a few who''ll sign for coin and a warm meal.', 1);
