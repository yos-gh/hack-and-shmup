# HACK & SHMUP

Find your way. Fight your way. A roguelite dungeon shooter.

[Play in your browser](https://yos-gh.github.io/hack-and-shmup/)

[Download for Windows](https://github.com/yos-gh/hack-and-shmup/releases/tag/v0.1.0-preview.2) — run the single executable.

Reach the stairs before time runs out. Defeat enemies to earn more time, and choose upgrades as you descend.

## Controls

| Input | Action |
| --- | --- |
| WASD / Mouse | Move / Aim |
| Left / Right click | Fire / Subweapon |
| Q / E or wheel | Switch subweapon |
| Esc | Pause |
| M | Cycle audio mode |
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

Boss practice is available from the title screen.

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

Open [localhost:8123](http://localhost:8123). To publish, export the latest game, commit the updated `web/` files, and push to `main`. GitHub Actions publishes Pages automatically.

[Development tools](tools/README.md) · [Asset sources and notices](assets/README.md)
