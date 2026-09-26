---
name: acs island
description: Black Dynamic Island that grows into a Tahoe-glass control centre coloured entirely by the active Omarchy theme.
colors:
  accent: "#7aa2f7"
  accent-text: "#1a1b26"
  theme-bg: "#1a1b26"
  glass: "rgba(26, 27, 38, 0.62)"
  edge: "rgba(192, 202, 245, 0.16)"
  specular: "rgba(192, 202, 245, 0.30)"
  tile: "rgba(36, 40, 59, 0.62)"
  tile-hover: "rgba(36, 40, 59, 0.92)"
  circle-off: "rgba(65, 72, 104, 0.95)"
  track: "rgba(65, 72, 104, 0.85)"
  text1: "#c0caf5"
  text2: "#565f89"
  pill: "#050505"
  pill-text: "#f5f5f7"
  pill-dim: "#8e8e93"
  danger: "#f7768e"
  shadow: "rgba(0, 0, 0, 0.09)"
typography:
  title:
    fontFamily: "SF Pro Text"
    fontSize: "15px"
    fontWeight: 700
  headline:
    fontFamily: "SF Pro Text"
    fontSize: "13px"
    fontWeight: 600
  label:
    fontFamily: "SF Pro Text"
    fontSize: "12px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro Text"
    fontSize: "11px"
    fontWeight: 400
  sub:
    fontFamily: "SF Pro Text"
    fontSize: "11px"
    fontWeight: 400
  caption:
    fontFamily: "SF Pro Text"
    fontSize: "10px"
    fontWeight: 400
  section:
    fontFamily: "SF Pro Text"
    fontSize: "10px"
    fontWeight: 600
    letterSpacing: "0.8px"
  glyph:
    fontFamily: "JetBrainsMono Nerd Font"
    fontSize: "16px"
    fontWeight: 400
rounded:
  art: "10px"
  row: "14px"
  module: "20px"
  panel: "28px"
  capsule: "50%"
spacing:
  hair: "1px"
  xs: "2px"
  sm: "6px"
  md: "10px"
  lg: "12px"
  panel: "14px"
components:
  module:
    backgroundColor: "{colors.tile}"
    rounded: "{rounded.module}"
    padding: "10px"
  module-hover:
    backgroundColor: "{colors.tile-hover}"
  row:
    backgroundColor: "{colors.tile}"
    rounded: "{rounded.row}"
    padding: "0 12px 0 10px"
    height: "40px"
  circle-off:
    backgroundColor: "{colors.circle-off}"
    textColor: "{colors.text1}"
    rounded: "{rounded.capsule}"
    size: "30px"
  circle-on:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-text}"
    rounded: "{rounded.capsule}"
    size: "30px"
  capsule-slider:
    backgroundColor: "{colors.track}"
    rounded: "{rounded.capsule}"
    height: "30px"
  capsule-slider-fill:
    backgroundColor: "{colors.text1}"
    textColor: "{colors.theme-bg}"
    rounded: "{rounded.capsule}"
    height: "30px"
  chip:
    backgroundColor: "{colors.tile}"
    textColor: "{colors.text1}"
    typography: "{typography.body}"
    rounded: "{rounded.capsule}"
    height: "28px"
    padding: "0 11px"
  chip-selected:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-text}"
  pill:
    backgroundColor: "{colors.pill}"
    textColor: "{colors.pill-text}"
    rounded: "{rounded.capsule}"
    height: "40px"
    padding: "0 15px"
  section-label:
    textColor: "{colors.text2}"
    typography: "{typography.section}"
---

# Design System: acs island

Native Quickshell 0.3.1 / Qt 6 QML surface on Hyprland. There is no CSS. Every token below is a property on the root `PanelWindow` in `shell.qml` (`root.glass`, `root.tile`, `root.ic.wifi`, ...) and every component is an inline `component` in the same file. Colour values in the frontmatter are the fallback literals in `shell.qml` (Tokyo Night); at runtime every one of them is replaced by the active Omarchy theme, so treat the frontmatter as the formula's worked example, not a palette. Where a value here disagrees with `shell.qml`, `shell.qml` wins.

