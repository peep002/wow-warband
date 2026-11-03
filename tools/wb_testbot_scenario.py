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
Phase 6 adds (tests 1, 3b, 6, 11): starter gear; loot goes to the armory (trade goods become
materials, unusable items are salvaged); upgrades are suggested; equipping keeps random suffixes and
puts the old item back; equip all; selling and salvaging; heroes are equipped; missions pay gold and
renown; a fallen hero's bag gear goes to the armory.
Phase 7 adds (test 12): trait auras (Stalwart Shield, Glass Jaw) on and off; Greedy pockets a drop
and it comes back when they fall; Clumsy and Hothead pull another pack; a Coward runs; a Selfless
hero draws an ally's attackers; a Field Medic gets a downed ally up.
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
# Test items (world DB item_template): two rings (an empty slot: always an upgrade), cloth pants with
# a random suffix, a death-knight-only medallion (nobody on the roster can use it), linen cloth (a
# trade good), a grey wand (junk), and a cape anyone can wear.
RING_A, RING_B, PANTS_RANDOM, DK_ONLY, LINEN, GREY_WAND, CAPE, CAPE2 = 8350, 20906, 6267, 38588, 2589, 5560, 1355, 2284
STARTER_SLOTS = (4, 5, 6, 7, 8, 9, 15)   # chest, waist, legs, feet, wrists, hands, main hand
FROST_NOVA = 122                # a Mage spell trained at level 10
RES_CLASSES = (2, 5, 7, 11)     # paladin, priest, shaman, druid: they have resurrection spells
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


def armory(bot):
    """(items list of dicts, raw read-out)"""
    s = bot.probe("armory")
    items = []
    for part in s.get("list", "none").split(","):
        f = part.split(":")
        if len(f) == 7:
            items.append(dict(id=int(f[0]), entry=int(f[1]), quality=int(f[2]), count=int(f[3]), prop=int(f[4]),
                              suffix=int(f[5]), upgrade_for=[] if f[6] == "-" else f[6].split("+")))
    return items, s


def worn(bot, who, slot):
    return bot.probe("worn %s %d" % (who, slot))


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


def traits(bot, name):
    """dict(traits=[pos, pos2, neg], auras={key: bool}, used=set, hp, alive, raw)"""
    s = bot.probe("traits " + name)
    auras = dict(a.split(":") for a in s.get("auras", "").split(",") if ":" in a)
    return dict(traits=s.get("traits", "").split(","), auras={k: v == "1" for k, v in auras.items()},
                used=set(s.get("used", "none").split(",")) - {"none"}, hp=num(s, "hp"), alive=num(s, "alive") == 1,
                raw=str(s))


def set_traits(bot, name, pos="brave", pos2="-", neg="restless"):
    """Brave and Restless do nothing yet (stress is phase 8): a hero with them behaves plainly."""
    for slot, key in (("pos", pos), ("pos2", pos2), ("neg", neg)):
        bot.probe("trait %s %s %s" % (name, slot, key))


def in_combat(bot, name, timeout=20):
    """Wait until a monster has reached the hero and the fight is on."""
    end = time.time() + timeout
    while time.time() < end:
        if bot.probe("traits " + name).get("combat") == "1":
            return True
        time.sleep(1)
    return False


def end_fight(bot):
    """Kill whatever is fighting and wait until nobody is in combat (combat lasts ~5 s after)."""
    bot.probe("calm")
    time.sleep(2)
    bot.probe("calm")
    time.sleep(7)


