# Development validation

Run from the project root with Godot 4.7 stable. These tools are excluded from Web exports.

```powershell
# All regression tests; audio uses a display, the rest run headless.
./tools/test.ps1

# Play a repeatable Lv19 floor. Weapon: 0 scatter, 1 shockwave, 2 lance.
Godot_console.exe --path . --script res://tools/scenario.gd -- --scenario=normal19 --seed=19045 --weapon=1 --frames=0

# Play HALO ENGINE at Lv45 with the same seed and balanced automatic upgrades.
Godot_console.exe --path . --script res://tools/scenario.gd -- --scenario=halo45 --frames=0

# 3600 fixed simulation steps, one per rendered frame, capped at 60 FPS.
# Create docs/validation first (test.ps1 also creates it).
Godot_console.exe --path . --disable-crash-handler --log-file scenario.log --max-fps 60 --script res://tools/scenario.gd -- --scenario=halo45 --frames=3600 --output=res://docs/validation/halo45.json --capture=res://docs/validation/halo45.png
```

Measurement mode disables live gameplay input, keeps the player stationary and protected, rotates aim, and fires both weapons whenever ready. Time is replenished. Interactive mode (`frames=0`) uses normal damage, time and controls. These fixtures measure a defined encounter, not maximum load or survival difficulty. Normal19 enters room 1; other rooms retain normal sleeping behavior.

Reports contain engine, CPU, display backend, sample count, CPU-update p95/p99/max, frame-interval p95/p99/max, initial enemies, peak bullets, and a final simulation digest. `--headless` can measure CPU work but cannot capture images or validate rendered frame performance. Fixed-step simulation time is frames/60; wall time can differ. Startup/import is not included; the first update is included. Record GPU, driver, browser and competing workloads separately when comparing hardware.

Determinism is scoped to the same engine, fixture, seed, weapon and frame count. This is not cross-version replay. Particle RNG is independent from gameplay RNG; fixtures seed both. Changing particle counts cannot change combat or later floor generation. Map generation and combat still share the gameplay stream. Digests from before this separation are not expected to match new runs.

## Publication

The Pages workflow is manual (`workflow_dispatch`). The repository's default branch must receive this workflow change before remote main pushes stop deploying. Local edits alone do not change GitHub behavior. Develop on short `codex/` branches. Review and merge playable changes, then explicitly run **Publish game to Pages** for a reviewed ref with matching `web/` artifacts. This workflow still uploads checked-in files; it does not build them.

Prototype baseline: local annotated tag `v0.1.0-prototype` at `b79a17c`. To prepare rollback, restore `web/` from that tag into a new branch, review the diff, merge and explicitly deploy. No history rewrite is required. Tags, merges, pushes and publication are separate operations; this foundation change has not been pushed or deployed.
