# HACK & SHMUP

A fast-paced dungeon shooter with translucent 3D arenas, luminous wireframe characters, and an endless descent. Built with Godot 4.7.

**[Play in your browser](https://yos-gh.github.io/hack-and-shmup/)** — desktop keyboard and mouse required. Click the game to enable audio. Use the title screen button to toggle fullscreen.

## How to play

- Reach the stairs before time runs out. You do not need to defeat every enemy; kills grant extra time.
- Choose an upgrade after each floor. Deeper floors bring tougher encounters.
- Every fifth floor features one of three bosses. Boss fights have no timer; defeat the boss to unlock the stairs.
- One hit means an immediate retry of the same floor. Enemies and the timer reset, but your upgrades remain.
- Walls and unexplored rooms block attacks. Flank shielded enemies to deal damage.
- Your deepest cleared floor is tracked for the current session only. Progress is not saved after closing the game.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move |
| Mouse | Aim |
| Hold left mouse button | Fire machine gun |
| Right mouse button | Use subweapon |
| Q / E or mouse wheel | Switch subweapon |
| 1 / 2 / 3 or click a card | Choose an upgrade |
| Esc | Pause; press again to return to title |
| Click while paused | Resume |
| M | Cycle all audio, sound effects only, and mute (starts with effects only) |
| F10 on title or pause | Open settings and rebind combat keys |
| Esc on the native title screen | Quit |

Subweapons: **Scatter** fires a close-range spread, **Shockwave** pushes enemies back and clears nearby bullets, and **Lance** pierces enemies beyond the screen until blocked by terrain or an unopened room. Obstacles stop only the covered portion of its width.

## Boss practice

Press **B** on the title screen. Select a boss with **A / D**, **Left / Right**, or **1 / 2 / 3**, select a floor with **W / S** or **Up / Down**, then press **Enter**. Mouse selection is also available.

Practice automatically grants upgrades for the selected floor. During play, **R** retries the same encounter and **B** returns to selection. Practice does not update your deepest-floor record.

## Run locally

1. Install **Godot 4.7 (standard edition)** and clone this repository:
   ```sh
   git clone https://github.com/yos-gh/hack-and-shmup.git
   cd hack-and-shmup
   ```
2. Import `project.godot` into Godot and press **F5**.

The game starts in the 25-degree glass-frame 3D view with sound effects only. Settings include volume, reduced flashes, and combat key bindings. Use Save to retain preferences where browser storage is available; runs and records remain session-only.

Characters combine transparent shells, luminous edges, and inner cores. Movement trails, room-entry scans, weapon effects, a descending stair device, and a redesigned HUD share the same visual style. Typography uses bundled Rajdhani and Barlow under the SIL Open Font License; see [asset sources](assets/README.md).

The bundled Sentry addon includes Windows x64 and Web binaries. Other native platforms require the corresponding Sentry Godot addon binaries.

## Build for Web

Install the matching Godot export templates through **Editor > Manage Export Templates**. The included `Web` preset uses GDExtension support without threads.

From the repository root, run in PowerShell (replace the executable path):

```powershell
./tools/export_web.ps1 -Godot "C:/path/to/Godot_console.exe"
```

The output is written to `web/`. The export preserves the landing page (`index.html`), which embeds the game (`game-v2.html`). To preview it, serve that directory over HTTP rather than opening the HTML file directly. For example, with Python 3 installed:

```sh
python tools/serve_web.py web
```

Open [localhost:8123](http://localhost:8123). To publish, commit the updated `web/` files, push to `main`, then run **Publish game to Pages** from GitHub Actions on `main`. Publishing is manual; the workflow uploads the checked-in build and does not export Godot itself.