def traits_test(bot, r):
    """Phase 7. Two heroes, A and B; each step gives them the traits it tests (rolled traits that
    would get in the way are swapped for ones that do nothing yet)."""
    time.sleep(11)
    heroes, raw = roster(bot)
    alive = [n for n, h in heroes.items() if h["status"] == "alive"]
    if len(alive) < 2:
        recruits, _ = tavern(bot)
        affordable = [x for x in recruits if x["cost"] <= num(state(bot), "gold")]
        if affordable:
            bot.cmd(".warband hire " + affordable[0]["name"])
            time.sleep(1)
            alive.append(affordable[0]["name"])
    r.check("12: two living heroes for the trait tests", len(alive) >= 2, raw.get("list"))
    if len(alive) < 2:
        return
    a, b = alive[0], alive[1]
    for n in (a, b):
        if not heroes.get(n, {}).get("party"):
            bot.cmd(".warband call " + n)
    wait_state(bot, lambda s: num(s, "bots") == 2, timeout=25)

    # Hidden auras: on with the trait, off without it.
    set_traits(bot, a, pos="stalwart", neg="glass_jaw")
    set_traits(bot, b)
    time.sleep(3)
    t = traits(bot, a)
    r.check("12: Stalwart Shield and Glass Jaw put their hidden auras on",
            t["auras"].get("stalwart") and t["auras"].get("glass_jaw"), t["raw"])
    set_traits(bot, a)
    time.sleep(3)
    t = traits(bot, a)
    r.check("12: the auras come off when the hero doesn't have the traits",
            not t["auras"].get("stalwart") and not t["auras"].get("glass_jaw"), t["raw"])

    # Greedy: a pocketed drop never reaches the armory (B pockets it; B falls at the end, below).
    set_traits(bot, b, neg="greedy")
    bot.probe("traitset greedy chance 1")
    before = sum(1 for it in armory(bot)[0] if it["entry"] == CAPE)
    since = bot.mark()
    bot.probe("lootsim %d %s" % (CAPE, a))
    r.check("12: a Greedy hero pockets a drop", bot.wait_chat(b + " pockets", 5, since) is not None)
    after = sum(1 for it in armory(bot)[0] if it["entry"] == CAPE)
    r.check("12: the pocketed drop isn't in the armory", after == before, f"{before} -> {after}")
    bot.probe("traitset greedy chance 0.1")
    set_traits(bot, b)

    if not embark(bot, r, "12"):
        return
    time.sleep(4)

    # Hothead first, while the entrance still has monsters in sight: right after a fight, charges
    # the next pack.
    set_traits(bot, a, neg="hothead")
    bot.probe("traitset hothead chance 1")
    bot.probe("traitset hothead range 250")
    bot.probe("aggro %s 200" % a)
    in_combat(bot, a)
    since = bot.mark()
    bot.probe("calm")
    time.sleep(2)
    bot.probe("calm")
    r.check("12: a Hothead charges the next pack after a fight",
            bot.wait_chat("charges the next pack", 20, since) is not None)
    bot.probe("traitset hothead chance 0.25")
    set_traits(bot, a)
    bot.probe("hp %s 100" % a)
    end_fight(bot)

    # Clumsy: a few seconds into a fight, another pack.
    set_traits(bot, a, neg="clumsy")
    bot.probe("traitset clumsy chance 1")
    bot.probe("traitset clumsy range 120")
    # Two tries: a pull needs a second pack in sight, and in the Deadmines' tunnels there isn't always one.
    ok = False
    for _ in range(2):
        since = bot.mark()
        bot.probe("aggro %s 150" % a)
        ok = bot.wait_chat("stumbles into another pack", 12, since) is not None
        if ok:
            break
        bot.probe("hp %s 100" % a)
        end_fight(bot)
    r.check("12: a Clumsy hero stumbles into another pack mid-fight", ok)
    bot.probe("traitset clumsy chance 0.2")
    set_traits(bot, a)
    bot.probe("hp %s 100" % a)
    end_fight(bot)

    # Coward: below 20% health in a fight, runs (once).
    set_traits(bot, a, neg="coward")
    since = bot.mark()
    bot.probe("aggro %s 200" % a)
    in_combat(bot, a)  # the monster may have a long walk
    bot.probe("hp %s 15" % a)
    ok = bot.wait_chat(a + " panics and runs", 5, since) is not None
    bot.probe("hp %s 100" % a)
    t = traits(bot, a)
    r.check("12: a Coward below 20% health panics and runs", ok, t["raw"])
    r.check("12: ...and it counts as used for this fight", "coward" in t["used"], t["raw"])
    set_traits(bot, a)
    end_fight(bot)

    # Selfless: an ally under 25% health; the enemies hitting them turn on the Selfless hero.
    set_traits(bot, a, pos="selfless")
    since = bot.mark()
    bot.probe("aggro %s 200" % b)
    in_combat(bot, b)
    time.sleep(1)
    bot.probe("hp %s 22" % b)
    ok = bot.wait_chat(a + " throws themself between " + b, 5, since) is not None
    bot.probe("hp %s 100" % b)
    r.check("12: a Selfless hero steps in for an ally under 25% health", ok)
    time.sleep(2)
    att = bot.probe("attackers " + a).get("attackers", "none")
    r.check("12: the enemies turn on the Selfless hero", (":" + a) in att, att)
    set_traits(bot, a)
    end_fight(bot)

    # Field Medic: someone down for 15 seconds is got back up, even with the normal rescue held.
    # The medic must be a class without a resurrection spell, or a bot priest (paladin, shaman,
    # druid) simply casts Resurrection first.
    heroes, _ = roster(bot)
    cls = {n: heroes.get(n, {}).get("cls", 0) for n in (a, b)}
    medic, patient = (b, a) if cls[a] in RES_CLASSES and cls[b] not in RES_CLASSES else (a, b)
    set_traits(bot, medic, pos="field_medic")
    since = bot.mark()
    bot.probe("down %s hold" % patient)
    ok = bot.wait_chat(medic + " gets " + patient + " back on their feet", 22, since) is not None
    r.check("12: a Field Medic gets a downed ally up after 15 seconds", ok, f"medic class {cls[medic]}")
    time.sleep(2)
    heroes, raw = roster(bot)
    r.check("12: ...and the saved ally is alive and wounded", heroes[patient]["alive"] and heroes[patient]["wounded"],
            raw.get("list"))
    set_traits(bot, medic)

    # B (who pocketed the cape) falls for good: the cape turns up. (Held, then bled out: B may or
    # may not be wounded by now.)
    since = bot.mark()
    bot.probe("down %s hold" % b)
    time.sleep(3)
    bot.probe("bleed " + b)
    ok = bot.wait_chat("pocketed item", 8, since) is not None
    back = sum(1 for it in armory(bot)[0] if it["entry"] == CAPE)
    r.check("12: what a Greedy hero pocketed comes back to the armory when they fall", ok and back == before + 1,
            f"{before} -> {back}")
    bot.cmd(".warband abandon")
    wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=20)


