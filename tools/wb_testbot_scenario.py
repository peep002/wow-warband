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
Phase 4 adds: the board deals Act I contracts that fit your level; kills give 10% XP; a completed
mission gives about 1.5-2.5 levels to you and your heroes (heroes spend their new talent points);
act progress; every embark is a fresh copy of the dungeon; abandoning gives a quarter; the gate;
nobody passes the act's level cap.
Phase 5 adds (test 11): a downed hero saved by the fight ending is wounded; downed again while
wounded = dead for good (memorial wall); bleeding out = dead for good; a wipe fails the mission,
loses the downed heroes and sends the commander home wounded; treating a wound costs gold; a
wounded hero who sits out a mission heals.
"""
import os
import subprocess
import sys
import time

import wb_testbot as T

HUB_MAP, DEADMINES = 0, 36
MARLOW, MAUDE = 9100000, 9100001
RHAHKZOR_SPAWN = 79168          # Rhahk'Zor's spawn guid in the Deadmines (world DB creature table)
VANCLEEF_SPAWN = 79336          # Edwin VanCleef's spawn guid
DEFIAS_MINER = 598              # a monster near the Deadmines entrance
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
        if len(f) == 10:
            heroes[f[0]] = dict(cls=int(f[1]), level=int(f[2]), party=f[3] == "1", online=f[4] == "1",
                                missions=int(f[5]), status=f[6], talents=int(f[7]), wounded=f[8] == "1",
                                alive=f[9] == "1")
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


def embark(bot, r, label, expect_ok=True, key="deadmines_short", contract="Into the Deadmines"):
    """Put exactly this contract on the board (the board is random), then take it at Marlow."""
    bot.probe("board " + key)
    menu = talk_to(bot, MARLOW)
    r.check(f"{label}: Sergeant Marlow answers", menu is not None)
    if not menu:
        return False
    asked = time.time()
    picked = bot.pick(menu, "Contract: " + contract)
    r.check(f"{label}: the board offers {contract}", picked, " | ".join(t for _, t, _ in menu["options"]))
    sub = bot.wait_menu(asked)
    since = bot.mark()
    ok = sub is not None and bot.pick(sub, r"Embark now")
    r.check(f"{label}: Embark is offered", ok)
    if not expect_ok:
        return bot.wait_chat(r"Only your company's heroes|Call at least", 6, since)
    s = wait_state(bot, lambda s: num(s, "map") == DEADMINES and s.get("mission") == key)
    r.check(f"{label}: embarking puts you in the Deadmines on the mission",
            num(s, "map") == DEADMINES and s.get("mission") == key and num(s, "state") == 1,
            f"map={s.get('map')} mission={s.get('mission')} state={s.get('state')}")
    return num(s, "map") == DEADMINES


def kill_boss(bot, spawn=RHAHKZOR_SPAWN):
    bot.cmd(".go creature %d" % spawn)
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
    b = bot.probe("board")
    offers = [k for k in b.get("board", "").split(",") if k]
    r.check("1: the board offers Act I contracts a level-10 commander is ready for",
            len(offers) >= 2 and set(offers) <= {"ragefire_short", "deadmines_short"}, b.get("board"))
    r.check("1: a new company starts Act I with no progress", num(b, "act") == 1 and num(b, "progress") == 0, str(b))

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
        time.sleep(3)
        x0 = bot.probe("xp")
        k = bot.probe("killnear %d" % DEFIAS_MINER)
        time.sleep(1)
        x = bot.probe("xp")
        cut_from, cut_to = num(x, "cutfrom"), num(x, "cutto")
        gained = num(x, "xp") - num(x0, "xp")
        r.check("5: killing a monster gives 10% of its normal XP", k.get("killed") == "1" and cut_from > 0
                and cut_to == cut_from // 10 and gained == cut_to,
                f"normal={cut_from} cut to={cut_to} really gained={gained}")

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
        s = state(bot)
        r.check("6: the commander gains about 1.5 levels (level 11)", num(s, "level") == 11, f"level={s.get('level')}")
        h0 = heroes[names[0]]
        r.check("6: the hero who went gains about 1.5 levels (level 11)", h0["level"] == 11, f"level={h0['level']}")
        r.check("6: the hero spent the new talent points", h0["talents"] == 0, f"unspent={h0['talents']}")
        r.check("6: a hero who stayed home gains nothing (bench XP comes later)", heroes[names[2]]["level"] == 10)
        b = bot.probe("board")
        r.check("6: the main mission counts towards the gate", num(b, "progress") == 1, str(b))
        r.check("6: the board deals new contracts after a mission", "board_dealt" in " ".join(bot.probe("log").values()))
        recruits, raw = tavern(bot)
        r.check("6: a new batch of 4 recruits arrives", len(recruits) == 4, raw.get("list"))
        r.check("6: new recruits cost gold", recruits and all(x["cost"] > 0 and not x["founding"] for x in recruits),
                raw.get("list"))
        if recruits:
            since = bot.mark()
            bot.cmd(".warband hire " + recruits[0]["name"])
            r.check("6: a full roster can't hire", bot.wait_chat(r"roster is full", 5, since) is not None)
        time.sleep(11)
        if embark(bot, r, "6b"):
            k = kill_boss(bot)
            r.check("6b: a second run gets a fresh copy (Rhahk'Zor is alive again)", k.get("killed") == "1", str(k))
            wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=30)
            r.check("6b: two main missions done", num(bot.probe("board"), "progress") == 2)

    # 7. Abandon -------------------------------------------------------------------------------
    print("Test 7: abandon")
    time.sleep(11)  # let the return teleport's grace time pass
    if embark(bot, r, "7"):
        before = bot.probe("xp")
        since = bot.mark()
        bot.cmd(".warband abandon")
        r.check("7: abandoning is confirmed", bot.wait_chat(r"Mission abandoned", 6, since) is not None)
        s = wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=20)
        r.check("7: abandoning brings you home", at_home(s) and num(s, "state") == 0,
                f"map={s.get('map')} mission={s.get('mission')} state={s.get('state')}")
        log = " ".join(bot.probe("log").values())
        r.check("7: abandoning is logged", "mission_abandoned" in log, log)
        after = bot.probe("xp")
        gain = (num(after, "xp") - num(before, "xp")) if num(after, "level") == num(before, "level") else -1
        expect = 1.5 * 0.25 * num(before, "next")
        r.check("7: abandoning gives a quarter of the mission's XP", gain > 0 and abs(gain - expect) <= 0.05 * expect + 2,
                f"gain={gain} expected~{expect:.0f}")
        r.check("7: an abandoned mission doesn't count towards the gate", num(bot.probe("board"), "progress") == 2)

    # 9. The gate --------------------------------------------------------------------------------
    print("Test 9: the act gate")
    time.sleep(11)
    bot.probe("progress 4")
    b = bot.probe("board refresh")
    r.check("9: after 4 main missions the gate is offered", b.get("board", "").startswith("act1_gate"), b.get("board"))
    if embark(bot, r, "9", key="act1_gate", contract="The Brotherhood's Last Stand"):
        since = bot.mark()
        k = kill_boss(bot, VANCLEEF_SPAWN)
        r.check("9: Edwin VanCleef found and killed", k.get("killed") == "1", str(k))
        r.check("9: beating the gate is announced", bot.wait_chat(r"The gate falls", 20, since) is not None)
        wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=30)
        log = " ".join(bot.probe("log").values())
        r.check("9: beating the gate is logged", "act_gate_beaten" in log, log)

    # 10. Level cap ------------------------------------------------------------------------------
    print("Test 10: level cap")
    lvl = num(state(bot), "level")
    bot.cmd(".levelup %d" % (19 - lvl))
    time.sleep(1)
    g = bot.probe("grant 5")
    r.check("10: mission XP stops at the act's level cap (20)", num(g, "level") == 20, str(g))

    # 11. Death's door ---------------------------------------------------------------------------
    print("Test 11: death's door")
    time.sleep(11)
    a, b = names[0], names[2]
    bot.cmd(".warband call " + b)
    wait_state(bot, lambda s: num(s, "bots") == 2, timeout=25)
    if embark(bot, r, "11"):
        time.sleep(4)
        bot.probe("clear")  # a quiet spot: a hero revived at 30% health next to monsters charges them
        time.sleep(2)
        since = bot.mark()
        bot.probe("down " + a)
        r.check("11: a hero at 0 health is downed and the party is told", bot.wait_chat(a + " is down", 5, since) is not None)
        d = bot.probe("downed")
        r.check("11: the bleed-out clock runs (45 seconds)", d.get("downed", "").startswith(a + ":"), str(d))
        time.sleep(6)  # down 3 s + nobody fighting for 3 s, checked every second
        heroes, raw = roster(bot)
        r.check("11: with the fight over, the downed hero is pulled back up", heroes[a]["alive"] and heroes[a]["status"] == "alive",
                raw.get("list"))
        r.check("11: a saved hero is wounded", heroes[a]["wounded"], raw.get("list"))

        since = bot.mark()
        bot.probe("down " + a)
        r.check("11: downed again while wounded = dies for good", bot.wait_chat(a + " has fallen", 6, since) is not None)
        heroes, raw = roster(bot)
        r.check("11: the fallen hero is off the roster's living", heroes[a]["status"] == "dead" and not heroes[a]["party"],
                raw.get("list"))

        bot.probe("down %s hold" % b)
        time.sleep(3)
        since = bot.mark()
        bot.probe("bleed " + b)
        r.check("11: bleeding out = dies for good", bot.wait_chat(b + " has fallen", 6, since) is not None)
        since = bot.mark()
        bot.cmd(".warband memorial")
        r.check("11: both are on the memorial wall", bot.wait_chat("Bled out", 5, since) is not None
                and bot.wait_chat("still wounded", 1, since) is not None)
        log = " ".join(bot.probe("log").values())
        r.check("11: deaths are logged", log.count("hero_died") >= 2, log)
        time.sleep(9)
        heroes, raw = roster(bot)
        r.check("11: fallen heroes are sent away (logged out)", not heroes[a]["online"] and not heroes[b]["online"],
                raw.get("list"))
        bot.cmd(".warband abandon")
        wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=20)

    # A wipe: the last hero down (held), then the commander.
    time.sleep(11)
    c = names[1]
    bot.cmd(".warband call " + c)
    wait_state(bot, lambda s: num(s, "bots") == 1, timeout=25)
    if embark(bot, r, "11w"):
        time.sleep(4)
        bot.probe("clear")
        time.sleep(2)
        bot.probe("down %s hold" % c)
        time.sleep(2)
        bot.cmd(".cheat god off")
        since = bot.mark()
        bot.probe("down me")
        r.check("11w: everyone down at once = the mission fails", bot.wait_chat("mission has failed", 8, since) is not None)
        s = wait_state(bot, lambda s: at_home(s) and num(s, "alive") == 1, timeout=20)
        r.check("11w: the commander wakes up at home, alive", at_home(s) and num(s, "alive") == 1 and s.get("mission") == "none",
                f"map={s.get('map')} alive={s.get('alive')} mission={s.get('mission')}")
        bot.cmd(".cheat god on")
        heroes, raw = roster(bot)
        r.check("11w: the downed hero is lost in the wipe", heroes[c]["status"] == "dead", raw.get("list"))
        r.check("11w: the commander is wounded", num(raw, "cwounded") == 1, str(raw.get("cwounded")))
        gold = num(state(bot), "gold")
        since = bot.mark()
        bot.cmd(".warband treat me")
        r.check("11w: treating a wound is confirmed", bot.wait_chat("is treated", 5, since) is not None)
        r.check("11w: treating costs gold (20 + 2 per level)", num(state(bot), "gold") == gold - (20 + 2 * 20)
                and num(roster(bot)[1], "cwounded") == 0, f"gold {gold} -> {state(bot).get('gold')}")

    # Sitting out heals: wound the last founder, then go without them.
    time.sleep(11)
    w = names[3]
    bot.cmd(".warband call " + w)
    wait_state(bot, lambda s: num(s, "bots") == 1, timeout=25)
    if embark(bot, r, "11s"):
        time.sleep(4)
        bot.probe("clear")
        time.sleep(2)
        bot.probe("down " + w)
        time.sleep(7)
        heroes, raw = roster(bot)
        r.check("11s: the hero is wounded", heroes[w]["wounded"], raw.get("list"))
        bot.cmd(".warband abandon")
        wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=20)
        r.check("11s: a hero who went keeps the wound", roster(bot)[0][w]["wounded"])
        bot.cmd(".warband send " + w)
        recruits, _ = tavern(bot)
        affordable = [x for x in recruits if x["cost"] <= num(state(bot), "gold")]
        if affordable:
            bot.cmd(".warband hire " + affordable[0]["name"])
            time.sleep(1)
            bot.cmd(".warband call " + affordable[0]["name"])
            wait_state(bot, lambda s: num(s, "bots") == 1, timeout=25)
            time.sleep(11)
            if embark(bot, r, "11s2"):
                bot.cmd(".warband abandon")
                wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=20)
                heroes, raw = roster(bot)
                r.check("11s: a wounded hero who sits out a mission heals", not heroes[w]["wounded"], raw.get("list"))
        else:
            r.check("11s: (could afford a new recruit for the sit-out check)", False, str(recruits))

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