## Overview

**Creative North Star: "Three Islands That Grow Into Glass"**

At rest the surface is three black shapes in a centred row, 10px apart: a 40px dot for whatever is playing, a 40px pill holding workspace dots, the clock and the tray, and a 40px dot on the right where charge and connectivity are fused into one mark. Each one grows in place into its own glass panel when the cursor rests on it, and the two that stay collapsed stay on screen, so the cursor can walk the row without closing anything on the way. OSD and now-playing stay black and capsule-shaped; only the control centre changes material, becoming a 360px sheet of frosted theme-tinted glass with a 28px corner, a hairline edge, a one-pixel specular top highlight and a soft stacked shadow. Blur is not the shell's job: Hyprland blurs the `acs-island` layer namespace (`looknfeel.lua`, `ignore_alpha = 0.3`), so glass is simply the theme background at 0.62 alpha and the compositor does the rest.

The palette is not owned by the shell. Every glass colour is one of the Omarchy theme's `colors.toml` keys, read at runtime, optionally at a fixed alpha: `background` is the glass, `lighter_background` the tiles, `foreground` the text and the hairlines, `bright_foreground` at 0.66 the secondary text (the theme's own `dark_foreground` measured 2.9:1 on the glass and failed), `muted` the resting circles and slider tracks, `red` the danger colour, `accent` the one state colour. The shell hard-codes no hue at all for the control centre; only the panel glass alpha still knows about dark versus light mode. There is no title bar and no floating action glyph: the control centre is a grid of glass modules, and state lives in a 30px icon circle that fills with the accent when on, never in a filled tile. Sliders are thick 30px capsules whose glyph rides inside a fill of the theme foreground.

One text face (SF Pro Text) and one glyph face (JetBrainsMono Nerd Font, Material Design range) carry the whole surface. Density is macOS Control Center density: 10px gaps between modules, 10px padding inside them, 12/600 labels over 10/400 subs.

**Key Characteristics:**
- Black opaque pill at rest; glass only when the control centre is open.
- Palette taken wholesale from the Omarchy theme (`accent`, background tiers, foreground tiers, `muted`, `red`); the shell owns only alphas and the pill greys.
- State is shown in the icon circle (accent fill), never by tinting the tile.
- Glyphs are Material codepoints from the Nerd Font, written as `\u{...}` escapes in the `root.ic` map and centred on their ink, not their advance box.
- One motion grammar: 240ms OutCubic for the island's size, 160ms colour, 120ms press scale.

## Colors

A theme-owned palette: the control centre is the Omarchy theme's own background, foreground and muted tiers layered at fixed alphas, with the theme accent as the only state colour.

### Primary
- **Theme Accent** (`root.accent`, `colors.toml` `accent`): fills a Circle when its control is on, fills a selected Chip, the focused workspace dot, today's date, calendar chevrons, the pill's now-playing note and the pill's battery percentage while charging. It is the only saturated colour the shell draws besides `danger`.
- **Accent Text** (`root.accentText`): computed, the theme `background` when the accent's luma is above 0.6, otherwise the theme foreground. Used for anything drawn on top of an accent fill (circle glyph, selected chip label, today's date). On the current green-on-navy theme it resolves to the navy background.

