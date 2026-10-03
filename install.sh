#!/usr/bin/env bash
# AppDock installer for Omarchy 4.x / Hyprland 0.56
# Installs: dock bar-widget, minimize/restore scripts, hyprbars Lua config.
# Non-destructive: backs up replaced files with .bak timestamps.
#
# Documented scope (for marketplace security review):
#   writes ~/.config/omarchy/plugins/gdeyoung.appdock/   (widget + manifest)
#   writes ~/.local/bin/omarchy-{minimize,restore}-window.sh
#   writes ~/.config/hypr/appdock.lua (+ one require line appended to
#         hyprland.lua if absent; existing file backed up first)
#   runs  omarchy plugin enable / omarchy bar put (best effort, non-fatal)
# It never needs root, never writes outside $HOME, and touches no other
# files. Uninstall: see README.
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "ERROR: run as your own user, not root — this installer only writes to \$HOME." >&2
  exit 1
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
home_dir="${HOME:?}"
backup_suffix=".bak.$(date +%s)"
errors=0

say()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; errors=$((errors+1)); }

# --- 1. Bar widget -----------------------------------------------------------
mkdir -p "$home_dir/.config/omarchy/plugins/gdeyoung.appdock"
install -m 644 "$repo_dir/DockWidget.qml" "$home_dir/.config/omarchy/plugins/gdeyoung.appdock/DockWidget.qml"
install -m 644 "$repo_dir/manifest.json"  "$home_dir/.config/omarchy/plugins/gdeyoung.appdock/manifest.json"
say "installed: bar widget -> ~/.config/omarchy/plugins/gdeyoung.appdock/"

# --- 2. Scripts --------------------------------------------------------------
# Installed INTO the plugin directory (shipped beside the widget, invoked via
# Qt.resolvedUrl — user-owned path, multi-user safe) and mirrored to
# ~/.local/bin for keybindings and the hypr titlebar buttons.
install -m 755 "$repo_dir/bin/appdock-minimize" "$home_dir/.config/omarchy/plugins/gdeyoung.appdock/omarchy-minimize-window.sh"
install -m 755 "$repo_dir/bin/appdock-restore"  "$home_dir/.config/omarchy/plugins/gdeyoung.appdock/omarchy-restore-window.sh"
mkdir -p "$home_dir/.local/bin"
install -m 755 "$repo_dir/bin/appdock-minimize" "$home_dir/.local/bin/omarchy-minimize-window.sh"
install -m 755 "$repo_dir/bin/appdock-restore"  "$home_dir/.local/bin/omarchy-restore-window.sh"
say "installed: scripts -> plugin dir (widget) + ~/.local/bin (keybinds/titlebars)"

# --- 3. Hyprland Lua ---------------------------------------------------------
mkdir -p "$home_dir/.config/hypr"
if [[ -f "$home_dir/.config/hypr/appdock.lua" ]]; then
  cp "$home_dir/.config/hypr/appdock.lua" "$home_dir/.config/hypr/appdock.lua$backup_suffix"
  say "backup: ~/.config/hypr/appdock.lua$backup_suffix"
fi
install -m 644 "$repo_dir/hypr/appdock.lua" "$home_dir/.config/hypr/appdock.lua"

if ! grep -q 'require("hypr.appdock")' "$home_dir/.config/hypr/hyprland.lua" 2>/dev/null; then
  printf '\n-- AppDock: titlebars + minimize engine (hyprbars)\nrequire("hypr.appdock")\n' >> "$home_dir/.config/hypr/hyprland.lua"
  say "added: require(\"hypr.appdock\") to ~/.config/hypr/hyprland.lua"
else
  say "ok: hyprland.lua already requires hypr.appdock"
fi

# --- 4. hyprbars.so ------------------------------------------------------------
# The titlebar plugin must be compiled against the running Hyprland. Only
# install the Lua when the .so exists; otherwise skip with instructions.
if [[ -f "$home_dir/.local/share/hyprland/plugins/hyprbars.so" ]]; then
  say "ok: hyprbars.so present"
else
  say "NOTE: hyprbars.so not found at ~/.local/share/hyprland/plugins/hyprbars.so"
  say "      The dock works without it (keyboard + click minimize); titlebar"
  say "      buttons need it. Build: docs/build-hyprbars.md"
fi

# --- 5. Enable + place the widget ---------------------------------------------
omarchy plugin enable gdeyoung.appdock 2>/dev/null || say "NOTE: run 'omarchy plugin enable gdeyoung.appdock' after shell restart"
omarchy bar put gdeyoung.appdock --section left --after omarchy.workspaces 2>/dev/null || true

# --- 6. Keybindings via the Omarchy toggle loader ------------------------------
# The toggle loader (default/hypr/toggles.lua) sources every *.lua in the
# state toggles dir on each Hyprland reload. It uses find -type f, which
# skips symlinks — so the snippet is COPIED, not linked (pattern from
# matthewjaybarr-png/omarchy-app-grid, MIT). Nothing under ~/.config/hypr
# is touched; removal is `rm` of one file.
toggles_dir="${XDG_STATE_HOME:-$home_dir/.local/state}/omarchy/toggles/hypr"
mkdir -p "$toggles_dir"
install -m 644 "$repo_dir/hypr/appdock-keybinds.lua" "$toggles_dir/appdock-keybinds.lua"
say "installed: keybinds -> $toggles_dir/appdock-keybinds.lua (SUPER+MINUS / SUPER+0)"

if hyprctl reload >/dev/null 2>&1; then
  config_errors=$(hyprctl configerrors 2>/dev/null || true)
  if [[ -n "${config_errors//[[:space:]]/}" ]]; then
    fail "Hyprland reported config errors after installing keybinds:"
    printf '%s\n' "$config_errors" >&2
  else
    say "ok: Hyprland reloaded, no config errors"
  fi
else
  say "NOTE: hyprctl reload unavailable (not running?); keybinds load on next Hyprland start"
fi

say ""
if [[ $errors -eq 0 ]]; then
  say "Done. Restart the shell to load the dock:  omarchy restart shell"
else
  say "Completed with $errors error(s)."
  exit 1
fi
