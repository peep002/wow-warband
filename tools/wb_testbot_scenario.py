"""The Warband test plan the bot plays. Run with:  python tools/wb_testbot.py run   (-v: every chat line)
Add "restart" to also restart the worldserver mid-mission (about 2 minutes more):
    python tools/wb_testbot.py run restart

Each run makes a fresh commander on WBTESTBOT (old characters named "Wb..." are deleted first),
so nothing of the owner's is touched.

Phase 2 checks:
  1. A new character becomes a commander: level 10, at Raven Hill, no hearthstone, class spells.
  2. Walking out of the hamlet sends you back.
  3. Sergeant Marlow's menu offers the contract; Embark takes you and your bot into the Deadmines.
  4. Leaving the dungeon on a mission puts you back at the entrance.
  5. Killing the target boss completes the mission and brings everyone home.
  6. Abandoning a mission brings everyone home.
  7. (restart) A running mission survives a worldserver restart.
"""
import os
import subprocess
import sys
import time

import wb_testbot as T

HUB_MAP, DEADMINES = 0, 36
MARLOW = 9100000
RHAHKZOR_SPAWN = 79168          # Rhahk'Zor's spawn guid in the Deadmines (world DB creature table)
FROST_NOVA = 122                # a Mage spell trained at level 10
LAUNCHER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server-launcher", "ServerLauncher.exe")


def state(bot):
    return bot.probe("state")


def num(s, key, default=-1):
    try:
        return int(float(s.get(key, default)))
    except ValueError:
        return default


def wait_state(bot, test, timeout=20, every=2):
    """Probe until test(state) is true or time runs out; returns the last state."""
    end = time.time() + timeout
    while True:
        s = state(bot)
        if test(s) or time.time() > end:
            return s
        time.sleep(every)


def talk_to_marlow(bot):
    npc = bot.probe("gonpc %d" % MARLOW)
    if npc.get("gonpc", "none") == "none":
        return None
    # After the jump the server needs a moment to accept the bot's new spot; until then it
    # thinks the bot is still too far away to talk and ignores the request. So: wait, retry.
    for _ in range(3):
        time.sleep(2.5)
        menu = bot.open_menu(npc_guid=T.creature_guid(MARLOW, int(npc["low"])))
        if menu:
            return menu
    return None


def embark(bot, r, label):
    menu = talk_to_marlow(bot)
    r.check(f"{label}: Sergeant Marlow answers", menu is not None)
    if not menu:
        return False
    asked = time.time()
    picked = bot.pick(menu, r"Contract: Into the Deadmines")
    r.check(f"{label}: the board offers Into the Deadmines", picked, " | ".join(t for _, t, _ in menu["options"]))
    sub = bot.wait_menu(asked)
    ok = sub is not None and bot.pick(sub, r"Embark now")
    r.check(f"{label}: Embark is offered", ok)
    s = wait_state(bot, lambda s: num(s, "map") == DEADMINES and s.get("mission") == "deadmines_short")
    r.check(f"{label}: embarking puts you in the Deadmines on the mission",
            num(s, "map") == DEADMINES and s.get("mission") == "deadmines_short" and num(s, "state") == 1,
            f"map={s.get('map')} mission={s.get('mission')} state={s.get('state')}")
    return num(s, "map") == DEADMINES


SERVER_LOG = r"C:\Claude\Projects\azerothcore-warband\build\bin\Release\Server.log"


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


