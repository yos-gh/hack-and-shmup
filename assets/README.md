# Project asset sources

`catalog.json` inventories authored PCM audio, combat definitions and presentation shaders. It records output hashes, audio format/frame counts, and generator hashes. Run `python tools/audit_assets.py --regenerate-audio` from the repository root to check the catalog and reproduce all audio in a temporary directory without touching working assets. After an intentional change, inspect the diff and run `--write` to refresh the catalog. Fixed-commit builds run this verification when the selected revision contains the auditor.

| Outputs | Editable source | Current provenance evidence |
| --- | --- | --- |
| `audio/descent.wav` | `tools/generate_audio.py` | Repository synthesis code, fixed random seed 177, Python standard library |
| All other `audio/*.wav` effects | `tools/generate_sfx.py` | Repository 2A03-style synthesis code, per-effect fixed seeds, Python standard library |
| `music/*.ogg` background music | REAPER projects in the local, untracked `bgm-work/reaper/`, rendered by `bgm-work/scripts/make_game_music.py` | Repository-local chiptune synthesis (Magical 8bit Plug 2, FAMISYNTH-II, RP2A03, SN76489 in REAPER); the sources are not in Git yet, so these files are outside the audited catalog |
| `definitions/*.tres` | The `.tres` files themselves | Authored combat/upgrade values; consumed by `scripts/combat_catalog.gd` |
| Sniper iris material | `scripts/sniper_iris.gdshader` | Repository shader source |

Keep editable generators in `tools`, game outputs in `assets/audio`, and combat data in `assets/definitions`. Music lives in `assets/music`: OGG Vorbis (quality 2, about 96 kbps, 44.1 kHz stereo), static-gain matched to about -16 LUFS (title -19, card select -20) so loops stay seamless. Every file ends on a bar line and loops from the offset stored both in its `.import` settings and in `scripts/music.gd` (`music_test.gd` checks they agree). Audio names follow their event names in `scripts/sound.gd`. Effects are stereo signed 16-bit PCM at 48 kHz and the music loop is mono 22050 Hz; the catalog records exact frame counts. Python/platform math differences may cause a regeneration mismatch, which must be reviewed rather than automatically accepted.

Player, enemy and environment geometry is built in code, principally `scripts/depth_view.gd`; the classic view is drawn in `scripts/world_view.gd`. Menu styling is in `scripts/menu_theme.gd`. These remain code-reviewed sources rather than external model files. Headings use bundled Rajdhani SemiBold; body text uses Barlow Regular/Medium. Their OFL-1.1 notices are included in assets/fonts and exported third-party notices. Exact font bytes and upstream locations are recorded in the dependency catalog.

This inventory is technical provenance, not a license grant or ownership determination. Author attribution and final distribution terms are not established here. Sentry is a separate third-party dependency with its own `addons/sentry/LICENSE.md`; exported Web icons require a separate dependency/credit review. Reference art and research under ignored `docs/` are outside this runtime catalog. Their backup and provenance are still outstanding T16 work.

Text-source hashes and byte counts in the catalog use LF-normalized content so Git CRLF conversion does not create false drift. Audio hashes remain raw bytes. Releases generate THIRD_PARTY_NOTICES.txt from the running Godot engine's embedded license/copyright API and the bundled Sentry addon notice; this does not settle remaining external asset or native dependency provenance.

The catalog also pins nine supported Sentry artifacts: Windows x86_64 libraries/crash handlers, threaded and nonthreaded Web libraries, and the JavaScript bundle. Unsupported local platform installations are excluded. Binary bytes are exact; JavaScript line endings are normalized to LF. Hashes identify the installed dependency content but do not establish its upstream release tag or the completeness of transitive notices.