### Neutral
- **Theme Background** (`root.themeBg`, `background`): the glyph riding inside a Capsule's fill, and the dark branch of `accentText`. Also the base of `glass`.
- **Glass** (`root.glass`): `background` at 0.62 alpha (0.72 in light mode). The control centre's own fill; the compositor blur makes it frosted. This is the only token that still reads `root.dark`.
- **Edge** (`root.edge`): foreground at 0.16. 1px border of the panel, of PageHeader's back circle and of unselected Chips; Modules use it at 0.7x alpha.
- **Specular** (`root.specular`): foreground at 0.30. The 1px horizontal gradient highlight across the top of the panel (full strength) and of every Module (0.6x, inset by the module radius).
- **Tile** / **Tile Hover** (`root.tile`, `root.tileHover`): `lighter_background` at 0.62 / 0.92. Every Module, Row_, Chip and the password field.
- **Circle Off** (`root.circleOff`): `muted` at 0.95. Resting state of a Circle, the play/pause button, and the Art placeholder.
- **Track** (`root.track`): `muted` at 0.85. The unfilled part of a Capsule.
- **Text 1** (`root.text1`): `bright_foreground`, falling back to `foreground`. Labels, titles, glyphs at rest, and the Capsule's filled portion.
- **Text 2** (`root.text2`): `dark_foreground`, falling back to `muted`. Subs, trailing values, section labels, disabled transport glyphs, and the Capsule fill when muted.
- **Pill** (`#050505`), **Pill Text** (`#f5f5f7`), **Pill Dim** (`#8e8e93`): the collapsed island, OSD capsule and media notify. Theme-independent; the pill is black under a light theme too.
- **Danger** (`root.danger`, `red`): urgent workspace dot and the pill's battery percentage below 20%.

Theme fallbacks in `applyTheme()`: `lighter_background` → `background`; `bright_foreground` → `foreground`; `dark_foreground` → `muted`; `muted` → `selection`. The file is watched, re-read by `qs ipc call island theme` from `~/.config/omarchy/hooks/theme-set.d/island-recolour`, and re-read every time the control centre opens, because the watch goes quiet when Omarchy swaps the theme directory.

### Named Rules
**The Borrowed Palette Rule.** The shell never hard-codes a hue for glass surfaces. Every control-centre colour is a `colors.toml` key, optionally through `a(colour, alpha)`. A new token is a new theme key or a new alpha on an existing one, never a new hex; the literals on the root are fallbacks for before the file loads.

**The Circle Carries State Rule.** On/off is shown by the icon circle filling with `accent`. A Module's background never changes with state, only with hover.

**The Black Pill Rule.** The collapsed pill, the OSD capsule, the media notify and the notification are `pill` black with `pillText` / `pillDim` type regardless of theme. Glass begins only when `root.control` is true. The theme reaches the pill only through `accent` (focused workspace, charging battery, playing note) and `danger` (urgent workspace, low battery).

## Typography

**Body Font:** SF Pro Text (no fallback declared; the machine ships it)
**Glyph Font:** JetBrainsMono Nerd Font, Material Design codepoints (`U+F0000` range) via the `root.ic` map

**Character:** macOS system-text hierarchy compressed for a 360px panel: DemiBold labels over regular subs, one Bold weight reserved for page titles. Tracking is default everywhere except the section label.

**The Two Type Sizes Rule.** A control names itself at one of two steps and never a third. **13/600 over 11/400** in the primary tile (`ToggleRow` — Wi‑Fi, Bluetooth, Sound, Fans), because that tile is the first thing read in the hardware panel. **12/600 over 11/400** everywhere else: `SquareTile`, `SliderTile`, `Row_`, and the media panel's identity and timestamps. The subs were 10px until 2026-09-12; a finish review called the step out as one size below everything it sits beside, and 10px at 0.66 alpha gave back what the contrast pass had just won.