def stress(bot, name):
    """dict(stress, resolve, kind, hopeless, focused, alive)"""
    s = bot.probe("stress " + name)
    return dict(stress=num(s, "stress"), resolve=s.get("resolve", "?"), kind=s.get("kind", "?"),
                hopeless=num(s, "hopeless") == 1, focused=num(s, "focused") == 1, alive=num(s, "alive") == 1, raw=str(s))


def plain(bot, name, neg="hates_dark"):
    """Traits that do nothing yet (darkness is phase 10): no Brave or Restless in the numbers."""
    set_traits(bot, name, pos="night_owl", neg=neg)


def stress_test(bot, r):
    """Phase 8. P and Q go on a mission; R1 and R2 (Restless) sit it out in the barracks."""
    time.sleep(11)
    heroes, raw = roster(bot)
    alive = [n for n, h in heroes.items() if h["status"] == "alive"]
    recruits, _ = tavern(bot)
    for rec in sorted(recruits, key=lambda x: x["cost"]):
        if len(alive) >= 4 or rec["cost"] > num(state(bot), "gold"):
            break
        bot.cmd(".warband hire " + rec["name"])
        time.sleep(1)
        alive.append(rec["name"])
    heroes, raw = roster(bot)
    alive = [n for n, h in heroes.items() if h["status"] == "alive"]
    r.check("13: four living heroes for the stress tests", len(alive) >= 4, raw.get("list"))
    if len(alive) < 2:
        return
    p, q = alive[0], alive[1]
    benched = alive[2:4]
    for n in alive[:4]:
        plain(bot, n)
        bot.cmd(".warband treat " + n)
    for n in (p, q):
        if not heroes[n]["party"]:
            bot.cmd(".warband call " + n)
    for n in benched:
        if heroes[n]["party"]:
            bot.cmd(".warband send " + n)
    wait_state(bot, lambda s: num(s, "bots") == 2, timeout=25)

    # Relief at the tavern.
    bot.probe("stress %s 60" % p)
    gold = num(state(bot), "gold")
    level = roster(bot)[0][p]["level"]
    since = bot.mark()
    bot.cmd(".warband drink " + p)
    r.check("13: a drink at the tavern is confirmed", bot.wait_chat(p + " drinks at the tavern", 5, since) is not None)
    s = stress(bot, p)
    r.check("13: a drink takes 40 stress off", s["stress"] == 20, s["raw"])
    r.check("13: a drink costs 10 gold + 1 per level", num(state(bot), "gold") == gold - (10 + level),
            f"gold {gold} -> {state(bot).get('gold')}, level {level}")
    bot.probe("stress %s 0" % p)
    since = bot.mark()
    bot.cmd(".warband drink " + p)
    r.check("13: no drink for a hero without stress", bot.wait_chat("isn't stressed", 5, since) is not None)

    # Brave: 25% less.
    set_traits(bot, p, pos="brave", neg="hates_dark")
    bot.probe("stress %s +8" % p)
    r.check("13: a Brave hero gains 25% less stress (8 -> 6)", stress(bot, p)["stress"] == 6, stress(bot, p)["raw"])
    plain(bot, p)

    # The resolve check at 100: an affliction; relief below 50 cures it.
    bot.probe("stressset virtue_chance 0")
    bot.probe("stress %s 95" % p)
    since = bot.mark()
    bot.probe("stress %s +10" % p)
    s = stress(bot, p)
    r.check("13: at 100 stress the resolve is tested", bot.wait_chat(p + "'s resolve is tested", 5, since) is not None)
    r.check("13: ...usually an affliction", s["kind"] == "affliction", s["raw"])
    since = bot.mark()
    bot.probe("stress %s -60" % p)
    s = stress(bot, p)
    r.check("13: relief below 50 cures the affliction", s["resolve"] == "none"
            and bot.wait_chat("is no longer", 5, since) is not None, s["raw"])
    bot.probe("resolve %s hopeless" % p)
    time.sleep(3)
    r.check("13: Hopeless puts its hidden aura on (-15% damage)", stress(bot, p)["hopeless"], stress(bot, p)["raw"])
    bot.probe("resolve %s -" % p)

    # ...or a virtue, which drops stress to 50.
    bot.probe("stressset virtue_chance 1")
    bot.probe("stress %s 95" % p)
    bot.probe("stress %s +10" % p)
    s = stress(bot, p)
    r.check("13: a virtue drops stress to 50", s["kind"] == "virtue" and s["stress"] == 50, s["raw"])
    bot.probe("resolve %s focused" % p)
    time.sleep(3)
    r.check("13: Focused puts its hidden aura on (+10% crit)", stress(bot, p)["focused"], stress(bot, p)["raw"])
    bot.probe("resolve %s -" % p)
    bot.probe("stressset virtue_chance 0.25")

    # On a mission.
    for n in (p, q):
        bot.probe("stress %s 0" % n)
    for n in benched:
        bot.probe("stress %s 30" % n)
    if len(benched) == 2:
        plain(bot, benched[1], neg="restless")
    if not embark(bot, r, "13"):
        return
    time.sleep(4)
    bot.probe("clear")
    time.sleep(2)
    bot.probe("heavyhit " + p)
    r.check("13: a heavy hit adds 2 stress", stress(bot, p)["stress"] == 2, stress(bot, p)["raw"])
    bot.probe("heavyhit " + p)
    r.check("13: ...but not twice within 3 seconds", stress(bot, p)["stress"] == 2, stress(bot, p)["raw"])

    bot.probe("down " + q)
    time.sleep(2)
    r.check("13: an ally going down adds 8 stress", stress(bot, p)["stress"] == 10, stress(bot, p)["raw"])
    time.sleep(6)  # the fight-is-over rescue

    bot.probe("stress %s 199" % p)
    since = bot.mark()
    bot.probe("stress %s +5" % p)
    r.check("13: at 200 stress a heart attack sends them to death's door",
            bot.wait_chat(p + "'s heart gives out", 5, since) is not None and bot.wait_chat(p + " is down", 4, since) is not None)
    r.check("13: ...and stress drops to 150", stress(bot, p)["stress"] == 150, stress(bot, p)["raw"])
    time.sleep(7)
    heroes, raw = roster(bot)
    r.check("13: ...saved by the fight ending, wounded", heroes[p]["alive"] and heroes[p]["wounded"], raw.get("list"))

    # Stalwart (virtue): going down while wounded doesn't kill them.
    bot.probe("resolve %s stalwart" % p)
    since = bot.mark()
    bot.probe("down " + p)
    time.sleep(3)
    fell = bot.wait_chat(p + " has fallen", 1, since) is not None
    r.check("13: a Stalwart hero who goes down while wounded doesn't die for good", not fell
            and roster(bot)[0][p]["status"] == "alive")
    time.sleep(6)
    q_before = stress(bot, q)["stress"]
    since = bot.mark()
    bot.cmd(".warband abandon")
    wait_state(bot, lambda s: at_home(s) and s.get("mission") == "none", timeout=20)
    time.sleep(1)
    s = stress(bot, p)
    r.check("13: a virtue ends with the mission", s["resolve"] == "none" and bot.wait_chat("is no longer Stalwart", 3, since)
            is not None, s["raw"])
    r.check("13: an abandoned Short mission adds 4 + 10 stress", stress(bot, q)["stress"] == q_before + 14,
            f"{q_before} -> {stress(bot, q)['raw']}")
    if benched:
        r.check("13: sitting a mission out in the barracks takes 10 off", stress(bot, benched[0])["stress"] == 20,
                stress(bot, benched[0])["raw"])
    if len(benched) == 2:
        r.check("13: ...but a Restless hero gains 8 instead", stress(bot, benched[1])["stress"] == 38,
                stress(bot, benched[1])["raw"])
    for n in alive[:4]:
        bot.probe("stress %s 0" % n)


