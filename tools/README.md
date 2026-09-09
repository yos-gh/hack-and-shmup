# Development validation

Run from the project root with Godot 4.7 stable. These tools are excluded from Web exports.

For the 3D art study, run `./tools/play_study.ps1` (or add `-Scenario halo45`). F6 switches between the same live game's classic and 3D presentation. Normal damage, time and input remain enabled. This is an early appearance study: terrain, player shell and three regular enemy bodies are 3D; bullets, attack ranges, boss bodies and UI retain the established 2D presentation. Initial 3D rendering can stall briefly; Web performance and final art are not yet validated.

```powershell
# All regression tests; audio and view-state checks use a display.
./tools/test.ps1

# Play a repeatable Lv19 floor. Weapon: 0 scatter, 1 shockwave, 2 lance.
Godot_console.exe --path . --script res://tools/scenario.gd -- --scenario=normal19 --seed=19045 --weapon=1 --frames=0

# Play HALO ENGINE at Lv45 with the same seed and balanced automatic upgrades.
Godot_console.exe --path . --script res://tools/scenario.gd -- --scenario=halo45 --frames=0

# Direct 3D study launch (F6 toggles presentation).
Godot_console.exe --path . --script res://tools/scenario.gd -- --scenario=normal19 --frames=0 --view=3d

# 3600 fixed simulation steps, one per rendered frame, capped at 60 FPS.
# Create docs/validation first (test.ps1 also creates it).
Godot_console.exe --path . --disable-crash-handler --log-file scenario.log --max-fps 60 --script res://tools/scenario.gd -- --scenario=halo45 --frames=3600 --output=res://docs/validation/halo45.json --capture=res://docs/validation/halo45.png
```

Measurement mode disables live gameplay input, keeps the player stationary and protected, rotates aim, and fires both weapons whenever ready. Time is replenished. Interactive mode (`frames=0`) uses normal damage, time and controls. These fixtures measure a defined encounter, not maximum load or survival difficulty. Normal19 enters room 1; other rooms retain normal sleeping behavior.

Reports contain engine, CPU, display backend, sample count, CPU-update p95/p99/max, frame-interval p95/p99/max, initial enemies, peak bullets, and a final simulation digest. `--headless` can measure CPU work but cannot capture images or validate rendered frame performance. Fixed-step simulation time is frames/60; wall time can differ. Startup/import is not included; the first update is included. Record GPU, driver, browser and competing workloads separately when comparing hardware.

The read-only `WorldView` and `GameHud` render during the host Game's draw callback. `PlayerInput` shares aim conversion between firing and visualization. Replay input accepts a screen-space `cursor`; an explicit `aim` overrides its derived world direction. The view-state regression checks that drawing combat and menus leaves simulation state and both RNG streams unchanged.

Determinism is scoped to the same engine, fixture, seed, weapon and frame count. This is not cross-version replay. Particle RNG is independent from gameplay RNG; fixtures seed both. Changing particle counts cannot change combat or later floor generation. Map generation and combat still share the gameplay stream. Digests from before this separation are not expected to match new runs.

## HUD and warning audio

`python tools/generate_warning.py` regenerates only the original 0.16-second warning WAV (mono 16-bit PCM, 22050 Hz). Keep its Godot import compression disabled, as with the existing effects. The countdown warns once at each 5-to-1-second threshold per attempt; time bonuses do not repeat a threshold. Death/timeout and clear effects have a reserved voice, and countdown has another. Use `tools/play_study.ps1` to check the cooldown bar while switching weapons and judge the warning level during firing. `hud_audio_test.gd` checks priority, saturation, mute, retry and pause behavior; listening remains necessary for the final mix.

## Publication workflow

The Pages workflow is manual (`workflow_dispatch`). The repository's default branch must receive this workflow change before remote main pushes stop deploying. Local edits alone do not change GitHub behavior. Develop on short `codex/` branches. Review and merge playable changes, then explicitly run **Publish game to Pages** for a reviewed ref with matching `web/` artifacts. This workflow still uploads checked-in files; it does not build them.

