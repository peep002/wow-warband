"""Headless test bot for the Warband server (127.0.0.1 only).
Copied from WoW-Roguelike/tools/rl_testbot.py on 2026-11-01 and pointed at Warband's own
databases and accounts. Only one server runs at a time, so it always talks to Warband.

It logs in like a game client, but has no graphics: it types chat commands, reads the
replies, raid warnings and NPC-dialogue menus, and clicks menu options. Together with
the read-outs in lua_scripts/warband/dev/wb_dev_probe.lua it checks Warband
while nobody is at the gaming PC.
It can't see the screen, move, or aim spells, so visuals and pathing still need a human.

Usage (from the project folder):
    python tools/wb_testbot.py make-account   # once: throwaway GM test accounts (WBTESTBOT...)
    python tools/wb_testbot.py run            # play the scenario in wb_testbot_scenario.py
    python tools/wb_testbot.py run restart    # also restart the worldserver mid-mission
    python tools/wb_testbot.py shutdown       # stop the worldserver cleanly (".server shutdown 1"),
                                              # e.g. when it runs outside a Terminal tab

The test accounts' names and generated passwords are kept in tools/wb_testbot.local.json,
which git ignores. It only ever talks to this PC's own server.
"""
import hashlib
import hmac
import json
import os
import random
import re
import secrets
import socket
import string
import struct
import subprocess
import sys
import threading
import time
import zlib

HOST, AUTH_PORT, BUILD = "127.0.0.1", 3724, 12340
N = int("894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7", 16)
G = 7
HERE = os.path.dirname(os.path.abspath(__file__))
CRED_FILE = os.path.join(HERE, "wb_testbot.local.json")
MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
ACCOUNT = "WBTESTBOT"
ACCOUNT2 = "WBTESTBOT2"  # a second bot, for co-op tests (two players in one run)
# Every bot account. A full run plays several tests at once, one account per lane
# (wb_testbot_scenario.LANES). Slot n's login is "account<n>" in CRED_FILE ("account" for 1).
ACCOUNTS = [ACCOUNT, ACCOUNT2, "WBTESTBOT3", "WBTESTBOT4"]
BOT_IDS = "(SELECT id FROM warband_auth.account WHERE username IN ({}))"


def cred_key(slot):
    return "" if slot == 1 else str(slot)


def bot_ids(names=None):
    return BOT_IDS.format(", ".join(f"'{n}'" for n in (names or ACCOUNTS)))

# Opcodes (AzerothCore src/server/game/Server/Protocol/Opcodes.h)
CMSG_CHAR_CREATE, CMSG_CHAR_ENUM, SMSG_CHAR_CREATE, SMSG_CHAR_ENUM = 0x036, 0x037, 0x03A, 0x03B
CMSG_CHAR_DELETE, SMSG_CHAR_DELETE = 0x038, 0x03C
CHAR_DELETE_SUCCESS = 0x47
CMSG_PLAYER_LOGIN, SMSG_NEW_WORLD = 0x03D, 0x03E
SMSG_ACTION_BUTTONS = 0x129
CMSG_LOGOUT_REQUEST, SMSG_LOGOUT_COMPLETE = 0x04B, 0x04D
CMSG_MESSAGECHAT, SMSG_MESSAGECHAT, SMSG_GM_MESSAGECHAT = 0x095, 0x096, 0x3B3
MSG_MOVE_TELEPORT_ACK, MSG_MOVE_WORLDPORT_ACK = 0x0C7, 0x0DC
CMSG_SET_SELECTION = 0x13D
CMSG_GAMEOBJ_USE = 0x0B1
CMSG_GROUP_INVITE, CMSG_GROUP_ACCEPT = 0x06E, 0x072
CMSG_GOSSIP_HELLO, CMSG_GOSSIP_SELECT_OPTION, SMSG_GOSSIP_MESSAGE, SMSG_GOSSIP_COMPLETE = 0x17B, 0x17C, 0x17D, 0x17E
SMSG_NOTIFICATION, CMSG_PING = 0x1CB, 0x1DC
SMSG_AUTH_CHALLENGE, CMSG_AUTH_SESSION, SMSG_AUTH_RESPONSE = 0x1EC, 0x1ED, 0x1EE
SMSG_LOGIN_VERIFY_WORLD = 0x236
SMSG_TIME_SYNC_REQ, CMSG_TIME_SYNC_RESP = 0x390, 0x391

