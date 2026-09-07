# HACK & SHMUP

A fast-paced, top-down dungeon shooter built with Godot 4.7.

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
| M | Cycle all audio, sound effects only, and mute |
| Esc on the native title screen | Quit |

Subweapons: **Scatter** fires a close-range spread, **Shockwave** pushes enemies back and clears nearby bullets, and **Lance** pierces enemies in a straight line.

## Boss practice

Press **B** on the title screen. Select a boss with **Left / Right** or **1 / 2 / 3**, select a floor with **Up / Down**, then press **Enter**. Mouse selection is also available.

Practice automatically grants upgrades for the selected floor. During play, **R** retries the same encounter and **B** returns to selection. Practice does not update your deepest-floor record.

## Run locally

1. Install **Godot 4.7 (standard edition)** and clone this repository:
   ```sh
   git clone https://github.com/yos-gh/hack-and-shmup.git
   cd hack-and-shmup
   ```
2. Import `project.godot` into Godot and press **F5**.

The bundled Sentry addon includes Windows x64 and Web binaries. Other native platforms require the corresponding Sentry Godot addon binaries.

## Build for Web

Install the matching Godot export templates through **Editor > Manage Export Templates**. The included `Web` preset uses GDExtension support without threads.

From the repository root, run in PowerShell (replace the executable path):

```powershell
./tools/export_web.ps1 -Godot "C:/path/to/Godot_console.exe"
```

The output is written to `web/`. To preview it, serve that directory over HTTP rather than opening the HTML file directly. For example, with Python 3 installed:

```sh
python -m http.server 8000 --directory web
```

Open [localhost:8000](http://localhost:8000). To publish a build, commit the updated `web/` files and push to `main`; the included GitHub Actions workflow deploys them to GitHub Pages.
