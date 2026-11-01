"""The Warband test plan the bot plays. Run with:  python tools/wb_testbot.py run   (-v: every chat line)
Add "restart" to also restart the worldserver mid-mission (about 2 minutes more):
    python tools/wb_testbot.py run restart

Each run makes a fresh commander on WBTESTBOT (old characters named "Wb..." are deleted first,
which also frees their heroes), so nothing of the owner's is touched.

  1. A new character becomes a commander: level 10, at Raven Hill, no hearthstone, class spells.
  2. Walking out of the hamlet sends you back.
  3. The founding tavern: 6 free recruits incl. a tank and a healer; hire 4 (Maude's menu and
     .warband hire); call heroes to the party, they log in set up at level 10; send one away;
     other bots can't march.
  4. Sergeant Marlow's menu offers the contract; Embark takes you and your heroes into the Deadmines.
  5. Leaving the dungeon on a mission puts you back at the entrance.
  6. Killing the target boss completes the mission and brings everyone home; heroes count the
     mission; a new batch of paid recruits arrives; a full roster can't hire.
  7. Abandoning a mission brings everyone home.
  8. (restart) A running mission and the party survive a worldserver restart.
"""
import os
import subprocess
import sys
import time

import wb_testbot as T

HUB_MAP, DEADMINES = 0, 36
MARLOW, MAUDE = 9100000, 9100001
RHAHKZOR_SPAWN = 79168          # Rhahk'Zor's spawn guid in the Deadmines (world DB creature table)
FROST_NOVA = 122                # a Mage spell trained at level 10
LAUNCHER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server-launcher", "ServerLauncher.exe")
SERVER_LOG = r"C:\Claude\Projects\azerothcore-warband\build\bin\Release\Server.log"


# Read-outs ------------------------------------------------------------------------------------

def state(bot):
    return bot.probe("state")


def num(s, key, default=-1):
    try:
        return int(float(s.get(key, default)))
    except ValueError:
        return default


def wait_state(bot, test, timeout=20, every=2, probe="state"):
    """Probe until test(read-out) is true or time runs out; returns the last read-out."""
    end = time.time() + timeout
    while True:
        s = bot.probe(probe)
        if test(s) or time.time() > end:
            return s
        time.sleep(every)


def roster(bot):
    """{name: dict(class, level, party, online, missions, status)} plus the raw read-out."""
    s = bot.probe("roster")
    heroes = {}
    for part in s.get("list", "none").split(","):
        f = part.split(":")
        if len(f) == 7:
            heroes[f[0]] = dict(cls=int(f[1]), level=int(f[2]), party=f[3] == "1", online=f[4] == "1",
                                missions=int(f[5]), status=f[6])
    return heroes, s


def tavern(bot):
    s = bot.probe("tavern")
    recruits = []
    for part in s.get("list", "none").split(","):
        f = part.split(":")
        if len(f) == 5:
            recruits.append(dict(name=f[0], role=f[1], level=int(f[2]), cost=int(f[3]), founding=f[4] == "1"))
    return recruits, s


def at_home(s):
    return num(s, "map") == HUB_MAP and 0 <= num(s, "hubdist") < 25


def wait_for_ready(timeout):
    """After a start, wait until the worldserver's log says it's ready (the log is rewritten
    from scratch on every start)."""
    time.sleep(5)
    end = time.time() + timeout
    while time.time() < end:
        try:
            with open(SERVER_LOG, encoding="utf-8", errors="replace") as f:
                if "ready..." in f.read():
                    time.sleep(5)
                    return True
        except OSError:
            pass
        time.sleep(3)
    return False


# Actions --------------------------------------------------------------------------------------

def talk_to(bot, entry):
    npc = bot.probe("gonpc %d" % entry)
    if npc.get("gonpc", "none") == "none":
        return None
    # After the jump the server needs a moment to accept the bot's new spot; until then it
    # thinks the bot is still too far away to talk and ignores the request. So: wait, retry.
    for _ in range(3):
        time.sleep(2.5)
        menu = bot.open_menu(npc_guid=T.creature_guid(entry, int(npc["low"])))
        if menu:
            return menu
    return None


