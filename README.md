# HACK & SHMUP

Find your way. Fight your way.

[Play in your browser](https://yos-gh.github.io/hack-and-shmup/) — desktop keyboard and mouse.

Reach the stairs before time runs out. Defeat enemies to earn more time, and choose upgrades as you descend.

## Controls

| Input | Action |
| --- | --- |
| WASD / Mouse | Move / Aim |
| Left / Right click | Fire / Subweapon |
| Q / E or wheel | Switch subweapon |
| Esc | Pause |
| F10 on title or pause | Settings |

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

Open [localhost:8123](http://localhost:8123). To publish, commit the updated `web/` files, push to `main`, then run **Publish game to Pages** from GitHub Actions.

[Development tools](tools/README.md) · [Asset sources and notices](assets/README.md)
