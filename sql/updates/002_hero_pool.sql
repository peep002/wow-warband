-- 002_hero_pool.sql  (databases: warband_auth, warband_characters, warband_playerbots)
-- Phase 3: the pool of hero characters.
--   * Makes the WBHEROES account. Its password is random bytes, so nobody can ever log in to it;
--     it only holds hero characters, which commanders control as bots.
--   * Moves playerbots' ready-made "AddClass" characters (all classes, both factions, offline)
--     onto it. On the next start playerbots makes new AddClass characters for itself.
--     Why move them: playerbots re-rolls an AddClass bot's level and gear whenever it logs in more
--     than 3 levels away from its master, which would wipe a hero. Off those accounts, it doesn't.
--
-- RUN ONLY WHILE THE WORLDSERVER IS STOPPED: the server caches which account owns each character.
-- Safe to re-run: re-running tops the pool up with whatever AddClass characters exist by then.

INSERT INTO `warband_auth`.`account` (`username`, `salt`, `verifier`, `email`, `reg_mail`, `expansion`)
SELECT 'WBHEROES', RANDOM_BYTES(32), RANDOM_BYTES(32), '', '', 2
WHERE NOT EXISTS (SELECT 1 FROM `warband_auth`.`account` WHERE `username` = 'WBHEROES');

UPDATE `warband_characters`.`characters` c
JOIN `warband_playerbots`.`playerbots_account_type` t ON t.`account_id` = c.`account` AND t.`account_type` = 2
SET c.`account` = (SELECT `id` FROM `warband_auth`.`account` WHERE `username` = 'WBHEROES')
WHERE c.`online` = 0;
