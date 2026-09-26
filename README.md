# quickshell island

A Dynamic Island for [Quickshell](https://quickshell.org) on Hyprland ([Omarchy](https://omarchy.org)). It replaces the Omarchy bar, OSD and panels.

Three shapes sit at the top of the screen:

- **Left dot: media.** Hover to open the player.
- **Centre pill: workspaces, clock, tray.** Hover for a bigger time, the month calendar, weather and a keep-awake switch. The second page holds notifications and do-not-disturb.
- **Right dot: battery and connectivity.** Hover for Wi‑Fi, Bluetooth, audio devices, screen and keyboard brightness, fan profile, lid LEDs, refresh rate, dGPU power and power actions.

When a panel opens it turns into macOS Tahoe-style glass. Its colours come from the active Omarchy theme (`~/.local/state/omarchy/current/theme/colors.toml`), in both light and dark mode.

## Install

```sh
git clone https://github.com/MyGuyArrow/quickshell ~/.config/quickshell
quickshell
```

It needs Quickshell 0.3+, SF Pro Text and JetBrainsMono Nerd Font.

The controls call ordinary command-line tools: `nmcli`, `brightnessctl` and `powerprofilesctl`. Some controls are specific to the ASUS ROG Zephyrus G16 and hide or do nothing on other machines: `asusctl` for the Slash LEDs, `/usr/local/bin/dgpu`, and the `fanstat` / `refresh-rate` helpers.

Weather comes from wttr.in. To add extra places, list them one per line in `weather-places`.

## Notifications

The island owns `org.freedesktop.Notifications`, so turn off Omarchy's plugin by adding `omarchy.notifications` to `disabledPlugins`. To drive the OSD from rebound keys, call it over IPC:

```sh
qs ipc call island osd …
```

## Files

| | |
|---|---|
| `shell.qml` | the island |
| `Calendar.qml`, `RoundedImage.qml` | components |
| `PRODUCT.md`, `DESIGN.md` | what it is for and the design system |
| `test-island.py` | end-to-end checks against the running island |

## Credits

Built by [MyGuyArrow](https://github.com/MyGuyArrow) with [Claude Code](https://claude.com/claude-code) as collaborator.