# The plan -------------------------------------------------------------------------------------

def main(bot, r, only=None):
    restart = "restart" in sys.argv
    bot.connect()
    old = [c for c in bot.characters() if c["name"].startswith("Wb")]
    if old:  # run the newest scripts before the new commander is created (starter gear etc.)
        bot.enter_world(old[0])
        bot.cmd(".reload ale", r"[Rr]eload", 10)
        time.sleep(2)
        bot.logout()
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
    on = [slot for slot in STARTER_SLOTS if num(worn(bot, "me", slot), "worn") > 0]
    r.check("1: a new commander gets starter gear (6 armour pieces and a weapon)", len(on) >= 6, f"slots worn: {on}")
    b = bot.probe("board")
    offers = [k for k in b.get("board", "").split(",") if k]
    ready = {"ragefire_short", "ragefire_medium", "ragefire_long", "deadmines_short", "wailing_short"}  # min level <= 11
    r.check("1: the board offers 3 Act I contracts a level-10 commander is (nearly) ready for",
            len(offers) == 3 and set(offers) <= ready, b.get("board"))
    r.check("1: the 3 contracts are different dungeons or lengths",
            len({o.split("_")[0] for o in offers}) >= 2 and len({o.split("_")[1] for o in offers}) >= 2, b.get("board"))
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

    # 3b. Armory -------------------------------------------------------------------------------------
    print("Test 3b: armory")
    me = state(bot)
    commander_name = None
    _, a0 = armory(bot)
    mats0, gold0 = num(a0, "materials"), num(a0, "gold")
    l = bot.probe("lootsim %d" % LINEN)
    _, a1 = armory(bot)
    r.check("3b: a looted trade good becomes materials", num(a1, "materials") == mats0 + 1 and num(l, "inbags") == 0,
            f"materials {mats0} -> {a1.get('materials')}, in bags {l.get('inbags')}")
    l = bot.probe("lootsim %d" % DK_ONLY)
    items, a2 = armory(bot)
    r.check("3b: an item nobody on the roster can use is salvaged", num(a2, "materials") > num(a1, "materials")
            and num(a2, "items") == 0 and num(l, "inbags") == 0, str(a2))
    for entry in (RING_A, PANTS_RANDOM, GREY_WAND):
        l = bot.probe("lootsim %d" % entry)
    items, raw = armory(bot)
    by_entry = {it["entry"]: it for it in items}
    r.check("3b: looted gear goes to the armory, out of the bags", set(by_entry) >= {RING_A, PANTS_RANDOM, GREY_WAND}
            and num(l, "inbags") == 0, raw.get("list"))
    pants = by_entry.get(PANTS_RANDOM)
    r.check("3b: the armory keeps an item's random suffix", pants is not None and (pants["prop"] > 0 or pants["suffix"] > 0),
            str(pants))
    ring = by_entry.get(RING_A)
    r.check("3b: an item for an empty slot is suggested as an upgrade", ring is not None and len(ring["upgrade_for"]) >= 1,
            str(ring))
    if pants:
        bot.cmd(".warband equip %d me" % pants["id"])
        time.sleep(1)
        w = worn(bot, "me", 6)
        r.check("3b: equipping puts the item on, with the same suffix", num(w, "worn") == PANTS_RANDOM
                and num(w, "prop") == pants["prop"] and num(w, "suffix") == pants["suffix"], str(w))
        items, raw = armory(bot)
        r.check("3b: what was worn goes back to the armory", any(it["entry"] not in (RING_A, GREY_WAND) for it in items),
                raw.get("list"))
    bot.probe("lootsim %d" % RING_B)
    since = bot.mark()
    bot.cmd(".warband equipall")
    r.check("3b: equip all upgrades", bot.wait_chat(r"upgrades? equipped", 5, since) is not None)
    r.check("3b: the rings are worn", num(worn(bot, "me", 10), "worn") in (RING_A, RING_B)
            or num(worn(bot, names[0], 10), "worn") in (RING_A, RING_B), "")
    gold1 = num(armory(bot)[1], "gold")
    bot.cmd(".warband selljunk")
    time.sleep(1)
    items, raw = armory(bot)
    r.check("3b: selling junk gives gold", num(raw, "gold") > gold1 and all(it["quality"] > 0 for it in items),
            f"gold {gold1} -> {raw.get('gold')}")
    if items:
        m1 = num(raw, "materials")
        bot.cmd(".warband salvage %d" % items[0]["id"])
        time.sleep(1)
        r.check("3b: salvaging gives materials", num(armory(bot)[1], "materials") > m1)
    bot.probe("lootsim %d" % CAPE)
    cape = next((it for it in armory(bot)[0] if it["entry"] == CAPE), None)
    if cape:
        bot.cmd(".warband equip %d %s" % (cape["id"], names[0]))
        time.sleep(1)
        r.check("3b: a hero in the party can be equipped", num(worn(bot, names[0], 14), "worn") == CAPE,
                str(worn(bot, names[0], 14)))

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
        log = " ".join(bot.probe("log mission_done").values())  # one event: stress lines fill the log now
        r.check("6: mission completion is logged", "mission_done" in log, log)
        heroes, raw = roster(bot)
        r.check("6: the hero on the mission counts it", heroes[names[0]]["missions"] == 1
                and heroes[names[2]]["missions"] == 0, raw.get("list"))
        s = state(bot)
        r.check("6: the commander gains about 1.5 levels (level 11)", num(s, "level") == 11, f"level={s.get('level')}")
        log = " ".join(bot.probe("log reward").values())
        r.check("6: a completed Short mission pays 60 gold and 4 renown", "reward:done_gold=60_renown=4" in log, log)
        # A hero who was down when the boss died is carried home and paid a few seconds later.
        end = time.time() + 12
        while roster(bot)[0][names[0]]["level"] < 11 and time.time() < end:
            time.sleep(2)
        h0 = roster(bot)[0][names[0]]
        r.check("6: the hero who went gains about 1.5 levels (level 11)", h0["level"] == 11,
                f"level={h0['level']} alive={h0['alive']}")
        r.check("6: the hero spent the new talent points", h0["talents"] == 0, f"unspent={h0['talents']}")
        r.check("6: a hero who stayed home gains nothing (bench XP comes later)", heroes[names[2]]["level"] == 10)
        b = bot.probe("board")
        r.check("6: the main mission counts towards the gate", num(b, "progress") == 1, str(b))
        r.check("6: the board deals new contracts after a mission", "board_dealt" in " ".join(bot.probe("log board_dealt").values()))
        recruits, raw = tavern(bot)
        r.check("6: a new batch of 4 recruits arrives", len(recruits) == 4, raw.get("list"))
        free = [x for x in recruits if x["cost"] == 0 and not x["founding"]]
        paid = [x for x in recruits if x["cost"] > 0]
        r.check("6: the batch has 2 free recruits and 2 paid veterans", len(free) == 2 and len(paid) == 2, raw.get("list"))
        avg = 11  # the hero who went is 11, the other three 10: average 10 (rounded down) -> veterans 10, free 10 (minimum)
        r.check("6: veterans come at the roster's level, free recruits a few below (never under 10)",
                all(x["level"] >= 10 for x in recruits), raw.get("list"))
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
        log = " ".join(bot.probe("log mission_abandoned").values())
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
        log = " ".join(bot.probe("log act_gate_beaten").values())
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

        bot.probe("giveitem %s %d" % (a, CAPE2))
        before = sum(1 for it in armory(bot)[0] if it["entry"] == CAPE2)
        since = bot.mark()
        bot.probe("down " + a)
        r.check("11: downed again while wounded = dies for good", bot.wait_chat(a + " has fallen", 6, since) is not None)
        after = sum(1 for it in armory(bot)[0] if it["entry"] == CAPE2)
        r.check("11: a fallen hero's bag gear goes to the armory", after == before + 1, f"{before} -> {after}")
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
        log = " ".join(bot.probe("log hero_died").values())
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

    # 12. Traits -------------------------------------------------------------------------------
    print("Test 12: traits")
    traits_test(bot, r)

    # 13. Stress ---------------------------------------------------------------------------------
    print("Test 13: stress")
    stress_test(bot, r)

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
            # Every hero in the party (one or more) is back, in the dungeon.
            back = lambda s: num(s, "bots") >= 1 and set(s.get("botmaps", "").split(",")) == {str(DEADMINES)}
            s = wait_state(bot2, back, timeout=30)
            r.check("8: after a restart the party heroes come back and join you", back(s),
                    f"bots={s.get('bots')} botmaps={s.get('botmaps')}")
            kill_boss(bot2)
            wait_state(bot2, lambda s: at_home(s) and s.get("mission") == "none", timeout=30)
            bot = bot2

    passed = sum(1 for _, ok, _ in r.rows if ok)
    print(f"\n{passed}/{len(r.rows)} checks passed.")
    for name, ok, detail in r.rows:
        if not ok:
            print(f"  FAILED: {name}  {detail}")
