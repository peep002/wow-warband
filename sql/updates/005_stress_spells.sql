-- 005_stress_spells.sql  (database: warband_world)
-- Phase 8: hidden auras for the afflictions and virtues that change a hero's numbers (same kind of
-- server-only passive spell as 004_trait_spells.sql). wb_traits.lua keeps them on heroes.
-- Safe to run more than once. Needs a worldserver restart.
-- Undo: DELETE FROM spell_dbc WHERE ID BETWEEN 102010 AND 102019;

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 102010 AND 102019;

INSERT INTO `spell_dbc` (`ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `RangeIndex`,
    `EquippedItemClass`, `SchoolMask`,
    `Effect_1`, `ImplicitTargetA_1`, `EffectAura_1`, `EffectMiscValue_1`, `EffectBasePoints_1`,
    `Name_Lang_enUS`) VALUES
-- Attributes 0x1C0 = passive, hidden, not in the combat log; duration 21 = forever; range 1 = self.
-- Hopeless: aura 79 (damage done, %) for every school (misc 127): -15%.
(102010, 0x1C0, 1, 21, 1, -1, 1, 6, 1, 79, 127, -15, 'Warband: Hopeless'),
-- Focused: aura 290 (critical strike chance of all attacks and spells): +10.
(102011, 0x1C0, 1, 21, 1, -1, 1, 6, 1, 290, 0, 10, 'Warband: Focused');