Prototype baseline: local annotated tag `v0.1.0-prototype` at `b79a17c`. To prepare rollback, restore `web/` from that tag into a new branch, review the diff, merge and explicitly deploy. No history rewrite is required. Tags, merges, pushes and publication are separate operations; this foundation change has not been pushed or deployed.

## Input and session regression

Existing keyboard bindings now live in `project.godot` InputMap (physical WASD for movement). `PlayerInput` routes events, `GameSession` owns transitions, and `FloorSnapshot` keeps the in-memory retry baseline. `FloorGenerator` returns an independent `FloorData` from `FloorSettings` and a seed or saved RNG state. `Game` applies the result and advances its RNG explicitly. Key-binding settings are not implemented yet.

`session_input_test.gd` checks InputMap bindings/remapping, held inputs and echo suppression, pause/resume shot gating, card/practice transitions and 50 retries across normal floors and all three bosses. Audio regression waits by elapsed time rather than uncapped render frames and exits with a failure result instead of hanging on an assertion.

`floor_data_test.gd` builds normal and all boss floors without a game scene, verifies connectivity/entrance safety/time budgets, and checks that settings, caller RNG and independently generated results cannot affect each other.

## Combat definitions

Edit authored values in `assets/definitions/*.tres`; `combat_catalog.gd` preserves the original weapon/enemy/upgrade index order. Resources are shared read-only at runtime. Weapon reach feeds both hit logic and previews, while upgrade title/description and effects are loaded from the same resource. Enemy HP interpolation keeps extrapolation beyond depth 15. Enemy movement, shot/warning timing, shield charge/recovery and primary fire are also authored resources. Boss-specific behavior is separated into siege/hunter/halo classes; the shared Boss owns queued attacks and warnings.

`combat_events_test.gd` checks shield, damage, kill and death notifications, duplicate suppression, and combat parity with the standard feedback listener disconnected. Signals carry values rather than mutable enemy dictionaries.

## Isolated commit builds

`./tools/build.ps1 -Ref HEAD` archives a committed revision into a new `docs/builds/` directory, checks the exact Godot version from that revision's `tools/toolchain.json`, imports it, runs all native regressions, and exports Web into that isolated directory. Uncommitted working-tree changes are intentionally excluded. The selected commit must contain the toolchain lock and test tools. The current Windows runner needs an available graphics/audio device.

The source ZIP is the original commit archive. The isolated project receives a derived Sentry release (`hack-and-shmup@<commit>`); the manifest records its project-file hash, engine binary hash, original source hash, regression results, package hash and each Web file's SHA-256. `web/build-info.json` identifies the build. No push or publication occurs, and tracked `web/` is not overwritten. This is a traceable fixed-source build, not a claim of byte-identical ZIPs across machines.

Run `python tools/verify_build.py <build-directory>` to check loose files, source/package hashes and the ZIP file list/contents without extracting it. Run `python tools/test_build_verifier.py` for eight verifier checks. Browser playback, interactive Windows play, CI and deployed hash comparison remain separate work. The Sentry regression checks only local binding/configuration; it does not submit a verification message.

For an x86-64 Windows package, run `./tools/build.ps1 -Target Windows -Ref HEAD`. This uses the committed Windows preset, requires the release executable/PCK/Sentry DLL and crash handler dependencies, and launches the exported executable headlessly for 30 frames with a 30-second timeout. Only a clean exit/log allows packaging. The manifest marks `startup_verified`; the verifier rejects Windows packages without that result. The output contains `windows.zip` and a `windows/` directory. Extract the complete ZIP, then run `hack-and-shmup.exe`; keep its PCK and DLL files together. This startup gate does not test interactive input, audio output, or GPU rendering in the exported application.

## Settings backend

`user_settings.gd` provides explicit JSON load/save and physical-key remapping. Construction does not access disk or change InputMap. Call `apply_bindings()` explicitly; reset then apply restores project defaults including mouse/wheel bindings. Remapping currently accepts nonreserved Latin letters/digits for eight combat actions and rejects collisions with unchanged defaults. Reserved menu keys remain fixed. Saving writes a temporary file before replacement; loading reports corrupt/unsupported files without overwriting them. Settings contain volume/reduced-effect preferences only, with no run records. The menu and audio/visual consumers are connected in T15b below.