### Hierarchy
- **Title** (700, 15px): PageHeader title beside the back circle ("Battery", "Wi‑Fi").
- **Headline** (600, 13px): ToggleRow label, control-centre now-playing title, calendar month, OSD percentage. Pill clock and media-notify title use 600 at 14px.
- **Label** (600, 12px): SquareTile, Row_ and SliderTile labels. This is the most common text on the surface.
- **Body** (400, 11px): ToggleRow subs, now-playing artist, slider trailing values. Chips use 11px at 600. Pill battery, notify artist and the Wi‑Fi password field use 400 at 12px.
- **Caption** (400, 10px): SquareTile and Row_ subs, calendar day numbers at 11px.
- **Section** (600, 10px, +0.8px tracking, uppercase): grouped-list headers inside pages ("POWER", "DEVICES", "OUTPUT"). Calendar weekday initials share the size and weight without tracking.
- **Glyph** (16px base): 15px inside a Circle, in a Capsule and for chevrons/check, 17px on play/pause, 18px calendar chevrons, 20px on prev/next and the Art placeholder, 13px for the pill's note.

### Named Rules
**The Two-Line Module Rule.** A control names itself with a 12/600 label and, when it has state to report, a 10/400 or 11/400 sub in `text2`. There is no third line.

**The One Bold Rule.** `Font.Bold` appears only on page titles and today's date. Everything else that needs emphasis is DemiBold.

**The Ink-Centred Glyph Rule.** `Glyph` is an `Item` sized to the glyph's `TextMetrics.tightBoundingRect`, with the inner `Text` offset by the difference between the tight and advance boxes. `anchors.centerIn` therefore centres the visible ink. Never draw a Nerd Font glyph with a bare `Text`.

## Layout

One `PanelWindow` anchored top/left/right, 760px tall, transparent, with the input mask limited to the island so clicks pass through elsewhere. The island is horizontally centred with a 10px top margin and grows in place:

- **Pill:** `idleRow.implicitWidth + 30` wide, 40px tall, 15px side padding, 10px item spacing.
- **OSD:** 330 x 58.
- **Media notify:** 320 x 76, on the LEFT island.
- **Notification:** 460 x 76, on the CENTRE island, same shell as the media notify.
- **Dots:** 40 x 40 each, `radius: height / 2`.
- **Media panel:** 320 wide, height follows `mediaCol.implicitHeight + 28`.
- **Centre panel:** 320 wide, height follows `centreCol.implicitHeight + 28`.
- **Hardware panel:** 360 wide, height follows `hwCol.implicitHeight + 28`; every content column has 14px margins and 10px spacing.

Home is a fixed-cell grid that never reflows: row 1 is a tall ToggleRow module (Wi‑Fi / Bluetooth / Sound) beside a right column of the Fans tile over two SquareTiles (Lid LEDs, Screen); then three full-width SliderTiles (Display, Sound, Keyboard Brightness); Now Playing when a player is active; then Battery and Calendar tiles. Pages replace the grid with a PageHeader followed by Row_ items and Chips grouped under Section labels. Only the section content changes between pages; the panel frame, width and header treatment are constant.

Spacing rhythm as used: 1px (hairlines, label-to-sub in ToggleRow), 2px (tile column, calendar rows), 6px (header row, slider column, chip flow), 10px (module gaps, module padding, row spacing), 12px (slider padding, row right inset, calendar inset), 14px (panel inset).

## Elevation & Depth

Hybrid: the compositor supplies blur, the shell supplies a hairline edge and a specular line. There is no shadow and no Qt shadow effect. Depth inside the panel is tonal only: Modules are `lighter_background` glass on `background` glass, Circles are `muted` on that, and hover raises a Module from `tile` (0.62) to `tileHover` (0.92) by alpha alone.

### Shadow Vocabulary
- **No island shadow.** This document described a stack of four offset rectangles under the island until 2026-09-12, when a finish review found the stack had never existed in any version of `shell.qml`. The claim is struck rather than built: the islands sit on a compositor-blurred ground and the hairline plus the specular line carry their edges. **Known gap:** three small shapes in light mode are light glass on a light wallpaper held by a 0.16 hairline alone. If separation ever fails there, build the stack — do not reach for `MultiEffect`, which would take the surface out of the compositor's blur path.
- **Panel Specular** (1px gradient transparent → `specular` → transparent, inset 1px at the top): visible only when the control centre is open.
- **Module Specular** (same gradient at 0.6x alpha, inset by the module radius so it stops short of the corners).

