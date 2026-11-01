-- 001_hamlet_undo.sql  (database: warband_world)
-- Undoes sql/updates/001_hamlet.sql: brings Raven Hill's own NPCs back and removes Sergeant
-- Marlow. Needs a worldserver restart.

UPDATE `creature` c JOIN `warband_hidden_creature` h ON h.`guid` = c.`guid` SET c.`spawnMask` = h.`spawnMask`;
DROP TABLE `warband_hidden_creature`;

DELETE FROM `creature`                WHERE `guid` = 9100000;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 9100000;
DELETE FROM `creature_template`       WHERE `entry` = 9100000;
DELETE FROM `npc_text`                WHERE `ID` = 9100000;
