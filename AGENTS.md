# AGENTS.md

## Cursor Cloud specific instructions

This repo is a **Godot 4.7 game** ("TMFCG-4", a Touhou-themed card game) written in GDScript, plus an optional Python asset-tooling package. There is no backend/database; the game runs as a native desktop app (its networking uses in-process/host multiplayer, so a single instance can create and join rooms locally).

### Engine
- Requires **Godot Engine 4.7-stable**, installed at `/usr/local/bin/godot` (persisted in the VM snapshot; not reinstalled by the update script). Verify with `godot --version`.
- The **Dialogic** and **gdUnit4** addons are vendored in `addons/` — no separate install.

### Running the game
- Run with `godot --path /workspace` on a display (a virtual display is available at `DISPLAY=:1`; the desktop/`computerUse` uses it). The lobby lets you Create Public/Private Room, chat, edit deck, etc.
- Benign on this VM: `WARNING: Could not set V-Sync`, ALSA/audio errors falling back to the dummy audio driver, and llvmpipe (software) rendering. A `Join failed: 无法重新加入房间` warning on startup is just the auto-rejoin of a previously-open room giving up — not a crash.
- First run needs the import cache (`.godot/`, gitignored). Generate/refresh it with `godot --headless --import --path /workspace` (~1 min) if assets changed.

### Tests (gdUnit4)
- Test suites live in `tests/`. Run with `GODOT_BIN=/usr/local/bin/godot DISPLAY=:1 ./addons/gdUnit4/runtest.sh -a tests`.
- **gdUnit4 refuses `--headless`** ("Headless mode is not supported!", exit 103). Run on a display (`DISPLAY=:1`) — do NOT pass `--headless`. (`--ignoreHeadlessMode` also exists but a real display is safer for input-driven tests.)
- HTML/XML reports are written to `reports/` (gitignored).

### Gotcha: import/headless runs mutate tracked files
Running `godot --headless --import` (and some headless runs) makes the **Dialogic** addon rewrite the `[dialogic]` section of `project.godot` (clearing `directories/dch_directory` and `dtl_directory`) and regenerate the `definitions/database/translations/*.translation` files. These are spurious — **revert them before committing**: `git checkout -- project.godot definitions/database/translations/`.

### Optional Python tooling
- `scripts/convert_characters/` regenerates character `.dch` files / translation CSVs from `Characters.json`, managed by **uv** (`uv sync --project scripts/convert_characters`, then `uv run --project scripts/convert_characters python convert_characters.py`). Not needed to build or play the game. Note the `convert-characters` console entry point is not installed (project is non-packaged); invoke the `.py` files directly.