### Named Rules
**The Compositor Blurs Rule.** Never add blur, `MultiEffect` or `FastBlur` in QML. Frosting comes from the `acs-island` layer rule; the shell only sets alpha.

**The Hairline Rule.** Every glass surface has a 1px `edge` border and a 1px specular top. Nothing has a thicker border.

## Shapes

Capsules and continuous corners. The pill, OSD, media notify, Circles, Capsules, Chips and the back button are all `radius: height / 2`. **Radius follows the element's height, not its width**, which is why a full-width `Row_` is tighter-cornered than the full-width Module above it: a panel is a 28px-radius sheet, Modules inside it are 20px, and `Row_` list items, at 40-46px tall, are 14px; album art is 10px (12px at the 50px notify size); workspace dots are 3px. Radius animates with the island's growth so the pill's full capsule eases into the panel's 28px corner. The island clips its contents.

## Components

### Circle
Signature control. A 30px capsule (`width: 30; height: 30; radius: 15`) holding a 15px Material glyph centred on its ink.
- **Off:** `circleOff` fill, `text1` glyph.
- **On:** `accent` fill, `accentText` glyph. 160ms `ColorAnimation`.
- **Press:** scales to 0.92 over 120ms.
- **Sizes:** 30px in ToggleRow; 26px (13 radius) inside SquareTile and Row_; 28px for PageHeader's back button; 32px for play/pause.

### Module
The glass tile. `radius: 20`, `tile` fill, 1px border at `edge` x 0.7 alpha, module specular across the top. Hover to `tileHover` in 160ms unless `hoverable: false` (SliderTile, Calendar). Clicks on empty area fire `clicked`. Sub-variants:
- **SquareTile:** 76px tall, 10px padding, 2px column spacing; 26px Circle top-left, chevron (`ic.chevR`, 15px, `text2`) top-right when it opens a page, label 12/600 and sub 10/400 bottom-aligned.
- **SliderTile:** 70px tall, 12px padding (9px top), 6px spacing; label 12/600 with a `text2` 11px trailing value, then a Capsule.
- **Row_:** list item; `radius: 14`, 40px tall (46px with a sub), 10px left / 12px right inset, 10px spacing; optional 26px Circle, label 12/600, sub 10/400, trailing 11px in `text2` (or `accent` DemiBold when `action` is true), and an `accent` check glyph when `showCheck && on`.

### ToggleRow
Non-glass row inside a Module: 30px Circle, 10px gap, label 13/600 over sub 11/400 with 1px spacing. Circle toggles; label area opens the page.

### Capsule (slider)
30px tall, `track` fill, `radius: height / 2`, clipped. Fill is `text1` (`text2` when muted), minimum width equals the height, animates width in 90ms. Glyph sits at `x: 8`, 15px, in `themeBg`, riding inside the fill so it reads as a cut-out of the theme background. Press or drag anywhere sets the value; pointer is a hand.

### Chips
`Flow` with 6px spacing. Each chip is 28px tall, `radius: 14`, `implicitWidth + 22` wide, label 11/600. Unselected: `tile` with a 1px `edge` border, hover to `tileHover`. Selected: `accent` fill, no border, `accentText` label. 140ms colour.

### PageHeader
28px `tile` back circle with 1px `edge` border and a 16px `ic.chevL`, 6px gap, then title 15/700 with a 4px left margin. Replaces the grid on every page; it is the only header the surface has.

### Section
Grouped-list header: 10/600 uppercase `text2` with 0.8px tracking, 6px top and 4px left margin. Sits between Row_ groups inside a page, in the macOS Settings sense. Never used above a title.