CHAT_SYSTEM, CHAT_SAY, CHAT_RAID_WARNING = 0x00, 0x01, 0x28
LANG_COMMON = 7
RACE_HUMAN, RACE_NIGHT_ELF, RACE_DRAENEI = 1, 4, 11
CLASS_WARRIOR, CLASS_PALADIN, CLASS_PRIEST, CLASS_SHAMAN, CLASS_MAGE, CLASS_WARLOCK, CLASS_DRUID = 1, 2, 5, 7, 8, 9, 11


def sha1(*parts):
    h = hashlib.sha1()
    for p in parts:
        h.update(p)
    return h.digest()


def le(b):
    return int.from_bytes(b, "little")


def tole(n, size=32):
    return n.to_bytes(size, "little")


def cstr(data, pos):
    end = data.index(b"\0", pos)
    return data[pos:end].decode("utf-8", "replace"), end + 1


class RC4:
    def __init__(self, key):
        s = list(range(256))
        j = 0
        for i in range(256):
            j = (j + s[i] + key[i % len(key)]) & 0xFF
            s[i], s[j] = s[j], s[i]
        self.s, self.i, self.j = s, 0, 0
        self.crypt(bytes(1024))  # WoW uses RC4-drop1024

    def crypt(self, data):
        s, i, j, out = self.s, self.i, self.j, bytearray(len(data))
        for n, b in enumerate(data):
            i = (i + 1) & 0xFF
            j = (j + s[i]) & 0xFF
            s[i], s[j] = s[j], s[i]
            out[n] = b ^ s[(s[i] + s[j]) & 0xFF]
        self.i, self.j = i, j
        return bytes(out)


# Account ----------------------------------------------------------------------------