def embark(bot, r, label, expect_ok=True):
    menu = talk_to(bot, MARLOW)
    r.check(f"{label}: Sergeant Marlow answers", menu is not None)
    if not menu:
        return False
    asked = time.time()
    picked = bot.pick(menu, r"Contract: Into the Deadmines")
    r.check(f"{label}: the board offers Into the Deadmines", picked, " | ".join(t for _, t, _ in menu["options"]))
    sub = bot.wait_menu(asked)
    since = bot.mark()
    ok = sub is not None and bot.pick(sub, r"Embark now")
    r.check(f"{label}: Embark is offered", ok)
    if not expect_ok:
        return bot.wait_chat(r"Only your company's heroes|Call at least", 6, since)
    s = wait_state(bot, lambda s: num(s, "map") == DEADMINES and s.get("mission") == "deadmines_short")
    r.check(f"{label}: embarking puts you in the Deadmines on the mission",
            num(s, "map") == DEADMINES and s.get("mission") == "deadmines_short" and num(s, "state") == 1,
            f"map={s.get('map')} mission={s.get('mission')} state={s.get('state')}")
    return num(s, "map") == DEADMINES


def kill_boss(bot):
    bot.cmd(".go creature %d" % RHAHKZOR_SPAWN)
    time.sleep(3)
    return bot.probe("killboss")


# The plan -------------------------------------------------------------------------------------