`user_settings_test.gd` uses a separate process-specific preferences file and tests overwrite, round trip, invalid values/version, collision rejection, isolation and default restoration.

T15b connects the backend to a scrollable Control/Theme menu (title or pause: button/F10). Levels apply immediately, with explicit Save for persistence. Normal main-scene startup loads preferences; SceneTree-script tests and embedded studies stay session-only. Esc cancels rebinding, then closes settings while preserving pause. Reduced flash suppresses the death overlay only. Master/music/effect gain retains the original audio modes and priority ducking. `settings_effects_test.gd` verifies these state transitions, saved preference application and combat/RNG isolation. Existing drawn menus, Web persistence and interactive audio checks remain separate work.


Settings use a fixed action footer and status area, focus-following scroll content, percentage volume labels and a shared MenuTheme. The settings regression also checks footer bounds, focus scrolling and focus retention after remapping.

GameMenus owns Control-based title, pause and upgrade screens using MenuTheme. Card Control rectangles share the pointer helper; resource descriptions wrap within them. Menu refresh preserves focused controls, settings suppresses underlying controls, and guarded card callbacks prevent duplicate transitions. game_menus_test covers these paths, including actual Viewport Enter dispatch. Boss practice also uses shared Controls and hit rectangles. Its arrow shortcuts take priority over GUI focus navigation; Tab/Enter activates controls. Tests cover depth bounds and guarded start without record mixing.


Key settings offer individual default restoration with collision checks, distinguish reserved/unsupported/conflicting inputs, and reject modifier chords. InputMap-derived captions drive the remapped controls guide in title/HUD. Individual resets preserve volume and other settings.

On Web, Save checks OS.is_userfs_persistent before claiming a persistent save. Unavailable storage leaves preferences active for the session and displays that limitation. This check does not verify asynchronous IndexedDB completion or browser reload behavior.

## Manual CI

`./tools/ci.ps1 -Godot <Godot_console.exe> -Ref HEAD` resolves one immutable commit, runs verifier self-tests, builds both targets in isolation, and verifies each manifest/ZIP. `-Targets Web` or `-Targets Windows` limits a local run. Machine-readable build results are written under a unique `docs/ci/` directory. The build script's optional `-ResultFile` returns revision, target and output directory without parsing console text.

`.github/workflows/verify-builds.yml` invokes the same entry point with the workflow commit and retains packages/manifests/logs for 14 days. It is manual-only and does not deploy. It requires a Windows x64 self-hosted runner labeled `godot-desktop`, running in a logged-in interactive desktop session with OpenGL/audio, PowerShell 7, Git, Python 3 and the exact Godot engine/export templates in `tools/toolchain.json`. Configure repository variable `GODOT_CONSOLE` with that runner's absolute engine path. Keep the runner checkout separate from the development workspace. Hosted-runner success is not assumed, and no runner registration or GitHub run is performed by adding these files.

A failed target stops the entry point; it never emits the successful artifact output list for a partial run. Local logs remain under `docs/builds/`. Successful workflow artifacts include original source ZIPs and release ZIPs with manifests and regression logs; extract a release ZIP into its target folder beside the manifest/source ZIP to use the standalone verifier. Interactive browser and exported Windows playback remain separate gates.

The workflow retains diagnostic logs on failure as a separate artifact. Local end-to-end validation of ci.ps1 succeeded for commit 698788a on both targets (25 native regressions each, Web 15 files, Windows 6 files and exported headless startup). GitHub runner execution remains unverified.

## Asset provenance verification

Run python tools/audit_assets.py --regenerate-audio to verify the catalog and regenerate audio in an isolated temporary directory; --write explicitly refreshes reviewed inventory changes. Run python tools/test_asset_audit.py for drift and nonmutation checks. See assets/README.md for source locations and the remaining provenance scope. Fixed-commit builds run the auditor when present in that revision.
