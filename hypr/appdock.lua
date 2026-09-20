-- AppDock hyprbars integration for Omarchy / Hyprland 0.56
--
-- Provides: native titlebars (close X / minimize _ / maximize □) on floating
-- windows, wired to the AppDock minimize engine. The minimize button calls
-- the companion script so the sidecar (origin workspace) is recorded —
-- DO NOT inline a hyprctl dispatch with an "address:" placeholder here;
-- hyprbars does not substitute it and the click fails silently.
--
-- Requires (install via the repo's install.sh):
--   ~/.local/share/hyprland/plugins/hyprbars.so        (titlebars)
--   ~/.local/share/omarchy-floating-mode/snap.so       (aero snap, optional)
--
-- Load AFTER Omarchy's defaults (add to ~/.config/hypr/hyprland.lua):
--   require("hypr.appdock")

local home = os.getenv("HOME") or "/home/guest"

-- hyprbars: native titlebars with buttons
hl.plugin.load(home .. "/.local/share/hyprland/plugins/hyprbars.so")

hl.config({
  plugin = {
    hyprbars = {
      enabled = true,
      bar_color = "rgba(333333c0)",
      bar_height = 30,
      bar_title_enabled = true,
      bar_text_size = 14,
      bar_text_weight = 600,
      bar_text_font = "Sans",
      bar_text_align = "left",
      bar_buttons_alignment = "right",
      bar_part_of_window = true,
      bar_precedence_over_border = true,
      bar_padding = 8,
      bar_button_padding = 6,
      icon_on_hover = false,
    },
  },
})

-- Buttons declared right-to-left: close, then minimize, then maximize.
-- Minimize MUST call the script (writes sidecar + notification).
hl.plugin.hyprbars.add_button({
  bg_color = "rgba(00000000)",
  fg_color = "rgba(ffffffff)",
  size = 21,
  icon = "X",
  action = [[hyprctl dispatch 'hl.dsp.window.close({})']],
})

hl.plugin.hyprbars.add_button({
  bg_color = "rgba(00000000)",
  fg_color = "rgba(ffffffff)",
  size = 21,
  icon = "_",
  action = [[]] .. home .. [[/.local/bin/omarchy-minimize-window.sh]],
})

hl.plugin.hyprbars.add_button({
  bg_color = "rgba(00000000)",
  fg_color = "rgba(ffffffff)",
  size = 21,
  icon = "□",
  action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
})

-- A maximized floating window fills the work area; drop its border.
hl.window_rule({
  name = "appdock-maximized-no-border",
  match = {
    float = true,
    fullscreen_state_internal = 1,
  },
  border_size = 0,
})
