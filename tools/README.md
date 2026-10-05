# Visual polish review (2026-09-14)

Normal launch now uses the 25-degree 3D view. The development scenario still accepts an explicit 2D comparison. Use `polish_review.gd` for protected fixed-step visual/performance fixtures and `polish_journey.gd` for the ordinary-rules movement/fire replay (seed 19045, no invulnerability or clock overrides). Both accept `--output=<directory>`; journey `--no-record` omits PNGs and supports headless execution. PNG sequences are 30fps; the simulation runs at 60Hz. Native recording uses the normal camera, not an art-review framing override. This is scripted gameplay input, not a recorded human playthrough.

`package_review.gd` is an external validation script for the exported PCK: run the Godot editor binary with `--main-pack <export.pck> --script <absolute-path-to-package_review.gd> -- --output=<absolute-directory>`, from the exported folder. Release templates ignore `--script`; verify the release executable separately through its actual UI.

---

# Development validation

Run from the project root with Godot 4.7 stable. These tools are excluded from Web exports.

For the 3D art study, run `./tools/play_study.ps1` (or add `-Scenario citadel5`, `-Scenario bastion15`, or `-Scenario triad45`). F6 switches between the same live game's classic and 3D presentation. Normal damage, time and input remain enabled. This is an early appearance study: terrain, player shell, regular enemies and all three boss bodies are 3D; bullets, attack ranges and UI retain the established 2D presentation. Initial 3D rendering can stall briefly; Web performance and final art are not yet validated.

```powershell
# All regression tests; audio and view-state checks use a display.
./tools/test.ps1

# Play from the normal floor-11 spawn with ten automatic upgrades.
./tools/play_study.ps1 -Scenario normal11

# Play any floor from its normal spawn (one automatic upgrade per cleared floor).
# On boss floors, -Boss 0/1/2 picks Citadel/Bastion/Triad; omit for the seeded pick.
./tools/play_study.ps1 -Floor 23
./tools/play_study.ps1 -Floor 30 -Boss 2
Godot_console.exe --path . --script res://tools/scenario.gd -- --floor=23 --frames=0

# Play a repeatable Lv19 floor. Weapon: 0 scatter, 1 shockwave, 2 lance.
Godot_console.exe --path . --script res://tools/scenario.gd -- --scenario=normal19 --seed=19045 --weapon=1 --frames=0

# Play TRIAD BATTERY at Lv45 with the same seed and balanced automatic upgrades.
Godot_console.exe --path . --script res://tools/scenario.gd -- --scenario=triad45 --frames=0

# Direct 3D study launch (F6 toggles presentation).
Godot_console.exe --path . --script res://tools/scenario.gd -- --scenario=normal19 --frames=0 --view=3d

# 3600 fixed simulation steps, one per rendered frame, capped at 60 FPS.
# Create docs/validation first (test.ps1 also creates it).
Godot_console.exe --path . --disable-crash-handler --log-file scenario.log --max-fps 60 --script res://tools/scenario.gd -- --scenario=triad45 --frames=3600 --output=res://docs/validation/triad45.json --capture=res://docs/validation/triad45.png
```

Measurement mode disables live gameplay input, keeps the player stationary and protected, rotates aim, and fires both weapons whenever ready. Time is replenished. Interactive mode (`frames=0`) uses normal damage, time and controls. These fixtures measure a defined encounter, not maximum load or survival difficulty. Normal11 starts at the normal spawn with ten automatic upgrades; Normal19 enters room 1; other rooms retain normal sleeping behavior.

Reports contain engine, CPU, display backend, sample count, CPU-update p95/p99/max, frame-interval p95/p99/max, initial enemies, peak bullets, and a final simulation digest. `--headless` can measure CPU work but cannot capture images or validate rendered frame performance. Fixed-step simulation time is frames/60; wall time can differ. Startup/import is not included; the first update is included. Record GPU, driver, browser and competing workloads separately when comparing hardware.