### Calendar
`Calendar.qml` receives `accent`, `accentText`, `fg: text1`, `dim: text2`, **`today: clock.date`** and the fonts from the root; it never reads the process clock, or a shell left running for days would circle the day it started. The grid draws only the rows the month needs (`7 × ceil((offset + daysInMonth) / 7)`), so a five-row month does not carry a dead sixth. Out-of-month days are dimmed once, by `dim` alone; its own literal defaults are placeholders before binding. Month title 13/600 in `fg`, chevrons 18px in `accent`, weekday initials 11/600 in `dim`, day numbers 11px (`fg` in month, `dim` outside), today a `accent` circle with `accentText` 11/700.

### Media panel (left island)
320 wide: 56px `Art` beside title 13/600, artist 11/400 and player identity 10/400; then, only when the player reports a position, a 4px track in `track` filled `accent` with elapsed and total 10/400 beneath it; then `MediaControls` centred in a 36px band. With no player the title reads "Nothing playing" and the identity line invites one.

### Centre panel (centre island)
320 wide, and its header is the TIME, never the date: `hhmm` as four 46px `FlipDigit` cells around a 46px colon in `themeFg` at 0.4, left-hung on the content margin like the calendar title beneath it, with the full date 12/400 directly under. Then the page — month `Calendar`, or Notifications — then a single `Row_` for Stay Awake whose sub names why it is held: "Held for a meeting", "Held while media plays", "Screen will not lock", or the usual timer. Stay Awake sits below both pages, because it belongs to the island rather than to either page.

**Two pages, one switch.** A 28px `tile` circle at the right of the time header, the same circle as `PageHeader`'s back button, carries a 15px glyph of **where the click goes, not where you are**: `ic.bell` (`ic.bellOff` under DND) while the calendar is up, `ic.calendar` while notifications are. Closing the panel returns it to the calendar — the calendar is what the centre island is, notifications are somewhere you went.

**Notifications page:** the DND `Row_` with a check, then RECENT as plain `Row_` items — the sender's `omarchy-glyph` else `ic.bell`, summary as label, body (else app name) as sub, arrival time as trailing, `on` when Critical — then a Clear history action row. Rows are not hoverable: history is a record, not a control. Empty state is one row, "Nothing yet / The last 10 land here". Ten is what fits: the panel grows with its content and the window is 760 tall.

### Media art
- **Art:** 44px, `radius: 10`, `circleOff` placeholder with a 20px `ic.music`; 50px / `radius: 12` in the notify. The raster is masked by `RoundedImage.qml`, not clipped: Qt's clip is rectangular and left the corners square.

### Notification
- **NotifIcon:** 44px, `radius: 12`, `circleOff` behind the same `RoundedImage`. Falls back to the sender's `omarchy-glyph` hint, else a 20px `ic.bell`, whenever the image is not Ready — which includes an icon name the theme does not have, since that otherwise paints Qt's magenta broken-texture checkerboard.
- **Text:** summary 14/600 in `pillText`, `danger` when urgency is Critical; body 12/400 in `pillDim`, plain text, wrapped to two lines and elided. A `+N` counter in a 24px `pillText`-at-0.14 circle when more are queued behind.
- **MediaControls:** prev / play-pause / next, 6px spacing; transport glyphs 20px, play in a 32px `circleOff` circle at 17px; disabled directions drop to `text2`. `tint` is `pillText` on the black notify, `text1` on glass.
- **Order:** newest first. The pill shows the most recent notification and the ones behind it wait in the `+N` counter, so the thing that just happened is never queued behind something older.
- **Do Not Disturb:** an `ic.bellOff` glyph at 13px in `pillDim`, first item in the pill's tray row, and nothing else — the pill re-centres the clock around it on its own. Critical notifications still reach the pill while it is on, because a thermal or battery warning is not a notification to hide.
- **Notifications page:** the centre panel's other page — see below.

