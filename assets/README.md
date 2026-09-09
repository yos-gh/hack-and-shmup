# Project asset sources

`catalog.json` inventories the 11 PCM audio files, 11 combat definitions and sniper iris shader. It records output hashes, audio format/frame counts, and generator hashes. Run `python tools/audit_assets.py --regenerate-audio` from the repository root to check the catalog and reproduce all audio in a temporary directory without touching working assets. After an intentional change, inspect the diff and run `--write` to refresh the catalog. Fixed-commit builds run this verification when the selected revision contains the auditor.

| Outputs | Editable source | Current provenance evidence |
| --- | --- | --- |
| `audio/descent.wav` and nine combat effects | `tools/generate_audio.py` | Repository synthesis code, fixed random seed 177, Python standard library |
| `audio/warning.wav` | `tools/generate_warning.py` | Repository two-pulse synthesis code, Python standard library |
| `definitions/*.tres` | The `.tres` files themselves | Authored combat/upgrade values; consumed by `scripts/combat_catalog.gd` |
| Sniper iris material | `scripts/sniper_iris.gdshader` | Repository shader source |

Keep editable generators in `tools`, game outputs in `assets/audio`, and combat data in `assets/definitions`. Audio names follow their event names in `scripts/sound.gd`. The current output format is mono, signed 16-bit PCM at 22050 Hz; the catalog records exact frame counts. Python/platform math differences may cause a regeneration mismatch, which must be reviewed rather than automatically accepted.

Player, enemy and environment geometry is built in code, principally `scripts/depth_view.gd`; the classic view is drawn in `scripts/world_view.gd`. Menu styling is in `scripts/menu_theme.gd`. These remain code-reviewed sources rather than external model files. Text currently uses Godot's fallback font.

This inventory is technical provenance, not a license grant or ownership determination. Author attribution and final distribution terms are not established here. Sentry is a separate third-party dependency with its own `addons/sentry/LICENSE.md`; engine/font dependency notices and exported Web icons require a separate dependency/credit review. Reference art and research under ignored `docs/` are outside this runtime catalog. Their backup and provenance are still outstanding T16 work.

Text-source hashes and byte counts in the catalog use LF-normalized content so Git CRLF conversion does not create false drift. Audio hashes remain raw bytes. Releases generate THIRD_PARTY_NOTICES.txt from the running Godot engine's embedded license/copyright API and the bundled Sentry addon notice; this does not settle remaining external asset or native dependency provenance.