The read-only `WorldView` and `GameHud` render during the host Game's draw callback. `PlayerInput` shares aim conversion between firing and visualization. Replay input accepts a screen-space `cursor`; an explicit `aim` overrides its derived world direction. The view-state regression checks that drawing combat and menus leaves simulation state and both RNG streams unchanged.

Determinism is scoped to the same engine, fixture, seed, weapon and frame count. This is not cross-version replay. Particle RNG is independent from gameplay RNG; fixtures seed both. Changing particle counts cannot change combat or later floor generation. Map generation and combat still share the gameplay stream. Digests from before this separation are not expected to match new runs.

## Abyss Wyrm review

`Godot_console.exe --path . --script res://tools/wyrm_review.gd -- --fire=0.5` plays the 25th-floor boss with a protected player who circles the arena and fires the primary at the head's core for the given share of each second while it is out. It saves captures of the breach warning, the three first-form patterns (beam, rings, bombardment), the bombardment's windup and slag column, the shock cage, a dive, holes closing, the second-form breach, body beams, the charge lane and the second-form bombardment to `docs/validation/wyrm-*.png` (framed on the boss) and prints how long each form lasted and the longest stop while prowling. Add `--floor=50` for the expert tier, `--form=2` to start at the second form, or `--headless --no-capture` to measure only. `tests/wyrm_test.gd` covers placement, cover, warnings, the crawling patterns, the shielded core, the form split, unstuck movement next to a pillar, the charge, body beams, the bombardment and the debug shortcuts.

In debug builds (the editor and debug exports, never release exports) F8 toggles invincibility and F9 sends the Abyss Wyrm to its second form. `./tools/play_study.ps1 -Floor 25 -Boss 3 -Form 2` starts a study at the second form.

## Lance cost profile

`Godot_console.exe --path . --max-fps 0 res://tools/lance_profile.tscn -- --output=<file>` measures lane tracing, firing and aiming/firing frame times at base and maximum lance width in 2D and 3D, beside the Shockwave guide on the same floor. Vsync is disabled so CPU cost is visible. For a browser measurement, export a copy of the project with this scene as main scene and `tools/*` removed from the Web exclude filter; the report is printed and stored in `window.lanceProfile`.

## Shockwave cost profile

`Godot_console.exe --path . --max-fps 0 res://tools/shock_profile.tscn -- --output=<file>` times the Shockwave firing call, the frame it fires on and the frames of its blast effect against idle frames with the guide, in 2D and 3D: alone, with 200 hostile bullets inside the blast, and with 60 mobs killed at once (kill bursts, hit marks, numbers and sparks). Browser measurement works as for the Lance profile; the report is stored in `window.shockProfile`.

## Whole-game load profile

`Godot_console.exe --path . --max-fps 0 --disable-vsync --script res://tools/load_profile.gd -- --floor=42 --alert=2 --output=<file>` plays a deep normal floor (about 680 mobs from floor 17 on) with a protected, stationary player firing in a rotating aim. Mob HP is inflated so the crowd keeps its size. `--alert=N` opens rooms 1..N with their mobs pursuing (the rest sleep); `--view=2d`, `--weapon=0..2`, `--fire=0` and `--capture=<png>` vary the run, and `--hide=<3D batch keys>`, `--msaa=0|2|4`, `--fx=0` (hides the full-screen pass) and `--depth_scale=N` (N times the 3D pixels, same framing) are GPU diagnostics; add `--resolution WxH` before `--script` to stress the full-screen pass. The report separates simulation, 3D sync, 2D draw, render CPU/GPU and frame interval, and carries a state digest for before/after parity. `tests/performance_rules_test.gd` checks that the Game's inlined `tile`/`center`/`walkable`/`entry_safe`/`attack_open` agree with `FloorQueries`, and that bullet lookups still match the brute-force scan when sleeping mobs in unopened rooms are left out of the buckets.

## HUD and warning audio

