# Omarchy AppDock

A KDE-style task manager and minimize system for [Omarchy](https://omarchy.org/) (Hyprland 0.56.x). Minimized windows stay visible in the dock — one click brings them back. One part of a complete desktop experience — see [Companion plugins](#companion-plugins).

## What you get

- **App Dock in the bar's left section** (after the workspace numbers): one icon per window on the current workspace, with real app icons
- **Click the focused app → minimizes to the dock** (icon dims, dot indicator appears)
- **Click a minimized icon → restores** it to the workspace you're on
- **Per-workspace docks**: minimized windows only appear on the workspace they came from
- **Native titlebars on floating windows** (close X / minimize _ / maximize □) via hyprbars, wired to the same engine
- Middle-click a dock icon to close; hover for app name + title

## Companion plugins

AppDock is one leg of a three-plugin desktop. Floating Mode handles floating windows, the Window Switcher handles keyboard cycling, AppDock handles the task manager and minimize:

- [**Floating Window Mode**](https://github.com/jwm3000/omarchy-windows) (jwm3000) — floating windows + aero-snap
- [**Window Switcher**](https://github.com/devmobasa/omarchy-window-switcher) (devmobasa) — MRU window list for Alt+Tab. **Recommended companion:** it shows AppDock-minimized windows, which native Hyprland `cycle_next` cannot see
- [**hyprbars**](https://github.com/hyprwm/hyprbars) (optional) — native titlebar close/minimize/maximize buttons wired to the same engine; see `docs/build-hyprbars.md`

## Requirements

- Omarchy 4.x with Hyprland 0.56.x
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

## Uninstall

```bash
omarchy plugin disable gdeyoung.appdock
# Remove the dock from the bar layout: edit ~/.config/omarchy/shell.json
# and delete "gdeyoung.appdock" from the left-section array
rm -rf ~/.config/omarchy/plugins/gdeyoung.appdock
rm -f ~/.local/bin/omarchy-minimize-window.sh ~/.local/bin/omarchy-restore-window.sh
rm -f ~/.config/hypr/appdock.lua
# Remove the AppDock line from ~/.config/hypr/hyprland.lua:
#   require("hypr.appdock")
# If you added the Super+Minus / Super+0 binds to ~/.config/hypr/bindings.lua, remove those too.
omarchy restart shell
```

Backups made by the installer (`*.bak.<timestamp>`) can be restored over the live files, or simply deleted.

## License

MIT — see [LICENSE](LICENSE).
