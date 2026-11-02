Continue building Warband, my WoW roguelite game mode, in C:\Claude\Projects\Warband.

Start by reading CLAUDE.md, then docs/PROGRESS.md (where we are, every decision, known issues),
docs/warband-design.md (the design), docs/DEV-ENVIRONMENT.md and docs/TEST-QUEUE.md. Then run
`git status` and `git log --oneline -10`.

Where we are: phases 1-6 are built, Act I is playable, and the fixes from my first playtest are in
(automated tests 134/134). Next steps, in order:
1. I replay the playtest (docs/TEST-SESSION.md); record my results in docs/TEST-QUEUE.md and fix
   what I report.
2. Phase 7: traits (their effects in game).
3. Plan one download for all my games (Scholomance Survival in C:\Claude\Projects\WoW-Roguelike,
   Warband, and future games) for a friend: read docs/BUNDLE.md and WoW-Roguelike/docs/PACKAGE.md,
   ask me the open questions there, and give me a short plan before building anything.

Keep working the way CLAUDE.md says: small testable steps, plain-language explanations, exact
in-game test steps, run the test bot (python tools/wb_testbot.py run), commit and push after each
working step.