`python tools/generate_sfx.py` regenerates every sound effect (48 kHz stereo 16-bit PCM) from 2A03-style pulse, triangle and noise voices; `--only key,key` and `--out DIR` render a subset elsewhere for auditioning. Each clip is normalised to the same short-term loudness, so the balance lives in the `MIX` table in `scripts/sound.gd` (enemy cues read it too). Primary fire retriggers its own voice so rapid fire never stacks. Keep Godot import compression disabled (`compress/mode=0`) for new clips. The countdown warns once at each 5-to-1-second threshold per attempt; time bonuses do not repeat a threshold. Death/timeout and clear effects have a reserved voice, and countdown has another. Use `tools/play_study.ps1` to check the cooldown bar while switching weapons and judge the warning level during firing. `hud_audio_test.gd` checks priority, saturation, mute, retry and pause behavior; listening remains necessary for the final mix.

## Background music

`scripts/music.gd` maps screens to tracks: title, card select (intermission), one track per boss, and a stage track for every newly generated normal floor. Stage tracks come from a shuffle bag, so all fourteen play before any repeats and the same song never plays on two floors in a row; a retry keeps the floor's track because selection follows `floor_revision`, not the attempt. Selection uses its own RNG, never the gameplay stream. `Sound.update_music` runs every physics tick and fades the old track out (0.4 s) before switching; music plays while AUDIO is ON, at `MUSIC_DB`. After a boss falls, the quiet `intermission_cooling` loop replaces the boss track until the stairs. Music keeps playing on the pause screen (including a focus-loss pause); effects freeze. The Abyss Wyrm (every 25th floor) plays `boss_abyss_core` for its first form and switches to `boss_recca_dark_v2` the moment it tears out of the floor (`Music.WYRM_SECOND`). The ending theme is imported but not yet used (`Music.RESERVED`). Boss floors also avoid repeating the previous boss of the run (`FloorSettings.previous_boss`); explicit picks (practice, `-Boss`) are unchanged. `music_test.gd` covers loading, loop points, selection, retry continuity and the boss rotation.

There is no volume setting, so music and effects share a final output bus with `OUTPUT_GAIN_DB` (+6 dB) of makeup gain into a hard limiter at -1 dBFS. `tools/mix_level_review.gd` records the real mixer in four moments (title, a normal floor under fire, a Triad fight, death and boss destruction) to `docs/validation/mix-*.wav`; run it with `--audio-driver Dummy` to keep it silent and measure the files with ffmpeg's `ebur128`. At the current settings combat measures about -18 LUFS, a boss fight about -17 LUFS with peaks touching the ceiling, and the title about -25 LUFS.

## Publication workflow

`.github/workflows/pages.yml` builds on GitHub-hosted Ubuntu runners for every pull request, push to `main`, `v*` tag and manual run. The Web job exports the `Web` preset with the Sentry release set to `hack-and-shmup@<commit>`, adds `web/index.html`, fonts, notices and `build-info.json`, and a push to `main` deploys it to Pages. The Windows job exports the `Windows Preview` single executable with the same Sentry removal as `export_windows_preview.ps1`, checks it with `verify_windows_preview.gd`, and keeps it as a workflow artifact; on a `v*` tag it also creates the GitHub Release. The Godot version comes from `tools/toolchain.json` (`tools/ci/install_godot.sh`). The Linux editor also needs the Sentry Linux library, which `tools/ci/install_sentry_linux.sh` downloads from the matching sentry-godot release. Hosted runners do not run the native regressions; those remain in the manual Windows workflow below.

Prototype baseline: annotated tag `v0.1.0-prototype` at `b79a17c`. To roll back the Web version, revert the change on `main`; the next run publishes the reverted build. Merging to `main` publishes the Web version; pushing a tag publishes a Windows release.

## Input and session regression