def main(bot, r, only=None):
    restart = "restart" in sys.argv
    bot.connect()
    gone = bot.delete_old_characters()
    print(f"Deleted {gone} old test characters.")
    char = bot.create_character(T.CLASS_MAGE, "Wb")
    bot.enter_world(char)
    time.sleep(3)
    bot.cmd(".gm off")
    # A level-10 commander dies fast in the Deadmines while the bot stands still, and a dead
    # player can't talk to NPCs. God mode keeps it alive; it still counts as a normal player.
    bot.cmd(".cheat god on")
    bot.cmd(".reload ale", r"[Rr]eload", 10)  # run the newest scripts (after the commander was made)
    time.sleep(2)

    # 1. New commander -------------------------------------------------------------------------
    print("Test 1: new commander")
    s = wait_state(bot, lambda s: num(s, "commander") == 1 and at_home(s), timeout=12)
    r.check("1: a new character becomes a commander", num(s, "commander") == 1)
    r.check("1: commander starts at level 10", num(s, "level") == 10, f"level={s.get('level')}")
    r.check("1: commander arrives at Raven Hill", at_home(s), f"map={s.get('map')} hubdist={s.get('hubdist')}")
    r.check("1: company is in the hamlet", num(s, "state") == 0)
    r.check("1: no hearthstone", num(s, "hearthstone") == 0, f"hearthstone={s.get('hearthstone')}")
    sp = bot.probe("hasspell %d" % FROST_NOVA)
    r.check("1: class spells learned on level-up (Frost Nova)", sp.get("known") == "1")
    log = bot.probe("log")
    r.check("1: company creation is logged", "company_created" in " ".join(log.values()))

    # 2. Hamlet leash --------------------------------------------------------------------------
    print("Test 2: hamlet leash")
    bot.probe("wander")
    time.sleep(2)
    s = wait_state(bot, at_home, timeout=15)
    r.check("2: walking out of the hamlet sends you back", at_home(s), f"map={s.get('map')} hubdist={s.get('hubdist')}")

    # 3. Tavern and roster ---------------------------------------------------------------------
    print("Test 3: tavern and roster")
    recruits, raw = tavern(bot)
    roles = [x["role"] for x in recruits]
    r.check("3: the founding tavern offers 6 recruits", len(recruits) == 6, raw.get("list"))
    r.check("3: founding recruits include a tank and a healer", "tank" in roles and "healer" in roles, ",".join(roles))
    r.check("3: founding recruits are free, 4 hires", num(raw, "free") == 4 and all(x["cost"] == 0 for x in recruits),
            f"free={raw.get('free')}")
    r.check("3: founding recruits are at the commander's level", all(x["level"] == 10 for x in recruits))

    menu = talk_to(bot, MAUDE)
    r.check("3: Maude Ashby answers", menu is not None)
    first = None
    if menu:
        first = bot.pick(menu, r"^Hire ")
        time.sleep(2)
    heroes, _ = roster(bot)
    r.check("3: hiring from Maude's menu puts the recruit on the roster", len(heroes) == 1, f"picked={first}")

    recruits, _ = tavern(bot)
    for rec in recruits[:3]:
        since = bot.mark()
        bot.cmd(".warband hire " + rec["name"])
        bot.wait_chat(r"signs with the company|\[Warband\]", 5, since)
    heroes, raw = roster(bot)
    r.check("3: four founding heroes hired", len(heroes) == 4, raw.get("list"))
    recruits, raw = tavern(bot)
    r.check("3: after 4 hires the other founding recruits leave", len(recruits) == 0, raw.get("list"))
    log = " ".join(bot.probe("log").values())
    r.check("3: hiring is logged", "hero_hired" in log, log)

    names = sorted(heroes)
    for name in names[:2]:
        bot.cmd(".warband call " + name)
        time.sleep(1)
    # In the roster read-out ":1:1:" = in the party and online.
    wait_state(bot, lambda s: s.get("list", "").count(":1:1:") >= 2, timeout=30, probe="roster")
    heroes, raw = roster(bot)
    online = [n for n, h in heroes.items() if h["online"]]
    r.check("3: called heroes log in", len(online) == 2, raw.get("list"))
    r.check("3: a new hero is set up at its recruit level (10)", all(heroes[n]["level"] == 10 for n in online),
            ",".join(f"{n}={heroes[n]['level']}" for n in online))
    s = wait_state(bot, lambda s: s.get("botmaps") == "0,0", timeout=15)
    r.check("3: called heroes join your group in the hamlet", num(s, "bots") == 2 and s.get("botmaps") == "0,0",
            f"bots={s.get('bots')} botmaps={s.get('botmaps')}")

    bot.cmd(".warband send " + names[1])
    s = wait_state(bot, lambda s: num(s, "bots") == 1, timeout=15)
    heroes, raw = roster(bot)
    r.check("3: a hero sent to the barracks leaves the party", num(s, "bots") == 1 and not heroes[names[1]]["party"],
            raw.get("list"))

    # Bots that aren't the company's heroes can't march.
    for _ in range(2):  # playerbots is sometimes slow to log a bot in: ask twice before failing
        bot.cmd(".playerbots bot addclass priest")
        s = wait_state(bot, lambda s: num(s, "bots") >= 2, timeout=20)
        if num(s, "bots") >= 2:
            break
    refused = embark(bot, r, "3", expect_ok=False) if num(s, "bots") >= 2 else None
    r.check("3: other bots in the group can't march", refused is not None, f"bots={s.get('bots')}")
    bot.cmd(".playerbots bot remove *")
    time.sleep(3)
    bot.cmd(".warband call " + names[0])  # the hero was logged out by "remove *": bring them back
    s = wait_state(bot, lambda s: num(s, "bots") == 1 and s.get("botmaps") == "0", timeout=25)
    r.check("3: a hero logged out by other means can be called back", num(s, "bots") == 1, f"bots={s.get('bots')}")

    # 4. Board and embark ------------------------------------------------------------------------
    print("Test 4: mission board and embark")
    if embark(bot, r, "4"):
        s = wait_state(bot, lambda s: s.get("botmaps") == str(DEADMINES), timeout=12)
        r.check("4: the hero comes along into the Deadmines", s.get("botmaps") == str(DEADMINES),
                f"botmaps={s.get('botmaps')}")

        # 5. Mission leash -----------------------------------------------------------------------
        print("Test 5: mission leash")
        bot.probe("wander")
        time.sleep(2)
        s = wait_state(bot, lambda s: num(s, "map") == DEADMINES, timeout=20)
        r.check("5: leaving the dungeon on a mission puts you back inside", num(s, "map") == DEADMINES,
                f"map={s.get('map')}")

        # 6. Boss kill -------------------------------------------------------------------------
        print("Test 6: boss kill")
        since = bot.mark()
        k = kill_boss(bot)
        r.check("6: Rhahk'Zor found and killed", k.get("killed") == "1", str(k))
        r.check("6: 'Mission complete' announced", bot.wait_chat(r"Mission complete", 8, since) is not None)
        s = wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=30)
        r.check("6: everyone is sent home after the boss", at_home(s) and s.get("mission") == "none"
                and num(s, "state") == 0, f"map={s.get('map')} mission={s.get('mission')} state={s.get('state')}")
        s = wait_state(bot, lambda s: s.get("botmaps") == str(HUB_MAP), timeout=12)
        r.check("6: the hero comes home too", s.get("botmaps") == str(HUB_MAP), f"botmaps={s.get('botmaps')}")
        log = " ".join(bot.probe("log").values())
        r.check("6: mission completion is logged", "mission_done" in log, log)
        heroes, raw = roster(bot)
        r.check("6: the hero on the mission counts it", heroes[names[0]]["missions"] == 1
                and heroes[names[2]]["missions"] == 0, raw.get("list"))
        recruits, raw = tavern(bot)
        r.check("6: a new batch of 4 recruits arrives", len(recruits) == 4, raw.get("list"))
        r.check("6: new recruits cost gold", recruits and all(x["cost"] > 0 and not x["founding"] for x in recruits),
                raw.get("list"))
        if recruits:
            since = bot.mark()
            bot.cmd(".warband hire " + recruits[0]["name"])
            r.check("6: a full roster can't hire", bot.wait_chat(r"roster is full", 5, since) is not None)

    # 7. Abandon -------------------------------------------------------------------------------
    print("Test 7: abandon")
    time.sleep(11)  # let the return teleport's grace time pass
    if embark(bot, r, "7"):
        since = bot.mark()
        bot.cmd(".warband abandon")
        r.check("7: abandoning is confirmed", bot.wait_chat(r"Mission abandoned", 6, since) is not None)
        s = wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=20)
        r.check("7: abandoning brings you home", at_home(s) and num(s, "state") == 0,
                f"map={s.get('map')} mission={s.get('mission')} state={s.get('state')}")
        log = " ".join(bot.probe("log").values())
        r.check("7: abandoning is logged", "mission_abandoned" in log, log)

    # 8. Restart -------------------------------------------------------------------------------
    if restart:
        print("Test 8: restart mid-mission")
        time.sleep(11)
        if embark(bot, r, "8"):
            bot.logout()
            subprocess.run([LAUNCHER, "--stop", "warband"], capture_output=True, text=True, timeout=180)
            time.sleep(2)
            subprocess.Popen([LAUNCHER, "--start", "warband"])
            r.check("8: the worldserver comes back up", wait_for_ready(180))
            # The first login after a start can be slow (the dungeon map loads then): one session,
            # and ask to enter the world again if the first answer doesn't come.
            time.sleep(15)
            bot2 = T.Bot(verbose=bot.verbose)
            bot2.connect()
            bot2.characters()  # the server only accepts a login for characters it has listed
            for attempt in range(3):
                try:
                    bot2.enter_world(char)
                    break
                except TimeoutError:
                    print(f"  (login attempt {attempt + 1} timed out, asking again)")
            time.sleep(3)
            bot2.cmd(".gm off")
            bot2.cmd(".cheat god on")
            s = wait_state(bot2, lambda s: num(s, "map") == DEADMINES, timeout=20)
            r.check("8: after a restart the mission is still running", s.get("mission") == "deadmines_short"
                    and num(s, "state") == 1, f"mission={s.get('mission')} state={s.get('state')}")
            r.check("8: after a restart you're in the mission's dungeon", num(s, "map") == DEADMINES,
                    f"map={s.get('map')}")
            s = wait_state(bot2, lambda s: s.get("botmaps") == str(DEADMINES), timeout=30)
            r.check("8: after a restart the party hero comes back and joins you", s.get("botmaps") == str(DEADMINES),
                    f"bots={s.get('bots')} botmaps={s.get('botmaps')}")
            kill_boss(bot2)
            wait_state(bot2, lambda s: at_home(s) and s.get("mission") == "none", timeout=30)
            bot = bot2

    passed = sum(1 for _, ok, _ in r.rows if ok)
    print(f"\n{passed}/{len(r.rows)} checks passed.")
    for name, ok, detail in r.rows:
        if not ok:
            print(f"  FAILED: {name}  {detail}")
