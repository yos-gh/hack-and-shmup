# HACK & SHMUP

Find your way. Fight your way. A roguelite dungeon shooter.

[Play in your browser](https://yos-gh.github.io/hack-and-shmup/)

[Download for Windows](https://github.com/yos-gh/hack-and-shmup/releases) — run the single executable.

Reach the stairs before time runs out. Defeat enemies to earn more time, and choose upgrades as you descend.

## Controls

| Input | Action |
| --- | --- |
| WASD / Mouse | Move / Aim |
| Left / Right click | Fire / Subweapon |
| Q / E or wheel | Switch subweapon |
| Esc | Pause |
| M | Sound on / off |
| Left stick / D-pad | Move |
| Right stick | Aim |
| A / Cross or LB | Fire / confirm menus |
| RB | Subweapon |
| LT / RT | Previous / next subweapon (Q / E) |
| B / Circle | Pause, return to title from pause, or quit at title in the native build |

Use the left stick or D-pad to select menu items, then A / Cross or LB to confirm.

## Subweapons

- **Scatter** — A close-range spread.
- **Shockwave** — Push enemies back and clear nearby bullets.
- **Lance** — A piercing beam.

Face one of three bosses every five floors, with no time limit. Boss practice is available from the title screen, with sound and fullscreen controls.

## Run and build

Open `project.godot` in **Godot 4.7** and press **F5**.
For Web builds, install the matching export templates and run:

```powershell
./tools/export_web.ps1 -Godot "C:/path/to/Godot_console.exe"
```

Preview with Python 3:

```sh
python tools/serve_web.py web
```

Open [localhost:8123](http://localhost:8123). The exported files in `web/` are for local preview only and are not committed; only `web/index.html` is.

GitHub Actions builds both the Web and Windows versions on every pull request and push. A push to `main` publishes the Web version to Pages. Pushing a `v*` tag publishes the Windows executable as a GitHub Release (a tag with a hyphen, such as `v0.1.0-preview.6`, becomes a pre-release, and an annotated tag's message becomes the release notes).

[Development tools](tools/README.md) · [Asset sources and notices](assets/README.md)
