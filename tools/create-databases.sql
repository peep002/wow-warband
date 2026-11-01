-- Creates Warband's own empty databases and lets the server's "acore" MySQL user use them.
-- Run ONCE as the MySQL root user (the owner types the root password; see docs/DEV-ENVIRONMENT.md).
-- Safe to re-run: nothing is created twice and nothing existing is deleted.
-- The worldserver fills the empty databases with AzerothCore's tables on its first start.
-- The Scholomance server's acore_* databases are not touched.

CREATE DATABASE IF NOT EXISTS `warband_auth`       DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `warband_characters` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `warband_world`      DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `warband_playerbots` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- The "acore" user already exists (made for the Scholomance server, local logins only).
GRANT ALL PRIVILEGES ON `warband_auth`.*       TO 'acore'@'localhost';
GRANT ALL PRIVILEGES ON `warband_characters`.* TO 'acore'@'localhost';
GRANT ALL PRIVILEGES ON `warband_world`.*      TO 'acore'@'localhost';
GRANT ALL PRIVILEGES ON `warband_playerbots`.* TO 'acore'@'localhost';
FLUSH PRIVILEGES;
