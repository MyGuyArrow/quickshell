---
version: 1
slug: "shell-qml"
primary_target: "shell.qml"
related_targets: ["Calendar.qml"]
---

# Surface: Dynamic Island control centre (shell.qml)

Scope: all three islands, collapsed and expanded — the media dot and its panel, the centre pill and its time/calendar/keep-awake panel, the right dot and the hardware panel behind it (home grid plus seven sub-pages). Mode: Operate. The OSD capsule stays as built.

Audience and job: Arjun at the keyboard, mid-task, glancing or flipping one system setting in under two seconds. Constraints: single monitor, Quickshell 0.3.1 QML, blur only via Hyprland layer rule, theme palette read at runtime from colors.toml (light or dark), SF Pro Text and JetBrainsMono Nerd Font (Material glyph range) are the only faces.

Confirmed answers (2026-09-08): Tahoe Liquid Glass following the Omarchy theme's light/dark; power actions live in a Battery module; the collapsed pill stays a black Dynamic Island.

Confirmed answers (2026-09-12, three-island restructure, with a reference image): workspace dots AND tray icons both stay in the centre pill; the media dot stays on screen as a dim placeholder when nothing is playing, so the row never moves; the right dot shows a battery ring around a signal glyph.

## Direction contract

THESIS: Not one island but three, tinted by whatever Omarchy theme is active, each growing in place into its own glass panel. The row is split by what the machine is doing, not by what it is made of: what is playing on the left, what time it is in the middle, what the hardware is up to on the right. It refuses the header-with-buttons dashboard: no title bar, no floating power glyph; every control is a module in the grid and state lives in the icon circle, not in a filled tile. On a collapsed dot, state lives in the ring around it.

OWN-WORLD: Frosted glass panel (theme background at ~0.62 alpha, Hyprland blur, hairline edge, 1px specular top highlight, soft shadow), 28px outer radius, 20px module radius. Modules are lighter glass; toggles are 30px circles that fill with the theme accent when on. Thick 30px capsule sliders with the glyph riding inside the white fill. SF Pro Text 13/600 labels, 11 secondary subs. Material glyphs only.

STORY: He taps the pill, sees the machine's state in one grid, flips a circle or drags a capsule, and it closes behind him.

FIRST VIEWPORT: three black shapes 10px apart, 40px tall. Hover the right dot for the 360px hardware panel. Row 1: tall Wi‑Fi/Bluetooth tile left; right column Fans tile over two squares (Keyboard LEDs, Display). Then Display, Sound, Keyboard sliders full width; Now Playing when active; bottom row Battery (power actions behind its chevron) and Calendar (date, opens month grid). Primary actions are the circles.

FORM: brief-pinned macOS Tahoe Liquid Glass control centre, executed as canon at full fidelity; seed key f50459ad (assigned index 4 overridden by the pinned brief; its topology of fixed cells that never move, only change state, is kept).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

Finish review 2026-09-12 (three-island restructure), disposition FIX, all acted on: the row was recentred so a growing side panel no longer shoves the clock sideways (measured, drift now under 1px in every state); the calendar's `today` was frozen at process start and is now injected from the island's clock; the month grid drew a dead sixth row; out-of-month days were dimmed twice; secondary text moved 10px→11px; the hover delay went 60ms→180ms now that one timer guards three targets across the top edge. Struck rather than built: the island shadow DESIGN.md had claimed since 2026-09-08 and which never existed in any version of the file. Cited rather than changed: the two-step type hierarchy, and radius following element height.
