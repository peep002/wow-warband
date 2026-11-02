-- 004_trait_spells.sql  (database: warband_world)
-- Phase 7: hidden auras for the traits that change a hero's numbers. Each row is a spell that
-- exists only on the server (spell_dbc adds spells to the game's spell list when worldserver
-- starts): a passive aura with no buff icon. wb_traits.lua keeps it on heroes with the trait.
-- Same trick as the Scholomance project's instant-cast auras (WoW-Roguelike sql/016).
--
-- Spell ids: Warband uses 102000-102099 (AzerothCore's own spell_dbc rows end at 100102; a
-- 9100000+ id would make the server reserve room for 9 million spells).
-- Safe to run more than once. Needs a worldserver restart.
-- Undo: DELETE FROM spell_dbc WHERE ID BETWEEN 102000 AND 102099;

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 102000 AND 102099;

INSERT INTO `spell_dbc` (`ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `RangeIndex`,
    `EquippedItemClass`, `SchoolMask`,
    `Effect_1`, `ImplicitTargetA_1`, `EffectAura_1`, `EffectMiscValue_1`, `EffectBasePoints_1`,
    `Effect_2`, `ImplicitTargetA_2`, `EffectAura_2`, `EffectMiscValue_2`, `EffectBasePoints_2`,
    `Name_Lang_enUS`) VALUES
-- Attributes 0x1C0 = passive, hidden from the client, not in the combat log. Duration 21 = forever,
-- range 1 = self, effect 6 = apply an aura.
-- Stalwart Shield: aura 10 (threat caused, %) for every school (misc 127): +10%.
(102000, 0x1C0, 1, 21, 1, -1, 1, 6, 1, 10, 127, 10, 0, 0, 0, 0, 0, 'Warband: Stalwart Shield'),
-- Glass Jaw: aura 203 (melee crit damage taken, %) +8 and aura 204 (ranged crit damage taken) +8.
(102001, 0x1C0, 1, 21, 1, -1, 1, 6, 1, 203, 0, 8, 6, 1, 204, 0, 8, 'Warband: Glass Jaw');