### Dots (collapsed, left and right)
40px black circles. The core says what the island is, the ring says what state it is in, and the ring is the only thing on a dot allowed to carry colour. **Left:** the album art, masked to a 30px circle by `RoundedImage`, ringed in `accent` by how far through the track it is; a 14px `ic.music` on `circleOff` when nothing is playing. **Right:** a 15px Wi‑Fi glyph in `pillText` (`pillDim`, and `ic.wifiOff`, when the radio is off or unjoined) inside a charge ring — `accent` while charging, `danger` below 20%, otherwise `pillText` at 0.5. Rings are `ProgressRing`: a 2.5px `PathAngleArc` from -90°, round cap, over a track of `pillText` at 0.16, sweeping over 420ms OutCubic.

### Pill (collapsed, centre)
40px black capsule, 15px side inset: workspace dots anchored left, tray icons anchored right, and the clock 16/600 in `pillText` anchored dead centre as four `FlipDigit` cells around a static colon in `pillText` at 0.5 — on a rollover the old digit leaves upward while the new one rises in behind it, 240ms OutCubic, each cell a fixed digit width so the pill never shifts. The digit on show is bound to the time and the roll is decoration over it: a layer surface only animates while the compositor draws it, so a clock written by its own animation goes stale while the screen sleeps, `accent` note when playing, workspace pills (`radius: 3`, `accent` focused / `danger` urgent / `pillDim` otherwise, width animates 160ms OutCubic) and 14px tray icons. **The pill's width is `clockRow + 2 × (max(workspaces, tray) + 14) + 30`** — symmetric about the clock on purpose, so the one element sitting at true screen centre never drifts as the sides change. Battery left the pill for the right dot; the accent workspace dot is the pill's only colour.

### OSD capsule
330 x 58 black capsule showing a Capsule slider (sun / keyboard / volume glyph) and the percentage 13/600 in `pillText`. Holds 1.4s after the last change; suppressed while the control centre is open.

### Inputs
One text field (Wi‑Fi password): 40px, `radius: 14`, `tile` fill, 12px text in `text1`, placeholder in `text2`. No focus ring is drawn.

## Do's and Don'ts

### Do:
- **Do** derive every new surface colour from a `colors.toml` key via `a(themeX, alpha)`; add it beside the existing `readonly property color` tokens on the root and give the source property a fallback literal.
- **Do** show state in a Circle (`accent` when on) and keep the tile at `tile`.
- **Do** add glyphs to `root.ic` as `\u{...}` Material codepoints and draw them with `Glyph`, which centres on ink.
- **Do** keep the 12/600 label + 10/400 sub pair for any new tile or row.
- **Do** use `Module` for anything glass and `Row_` for anything in a list; both already carry edge, specular and hover.
- **Do** keep new island states inside that island's width/height/radius ternaries so the 240ms OutCubic growth covers them.
- **Do** put state on a dot in its ring, never as a second mark beside the core.
- **Do** mask each island into the window `mask` region separately; the Row's own bounding box would swallow clicks in the empty space beside an open panel.
- **Do** route anything that must re-theme through `applyTheme()`; the `island theme` IPC and the open-control reload already call it.

### Don't:
- **Don't** hard-code a hue or a white/black alpha for glass; every control-centre colour is a theme key, and `root.dark` is consulted only for the glass alpha.
- **Don't** tint a Module's background to show on/off.
- **Don't** add blur or shadow effects in QML; blur is Hyprland's and the island shadow is the four stacked rectangles.
- **Don't** put a title bar, close button or floating power glyph on the control centre; pages get a PageHeader and home gets none.
- **Don't** make the collapsed pill, OSD or media notify glass; they stay `pill` black under every theme.
- **Don't** put a status dot or any second colour signal in the centre pill; the workspace dots are its only colour.
- **Don't** let a displayed value be written only by an animation. A layer surface stops animating while the screen sleeps, and the clock read eleven minutes behind until the digit was bound to the time with the roll as decoration over it.
- **Don't** introduce a second text face or SF Pro Display; every string is SF Pro Text and every icon is a Nerd Font Material glyph.
