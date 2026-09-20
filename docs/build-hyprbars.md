# Building hyprbars.so for Hyprland 0.56.x

The titlebar buttons need `hyprbars.so` compiled against the **running**
Hyprland version. Verified working on Hyprland 0.56.2 (Omarchy 4.0.4):

```bash
# Prereqs (all present on Omarchy): cmake, g++, git, hyprland headers
sudo pacman -S cmake --needed   # if missing

cd /tmp
git clone --depth 1 https://github.com/hyprwm/hyprland-plugins
cd hyprland-plugins
git checkout --detach 7644cecdb947060682891a0db2a0cdc5c0b9e704   # tested commit

cd hyprbars
cmake .
make -j$(nproc)

mkdir -p ~/.local/share/hyprland/plugins
cp hyprbars.so ~/.local/share/hyprland/plugins/   # build output name may be libhyprbars.so — rename if needed
hyprctl reload && hyprctl configerrors   # must be empty
```

Notes:
- Build warnings (narrowing, deprecated API) are normal.
- After a Hyprland update, rebuild: the headers must match the running version.
- Verify buttons: open a floating window (Super+T), click `_` — the window
  should minimize and appear (dimmed, with dot) in the dock.
- `decorations: {}` in `hyprctl clients -j` is always empty for hyprbars —
  it renders via its own pass; visual check is the only reliable test.
