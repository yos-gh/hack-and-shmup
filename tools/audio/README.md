# Sound review production

This is the representative listening gate, not the completed soundtrack.
The first eight approved SFX are now installed in assets/audio. BGM and audio
defaults are unchanged. Current selected editable music is in docs/audio/selected;
effect source RPP/WAV and cues are in docs/audio/production_se. Temporary audition
WAVs, archives and videos were cleaned up, so regenerate old previews before
using the historical audition commands below. Never run close_session.py again
as a general cleanup: it records this one completed handoff and original paths.

Requirements: REAPER 7.79, Magical 8bit Plug 2 VST3, stock ReaEQ/ReaDelay/ReaComp,
Python 3, FFmpeg with libvorbis, and the project's Godot engine. No MCP needed.

1. Run `python tools/audio/sample_score.py` to prepare original score data and MIDI.
2. Run REAPER with `-nonewinst` and the absolute path to `reaper_sample.lua`.
   It creates dedicated tabs and writes projects/24-bit renders to
   `docs/audio/sample/v02/`. A fresh revision directory avoids overwrite prompts.
3. Run `python tools/audio/prepare_review.py` to extract the settled 48-second
   loop, apply static headroom-aware gain, encode Ogg, and prepare eight effects.
4. Run `tools/audio/play_review.ps1` for interactive review. Other effect families
   remain the existing placeholders. `M` cycles audio, Q/E changes weapons.

`reaper_probe.lua` is the minimal instrument/load/render diagnostic.
`reaper_fx_probe.lua` records the local stock-effects parameter map. The renderer
checks the synth parameter names and reads back nonlinear formatted values.

`review.gd -- --capture`, with Godot Movie Maker enabled at 60 fps, records a
48-second controlled combat demonstration, including a death at 21 seconds.
The fixture is stationary and protected except for that explicit death; it is
not a balance test. `loop_review.gd` renders three Ogg cycles through Godot.

Short effects may have no integrated LUFS measurement because they are shorter
than its analysis gate. Their true peaks are measured; undefined LUFS is null.

Production sources and review artifacts live under `docs/audio/`, following the
repository's existing ignored-docs policy. Keep that folder with this checkout;
scripts are tracked, but generated RPP/MIDI/audio are not included in a git clone
unless separately archived. Release presets exclude docs and tools.

## Underground BGM candidates

The representative SFX direction is approved. BGM candidates are audition-only;
the user will select songs before game integration.

`candidate_scores.py` generates eight stage and two title scores, each 112–128 s.
Write one catalog ID to `docs/audio/candidates/underground-v1/render_selection.txt`
and invoke `reaper_candidates.lua` through REAPER. Wait for that ID's COMPLETE
line before changing the selection and invoking the next render. Existing
renders may require overwrite confirmation; use a fresh revision for changes.
The shared `reaper_engine.lua` uses Magical 8bit Plug 2, stock REAPER effects
and stock JS Saturation [LOSER]. `prepare_candidates.py` extracts settled loops,
matches group loudness, checks encoded peaks and makes a local listening page,
comparison reel, playlist and portable audition archive. Masters and source
projects remain alongside the audition set. No normal game files are changed.

Second round: `revision_scores.py` creates three revised stages, three boss
studies and the revised T2 under `underground-v2`. Put each selected ID in that
folder's `render_selection.txt` and run `reaper_revision.lua`; wait for COMPLETE
before moving to the next ID. Then run `prepare_candidates.py underground-v2`
and `compare_revisions.py` to add the loudness-matched original/revision reel.
The previous audition round remains unchanged. Selection and integration are
separate steps; the second round does not authorize changes to game music policy.

Third round: `stage_round3.py` rebuilds only three stage scores from the first
BLACK CIRCUIT direction, with compact stable-pitch melodies and distinct drum/
bass palettes. Use `reaper_round3.lua` with each ID in
`docs/audio/candidates/stage-v3/render_selection.txt`, waiting for COMPLETE.
Then `prepare_candidates.py stage-v3` makes the full-loop listening package.
If an invocation times out before BEGIN, inspect REAPER before retrying; do not
queue duplicate renders. This round preserves title, boss, SE and runtime files.

Fourth round: `melody_round4.py` creates four short melody studies for stage 02
only. `reaper_melody4.lua` renders `02-melody-v4`, and
`prepare_candidates.py 02-melody-v4` packages the auditions. All share backing
notes, instrument settings and a common output gain; their lead themes differ.
They preserve the 8-bar opening and use an 8-bar theme/answer/restatement layout.

Fifth round: `locked_current_v5.py` and `reaper_motion5.lua` produce one complete
stage-02 loop with articulated lead, responding counterline and chord/octave
layers. Run `prepare_candidates.py 02-motion-v5` to package. The generator checks
exact drum/bass preservation and unchanged opening note events. Earlier songs,
title/boss candidates and game assets remain untouched; this is an audition.

Stage-01 selection: `circuit_variants.py`, `reaper_circuit_variants.lua`, then
`prepare_candidates.py 01-variants-v1` produce three 48-second studies with a
common backing/gain. 02 is left at MOTION V5. Deliver locally; Google Drive
uploads require an explicit user request, not an inferred ongoing preference.

Stage-03 selection: `breaker_variants.py`, `reaper_breaker_variants.lua`, then
`prepare_candidates.py 03-variants-v1` produce three 46.3-second breakbeat studies.
They replace singing leads with short riff/arp/retrigger cells while preserving
the original bass/drum data. Stage 01 C / GRIDLOCK is the preferred candidate;
02 remains MOTION V5. Deliver locally, without game integration or Drive upload.
