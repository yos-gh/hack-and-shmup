# HACK & SHMUP

Find your way. Fight your way.

A roguelite dungeon shooter.

[Play in your browser](https://yos-gh.github.io/hack-and-shmup/) — desktop keyboard and mouse.

Reach the stairs before time runs out. Defeat enemies to earn more time, and choose upgrades as you descend.

## Controls

| Input | Action |
| --- | --- |
| WASD / Mouse | Move / Aim |
| Left / Right click | Fire / Subweapon |
| Q / E or wheel | Switch subweapon |
| Esc | Pause |
| M | Cycle audio mode |

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