def mysql(sql):
    out = subprocess.run([MYSQL, "-u", "acore", "-pacore", "-N", "-e", sql],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit("mysql failed: " + out.stderr.strip())
    return out.stdout.strip()


def make_account():
    """Make whichever of the bot accounts doesn't exist yet."""
    cred = json.load(open(CRED_FILE)) if os.path.exists(CRED_FILE) else {}
    for slot, name in enumerate(ACCOUNTS, 1):
        key = cred_key(slot)
        if cred.get("account" + key):
            print(f"Test account {name} already made.")
            continue
        if mysql(f"SELECT COUNT(*) FROM warband_auth.account WHERE username='{name}'") != "0":
            raise SystemExit(f"Account {name} exists but its login isn't in {CRED_FILE}; remove it by hand first.")
        password = secrets.token_hex(8).upper()  # the server stores names and passwords upper-case
        salt = secrets.token_bytes(32)
        x = le(sha1(salt, sha1(f"{name}:{password}".encode())))
        verifier = tole(pow(G, x, N))
        mysql(f"INSERT INTO warband_auth.account (username, salt, verifier, email, reg_mail, expansion) "
              f"VALUES ('{name}', 0x{salt.hex()}, 0x{verifier.hex()}, '', '', 2); "
              f"INSERT INTO warband_auth.account_access (id, gmlevel, RealmID, comment) "
              f"SELECT id, 3, -1, 'wb_testbot' FROM warband_auth.account WHERE username='{name}';")
        cred["account" + key], cred["password" + key] = name, password
        with open(CRED_FILE, "w") as f:
            json.dump(cred, f)
        print(f"Made GM test account {name}; login saved in {CRED_FILE}.")


# Auth server (SRP6) ----------------------------------------------------------------------

def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("connection closed")
        buf += chunk
    return buf


def interleave(S):
    """Session key from S, the way the server does it (SRP6::SHA1Interleave)."""
    p = 0
    while p < len(S) and S[p] == 0:
        p += 1
    if p & 1:
        p += 1
    p //= 2
    h0 = sha1(S[0::2][p:])
    h1 = sha1(S[1::2][p:])
    return bytes(b for pair in zip(h0, h1) for b in pair)


def auth_login(user, password):
    U, P = user.upper().encode(), password.upper().encode()
    sock = socket.create_connection((HOST, AUTH_PORT), timeout=10)
    body = (b"WoW\0" + bytes([3, 3, 5]) + struct.pack("<H", BUILD) + b"68x\0" + b"niW\0" + b"SUne"
            + struct.pack("<I", 0) + bytes([127, 0, 0, 1]) + bytes([len(U)]) + U)
    sock.sendall(struct.pack("<BBH", 0, 3, len(body)) + body)
    head = recv_exact(sock, 3)
    if head[2] != 0:
        raise SystemExit(f"auth challenge refused (error {head[2]})")
    B = recv_exact(sock, 32)
    recv_exact(sock, recv_exact(sock, 1)[0])  # g
    recv_exact(sock, recv_exact(sock, 1)[0])  # N
    salt = recv_exact(sock, 32)
    recv_exact(sock, 16)
    if recv_exact(sock, 1)[0] != 0:
        raise SystemExit("account needs an authenticator token; not supported")

    a = le(secrets.token_bytes(32))
    A = tole(pow(G, a, N))
    u = le(sha1(A, B))
    x = le(sha1(salt, sha1(U + b":" + P)))
    S = pow((le(B) - 3 * pow(G, x, N)) % N, a + u * x, N)
    K = interleave(tole(S))
    ng = bytes(p ^ q for p, q in zip(sha1(tole(N)), sha1(bytes([G]))))
    M1 = sha1(ng, sha1(U), salt, A, B, K)
    sock.sendall(bytes([1]) + A + M1 + bytes(20) + bytes([0, 0]))
    proof = recv_exact(sock, 2)
    if proof[1] != 0:
        raise SystemExit(f"login refused (error {proof[1]})")
    recv_exact(sock, 20 + 4 + 4 + 2)

    sock.sendall(struct.pack("<BI", 0x10, 0))
    _, size = struct.unpack("<BH", recv_exact(sock, 3))
    data = recv_exact(sock, size)
    pos = 6  # u32 unused, u16 count
    pos += 3
    _, pos = cstr(data, pos)
    address, pos = cstr(data, pos)
    pos += 4 + 1 + 1
    realm_id = data[pos]
    sock.close()
    host, port = address.split(":")
    return K, host, int(port), realm_id


# World server -------------------------------------------------------------------------

class Bot:
    def __init__(self, verbose=True, second=False, slot=None):
        cred = json.load(open(CRED_FILE))
        self.slot = slot or (2 if second else 1)
        self.owner = threading.get_ident()  # the thread (lane) this bot belongs to
        key = cred_key(self.slot)
        if "account" + key not in cred:
            raise SystemExit(f"Bot account {self.slot} is missing: run  python tools/wb_testbot.py make-account")
        self.account, self.password = cred["account" + key], cred["password" + key]
        self.verbose = verbose
        self.chat = []            # (time, kind, text)
        self.gossip = None        # last menu: dict(guid, menu, options=[(index, text, box)])
        self.events = {}          # opcode -> list of payloads
        self.cond = threading.Condition()
        self.player_guid = 0
        self.map = None
        self.closed = False

    # -- connection
    def connect(self):
        K, host, port, realm = auth_login(self.account, self.password)
        self.sock = socket.create_connection((host, port), timeout=None)
        size, op = struct.unpack(">H", recv_exact(self.sock, 2))[0], struct.unpack("<H", recv_exact(self.sock, 2))[0]
        body = recv_exact(self.sock, size - 2)
        assert op == SMSG_AUTH_CHALLENGE, hex(op)
        server_seed = body[4:8]
        client_seed = secrets.token_bytes(4)
        U = self.account.upper().encode()
        digest = sha1(U, bytes(4), client_seed, server_seed, K)
        addons = zlib.compress(struct.pack("<II", 0, 0))
        payload = (struct.pack("<II", BUILD, 0) + U + b"\0" + struct.pack("<I", 0) + client_seed
                   + struct.pack("<III", 0, 0, realm) + struct.pack("<Q", 0) + digest
                   + struct.pack("<I", 8) + addons)
        self.sock.sendall(struct.pack(">H", len(payload) + 4) + struct.pack("<I", CMSG_AUTH_SESSION) + payload)
        self.enc = RC4(hmac.new(bytes.fromhex("C2B3723CC6AED9B5343C53EE2F4367CE"), K, hashlib.sha1).digest())
        self.dec = RC4(hmac.new(bytes.fromhex("CC98AE04E897EACA12DDC09342915357"), K, hashlib.sha1).digest())
        self.send_lock = threading.Lock()
        threading.Thread(target=self._reader, daemon=True).start()
        threading.Thread(target=self._pinger, daemon=True).start()
        code = self.wait_event(SMSG_AUTH_RESPONSE)[0]
        if code != 0x0C:
            raise SystemExit(f"world login refused (code {code:#x})")

    def send(self, op, payload=b""):
        header = self.enc.crypt(struct.pack(">H", len(payload) + 4) + struct.pack("<I", op))
        with self.send_lock:
            self.sock.sendall(header + payload)

    def _reader(self):
        try:
            while True:
                first = self.dec.crypt(recv_exact(self.sock, 1))
                if first[0] & 0x80:
                    rest = self.dec.crypt(recv_exact(self.sock, 4))
                    size = ((first[0] & 0x7F) << 16) | (rest[0] << 8) | rest[1]
                    op = struct.unpack("<H", rest[2:4])[0]
                else:
                    rest = self.dec.crypt(recv_exact(self.sock, 3))
                    size = (first[0] << 8) | rest[0]
                    op = struct.unpack("<H", rest[1:3])[0]
                data = recv_exact(self.sock, size - 2)
                try:
                    self._handle(op, data)
                except (struct.error, IndexError, ValueError) as e:  # a layout we don't know: skip it
                    if self.verbose:
                        print(f"      (skipped packet {op:#x}: {e})")
        except (ConnectionError, OSError) as e:
            with self.cond:
                self.closed = True
                self.chat.append((time.time(), "DISCONNECT", str(e)))
                self.cond.notify_all()

    def _pinger(self):
        seq = 0
        while not self.closed:
            time.sleep(20)
            seq += 1
            try:
                self.send(CMSG_PING, struct.pack("<II", seq, 10))
            except OSError:
                return

    def _log(self, kind, text):
        with self.cond:
            self.chat.append((time.time(), kind, text))
            self.cond.notify_all()
        if self.verbose:  # runs on the reader thread: write to the lane that made this bot
            out = sys.stdout
            line = f"      <{kind}> {text}" + chr(10)
            if isinstance(out, LaneOutput):
                out.write_for(self.owner, line)
            else:
                out.write(line)

    def _handle(self, op, data):
        if op in (SMSG_MESSAGECHAT, SMSG_GM_MESSAGECHAT):
            kind = data[0]
            pos = 1 + 4 + 8 + 4
            if op == SMSG_GM_MESSAGECHAT:
                n = struct.unpack_from("<I", data, pos)[0]
                pos += 4 + n
            pos += 8
            n = struct.unpack_from("<I", data, pos)[0]
            text = data[pos + 4:pos + 4 + n - 1].decode("utf-8", "replace")
            text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", text)
            name = {CHAT_SYSTEM: "SYS", CHAT_RAID_WARNING: "RAID"}.get(kind, f"chat{kind:#x}")
            self._log(name, text)
        elif op == SMSG_NOTIFICATION:
            self._log("NOTIFY", cstr(data, 0)[0])
        elif op == SMSG_GOSSIP_MESSAGE:
            guid, menu, _, count = struct.unpack_from("<QIII", data, 0)
            pos, options = 20, []
            for _ in range(count):
                index, _, coded, _ = struct.unpack_from("<IBBI", data, pos)
                pos += 10
                text, pos = cstr(data, pos)
                box, pos = cstr(data, pos)
                options.append((index, text, box))
            with self.cond:
                self.gossip = {"guid": guid, "menu": menu, "options": options, "at": time.time()}
                self.cond.notify_all()
            if self.verbose:
                print("      <MENU> " + " | ".join(t for _, t, _ in options))
        elif op == SMSG_GOSSIP_COMPLETE:
            with self.cond:
                self.gossip = None
        elif op == SMSG_TIME_SYNC_REQ:
            self.send(CMSG_TIME_SYNC_RESP, data[:4] + struct.pack("<I", int(time.time() * 1000) & 0xFFFFFFFF))
        elif op == SMSG_NEW_WORLD:
            self.map = struct.unpack_from("<I", data, 0)[0]
            self.send(MSG_MOVE_WORLDPORT_ACK)
        elif op == MSG_MOVE_TELEPORT_ACK:
            mask, pos = data[0], 1
            pg = data[:1]
            for bit in range(8):
                if mask & (1 << bit):
                    pg += data[pos:pos + 1]
                    pos += 1
            counter = data[pos:pos + 4]
            self.send(MSG_MOVE_TELEPORT_ACK, pg + counter + struct.pack("<I", int(time.time() * 1000) & 0xFFFFFFFF))
        else:
            with self.cond:
                self.events.setdefault(op, []).append(data)
                self.cond.notify_all()

    # -- waiting
    def wait_event(self, op, timeout=15):
        end = time.time() + timeout
        with self.cond:
            while not self.events.get(op):
                left = end - time.time()
                if left <= 0 or self.closed:
                    raise TimeoutError(f"no packet {op:#x}")
                self.cond.wait(left)
            return self.events[op].pop(0)

    def action_bar(self):
        """The spell on each action button (index 0-143) from the last button list the
        server sent, or None if none came."""
        with self.cond:
            sent = self.events.get(SMSG_ACTION_BUTTONS)
            data = sent[-1] if sent else None
        if not data:
            return None
        return [v & 0xFFFFFF for v in struct.unpack_from("<144I", data, 1)]

    def mark(self):
        with self.cond:
            return len(self.chat)

    def wait_chat(self, pattern, timeout=10, since=None):
        """First chat line (from index 'since') matching pattern, or None."""
        rx = re.compile(pattern)
        end = time.time() + timeout
        i = 0 if since is None else since
        with self.cond:
            while True:
                while i < len(self.chat):
                    m = rx.search(self.chat[i][2])
                    i += 1
                    if m:
                        return m
                left = end - time.time()
                if left <= 0 or self.closed:
                    return None
                self.cond.wait(left)

    def wait_menu(self, after, timeout=8):
        end = time.time() + timeout
        with self.cond:
            while not (self.gossip and self.gossip["at"] >= after):
                left = end - time.time()
                if left <= 0:
                    return None
                self.cond.wait(left)
            return self.gossip

    # -- actions
    def say(self, text):
        self.send(CMSG_MESSAGECHAT, struct.pack("<II", CHAT_SAY, LANG_COMMON) + text.encode() + b"\0")

    def cmd(self, text, pattern=None, timeout=8):
        since = self.mark()
        self.say(text)
        return self.wait_chat(pattern, timeout, since) if pattern else None

    def probe(self, what, timeout=6):
        """Run a .wbdev probe and return its key=value pairs (all lines it printed)."""
        since = self.mark()
        self.say(".wbdev " + what)
        self.wait_chat(r"^\[probe\]", timeout, since)
        time.sleep(0.4)
        out = {}
        with self.cond:
            lines = [t for _, _, t in self.chat[since:] if t.startswith("[probe]")]
        for line in lines:
            for key, val in re.findall(r"(\w+)=(.*?)(?= \w+=|$)", line[8:]):
                out[key] = val
        return out

    def open_menu(self, text_cmd=None, npc_guid=None):
        start = time.time()
        if text_cmd:
            self.say(text_cmd)
        else:
            self.send(CMSG_GOSSIP_HELLO, struct.pack("<Q", npc_guid))
        return self.wait_menu(start)

    def use_object(self, guid):
        """Click a game object (e.g. a chest); returns the menu it opens, if any."""
        start = time.time()
        self.send(CMSG_GAMEOBJ_USE, struct.pack("<Q", guid))
        return self.wait_menu(start)

    def pick(self, menu, pattern, code=None):
        """Click the first option matching pattern; code = the text typed into its popup box."""
        for index, text, _ in menu["options"]:
            if re.search(pattern, text):
                data = struct.pack("<QII", menu["guid"], menu["menu"], index)
                if code is not None:
                    data += code.encode() + b"\0"
                self.send(CMSG_GOSSIP_SELECT_OPTION, data)
                return text
        return None

    def invite(self, name):
        self.send(CMSG_GROUP_INVITE, name.encode() + b"\0" + struct.pack("<I", 0))

    def accept_invite(self):
        self.send(CMSG_GROUP_ACCEPT, struct.pack("<I", 0))

    def target(self, guid):
        self.send(CMSG_SET_SELECTION, struct.pack("<Q", guid))

    # -- characters
    def characters(self):
        self.send(CMSG_CHAR_ENUM)
        data = self.wait_event(SMSG_CHAR_ENUM)
        chars, pos = [], 1
        for _ in range(data[0]):
            guid = struct.unpack_from("<Q", data, pos)[0]
            name, pos = cstr(data, pos + 8)
            race, cls = data[pos], data[pos + 1]
            level = data[pos + 8]
            pos += 9 + 4 + 4 + 12 + 4 + 4 + 4 + 1 + 12 + 23 * 9
            chars.append({"guid": guid, "name": name, "race": race, "class": cls, "level": level})
        return chars

    def delete_old_characters(self):
        """Delete this account's old bot characters (names starting "Wb"), so it never hits
        the 10-characters-per-realm limit. Only ever runs on the bot's own account."""
        assert self.account.upper() in ACCOUNTS, "only the test-bot accounts"
        gone = 0
        for c in self.characters():
            if c["name"].startswith("Wb"):
                self.send(CMSG_CHAR_DELETE, struct.pack("<Q", c["guid"]))
                try:
                    if self.wait_event(SMSG_CHAR_DELETE, 8)[0] == CHAR_DELETE_SUCCESS:
                        gone += 1
                except TimeoutError:  # still in the world (an earlier run didn't log out)
                    print(f"  (couldn't delete {c['name']} yet: still logged in)")
        return gone

    def create_character(self, cls, prefix, race=RACE_HUMAN):
        for _ in range(5):  # a random name can break a naming rule (e.g. "aaa"): try another
            name = prefix + "".join(random.choice(string.ascii_lowercase) for _ in range(5))
            self.send(CMSG_CHAR_CREATE, name.encode() + b"\0" + bytes([race, cls, 0, 0, 0, 0, 0, 0, 0]))
            code = self.wait_event(SMSG_CHAR_CREATE)[0]
            if code == 0x2F:
                return next(c for c in self.characters() if c["name"] == name)
            if code < 0x50:  # not a name problem (e.g. 0x35: this account has 10 characters)
                break
        raise RuntimeError(f"character create failed (code {code:#x})")

    def enter_world(self, char):
        self.player_guid = char["guid"]
        self.send(CMSG_PLAYER_LOGIN, struct.pack("<Q", char["guid"]))
        self.map = struct.unpack_from("<I", self.wait_event(SMSG_LOGIN_VERIFY_WORLD, 30), 0)[0]
        time.sleep(3)

    def logout(self):
        self.send(CMSG_LOGOUT_REQUEST)
        self.wait_event(SMSG_LOGOUT_COMPLETE, 30)
        time.sleep(1)


def creature_guid(entry, low):
    return (0xF130 << 48) | (entry << 24) | low


def object_guid(entry, low):
    return (0xF110 << 48) | (entry << 24) | low


# Test scenario --------------------------------------------------------------------------

class Results:
    """Every check's result. Safe to use from several lanes (threads) at once; each line
    is printed straight away, tagged with its lane when there is one."""
    def __init__(self, lane=None, parent=None):
        self.rows = parent.rows if parent else []
        self.lock = parent.lock if parent else threading.Lock()
        self.lane = lane

    def for_lane(self, lane):
        return Results(lane, self)

    def check(self, name, ok, detail=""):
        line = ("  PASS  " if ok else "  FAIL  ") + name + (f"  ({detail})" if detail else "")
        with self.lock:
            self.rows.append((name, bool(ok), detail))
            if self.lane:
                LIVE.write(f"[{self.lane}] {line.strip()}\n")
                LIVE.flush()
        print(line)
        return ok


# A full run plays its lanes in threads. Each lane's own prints (test headers, chat with
# -v) are kept apart and printed as one block when the lane ends; PASS/FAIL lines also
# go straight to LIVE, the real output.
LIVE = sys.stdout


class LaneOutput:
    def __init__(self):
        self.buffers = {}  # thread id -> list of strings; the main thread prints directly

    def write(self, text):
        self.write_for(threading.get_ident(), text)

    def write_for(self, ident, text):
        buf = self.buffers.get(ident)
        if buf is None:
            LIVE.write(text)
        else:
            buf.append(text)

    def flush(self):
        LIVE.flush()

    def start_lane(self):
        self.buffers[threading.get_ident()] = []

    def end_lane(self):
        return "".join(self.buffers.pop(threading.get_ident(), []))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "make-account":
        make_account()
    elif len(sys.argv) > 1 and sys.argv[1] == "run":
        import wb_testbot_scenario as rl_testbot_scenario
        only = next((a for a in sys.argv[2:] if a.isdigit()), None)  # "run 9": only test 9
        rl_testbot_scenario.main(Bot(verbose="-v" in sys.argv), Results(), only)
    elif len(sys.argv) > 1 and sys.argv[1] == "shutdown":
        bot = Bot()
        bot.connect()
        chars = bot.characters()
        bot.enter_world(chars[0] if chars else bot.create_character(CLASS_MAGE, "Wbstop"))
        bot.cmd(".server shutdown 1")
        print("Asked the worldserver to shut down.")
    else:
        print(__doc__)