def at_home(s):
    return num(s, "map") == HUB_MAP and 0 <= num(s, "hubdist") < 25


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
    away = state(bot)
    s = wait_state(bot, at_home, timeout=15)
    r.check("2: walking out of the hamlet sends you back", at_home(s),
            f"was hubdist={away.get('hubdist')}, now map={s.get('map')} hubdist={s.get('hubdist')}")

    # 3. Board and embark (with one bot hero) --------------------------------------------------
    print("Test 3: mission board and embark")
    for _ in range(2):  # playerbots is sometimes slow to log a bot in: ask twice before failing
        bot.cmd(".playerbots bot addclass priest")
        s = wait_state(bot, lambda s: num(s, "bots") >= 1, timeout=20)
        if num(s, "bots") >= 1:
            break
    r.check("3: a bot joins the group", num(s, "bots") >= 1, f"bots={s.get('bots')}")
    if embark(bot, r, "3"):
        s = wait_state(bot, lambda s: s.get("botmaps") == str(DEADMINES), timeout=12)
        r.check("3: the bot comes along into the Deadmines", s.get("botmaps") == str(DEADMINES),
                f"botmaps={s.get('botmaps')}")

        # 4. Mission leash ---------------------------------------------------------------------
        print("Test 4: mission leash")
        bot.probe("wander")
        time.sleep(2)
        s = wait_state(bot, lambda s: num(s, "map") == DEADMINES, timeout=20)
        r.check("4: leaving the dungeon on a mission puts you back inside", num(s, "map") == DEADMINES,
                f"map={s.get('map')}")

        # 5. Boss kill -------------------------------------------------------------------------
        print("Test 5: boss kill")
        bot.cmd(".go creature %d" % RHAHKZOR_SPAWN)
        time.sleep(3)
        since = bot.mark()
        k = bot.probe("killboss")
        r.check("5: Rhahk'Zor found and killed", k.get("killed") == "1", str(k))
        r.check("5: 'Mission complete' announced", bot.wait_chat(r"Mission complete", 8, since) is not None)
        s = wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=30)
        r.check("5: everyone is sent home after the boss", at_home(s) and s.get("mission") == "none"
                and num(s, "state") == 0, f"map={s.get('map')} mission={s.get('mission')} state={s.get('state')}")
        s = wait_state(bot, lambda s: s.get("botmaps") == str(HUB_MAP), timeout=12)
        r.check("5: the bot comes home too", s.get("botmaps") == str(HUB_MAP), f"botmaps={s.get('botmaps')}")
        log = " ".join(bot.probe("log").values())
        r.check("5: mission completion is logged", "mission_done" in log, log)

    # 6. Abandon ---------------------------------------------------------------------------------
    print("Test 6: abandon")
    time.sleep(11)  # let the return teleport's grace time pass
    if embark(bot, r, "6"):
        since = bot.mark()
        bot.cmd(".warband abandon")
        r.check("6: abandoning is confirmed", bot.wait_chat(r"Mission abandoned", 6, since) is not None)
        s = wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=20)
        r.check("6: abandoning brings you home", at_home(s) and num(s, "state") == 0,
                f"map={s.get('map')} mission={s.get('mission')} state={s.get('state')}")
        log = " ".join(bot.probe("log").values())
        r.check("6: abandoning is logged", "mission_abandoned" in log, log)

    # 7. Restart -----------------------------------------------------------------------------------
    if restart:
        print("Test 7: restart mid-mission")
        time.sleep(11)
        if embark(bot, r, "7"):
            bot.logout()
            subprocess.run([LAUNCHER, "--stop", "warband"], capture_output=True, text=True, timeout=180)
            time.sleep(2)
            subprocess.Popen([LAUNCHER, "--start", "warband"])
            ready = wait_for_ready(180)
            r.check("7: the worldserver comes back up", ready)
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
            r.check("7: after a restart the mission is still running", s.get("mission") == "deadmines_short"
                    and num(s, "state") == 1, f"mission={s.get('mission')} state={s.get('state')}")
            r.check("7: after a restart you're in the mission's dungeon", num(s, "map") == DEADMINES,
                    f"map={s.get('map')}")
            bot2.cmd(".go creature %d" % RHAHKZOR_SPAWN)
            time.sleep(3)
            bot2.probe("killboss")
            wait_state(bot2, lambda s: at_home(s) and s.get("mission") == "none", timeout=30)
            bot = bot2

    bot.cmd(".playerbots bot remove *")
    passed = sum(1 for _, ok, _ in r.rows if ok)
    print(f"\n{passed}/{len(r.rows)} checks passed.")
    for name, ok, detail in r.rows:
        if not ok:
            print(f"  FAILED: {name}  {detail}")
