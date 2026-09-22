# Omarchy AppDock

The task manager and **true minimize/restore system** for [Omarchy](https://omarchy.org/) (Hyprland 0.56.x). Minimized windows stay visible in the dock — one click brings them back. One part of a complete desktop experience — see [Why AppDock](#why-appdock) and [Companion plugins](#companion-plugins).

## What you get

- **App Dock in the bar's left section** (after the workspace numbers): one icon per window on the current workspace, with real app icons
- **Click the focused app → minimizes to the dock** (icon dims, dot indicator appears)
- **Click a minimized icon → restores** it to the workspace you're on
- **Per-workspace docks**: minimized windows only appear on the workspace they came from
- **Native titlebars on floating windows** (close X / minimize _ / maximize □) via hyprbars, wired to the same engine
- Middle-click a dock icon to close; hover for app name + title

## Why AppDock

Omarchy's opinion is a tiling, keyboard-first desktop — which is why Hyprland 0.56 ships with no minimize at all. AppDock brings the familiar task-manager model back **without fighting that opinion**:

- **Real minimize, not just indicators.** Windows move to a hidden `special:minimized` workspace; a sidecar remembers each window's origin workspace, so docks are per-workspace and restore is one click. Launcher docks and workspace overviews show you what's running — none of them can minimize a window and bring it back.
- **A task manager, not a launcher.** Launcher docks (Animated Dock, OmaPanel) magnify and launch pinned apps. AppDock mirrors your actual windows: click the focused app to minimize it, click a dimmed icon to restore, middle-click to close.
- **Keyboard flow stays first-class.** Super+Minus / Super+0 drive the same engine, and devmobasa's Window Switcher covers Alt+Tab for minimized windows (native `cycle_next` can't see them).
- **Optional titlebar buttons.** With hyprbars, floating windows get close/minimize/maximize wired to the same minimize engine — not just a hover close button.

## Companion plugins — the full desktop experience

AppDock is one leg of a three-plugin desktop. Each plugin owns one layer — no overlap, no duplicated keybinds — and the switcher and titlebars ride on AppDock's minimize engine:

- [**Floating Window Mode**](https://github.com/jwm3000/omarchy-windows) (jwm3000) — **the floating layer**: float windows freely, aero-snap them to screen edges
- [**Window Switcher**](https://github.com/devmobasa/omarchy-window-switcher) (devmobasa) — **the keyboard layer**: MRU Alt+Tab list that includes minimized windows, which native `cycle_next` cannot see
- [**AppDock**](https://github.com/gdeyoung/omarchy-appdock) — **the task-manager layer**: dock icons, minimize/restore, titlebar buttons
- [**hyprbars**](https://github.com/hyprwm/hyprland-plugins/tree/main/hyprbars) (optional) — native titlebar close/minimize/maximize buttons wired to the same engine; see `docs/build-hyprbars.md`

Install all three and Omarchy behaves like a conventional desktop when you reach for the mouse, and a tiling WM when you stay on the keyboard.

## Requirements

- Omarchy 4.x with Hyprland 0.56.x
- hyprbars.so for the titlebar buttons — optional; the dock itself works without it (see `docs/build-hyprbars.md`)

## Install

Install a **pinned release** (recommended — you get an immutable snapshot and can review every file before anything runs):

```bash
curl -fsSL https://github.com/gdeyoung/omarchy-appdock/archive/refs/tags/v0.2.0.tar.gz | tar xz -C /tmp
less /tmp/omarchy-appdock-0.2.0/install.sh   # review before running — it's your machine
/tmp/omarchy-appdock-0.2.0/install.sh
omarchy restart shell
```

Or from a pinned tag with git:

```bash
git clone --depth 1 --branch v0.2.0 https://github.com/gdeyoung/omarchy-appdock.git
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

Non-destructive: existing files are backed up with `.bak.<timestamp>` suffixes. Refuses to run as root; never needs sudo.

## Security

Runtime state (origin workspaces, window thumbnails) lives only in `$XDG_RUNTIME_DIR/hyprland-minimizer/` — an owner-only directory (`0700`, files `0600`) that systemd wipes at logout. Nothing is written to `/tmp`, and no privileged operation ever trusts shared temp state.

The minimize/restore scripts pass all data into Python as argv — window titles and addresses are never interpolated into source code — and they never need root. The installer writes only inside `$HOME` (scope documented in its header) and never modifies sudoers or system units.

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