Existing keyboard bindings now live in `project.godot` InputMap (physical WASD for movement). `PlayerInput` routes events, `GameSession` owns transitions, and `FloorSnapshot` keeps the in-memory retry baseline. `FloorGenerator` returns an independent `FloorData` from `FloorSettings` and a seed or saved RNG state. `Game` applies the result and advances its RNG explicitly. Combat key bindings can be changed from the settings menu.

`session_input_test.gd` checks InputMap bindings/remapping, held inputs and echo suppression, pause/resume shot gating, card/practice transitions and 50 retries across normal floors and all three bosses. Audio regression waits by elapsed time rather than uncapped render frames and exits with a failure result instead of hanging on an assertion.

`floor_data_test.gd` builds normal and all boss floors without a game scene, verifies connectivity/entrance safety/time budgets, and checks that settings, caller RNG and independently generated results cannot affect each other.

## Combat definitions

Edit authored values in `assets/definitions/*.tres`; `combat_catalog.gd` preserves the original weapon/enemy/upgrade index order. Resources are shared read-only at runtime. Weapon reach feeds both hit logic and previews, while upgrade title/description and effects are loaded from the same resource. Enemy HP interpolation keeps extrapolation beyond depth 15. Enemy movement, shot/warning timing, shield charge/recovery and primary fire are also authored resources. Boss-specific behavior is separated into Citadel/Bastion/Triad classes; the shared Boss owns queued attacks and warnings.

`combat_events_test.gd` checks shield, damage, kill and death notifications, duplicate suppression, and combat parity with the standard feedback listener disconnected. Signals carry values rather than mutable enemy dictionaries.

## Isolated commit builds

`./tools/build.ps1 -Ref HEAD` archives a committed revision into a new `docs/builds/` directory, checks the exact Godot version from that revision's `tools/toolchain.json`, imports it, runs all native regressions, and exports Web into that isolated directory. Uncommitted working-tree changes are intentionally excluded. The selected commit must contain the toolchain lock and test tools. The current Windows runner needs an available graphics/audio device.

The source ZIP is the original commit archive. The isolated project receives a derived Sentry release (`hack-and-shmup@<commit>`); the manifest records its project-file hash, engine binary hash, original source hash, regression results, package hash and each Web file's SHA-256. `web/build-info.json` identifies the build. No push or publication occurs, and tracked `web/` is not overwritten. This is a traceable fixed-source build, not a claim of byte-identical ZIPs across machines.

Run `python tools/verify_build.py <build-directory>` to check loose files, source/package hashes and the ZIP file list/contents without extracting it. Run `python tools/test_build_verifier.py` for eight verifier checks. Browser playback, interactive Windows play, CI and deployed hash comparison remain separate work. The Sentry regression checks only local binding/configuration; it does not submit a verification message.

For an x86-64 Windows package, run `./tools/build.ps1 -Target Windows -Ref HEAD`. This uses the committed Windows preset, requires the release executable/PCK/Sentry DLL and crash handler dependencies, and launches the exported executable headlessly for 30 frames with a 30-second timeout. Only a clean exit/log allows packaging. The manifest marks `startup_verified`; the verifier rejects Windows packages without that result. The output contains `windows.zip` and a `windows/` directory. Extract the complete ZIP, then run `hack-and-shmup.exe`; keep its PCK and DLL files together. This startup gate does not test interactive input, audio output, or GPU rendering in the exported application.

## Session controls

Controls use the fixed project InputMap. Sound (a simple ON/OFF toggle: M or the AUDIO button) and fullscreen can be changed for the current session; sound starts ON. There is no settings screen, preference file, or persistent record.

GameMenus owns title, pause, practice, CONTINUE and upgrade Controls. Boss practice is no longer on the title; debug builds still open it with B, and the review tools call `BossPractice.start` directly. `scripts/run_password.gd` encodes the resume password: the floor, its generator state, the previous boss, card counts, sub weapon, deaths and floor-start kills, behind a salted 24-bit checksum that also scrambles the body. Decoding rejects edits and impossible runs (card caps, one card per cleared floor, stat floors). `password_test.gd` checks that resumed floors rebuild identically, including boss floors. Card rectangles share the pointer helper, keyboard focus survives refresh, and guarded callbacks prevent duplicate transitions. Pause and card screens show all seven player stats, including sub range, radius, width and recharge caps.

