# Who Wears It

World of Warcraft Forever addon (Interface 16001) by ibol records.

1. `/wwi` opens a window: pick a slot and an armor type, see every appearance and which ones you are missing.
2. "Who can wear it" lists each of your characters with a check mark or the reason they cannot (armor, level, class).
3. Click an appearance to preview it on your character; "Add to look" builds a meta outfit and shows its progress.
4. Your characters are recorded on login; nothing about other players is stored.
5. To test: copy this folder to `_forever_\Interface\AddOns\WhoWearsIt`, log in and type `/wwi selftest`.

Development checks without the game: `python -I tools/check_addon.py`, `powershell -File tools/check-toc.ps1`,
and `lua tests/rules_spec.lua` / `lua tests/db_spec.lua` when Lua 5.1 is available. API notes: `docs/API-NOTES.md`.
