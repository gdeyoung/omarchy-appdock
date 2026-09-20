# Omarchy AppDock

A KDE/GNOME-style task manager and minimize system for [Omarchy](https://omarchy.org/) (Hyprland 0.56.x) — because "the window is minimized somewhere" should never mean "the window is lost".

## What you get

- **App Dock in the bar's left section** (after the workspace numbers): one icon per window on the current workspace, with real app icons
- **Click the focused app → minimizes to the dock** (icon dims, dot indicator appears)
- **Click a minimized icon → restores** it to the workspace you're on
- **Per-workspace docks**: minimized windows only appear on the workspace they came from
- **Native titlebars on floating windows** (close X / minimize _ / maximize □) via hyprbars, wired to the same engine
- Middle-click a dock icon to close; hover for app name + title

Works alongside [jwm3000's Floating Window Mode](https://github.com/jwm3000/omarchy-windows) (floating windows, aero-snap) — that plugin handles floating; AppDock handles the task manager and minimize.

## Requirements

- Omarchy 4.x with Hyprland 0.56.x
- `notify-send` (libnotify) for the notifications — optional but recommended
- hyprbars.so for the titlebar buttons — optional; the dock itself works without it (see `docs/build-hyprbars.md`)

## Install

```bash
git clone https://github.com/gdeyoung/omarchy-appdock.git
cd omarchy-appdock
./install.sh
omarchy restart shell
```

The installer:
1. Copies the dock widget to `~/.config/omarchy/plugins/gdeyoung.appdock/`
2. Installs `omarchy-minimize-window.sh` / `omarchy-restore-window.sh` to `~/.local/bin/`
3. Installs `~/.config/hypr/appdock.lua` (titlebars + buttons) and adds `require("hypr.appdock")` to your hyprland config
4. Enables the widget and places it after the workspace numbers
5. Prints keybinding hints (Super+Minus minimize / Super+0 restore)

Non-destructive: existing files are backed up with `.bak.<timestamp>` suffixes.

## How it works

Hyprland 0.56 has no native minimize. AppDock implements the community pattern:

1. **Minimize** = move the window to the hidden `special:minimized` workspace
   (`hl.dsp.window.move({ window = "address:...", workspace = "special:minimized", follow = false })`)
2. A **sidecar** at `$XDG_RUNTIME_DIR/hyprland-minimizer/state.json` records each
   window's origin workspace — that's what makes docks per-workspace
3. **Restore** = move it back with `follow = true`, then focus it
4. The dock widget watches both the compositor's toplevel list (live windows)
   and the sidecar (origins) — everything updates reactively

## Troubleshooting

- **Dock doesn't appear after editing DockWidget.qml** — bar widgets don't
  re-instantiate on hot-reload; run `omarchy restart shell`
- **Icons show letters instead of app icons** — the desktop entry didn't match;
  the widget falls back through class → StartupWMClass → heuristic → PID→exe
- **A minimized window feels "lost"** — click its dimmed icon in the dock, or
  press Super+0; unknown-origin windows appear on every workspace by design

## Files

| Repo file | Installs to |
|---|---|
| `DockWidget.qml` + `manifest.json` | `~/.config/omarchy/plugins/gdeyoung.appdock/` |
| `bin/appdock-minimize` | `~/.local/bin/omarchy-minimize-window.sh` |
| `bin/appdock-restore` | `~/.local/bin/omarchy-restore-window.sh` |
| `hypr/appdock.lua` | `~/.config/hypr/appdock.lua` |
| `docs/build-hyprbars.md` | (reference only) |

## License

MIT