## Manual CI

`./tools/ci.ps1 -Godot <Godot_console.exe> -Ref HEAD` resolves one immutable commit, runs verifier self-tests, builds both targets in isolation, and verifies each manifest/ZIP. `-Targets Web` or `-Targets Windows` limits a local run. Machine-readable build results are written under a unique `docs/ci/` directory. The build script's optional `-ResultFile` returns revision, target and output directory without parsing console text.

`.github/workflows/verify-builds.yml` invokes the same entry point with the workflow commit and retains packages/manifests/logs for 14 days. It is manual-only and does not deploy. It requires a Windows x64 self-hosted runner labeled `godot-desktop`, running in a logged-in interactive desktop session with OpenGL/audio, PowerShell 7, Git, Python 3 and the exact Godot engine/export templates in `tools/toolchain.json`. Configure repository variable `GODOT_CONSOLE` with that runner's absolute engine path. Keep the runner checkout separate from the development workspace. Hosted-runner success is not assumed, and no runner registration or GitHub run is performed by adding these files.

A failed target stops the entry point; it never emits the successful artifact output list for a partial run. Local logs remain under `docs/builds/`. Successful workflow artifacts include original source ZIPs and release ZIPs with manifests and regression logs; extract a release ZIP into its target folder beside the manifest/source ZIP to use the standalone verifier. Interactive browser and exported Windows playback remain separate gates.

The workflow retains diagnostic logs on failure as a separate artifact. Local end-to-end validation of ci.ps1 succeeded for commit 698788a on both targets (25 native regressions each, Web 15 files, Windows 6 files and exported headless startup). GitHub runner execution remains unverified.

## Asset provenance verification

Run python tools/audit_assets.py --regenerate-audio to verify the catalog and regenerate audio in an isolated temporary directory; --write explicitly refreshes reviewed inventory changes. Run python tools/test_asset_audit.py for drift and nonmutation checks. See assets/README.md for source locations and the remaining provenance scope. Fixed-commit builds run the auditor when present in that revision.

## Authored docs backup

Run `python tools/backup_docs.py` to create a unique ZIP and SHA-256 sidecar in `docs/backups/`. It covers authored docs and captures/references, excluding `builds`, `validation`, `ci`, and `backups` before traversing them, so backups never include earlier backups. `--output-dir` can select a subdirectory of `docs/backups/` or an external directory. Run `--verify <zip>` to check every member against the embedded manifest. `python tools/test_backup_docs.py` checks round-trip bytes, exclusions, repeated internal backups, default output, and invalid destinations/extra members. A same-PC ZIP is not off-device storage; no automatic schedule is created.

Release builds containing tools/export_notices.gd generate THIRD_PARTY_NOTICES.txt with the running engine's embedded notices and the bundled Sentry license. The manifest marks notices_generated and includes its hash; verify_build.py requires that file when declared. Asset auditing normalizes CRLF to LF for textual sources while preserving binary audio hashes.

Application focus loss pauses active combat/audio and disarms firing; focus return alone never resumes. Key capture is cancelled, while title and upgrade selection retain their contexts. focus_pause_test sends notifications directly and verifies frozen simulation and explicit resume gating. Actual OS/browser notification delivery remains an interactive check.

## Local Web preview

Run `python tools/serve_web.py <build-directory>/web` from the project root, then open `http://127.0.0.1:8123/game-v2.html`. The directory must contain the exported `game-v2.html`. Use `--port` to choose another port and Ctrl+C in the serving terminal to stop. This serves only on localhost with Godot isolation headers and caching disabled; it does not publish a build. Browser persistence, audio and font rendering still require interactive verification.
