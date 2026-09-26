# Product

<!-- impeccable:product-schema 1 -->

## Platform

linux-desktop (Quickshell / QML layer-shell surface on Hyprland; not one of the schema's web/ios/android/adaptive values)

## Users

One user: Arjun, on his ASUS ROG Zephyrus G16 running Omarchy (Arch + Hyprland). He is at the keyboard, usually mid-task, and reaches for the island to glance at status or flip a system setting in under two seconds, then go back to work.

## Product Purpose

Three top-of-screen surfaces that replace the Omarchy bar, OSD and panels. Collapsed they are a media dot, a Dynamic Island pill (workspaces, clock, tray) and a dot fusing battery with connectivity. Each grows on hover into its own panel: the player on the left, the time with the month, the weather and the keep-awake switch in the middle, and the machine's hardware on the right — Wi‑Fi, Bluetooth, audio devices, screen and keyboard brightness, fan profile, lid LEDs, refresh rate, dGPU power and power actions. Success is that nothing he used to reach through the bar needs another window.

## Positioning

The one place on this machine where ASUS-specific hardware controls (fan profiles, Slash lid LEDs, dGPU runtime power, 60/240 Hz) sit beside the ordinary system toggles, in one grammar, inside the island itself.

## Operating Context

- Hyprland with a macOS-style look already pinned: blur, rounding, hairline borders, SF Pro Text for shell surfaces (`~/.config/hypr/looknfeel.lua`, `~/.config/omarchy/shell.toml`).
- The active Omarchy theme supplies the palette at runtime from `~/.local/state/omarchy/current/theme/colors.toml` (`mode = light|dark`, `accent`, foreground/background tiers). Themes change often; the surface must follow.
- Omarchy's own shell keeps running for menu, lock, polkit and idle. The island must not depend on it visually. Notifications moved to the island on 2026-09-12: `omarchy.notifications` is in `disabledPlugins`, because only one process can own `org.freedesktop.Notifications`. Omarchy's five notification keybindings were rebound to the island's IPC the same day (`~/.config/hypr/bindings.lua`), since all five aimed at the disabled plugin.
- Controls run shell commands: `nmcli`, `brightnessctl`, `powerprofilesctl`, `asusctl slash`, `sudo -n /usr/local/bin/dgpu`, the acs.fans `fanstat` and acs.monitor `refresh-rate` helper scripts, `omarchy system …`.
- Weather comes from wttr.in every 15 minutes, fetched through `mullvad-exclude` so the answer is for where the machine is and not for the Mullvad exit relay. The centre panel's header carries a full-height weather card beside the clock; clicking it opens the panel's third page — a three-hourly forecast for the next day, feels-like, humidity and wind, and the list of places. Extra places live in `~/.config/quickshell/weather-places`, one per line. The same call fetches the place's own wall clock, because the forecast slots are stamped in its local time and reading them against this machine's clock silently shows hours that have already passed.

## Capabilities and Constraints

- Quickshell 0.3.1, Qt 6 QML. No web stack, no CSS; blur comes from Hyprland layer rules on the window namespace, not from the shell.
- One `PanelWindow` holding three islands in a centred Row, single monitor for now. The input mask is the union of the three island shapes, so clicks anywhere else pass through; click-outside closes via HyprlandFocusGrab.
- Fonts on the machine: SF Pro Text / SF Pro Display, JetBrainsMono Nerd Font (icon glyphs). Icon glyphs in U+F000–F8FF must be written as `\uXXXX` escapes in QML.
- Brightness OSD is triggered by rebound keys via `qs ipc call island osd …`; volume OSD by Pipewire sink changes.
- The machine is kept awake while media is playing or a Google Meet window is open, by holding the Wayland idle inhibitor on the island's own surface. Chromium here runs under XWayland, so its own inhibit request never reaches Hyprland and the screen locked mid-video.
- Open: multi-monitor untested. Meet is detected by window title, so a call in a background tab is not seen. The inhibitor is held even once the session is locked, so a video left playing keeps the panel lit. Do-not-disturb and history came back to the island on 2026-09-12, as the centre panel's second page opposite the calendar: DND silences everything but Critical, and the last 10 notifications are kept in memory — they survive a config reload, not a restart of the shell. The `omarchy-menu` toggle entry for silencing still calls the disabled plugin and does nothing.

## Brand Commitments

- Binding visual constraint from Arjun (2026-09-08): macOS Tahoe Liquid Glass control centre, following the Omarchy theme's light or dark mode; battery module carries the power actions; the collapsed pill stays a black Dynamic Island.
- Binding structural constraint from Arjun (2026-09-12, with a reference image): three islands, not one. Media is the left dot, battery and connectivity fuse into the right dot and open the hardware page on hover, and the centre keeps the calendar, a bigger time and the keep-awake switch. The hover page header is the time, never the date.

## Evidence on Hand

- Working implementation: `shell.qml`, `Calendar.qml`; originals `shell.qml.skeleton` (Arjun's skeleton) and `shell.qml.pre-pages`.
- Real device data available at runtime (network list, paired devices, sinks, fan rpm, Slash config, monitor modes). Nothing needs to be invented.

## Product Principles

- Glanceable first: the three collapsed shapes answer time, battery, connectivity, workspace and playback without opening anything.
- One grammar for every control, ASUS-specific or not.
- Follow the theme, never fight it.
- Reuse the working helper scripts; the island is UI, not a second daemon.
- Keep click-through outside the island; it must never trap the desktop.
