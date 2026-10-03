-- gdeyoung.appdock: keyboard minimize/restore, wired to the AppDock engine.
--
-- Installed (and removed) by the plugin's install.sh, which COPIES this file
-- into ~/.local/state/omarchy/toggles/hypr/. Omarchy's toggle loader
-- (default/hypr/toggles.lua) sources every *.lua there on each Hyprland
-- reload — it uses find -type f, which skips symlinks, so a symlink would
-- silently never load.
--
-- The engine scripts exist at different paths depending on how the plugin
-- was installed: install.sh mirrors them to ~/.local/bin, a plain
-- `omarchy plugin add` clone ships them in bin/ inside the plugin dir.
-- Both are resolved at load time; neither is hardcoded to a username.

local home = os.getenv("HOME") or ""
local plugin_bin = home .. "/.config/omarchy/plugins/gdeyoung.appdock/bin"

local function script(name, mirrored)
  local mirror = home .. "/.local/bin/" .. mirrored
  local f = io.open(mirror, "r")
  if f then
    f:close()
    return mirror
  end
  return plugin_bin .. "/" .. name
end

local minimize_cmd = script("appdock-minimize", "omarchy-minimize-window.sh")
local restore_cmd = script("appdock-restore", "omarchy-restore-window.sh")

hl.bind("SUPER + MINUS", hl.dsp.exec_cmd(minimize_cmd), {
  description = "Minimize window to the dock",
})

hl.bind("SUPER + 0", hl.dsp.exec_cmd(restore_cmd), {
  description = "Restore last minimized window",
})
