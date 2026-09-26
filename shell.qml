import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Services.UPower

PanelWindow {
    id: root

    // ---- state ------------------------------------------------------------
    property bool mediaNotify: false          // media view, shown briefly when a track starts
    property string panel: ""                 // which island is open: "" | "media" | "centre" | "hw"
    property string osd: ""                   // "" | "volume" | "brightness" | "kbd"
    property string page: ""                  // page inside the hardware panel: "" home | wifi | bluetooth | audio | power | fans | slash | display

    readonly property bool mediaOpen: panel === "media"
    readonly property bool centreOpen: panel === "centre"
    readonly property bool hwOpen: panel === "hw"
    readonly property bool control: panel !== ""
    // The centre pill is busy whenever something has taken it over.
    readonly property bool centreBusy: osd !== "" || notif !== null || centreOpen || voice !== ""
    // Voxtype dictation: "" idle | "recording" | "transcribing". Outranks the
    // OSD and notifications in the centre pill; an open panel still wins.
    property string voice: ""
    readonly property bool voiceShown: voice !== "" && !centreOpen
    // Sized symmetrically about the clock, so the time sits at true screen centre
    // however wide the workspaces or the tray happen to be.
    readonly property real pillWidth: clockRow.implicitWidth + 2 * (Math.max(wsRow.implicitWidth, trayRow.implicitWidth) + 14) + 30
    property var notifs: []                   // live notifications, newest first; [0] is the one on screen
    readonly property var notif: notifs.length > 0 ? notifs[0] : null
    property bool dnd: false                  // do not disturb: nothing but Critical reaches the pill
    property var notifLog: []                 // the last 10, newest first, as plain data — see notifRecord
    property string centrePage: "calendar"    // what the centre panel shows: "calendar" | "notifications" | "weather"
    // Latest weather, empty until the first fetch lands. See the weather block.
    property var wx: ({ temp: "", desc: "", place: "", hi: "", lo: "", feels: "",
                        humidity: "", wind: "", localHour: -1, hours: [] })
    property int weatherAt: 0                 // index into weatherPlaces; 0 is wherever this machine is

    readonly property string fam: "SF Pro Text"
    readonly property string icons: "JetBrainsMono Nerd Font"

    // ---- theme (Omarchy colors.toml → Tahoe glass tokens) -----------------
    // Every colour below is read from the active theme's colors.toml; the
    // literals are only the fallback before the file loads.
    property bool dark: true
    property color accent: "#7aa2f7"
    property color themeBg: "#1a1b26"
    property color themeBg2: "#24283b"      // lighter_background
    property color themeFg: "#c0caf5"       // bright_foreground, else foreground
    property color themeFgDim: "#565f89"    // dark_foreground
    property color themeMuted: "#414868"    // muted
    property color danger: "#f7768e"        // red
    function a(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha) }
    readonly property color glass: a(themeBg, dark ? 0.62 : 0.72)
    readonly property color edge: a(themeFg, 0.16)
    readonly property color specular: a(themeFg, 0.30)
    readonly property color tile: a(themeBg2, 0.62)
    readonly property color tileHover: a(themeBg2, 0.92)
    readonly property color circleOff: a(themeMuted, 0.95)
    readonly property color text1: themeFg
    // Measured, not guessed: the theme's dark_foreground key came out at 2.9:1
    // on the glass. Secondary text is the bright foreground held back instead.
    readonly property color text2: a(themeFg, 0.66)
    readonly property color track: a(themeMuted, 0.85)
    readonly property color accentText: (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) > 0.6 ? themeBg : themeFg
    readonly property color pill: "#050505"
    readonly property color pillText: "#f5f5f7"
    readonly property color pillDim: "#8e8e93"

    // Material glyphs (JetBrainsMono Nerd Font, verified on this machine).
    readonly property var ic: ({
        wifi: "\u{f05a9}", wifiOff: "\u{f05aa}", bt: "\u{f00af}", btOff: "\u{f00b2}",
        volHigh: "\u{f057e}", volOff: "\u{f0581}", sun: "\u{f05a8}", keyboard: "\u{f030c}",
        fan: "\u{f0210}", monitor: "\u{f0379}", power: "\u{f0425}", lock: "\u{f033e}",
        night: "\u{f0594}", logout: "\u{f0343}", restart: "\u{f0709}", chevR: "\u{f0142}", chevL: "\u{f0141}",
        music: "\u{f0387}", headphones: "\u{f02cb}", thermo: "\u{f050f}", battery: "\u{f0079}", batteryChg: "\u{f0084}",
        check: "\u{f012c}", play: "\u{f040a}", pause: "\u{f03e4}", next: "\u{f04ad}", prev: "\u{f04ae}",
        bell: "\u{f009a}", bellOff: "\u{f009b}", led: "\u{f07d6}", gpu: "\u{f08ae}", mic: "\u{f036c}", calendar: "\u{f00ed}", chevD: "\u{f0140}", coffee: "\u{f0176}",
        sunny: "\u{f0599}", clearNight: "\u{f0594}", partly: "\u{f0595}", partlyNight: "\u{f0f31}", cloudy: "\u{f0590}",
        rainy: "\u{f0597}", storm: "\u{f0593}", snowy: "\u{f0598}", hail: "\u{f0592}", fog: "\u{f0591}",
        humidity: "\u{f058e}", wind: "\u{f059d}", pin: "\u{f034e}"
    })

    readonly property string hhmm: Qt.formatTime(clock.date, "hh:mm")

    property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    property var sink: Pipewire.defaultAudioSink
    property var battery: UPower.displayDevice
    property var bt: Bluetooth.defaultAdapter


    // How far through the track, polled while it plays: the left dot's ring.
    property real trackProgress: 0
    function mmss(sec) {
        var t = Math.max(0, Math.floor(Number(sec) || 0))
        return Math.floor(t / 60) + ":" + ("0" + (t % 60)).slice(-2)
    }

    property int brightness: 0
    property int kbd: 0
    property int kbdMax: 3

    property bool wifiOn: true
    property string ssid: ""
    property int signal: 0

    anchors { top: true; left: true; right: true }

    implicitHeight: 760
    color: "transparent"
    // Hidden mode keeps the surface (and its input mask) so hovering where the
    // islands sit reveals them; it only gives the screen edge back.
    property bool hiddenMode: false
    exclusiveZone: hiddenMode ? 0 : 50
    aboveWindows: true
    readonly property bool grabbed: control && (!hoverOpened || askPassFor !== "")
    focusable: root.grabbed
    WlrLayershell.namespace: "acs-island"   // Hyprland blurs this namespace (looknfeel.lua)

    PwObjectTracker { objects: [root.sink] }

    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() { root.showOsd("volume") }
        function onMutedChanged() { root.showOsd("volume") }
    }

    function showOsd(kind) {
        if (kind === "brightness") brightnessProbe.running = true
        if (kind === "kbd") kbdProbe.running = true
        if (root.control) return
        root.osd = kind
        osdTimer.restart()
    }

    function openIsland(which) {
        root.hoverOpened = false
        if (which !== "") colorsFile.reload()
        if (which === "hw") { brightnessProbe.running = true; kbdProbe.running = true; wifiProbe.running = true; fanProbe.running = true; modesProbe.running = true; dgpuProbe.running = true }
        // A month you paged away from should not still be there tomorrow.
        if (which === "centre") { idleProbe.running = true; cal.shown = clock.date }
        if (which !== "centre") root.centrePage = "calendar"
        root.panel = which
        root.osd = ""
        if (which !== "hw") { root.page = ""; root.askPassFor = ""; if (root.bt && root.bt.discovering) root.bt.discovering = false }
    }

    // Hovering one island while another is open swaps them, so the cursor can
    // walk the row without having to close anything on the way.
    property string hoverTarget: ""
    readonly property bool anyHovered: mediaHover.hovered || centreHover.hovered || hwHover.hovered
    function hoverChanged(which, hovered) {
        if (hovered) {
            hoverClose.stop()
            if (root.panel !== which) { root.hoverTarget = which; hoverOpen.restart() }
        } else {
            hoverOpen.stop()
            if (root.panel !== "") hoverClose.restart()
        }
    }

    function go(name) {
        root.page = name
        if (name === "wifi") { root.run(["nmcli", "dev", "wifi", "rescan"]); wifiListProbe.running = true }
        if (name === "fans") fanProbe.running = true
        if (name === "display") { modesProbe.running = true; dgpuProbe.running = true }
        if (root.bt) root.bt.discovering = name === "bluetooth"
    }

    Connections {
        target: root.player
        function onTrackChanged() { root.notifyMedia() }
        function onIsPlayingChanged() { root.notifyMedia() }
    }

    function notifyMedia() {
        if (!root.player || !root.player.isPlaying || root.control) return
        root.mediaNotify = true
        mediaTimer.restart()
    }

    // ---- notifications ------------------------------------------------------
    // The island is the notification daemon: omarchy.notifications is disabled
    // in shell.json, because only one process can own org.freedesktop.Notifications.

    NotificationServer {
        id: notifServer
        keepOnReload: false
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        // Let omarchy-notification-send's own hints through, so its glyph and
        // click action survive the trip.
        extraHints: ["omarchy-glyph", "omarchy-exec-argv"]

        onNotification: function(n) {
            root.notifRecord(n)
            // Silenced: it is in the history and nowhere else. Critical still gets
            // through — a thermal or battery warning is not a notification to hide.
            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return
            // Without tracked the object is destroyed the moment this returns.
            n.tracked = true
            n.closed.connect(function() { root.notifClose(n, false) })
            // Newest first: the island always shows the most recent one, and the
            // ones behind it wait as the +N counter.
            root.notifs = [n].concat(root.notifs)
            root.notifArm()
        }
    }

    // Lifetime of the notification at the head of the queue. A critical one
    // never expires on its own — it waits to be clicked away.
    function notifArm() {
        notifTimer.stop()
        var n = root.notif
        if (!n) return
        var ms = n.urgency === NotificationUrgency.Critical ? 0
               : n.expireTimeout > 0 ? Math.min(30000, Math.max(2000, n.expireTimeout))
               : n.urgency === NotificationUrgency.Low ? 5000 : 8000
        if (ms > 0) { notifTimer.interval = ms; notifTimer.restart() }
    }

    // History. The Notification object dies with the notification, so what is kept
    // is a flat copy: a glyph rather than an image, because the history draws rows,
    // not the 44px icon the pill draws.
    // ponytail: 10 entries in memory — they survive a config reload but not a
    // restart of the shell. A file-backed log if that ever matters.
    function notifRecord(n) {
        var e = {
            summary: String(n.summary || n.appName || "Notification"),
            body: String(n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim(),
            app: String(n.appName || ""),
            glyph: n.hints ? String(n.hints["omarchy-glyph"] || "") : "",
            critical: n.urgency === NotificationUrgency.Critical,
            at: Qt.formatTime(new Date(), "HH:mm")
        }
        root.notifLog = [e].concat(root.notifLog).slice(0, 10)
    }

    // Drop one notification from the queue. `dismiss` also closes it on the bus;
    // a close that came FROM the sender arrives here with dismiss false, because
    // the object is already on its way out.
    function notifClose(n, dismiss) {
        if (!n) return
        var head = root.notif
        var out = []
        for (var i = 0; i < root.notifs.length; i++) {
            var x = root.notifs[i]
            if (x && x !== n) out.push(x)
        }
        root.notifs = out
        if (dismiss) n.dismiss()
        if (head === n) root.notifArm()
    }

    // Click: run the notification's action, then close it. omarchy-notification-send
    // carries its --exec argv as a hint rather than a libnotify action, so the click
    // still works after the sending script has exited. Run as argv, never a shell
    // string, so a filename in there can never become a command.
    function notifActivate() {
        var n = root.notif
        if (!n) return
        var argv = n.hints ? n.hints["omarchy-exec-argv"] : ""
        var ran = false
        if (argv) {
            try {
                var a = JSON.parse(argv)
                if (Array.isArray(a) && a.length > 0 && typeof a[0] === "string" && a[0] !== "" && a[0][0] !== "-") {
                    root.run(a)
                    ran = true
                }
            } catch (e) { }
        }
        if (!ran && n.actions && n.actions.length > 0) n.actions[0].invoke()
        root.notifClose(n, true)
    }

    // Bodies may carry the freedesktop markup subset. The pill is two lines of
    // plain text, so drop the tags instead of rendering them.
    readonly property string notifBody: notif ? String(notif.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : ""

    // The icon to draw: the notification's own image, else the sending app's icon.
    // Either can arrive as a themed name, which quickshell hands back as
    // image://icon/<name> — and that URL still loads as Qt's magenta
    // broken-texture checker when the theme holds no such icon. So the name is
    // checked before it is used, and NotifIcon draws its glyph instead.
    readonly property string notifIconUrl: {
        var n = root.notif
        if (!n) return ""
        var v = String(n.image || n.appIcon || "")
        if (v === "") return ""
        if (v.indexOf("image://icon/") === 0) v = v.substring(13)
        if (v.charAt(0) === "/") return "file://" + v
        if (v.indexOf("://") !== -1) return v
        return Quickshell.hasThemeIcon(v) ? "image://icon/" + v : ""
    }

    IpcHandler {
        target: "island"
        function volume(): void { root.showOsd("volume") }
        function osd(kind: string): void { root.showOsd(kind) }
        function toggle(): void { root.openIsland(root.hwOpen ? "" : "hw") }
        function toggleVisible(): void { root.openIsland(""); root.hiddenMode = !root.hiddenMode }
        // "media" | "centre" | "hw", or "" to close.
        function panel(which: string): void { root.openIsland(which) }
        function state(): string { return "panel=" + (root.panel === "" ? "-" : root.panel) + " page=" + (root.page === "" ? "-" : root.page) + " hover=" + (mediaHover.hovered ? "media" : centreHover.hovered ? "centre" : hwHover.hovered ? "hw" : "-") }
        function page(name: string): void {
            if (name === "calendar" || name === "notifications" || name === "weather") {
                root.openIsland("centre")
                root.centrePage = name
                return
            }
            root.openIsland("hw"); root.go(name)
        }
        function theme(): void { colorsFile.reload() }
        // The forecast strip as the island built it: the place's own hour, then
        // the slots that follow it. The handle the self-check pulls on.
        function forecast(): string {
            return "localHour=" + root.wx.localHour + " here=" + clock.date.getHours()
                 + " slots=" + root.wx.hours.map(function(h) { return h.hour }).join(",")
        }
        // No argument reports and refetches; a name shows that place, saved or not;
        // "here" goes back to wherever the machine is.
        function weather(place: string): string {
            if (place === "here") root.setWeather(0)
            else if (place !== "") root.showWeather(place)
            else weatherProbe.running = true
            return root.wx.place + " " + root.wx.temp + "C " + root.wx.desc + " loc=" + (root.weatherLoc === "" ? "-here-" : root.weatherLoc)
        }
        // Queue depth and what is on screen — the handle the self-check pulls on.
        // Clear every queued notification.
        function dismiss(): void { while (root.notifs.length > 0) root.notifClose(root.notif, true) }
        // Just the one on screen; the next takes its place.
        function dismissOne(): void { root.notifClose(root.notif, true) }
        // What a left click on the pill does: run its action, then close it.
        function invoke(): void { root.notifActivate() }
        function dnd(): string { root.dnd = !root.dnd; return root.dnd ? "on" : "off" }
        function history(): string { return root.notifLog.length + " entries" }
        function clearHistory(): void { root.notifLog = [] }
        function notifs(): string { return root.notifs.length + " " + (root.notif ? root.notif.summary : "-") }
        // Grab the island to a PNG. A plain screenshot of the top of the screen
        // is blocked whenever any window is fullscreen; this is not.
        // Why the machine is being kept awake, if it is.
        function awake(): string { return "inhibit=" + (root.stayAwake || root.autoAwake) + " media=" + root.mediaPlaying + " meet=" + root.meetOpen + " manual=" + root.stayAwake }
        function clocknow(): string { return root.hhmm + " sys=" + Qt.formatDateTime(new Date(), "hh:mm:ss") }
        function mic(): string { return "voice=" + (root.voice || "-") + " peak=" + micPeak.peak.toFixed(4) + " level=" + root.micLevel.toFixed(2) + " floor=" + root.micFloor.toFixed(1) + "dB" }
        // Preview the voice pill without dictating: level 0..1, or -1 to stop.
        function voicetest(level: real): void { root.micTest = level; root.voice = level >= 0 ? "recording" : "" }
        function grab(path: string): void { islandRow.grabToImage(function (r) { r.saveToFile(path) }) }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.grabbed
        onCleared: root.openIsland("")
    }

    // ---- probes -----------------------------------------------------------
    Process {
        id: brightnessProbe
        command: ["brightnessctl", "-m", "-d", "intel_backlight"]
        stdout: SplitParser { onRead: function(line) { var f = line.split(","); if (f.length > 3) root.brightness = parseInt(f[3]) || 0 } }
    }
    Process {
        id: kbdProbe
        command: ["brightnessctl", "-m", "-d", "asus::kbd_backlight"]
        stdout: SplitParser { onRead: function(line) { var f = line.split(","); if (f.length > 4) { root.kbd = parseInt(f[2]) || 0; root.kbdMax = parseInt(f[4]) || 3 } } }
    }
    Process {
        id: wifiProbe
        running: true
        command: ["bash", "-c", "echo \"$(nmcli -t radio wifi)|$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^yes' | head -1)\""]
        stdout: SplitParser {
            onRead: function(line) {
                var f = line.split("|")
                root.wifiOn = f[0] === "enabled"
                var w = (f[1] || "").split(":")
                root.ssid = w.length > 1 ? w[1] : ""
                root.signal = w.length > 2 ? parseInt(w[2]) || 0 : 0
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: wifiProbe.running = true }

    // One JSON line per voxtype state change; restarts if the daemon goes away.
    Process {
        id: voxFollow
        command: ["voxtype", "status", "--follow", "--format", "json"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                try { var a = JSON.parse(line).alt } catch (e) { return }
                // "streaming" = live dictation (Parakeet): still listening.
                root.voice = a === "recording" || a === "streaming" ? "recording" : a === "transcribing" ? a : ""
            }
        }
        onExited: { root.voice = ""; voxRetry.restart() }
    }
    Timer { id: voxRetry; interval: 3000; onTriggered: voxFollow.running = true }

    // Mic level for the voice band, only while recording. This mic idles
    // around -14 dBFS (fans), so a fixed scale reads silence as loud: the floor
    // follows the quietest recent level (drops at once, rises at most
    // 0.5 dB/s so speech never becomes the floor) and the band shows how far
    // the voice sits above it. micRange is the tuning knob: dB above the floor
    // that fills the band.
    PwObjectTracker { objects: [Pipewire.defaultAudioSource] }
    property real micFloor: -60
    property real micLevel: 0
    readonly property real micRange: 3.5
    property real micTest: -1   // qs ipc call island voicetest <0..1>, -1 = off
    property double micT: 0
    PwNodePeakMonitor {
        id: micPeak
        node: Pipewire.defaultAudioSource
        enabled: root.voice === "recording"
        onEnabledChanged: { root.micFloor = 0; root.micLevel = 0; root.micT = Date.now() }
        onPeakChanged: {
            if (!(peak > 0)) { root.micLevel = 0; return }
            var db = 20 * Math.log(peak) / Math.LN10
            var now = Date.now(), dt = (now - root.micT) / 1000
            root.micT = now
            root.micFloor = db < root.micFloor ? db : root.micFloor + Math.min(db - root.micFloor, 0.5 * dt)
            root.micLevel = Math.max(0, Math.min(1, (db - root.micFloor - 1) / root.micRange))
        }
    }
    Process { id: setter }
    function run(cmd) { setter.command = cmd; setter.running = true }

    property var networks: []
    property string askPassFor: ""
    property bool hoverOpened: false     // control centre was opened by hover, not by a keybind
    Process {
        id: wifiListProbe
        command: ["bash", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi | awk -F: '$2!=\"\"' | sort -t: -k3 -nr | awk -F: '!seen[$2]++' | head -8"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                text.trim().split("\n").forEach(function(l) {
                    if (!l) return
                    var f = l.split(":")
                    out.push({ inUse: f[0].trim() === "*", ssid: f[1], signal: parseInt(f[2]) || 0, secure: (f[3] || "").trim() !== "" })
                })
                root.networks = out
            }
        }
    }
    Process {
        id: wifiConnect
        property string ssid: ""
        onExited: function(code) {
            root.askPassFor = code !== 0 ? wifiConnect.ssid : ""
            wifiProbe.running = true; wifiListProbe.running = true
        }
    }
    function connectWifi(ssid, pass) {
        wifiConnect.ssid = ssid
        wifiConnect.command = pass ? ["nmcli", "dev", "wifi", "connect", ssid, "password", pass] : ["nmcli", "dev", "wifi", "connect", ssid]
        wifiConnect.running = true
    }
    // The connected row is always the active network, so drop the device: unlike `con down`
    // that also stops NetworkManager autoconnecting straight back to it.
    function disconnectWifi() {
        wifiConnect.ssid = ""            // a failure here must not open the password prompt
        wifiConnect.command = ["bash", "-c", "nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2==\"wifi\"{print $1}' | head -1 | xargs -r nmcli dev disconnect"]
        wifiConnect.running = true
    }
    Timer { interval: 8000; running: root.page === "wifi"; repeat: true; onTriggered: wifiListProbe.running = true }

    // Stay awake: Omarchy's idle service owns the state; we only read and flip it.
    property bool stayAwake: false
    Process {
        id: idleProbe
        command: ["omarchy-shell", "idle", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.stayAwake = JSON.parse(text).stayAwake === true } catch (e) {} } }
    }
    function toggleStayAwake() { root.stayAwake = !root.stayAwake; root.run(["omarchy-shell", "idle", root.stayAwake ? "disable" : "enable"]); idleSettle.restart() }

    // Playing media, or a Google Meet window, means the machine must not blank
    // or lock. Chromium runs under XWayland here, so its own idle-inhibit
    // request never reaches Hyprland and the screen locked mid-video; the
    // island holds the Wayland inhibitor on its behalf. The inhibitor belongs
    // to the island's surface, so it is dropped the moment the island exits —
    // unlike `omarchy-shell idle disable`, which persists to a state file.
    readonly property bool mediaPlaying: {
        var ps = Mpris.players.values
        for (var i = 0; i < ps.length; i++) if (ps[i].isPlaying) return true
        return false
    }

    // ponytail: title match only. A window title carries the focused tab, so a
    // call sitting in a background tab is not seen. Watch the microphone stream
    // instead if that turns out to matter.
    readonly property bool meetOpen: {
        var ts = ToplevelManager.toplevels.values
        for (var i = 0; i < ts.length; i++) {
            var t = ts[i]
            if (/meet\.google\.com/i.test(String(t.appId || ""))) return true
            if (/^meet\b|\bgoogle meet\b/i.test(String(t.title || ""))) return true
        }
        return false
    }

    readonly property bool autoAwake: mediaPlaying || meetOpen

    IdleInhibitor {
        window: root
        enabled: root.stayAwake || root.autoAwake
    }

    // ---- weather ----------------------------------------------------------
    // wttr.in answers with the place as well as the conditions, so one call
    // covers both. It runs under mullvad-exclude: inside the tunnel "here" is
    // whichever relay is up, and the island would report Glasgow's rain while
    // the machine sits in Bengaluru. No exclusion available (no Mullvad, or the
    // daemon is down) means there is no tunnel to be wrong about, so plain curl
    // is the right fallback — never a second, in-tunnel attempt.
    // Alternate places live in ~/.config/quickshell/weather-places, one per
    // line; the blank first entry is always "wherever this machine is", and
    // clicking the widget walks the list.
    property var weatherPlaces: [""]
    property string weatherLoc: ""            // "" is wherever this machine is
    FileView {
        id: weatherPlacesFile
        path: Quickshell.env("HOME") + "/.config/quickshell/weather-places"
        watchChanges: true
        printErrors: false
        onLoaded: {
            var ls = (text() || "").split("\n")
                .map(function(l) { return l.trim() })
                .filter(function(l) { return l !== "" && l.charAt(0) !== "#" })
            root.weatherPlaces = [""].concat(ls)
            root.setWeather(0)
        }
        onFileChanged: reload()
    }
    // Step to a saved place by position; the list wraps, so the widget's click
    // always lands somewhere.
    function setWeather(i) {
        var n = Math.max(root.weatherPlaces.length, 1)
        root.weatherAt = ((i % n) + n) % n
        root.weatherLoc = root.weatherPlaces[root.weatherAt] || ""
        weatherProbe.running = true
    }
    // Any place, saved or not. A saved one keeps its position in the cycle.
    function showWeather(place) {
        var i = root.weatherPlaces.map(function(p) { return p.toLowerCase() }).indexOf(place.toLowerCase())
        if (i >= 0) { root.setWeather(i); return }
        root.weatherLoc = place
        weatherProbe.running = true
    }
    // Two calls, one process: the place's own wall clock on the first line, then
    // the forecast. The hourly slots are stamped in the place's local time, so
    // without its clock there is no way to know which slot is "next" for
    // anywhere but here.
    readonly property string wxScript:
        'u="https://wttr.in/$1"; ' +
        'get() { if command -v mullvad-exclude >/dev/null 2>&1; then mullvad-exclude curl -sfL --max-time 10 "$1"; else curl -sfL --max-time 10 "$1"; fi; }; ' +
        'get "$u?format=%T"; echo; get "$u?format=j1"'
    Process {
        id: weatherProbe
        running: true
        command: ["bash", "-c", root.wxScript, "_", encodeURIComponent(root.weatherLoc)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var cut = text.indexOf("\n")
                    var lh = parseInt(text.substring(0, cut).trim().substring(0, 2))
                    if (isNaN(lh)) lh = clock.date.getHours()
                    var d = JSON.parse(text.substring(cut + 1))
                    var c = d.current_condition[0], a = d.nearest_area[0], f = d.weather[0]

                    // The next 24 hours, in the three-hour steps the forecast comes
                    // in. Today's slots that have already been and gone are skipped,
                    // and tomorrow's carry on from where today runs out.
                    var hours = []
                    for (var di = 0; di < d.weather.length && hours.length < 8; di++) {
                        var hs = d.weather[di].hourly
                        for (var hi = 0; hi < hs.length && hours.length < 8; hi++) {
                            var h = Math.floor(parseInt(hs[hi].time) / 100)
                            if (di === 0 && h <= lh) continue
                            hours.push({ hour: h, temp: hs[hi].tempC, rain: parseInt(hs[hi].chanceofrain) || 0,
                                         desc: String(hs[hi].weatherDesc[0].value).trim() })
                        }
                    }

                    root.wx = { temp: c.temp_C, feels: c.FeelsLikeC, desc: String(c.weatherDesc[0].value).trim(),
                                // Asked for a place by name? Show that name. The provider
                                // answers London with "Strand", which is true and useless.
                                place: root.weatherLoc !== "" ? root.weatherLoc : a.areaName[0].value,
                                hi: f.maxtempC, lo: f.mintempC, humidity: c.humidity, wind: c.windspeedKmph,
                                localHour: lh, hours: hours }
                } catch (e) {}
            }
        }
    }
    Timer { interval: 900000; running: true; repeat: true; onTriggered: weatherProbe.running = true }

    // The condition comes back as English prose, which is a steadier thing to
    // match on than the provider's 40-value code table. The hour is the one
    // being drawn, in the weather's own timezone — pass it, or this machine's
    // clock stands in.
    function wglyph(desc, hour) {
        var d = String(desc).toLowerCase()
        var h = (hour === undefined || hour < 0) ? clock.date.getHours() : hour
        var day = h >= 6 && h < 20
        if (/thunder/.test(d)) return root.ic.storm
        if (/snow|blizzard/.test(d)) return root.ic.snowy
        if (/sleet|hail|ice/.test(d)) return root.ic.hail
        if (/rain|drizzle|shower/.test(d)) return root.ic.rainy
        if (/fog|mist/.test(d)) return root.ic.fog
        if (/overcast/.test(d)) return root.ic.cloudy
        if (/cloud/.test(d)) return day ? root.ic.partly : root.ic.partlyNight
        return day ? root.ic.sunny : root.ic.clearNight
    }

    property var fanStat: ({ profile: "", fans: [], cpu: null, dgpu: "" })
    Process {
        id: fanProbe
        command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/acs.fans/fanstat", "--gpu"]
        stdout: StdioCollector { onStreamFinished: { try { root.fanStat = JSON.parse(text) } catch (e) {} } }
    }
    Timer { interval: 2000; running: root.page === "fans"; repeat: true; onTriggered: fanProbe.running = true }
    readonly property var profiles: [{ value: "power-saver", label: "Silent" }, { value: "balanced", label: "Balanced" }, { value: "performance", label: "Turbo" }]
    function profileLabel(v) { for (var i = 0; i < profiles.length; i++) if (profiles[i].value === v) return profiles[i].label; return "Balanced" }
    function setProfile(v) { root.run(["powerprofilesctl", "set", v]); var s = root.fanStat; s.profile = v; root.fanStat = s; fanSettle.restart() }
    function cycleProfile() {
        var i = 0; for (var k = 0; k < profiles.length; k++) if (profiles[k].value === root.fanStat.profile) i = k
        setProfile(profiles[(i + 1) % profiles.length].value)
    }

    property var slash: ({})
    FileView {
        id: slashFile
        path: "/etc/asusd/slash.ron"
        watchChanges: true
        printErrors: false
        onLoaded: root.parseSlash()
        onFileChanged: reload()
    }
    function parseSlash() {
        var o = {}, re = /^\s*(\w+):\s*([^,]+),/gm, m
        var t = slashFile.text() || ""
        while ((m = re.exec(t)) !== null) o[m[1]] = m[2].trim() === "true" ? true : m[2].trim() === "false" ? false : (isNaN(Number(m[2])) ? m[2].trim() : Number(m[2]))
        root.slash = o
    }
    function slashctl(args) { root.run(["asusctl", "slash"].concat(args)) }
    readonly property var slashModes: ["Static", "Bounce", "Slash", "Loading", "BitStream", "Transmission", "Flow", "Flux", "Phantom", "Spectrum", "Hazard", "Interfacing", "Ramp", "GameOver", "Start", "Buzzer"]

    property var refreshRates: []
    property int refreshRate: 0
    property string monitorName: "eDP-2"
    property string dgpuControl: ""
    property string dgpuStatus: ""
    Process {
        id: modesProbe
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var mons = JSON.parse(text), m = mons.find(function(x) { return x.focused }) || mons[0]
                    if (!m) return
                    root.monitorName = m.name
                    root.refreshRate = Math.round(m.refreshRate)
                    var res = m.width + "x" + m.height, rates = {}
                    m.availableModes.forEach(function(mode) { if (mode.indexOf(res + "@") === 0) rates[Math.round(parseFloat(mode.split("@")[1]))] = true })
                    root.refreshRates = Object.keys(rates).map(Number).sort(function(a, b) { return a - b })
                } catch (e) {}
            }
        }
    }
    Process {
        id: dgpuProbe
        command: ["/usr/local/bin/dgpu", "status"]
        stdout: StdioCollector { onStreamFinished: { var f = text.trim().split(" "); root.dgpuControl = f[0] || ""; root.dgpuStatus = f[1] || "" } }
    }
    Process { id: displayAction; onExited: { modesProbe.running = true; dgpuProbe.running = true } }

    property int chargeLimit: 0
    FileView {
        path: "/sys/class/power_supply/BAT1/charge_control_end_threshold"
        printErrors: false
        onLoaded: root.chargeLimit = parseInt(text()) || 0
    }

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
        watchChanges: true
        printErrors: false
        onLoaded: root.applyTheme()
        onFileChanged: reload()
    }
    // theme.name is rewritten in place right after Omarchy swaps the theme dir,
    // long before its theme-set hook runs, so recolour from here.
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); colorsFile.reload() }
    }
    function applyTheme() {
        var t = colorsFile.text() || ""
        function pick(key, fallback) {
            var m = t.match(new RegExp("^" + key + "\\s*=\\s*\"(#[0-9a-fA-F]{6})\"", "m"))
            return m ? m[1] : fallback
        }
        var mode = t.match(/^mode\s*=\s*"(\w+)"/m)
        root.dark = !(mode && mode[1] === "light")
        root.accent = pick("accent", root.accent)
        root.themeBg = pick("background", root.themeBg)
        root.themeBg2 = pick("lighter_background", pick("background", root.themeBg2))
        root.themeFg = pick("bright_foreground", pick("foreground", root.themeFg))
        root.themeFgDim = pick("dark_foreground", pick("muted", root.themeFgDim))
        root.themeMuted = pick("muted", pick("selection", root.themeMuted))
        root.danger = pick("red", root.danger)
    }

    // One region per island, not the row: the row's bounding box would swallow
    // clicks in the empty space beside an open panel.
    // Hidden and not yet revealed, only the 1px screen edge above the row
    // listens; touching it reveals the islands and swaps in the full mask.
    mask: hiddenMode && !revealed ? edgeMask : islandMask
    property Region edgeMask: Region { item: edgeLine }
    property Region islandMask: Region {
        // Explicitly empty, then three islands unioned into it. The window is
        // 760px of transparent nothing; only these three shapes may take a click.
        width: 0; height: 0
        intersection: Intersection.Combine
        regions: [
            // The gap above the row, so a cursor coming down off the edge stays inside.
            Region { item: edgeStrip; intersection: Intersection.Combine },
            Region { item: mediaAura.hit; intersection: Intersection.Combine },
            Region { item: centreAura.hit; intersection: Intersection.Combine },
            Region { item: hwAura.hit; intersection: Intersection.Combine }
        ]
    }

    property bool revealed: false
    readonly property bool shownTarget: !hiddenMode || revealed
    onShownTargetChanged: {
        showAnim.stop(); hideAnim.stop()
        if (shownTarget) showAnim.start(); else hideAnim.start()
        glowAnim.restart()
    }
    ParallelAnimation {
        id: showAnim
        SpringAnimation { target: islandRow; property: "sx"; to: 1; spring: 5; damping: 0.32; epsilon: 0.002 }
        SpringAnimation { target: islandRow; property: "sy"; to: 1; spring: 3; damping: 0.24; epsilon: 0.002 }
    }
    // Reverse water droplet: a small sag as it gathers weight, then it is drawn
    // up into the screen edge. Height drains faster than width, so the last of
    // it flattens and spreads slightly as it merges into the surface.
    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: islandRow; property: "sy"; to: 1.08; duration: 60; easing.type: Easing.OutQuad }
            NumberAnimation { target: islandRow; property: "sx"; to: 0.96; duration: 60; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: islandRow; property: "sy"; to: 0; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: islandRow; property: "sx"; to: 1.08; duration: 200; easing.type: Easing.InOutSine }
        }
        // Reset out of sight so the next show still pours in from a point.
        PropertyAction { target: islandRow; property: "sx"; value: 0 }
    }
    // Siri edge: flashes in on every show/hide, then fades.
    property real glow: 0
    SequentialAnimation {
        id: glowAnim
        NumberAnimation { target: root; property: "glow"; to: 1; duration: 150; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 450 }
        NumberAnimation { target: root; property: "glow"; to: 0; duration: 700; easing.type: Easing.InOutQuad }
    }
    readonly property bool revealHold: edgeHover.hovered || anyHovered || control || voice !== ""
    onRevealHoldChanged: if (revealHold) { unreveal.stop(); revealed = true } else unreveal.restart()
    Timer { id: unreveal; interval: 150; onTriggered: root.revealed = false }

    Item {
        id: edgeStrip
        x: islandRow.x; width: islandRow.width
        height: root.hiddenMode ? islandRow.anchors.topMargin : 0
        HoverHandler { id: edgeHover }
        Item { id: edgeLine; width: parent.width; height: 1 }
    }

    // ---- components ---------------------------------------------------------
    // Nerd Font icons sit off-centre in their advance box; this measures the ink
    // and sizes the item to it, so anchors.centerIn centres what you can see.
    component Glyph: Item {
        id: g
        property alias text: t.text
        property alias color: t.color
        property alias font: t.font
        implicitWidth: Math.ceil(tm.tightBoundingRect.width)
        implicitHeight: Math.ceil(tm.tightBoundingRect.height)
        TextMetrics { id: tm; font: t.font; text: t.text }
        Text {
            id: t
            font.family: root.icons
            font.pixelSize: 16
            color: root.text1
            x: -(tm.tightBoundingRect.x - tm.boundingRect.x)
            y: -(tm.tightBoundingRect.y - tm.boundingRect.y)
        }
    }

    // The one-pixel highlight along the top edge of a glass panel.
    // Liquid-glass lens over an island while it shows or hides: light caught
    // on the lower rim (bright at the bottom, gone at the top), a soft pool of
    // light inside along the bottom, and a thin caustic band across the lower
    // middle. Theme foreground + accent only.
    component GlassRim: Item {
        id: rim
        property real r: 20
        property bool caustic: true
        anchors.fill: parent
        z: 50
        visible: opacity > 0.01
        function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
        Rectangle {
            id: rimLight
            anchors.fill: parent; visible: false; layer.enabled: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: rim.tint(root.themeFg, 0) }
                GradientStop { position: 0.5; color: rim.tint(root.themeFg, 0.06) }
                GradientStop { position: 1.0; color: rim.tint(root.themeFg, 0.95) }
            }
        }
        Item {
            id: rimLine
            anchors.fill: parent; visible: false; layer.enabled: true
            Shape { anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: "white"; strokeWidth: 1.5; fillColor: "transparent"
                    PathRectangle { x: 0.75; y: 0.75; width: rim.width - 1.5; height: rim.height - 1.5; radius: Math.max(0, rim.r - 0.75) } } }
        }
        Item {
            id: rimHalo
            anchors.fill: parent; visible: false; layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 16 }
            Shape { anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: "white"; strokeWidth: 6; fillColor: "transparent"
                    PathRectangle { x: 3; y: 3; width: rim.width - 6; height: rim.height - 6; radius: Math.max(0, rim.r - 3) } } }
        }
        MultiEffect { anchors.fill: parent; source: rimLight; maskEnabled: true; maskSource: rimHalo; opacity: 0.5 }
        MultiEffect { anchors.fill: parent; source: rimLight; maskEnabled: true; maskSource: rimLine }
        Rectangle {
            visible: rim.caustic
            x: parent.width * 0.2; width: parent.width * 0.6
            y: parent.height * 0.62; height: Math.max(2, parent.height * 0.08)
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: rim.tint(root.accent, 0.8) }
                GradientStop { position: 0.55; color: rim.tint(root.themeFg, 0.9) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 0.5; blurMax: 8 }
        }
    }

    // Behind one island: a blurred rainbow bloom while the rim flashes.
    // Tracks the island's layout box, not the row's collapse transform.
    component IslandAura: Item {
        id: aura
        property Item island
        readonly property int pad: 40
        // Untransformed stand-in for the island's input region: a Region built
        // from the island itself is sized once through the collapse transform
        // (at scale 0 on reveal) and never refreshed, so hover went dead.
        property alias hit: hitBox
        Item { id: hitBox; x: aura.pad; y: aura.pad; width: aura.island.width; height: aura.island.height }
        x: islandRow.x + island.x - pad; y: islandRow.y + island.y - pad
        width: island.width + 2 * pad; height: island.height + 2 * pad
        Rectangle {
            anchors.fill: parent; anchors.margins: aura.pad - 5
            radius: aura.island.radius + 5
            opacity: root.glow * 0.35 * Math.max(0, Math.min(1, islandRow.sx, islandRow.sy))   // gone with the shell
            visible: opacity > 0.01
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.accent }
                GradientStop { position: 1.0; color: root.accent }
            }
            layer.enabled: visible
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 32 }
        }
    }

    component Specular: Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: root.specular }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // A ring drawn around a dot island: charge on the right, track position on
    // the left. It is the state, not an ornament, so it is the only thing on a
    // dot allowed to carry colour.
    component ProgressRing: Item {
        id: ring
        property real value: 0
        property color stroke: root.accent
        property color track: root.a(root.pillText, 0.16)
        property real thickness: 2.5
        readonly property real rx: (Math.min(width, height) - thickness) / 2

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: ring.track
                strokeWidth: ring.thickness
                fillColor: "transparent"
                PathAngleArc {
                    centerX: ring.width / 2; centerY: ring.height / 2
                    radiusX: ring.rx; radiusY: ring.rx
                    startAngle: -90; sweepAngle: 360
                }
            }
            ShapePath {
                strokeColor: ring.stroke
                strokeWidth: ring.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2; centerY: ring.height / 2
                    radiusX: ring.rx; radiusY: ring.rx
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0, Math.min(1, ring.value))
                    Behavior on sweepAngle { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    // A glass module. Click on the empty area fires `clicked`.
    component Module: Rectangle {
        id: mod
        property bool hoverable: true
        readonly property bool hover: area.containsMouse
        signal clicked()
        radius: 20
        color: hover && hoverable ? root.tileHover : root.tile
        border.width: 1
        border.color: Qt.rgba(root.edge.r, root.edge.g, root.edge.b, root.edge.a * 0.7)
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1; leftMargin: mod.radius; rightMargin: mod.radius }
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(root.specular.r, root.specular.g, root.specular.b, root.specular.a * 0.6) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; z: -1; onClicked: mod.clicked() }
    }

    // The macOS state circle: filled accent when on.
    component Circle: Rectangle {
        id: circ
        property string icon: ""
        property bool on: false
        property bool toggles: true
        signal clicked()
        width: 30; height: 30; radius: 15
        color: on ? root.accent : root.circleOff
        scale: press.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 120 } }
        Glyph { anchors.centerIn: parent; text: circ.icon; color: circ.on ? root.accentText : root.text1; font.pixelSize: 15 }
        MouseArea { id: press; anchors.fill: parent; enabled: circ.toggles; onClicked: circ.clicked() }
    }

    component ToggleRow: RowLayout {
        id: tr
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        signal toggled()
        signal opened()
        spacing: 10
        Circle { icon: tr.icon; on: tr.on; onClicked: tr.toggled() }
        Item {
            Layout.fillWidth: true
            implicitHeight: trCol.implicitHeight
            ColumnLayout {
                id: trCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 1
                Text { Layout.fillWidth: true; text: tr.label; color: root.text1; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: tr.sub; color: root.text2; font.family: root.fam; font.pixelSize: 11; elide: Text.ElideRight; visible: text !== "" }
            }
            MouseArea { anchors.fill: parent; z: -1; onClicked: tr.opened() }
        }
    }

    component SquareTile: Module {
        id: sq
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property bool toggles: false
        property bool chevron: false
        signal toggled()
        Layout.fillWidth: true
        Layout.preferredWidth: 160
        implicitHeight: 76
        ColumnLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 2
            Circle { icon: sq.icon; on: sq.on; toggles: sq.toggles; width: 26; height: 26; radius: 13; onClicked: sq.toggled() }
            Item { Layout.fillHeight: true }
            Text { Layout.fillWidth: true; text: sq.label; color: root.text1; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; text: sq.sub; color: root.text2; font.family: root.fam; font.pixelSize: 11; elide: Text.ElideRight; visible: text !== "" }
        }
        Glyph { visible: sq.chevron; anchors { right: parent.right; top: parent.top; margins: 10 }
            text: root.ic.chevR; color: root.text2; font.pixelSize: 15 }
    }

    // Thick capsule slider, glyph riding inside the fill like macOS.
    component Capsule: Item {
        id: cap
        property string icon: ""
        property real value: 0
        property bool muted: false
        signal moved(real v)
        Layout.fillWidth: true
        implicitHeight: 30
        Rectangle {
            id: trackRect
            anchors.fill: parent
            radius: height / 2
            color: root.track
            clip: true
            Rectangle {
                height: parent.height
                radius: parent.radius
                width: Math.max(parent.height, parent.width * Math.min(Math.max(cap.value, 0), 1))
                color: cap.muted ? root.text2 : root.text1
                Behavior on width { NumberAnimation { duration: 90 } }
            }
            Glyph { x: 8; anchors.verticalCenter: parent.verticalCenter; text: cap.icon; color: root.themeBg; font.pixelSize: 15 }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function set(x) { cap.moved(Math.min(Math.max(x / trackRect.width, 0), 1)) }
                onPressed: function(m) { set(m.x) }
                onPositionChanged: function(m) { if (pressed) set(m.x) }
            }
        }
    }

    component SliderTile: Module {
        id: st
        property string label: ""
        property alias icon: capsule.icon
        property alias value: capsule.value
        property alias muted: capsule.muted
        property string trailing: ""
        signal moved(real v)
        hoverable: false
        Layout.fillWidth: true
        implicitHeight: 70
        ColumnLayout {
            anchors { fill: parent; margins: 12; topMargin: 9 }
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: st.label; color: root.text1; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold }
                Text { text: st.trailing; color: root.text2; font.family: root.fam; font.pixelSize: 11 }
            }
            Capsule { id: capsule; onMoved: function(v) { st.moved(v) } }
        }
    }

    component PageHeader: RowLayout {
        id: hdr
        property string title: ""
        property string glyph: root.ic.chevL
        Layout.fillWidth: true
        spacing: 6
        Rectangle {
            width: 28; height: 28; radius: 14
            color: back.containsMouse ? root.tileHover : root.tile
            border.width: 1; border.color: root.edge
            Glyph { anchors.centerIn: parent; text: hdr.glyph; font.pixelSize: 16 }
            MouseArea { id: back; anchors.fill: parent; hoverEnabled: true; onClicked: root.go("") }
        }
        Text { Layout.fillWidth: true; text: parent.title; color: root.text1; font.family: root.fam; font.pixelSize: 15; font.weight: Font.Bold; Layout.leftMargin: 4 }
    }

    component Row_: Module {
        id: row
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property string trailing: ""
        property bool action: false     // trailing is a verb the click performs
        property bool showCheck: false
        property bool chevron: false
        property string chevronIcon: root.ic.chevR
        Layout.fillWidth: true
        implicitHeight: sub !== "" ? 46 : 40
        radius: 14
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
            spacing: 10
            Circle { visible: row.icon !== ""; icon: row.icon; on: row.on; toggles: false; width: 26; height: 26; radius: 13 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { Layout.fillWidth: true; text: row.label; color: root.text1; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; visible: row.sub !== ""; text: row.sub; color: root.text2; font.family: root.fam; font.pixelSize: 11; elide: Text.ElideRight }
            }
            Text { visible: row.trailing !== ""; text: row.trailing; color: row.action ? root.accent : root.text2; font.family: root.fam; font.pixelSize: 11; font.weight: row.action ? Font.DemiBold : Font.Normal }
            Glyph { visible: row.showCheck && row.on; text: root.ic.check; color: root.accent; font.pixelSize: 15 }
            Glyph { visible: row.chevron; text: row.chevronIcon; color: root.text2; font.pixelSize: 15 }
        }
    }

    component Chips: Flow {
        property var model: []
        property string current: ""
        signal picked(string v)
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: parent.model
            Rectangle {
                required property var modelData
                readonly property string v: typeof modelData === "object" ? modelData.value : String(modelData)
                readonly property string l: typeof modelData === "object" ? modelData.label : String(modelData)
                readonly property bool sel: v === parent.current
                width: t.implicitWidth + 22; height: 28; radius: 14
                color: sel ? root.accent : (ch.containsMouse ? root.tileHover : root.tile)
                border.width: sel ? 0 : 1; border.color: root.edge
                Behavior on color { ColorAnimation { duration: 140 } }
                Text { id: t; anchors.centerIn: parent; text: parent.l; color: parent.sel ? root.accentText : root.text1; font.family: root.fam; font.pixelSize: 11; font.weight: Font.DemiBold }
                MouseArea { id: ch; anchors.fill: parent; hoverEnabled: true; onClicked: parent.parent.picked(parent.v) }
            }
        }
    }

    component Section: Text { Layout.fillWidth: true; Layout.topMargin: 6; Layout.leftMargin: 4; color: root.text2; font.family: root.fam; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }

    component MediaControls: RowLayout {
        id: mc
        property color tint: root.text1
        spacing: 6
        Glyph { text: root.ic.prev; color: root.player && root.player.canGoPrevious ? mc.tint : root.text2; font.pixelSize: 20
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: if (root.player && root.player.canGoPrevious) root.player.previous() } }
        Rectangle {
            width: 32; height: 32; radius: 16; color: root.circleOff
            Glyph { anchors.centerIn: parent; text: root.player && root.player.isPlaying ? root.ic.pause : root.ic.play; color: mc.tint; font.pixelSize: 17 }
            MouseArea { anchors.fill: parent; onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying() }
        }
        Glyph { text: root.ic.next; color: root.player && root.player.canGoNext ? mc.tint : root.text2; font.pixelSize: 20
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: if (root.player && root.player.canGoNext) root.player.next() } }
    }

    // One clock digit that rolls over when it changes: the old glyph leaves
    // upward while the new one rises in behind it. The cell is a fixed digit
    // width, so a rollover never shifts the pill.
    component FlipDigit: Item {
        id: fd
        property string value: "0"
        property color color: root.pillText
        property int pixelSize: 14

        implicitWidth: tm.advanceWidth
        implicitHeight: tm.height
        clip: true

        TextMetrics {
            id: tm
            font.family: root.fam; font.pixelSize: fd.pixelSize; font.weight: Font.DemiBold
            text: "0"
        }

        // The digit on show is BOUND to the value, and the roll is decoration
        // over the top of it. A layer surface only animates while the
        // compositor is drawing it, so anything the animation alone wrote went
        // stale the moment the screen slept — the clock read eleven minutes
        // behind. What the clock says can never depend on a frame being drawn.
        Text {
            id: current
            width: fd.width
            horizontalAlignment: Text.AlignHCenter
            font: tm.font
            color: fd.color
            text: fd.value
        }

        // A copy of the digit being replaced, drawn only while it leaves.
        Text {
            id: leaving
            width: fd.width
            horizontalAlignment: Text.AlignHCenter
            font: tm.font
            color: fd.color
            visible: roll.running
        }

        property string previous: value
        onValueChanged: {
            leaving.text = fd.previous
            fd.previous = fd.value
            roll.restart()
        }

        ParallelAnimation {
            id: roll
            onStopped: { current.y = 0; leaving.y = 0 }
            NumberAnimation { target: leaving; property: "y"; from: 0; to: -fd.height; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: current; property: "y"; from: fd.height; to: 0; duration: 240; easing.type: Easing.OutCubic }
        }
    }

    component Art: Rectangle {
        id: art
        readonly property string url: root.player ? String(root.player.trackArtUrl || "") : ""
        width: 44; height: 44; radius: 10; color: root.circleOff
        RoundedImage { id: artImg; anchors.fill: parent; cornerRadius: art.radius; source: art.url }
        Glyph { anchors.centerIn: parent; visible: artImg.status !== Image.Ready; text: root.ic.music; font.pixelSize: Math.round(art.width * 0.45) }
    }

    component NotifIcon: Rectangle {
        id: ni
        readonly property string glyph: root.notif && root.notif.hints ? String(root.notif.hints["omarchy-glyph"] || "") : ""
        width: 44; height: 44; radius: 12; color: root.circleOff
        RoundedImage { id: niImg; anchors.fill: parent; cornerRadius: ni.radius; source: root.notifIconUrl }
        Glyph {
            anchors.centerIn: parent
            visible: niImg.status !== Image.Ready
            text: ni.glyph !== "" ? ni.glyph : root.ic.bell
            color: root.pillText
            font.pixelSize: 20
        }
    }

    // ---- the island ---------------------------------------------------------
    // ---- the islands --------------------------------------------------------
    // Three surfaces, not one. Media on the left, the clock in the middle,
    // battery and connectivity on the right. Each grows in place into its own
    // glass panel, and the Row keeps them adjacent so the two that stay
    // collapsed are still on screen to hover across.
    IslandAura { id: mediaAura; island: mediaIsland }
    IslandAura { id: centreAura; island: centreIsland }
    IslandAura { id: hwAura; island: hwIsland }

    Row {
        id: islandRow
        anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
        // Keep the CENTRE island centred, not the row: opening a side panel would
        // otherwise slide the clock 140px sideways. Both widths already animate,
        // so this rides along with them.
        anchors.horizontalCenterOffset: (hwIsland.width - mediaIsland.width) / 2
        spacing: 10
        // Show pours out of the screen edge on two springs (height looser than
        // width, so it stretches and overshoots); hide is a plain eased pull
        // back in — a spring on the way out dips below zero and reads as jank.
        property real sx: 1
        property real sy: 1
        opacity: Math.min(1, Math.max(0, sy) * 2.5)
        transform: [
            Scale {
                origin.x: islandRow.width / 2; origin.y: -islandRow.anchors.topMargin
                xScale: Math.max(0, islandRow.sx)
                yScale: Math.max(0, islandRow.sy)
            }
        ]

        // ======================= LEFT — MEDIA =======================
        Rectangle {
            id: mediaIsland
            GlassRim { r: mediaIsland.radius; opacity: root.glow }

            width: root.mediaOpen || root.mediaNotify ? 320 : 40
            height: root.mediaOpen ? mediaCol.implicitHeight + 28 : root.mediaNotify ? 76 : 40
            radius: root.mediaOpen ? 28 : height / 2
            color: root.mediaOpen ? root.glass : root.pill
            border.width: 1
            border.color: root.mediaOpen ? root.edge : "transparent"
            clip: true

            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 240 } }
            Behavior on color { ColorAnimation { duration: 220 } }

            Specular { visible: root.mediaOpen }

            // DOT — the artwork is the island, ringed by how far through the track it is.
            Item {
                anchors.fill: parent
                visible: !root.mediaOpen && !root.mediaNotify
                ProgressRing {
                    anchors.fill: parent
                    visible: root.trackProgress > 0
                    value: root.trackProgress
                    stroke: root.accent
                    track: root.a(root.pillText, 0.14)
                }
                Art { anchors.centerIn: parent; width: 30; height: 30; radius: 15 }
            }

            // MEDIA notify (black pill). Ranks below the OSD and a notification.
            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 16 }
                visible: root.mediaNotify && !root.mediaOpen
                spacing: 12
                Art { width: 50; height: 50; radius: 12 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { Layout.fillWidth: true; text: root.player ? (root.player.trackTitle || "Unknown Track") : ""; color: root.pillText; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: root.player ? (root.player.trackArtist || "Unknown Artist") : ""; color: root.pillDim; font.family: root.fam; font.pixelSize: 12; elide: Text.ElideRight }
                }
                MediaControls { tint: root.pillText }
            }

            // PANEL — the player itself.
            ColumnLayout {
                id: mediaCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                visible: root.mediaOpen
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Art { width: 56; height: 56; radius: 14 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: root.player ? (root.player.trackTitle || "Unknown track") : "Nothing playing"
                            color: root.text1; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.player ? (root.player.trackArtist || "") : ""
                            color: root.text2; font.family: root.fam; font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.player ? (root.player.identity || "") : "Start something and it lands here"
                            color: root.text2; font.family: root.fam; font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                // Position, only when the player reports one.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 5
                    visible: root.trackProgress > 0
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        Rectangle { anchors.fill: parent; radius: 2; color: root.track }
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: parent.width * root.trackProgress
                            radius: 2; color: root.accent
                            Behavior on width { NumberAnimation { duration: 900 } }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: root.mmss(root.player ? root.player.position : 0); color: root.text2; font.family: root.fam; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Text { text: root.mmss(root.player ? root.player.length : 0); color: root.text2; font.family: root.fam; font.pixelSize: 11 }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    MediaControls { anchors.centerIn: parent }
                }
            }

            HoverHandler { id: mediaHover; onHoveredChanged: root.hoverChanged("media", hovered) }
            MouseArea {
                anchors.fill: parent
                z: -2
                onClicked: root.openIsland(root.mediaOpen ? "" : "media")
            }
        }

        // ====================== CENTRE — TIME =======================
        Rectangle {
            id: centreIsland
            GlassRim { r: centreIsland.radius; opacity: root.voiceShown ? 1 : root.glow; caustic: !root.voiceShown }

            width: root.centreOpen ? 344
                 : root.voiceShown ? 230
                 : root.osd !== "" ? 330
                 : root.notif !== null ? 460
                 : root.pillWidth

            height: root.centreOpen ? centreCol.implicitHeight + 28
                  : root.voiceShown ? 78
                  : root.osd !== "" ? 58
                  : root.notif !== null ? 76
                  : 40

            radius: root.centreOpen ? 28 : height / 2
            color: root.centreOpen ? root.glass : root.pill
            border.width: 1
            border.color: root.centreOpen ? root.edge : "transparent"
            clip: true

            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 240 } }
            Behavior on color { ColorAnimation { duration: 220 } }

            Specular { visible: root.centreOpen }

            // PILL — workspaces left, tray right, and the time dead centre of
            // the screen. The pill is sized symmetrically around the clock so
            // the one element at true centre never drifts as the sides change.
            Item {
                anchors.fill: parent
                visible: !root.centreBusy

                Row {
                    id: wsRow
                    anchors { left: parent.left; leftMargin: 15; verticalCenter: parent.verticalCenter }
                    spacing: 5
                    Repeater {
                        model: Hyprland.workspaces
                        Rectangle {
                            required property var modelData
                            visible: modelData.id > 0
                            width: modelData.focused ? 14 : 6
                            height: 6
                            radius: 3
                            color: modelData.focused ? root.accent : (modelData.urgent ? root.danger : root.pillDim)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            MouseArea { anchors.fill: parent; onClicked: Hyprland.dispatch("workspace " + modelData.id) }
                        }
                    }
                }

                Row {
                    id: clockRow
                    anchors.centerIn: parent
                    spacing: 0
                    FlipDigit { value: root.hhmm.charAt(0); pixelSize: 16 }
                    FlipDigit { value: root.hhmm.charAt(1); pixelSize: 16 }
                    Text { text: ":"; color: root.a(root.pillText, 0.5); font.family: root.fam; font.pixelSize: 16; font.weight: Font.DemiBold }
                    FlipDigit { value: root.hhmm.charAt(3); pixelSize: 16 }
                    FlipDigit { value: root.hhmm.charAt(4); pixelSize: 16 }
                }

                Row {
                    id: trayRow
                    anchors { right: parent.right; rightMargin: 15; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Glyph {
                        visible: root.dnd
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.ic.bellOff; color: root.pillDim; font.pixelSize: 13
                    }
                    Repeater {
                        model: SystemTray.items
                        Image {
                            required property var modelData
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.icon
                            sourceSize: Qt.size(28, 28)
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(m) {
                                    if (m.button === Qt.RightButton) { var p = mapToItem(null, 0, height); modelData.display(root, p.x, p.y) }
                                    else modelData.activate()
                                }
                            }
                        }
                    }
                }
            }

            // VOICE — the pill becomes a glass lens (GlassRim at full) with a
            // Siri-style waveform whose height follows the mic level; a steady
            // mid-height wave while transcribing.
            Item {
                id: voiceView
                anchors.fill: parent
                visible: root.voiceShown
                readonly property bool busy: root.voice === "transcribing"

                Row {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 13 }
                    spacing: 7
                    Glyph { text: root.ic.mic; color: voiceView.busy ? root.pillText : root.accent; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: voiceView.busy ? "Transcribing" : "Listening"
                        color: root.pillText; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    id: caustic
                    width: parent.width * 0.8; height: 32
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                    // Follows the voice: quick to rise, slower to fall.
                    property real level: voiceView.busy ? 0.35 : root.micTest >= 0 ? root.micTest : root.micLevel
                    Behavior on level { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                    // One clock; waves slide faster when louder by scaling phase, not the clock.
                    property real t: 0
                    NumberAnimation on t {
                        running: voiceView.visible; loops: Animation.Infinite
                        from: 0; to: 2 * Math.PI; duration: 1600
                    }
                    onTChanged: waveCanvas.requestPaint()
                    onLevelChanged: waveCanvas.requestPaint()

                    // Siri waveform: three sines under an envelope that pinches both
                    // ends to zero, amplitude driven by the voice, drawn additively.
                    Canvas {
                        id: waveCanvas
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d"), w = width, h = height, mid = h / 2
                            ctx.reset()
                            ctx.globalCompositeOperation = "lighter"
                            var lv = caustic.level
                            var waves = [
                                { c: root.accent, f: 3.0, sp: 2, amp: 1.0, a: 0.9 },
                                { c: root.themeFg, f: 4.5, sp: -3, amp: 0.7, a: 0.75 },
                                { c: Qt.tint(root.accent, Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.5)), f: 2.2, sp: 1, amp: 0.55, a: 0.6 }
                            ]
                            for (var k = 0; k < waves.length; k++) {
                                var wv = waves[k]
                                var A = mid * (0.08 + 0.92 * Math.sqrt(lv)) * wv.amp   // sqrt: normal speech reaches most of the height
                                ctx.beginPath()
                                for (var i = 0; i <= 64; i++) {
                                    var u = i / 64 * 4 - 2                         // -2..2
                                    var env = Math.pow(4 / (4 + Math.pow(u, 4)), 4)  // Siri's attenuation
                                    var y = mid - A * env * Math.sin(wv.f * u - caustic.t * wv.sp)
                                    if (i === 0) ctx.moveTo(0, y); else ctx.lineTo(i / 64 * w, y)
                                }
                                // Filled lens between the curve and the midline, then a crisp stroke.
                                ctx.lineTo(w, mid); ctx.lineTo(0, mid); ctx.closePath()
                                ctx.fillStyle = Qt.rgba(wv.c.r, wv.c.g, wv.c.b, 0.22 * wv.a)
                                ctx.fill()
                                ctx.beginPath()
                                for (var j = 0; j <= 64; j++) {
                                    var u2 = j / 64 * 4 - 2
                                    var env2 = Math.pow(4 / (4 + Math.pow(u2, 4)), 4)
                                    var y2 = mid - A * env2 * Math.sin(wv.f * u2 - caustic.t * wv.sp)
                                    if (j === 0) ctx.moveTo(0, y2); else ctx.lineTo(j / 64 * w, y2)
                                }
                                ctx.lineWidth = 1.6
                                // Fade the flat ends; overlapping there they add up to white.
                                var g = ctx.createLinearGradient(0, 0, w, 0)
                                g.addColorStop(0, Qt.rgba(wv.c.r, wv.c.g, wv.c.b, 0))
                                g.addColorStop(0.3, Qt.rgba(wv.c.r, wv.c.g, wv.c.b, wv.a))
                                g.addColorStop(0.7, Qt.rgba(wv.c.r, wv.c.g, wv.c.b, wv.a))
                                g.addColorStop(1, Qt.rgba(wv.c.r, wv.c.g, wv.c.b, 0))
                                ctx.strokeStyle = g
                                ctx.stroke()
                            }
                        }
                    }
                    layer.enabled: voiceView.visible
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.accent; shadowBlur: 0.6; shadowHorizontalOffset: 0; shadowVerticalOffset: 0; shadowOpacity: 0.9 }
                }
            }

            // OSD capsule (volume / brightness / keyboard)
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 18 }
                visible: root.osd !== "" && !root.voiceShown
                spacing: 12
                Capsule {
                    icon: root.osd === "brightness" ? root.ic.sun : root.osd === "kbd" ? root.ic.keyboard : (root.sink && root.sink.audio && root.sink.audio.muted ? root.ic.volOff : root.ic.volHigh)
                    muted: root.osd === "volume" && root.sink && root.sink.audio && root.sink.audio.muted
                    value: root.osd === "brightness" ? root.brightness / 100
                         : root.osd === "kbd" ? root.kbd / Math.max(root.kbdMax, 1)
                         : (root.sink && root.sink.audio ? root.sink.audio.volume : 0)
                    onMoved: function(v) {
                        if (root.osd === "volume" && root.sink) root.sink.audio.volume = v
                        else if (root.osd === "brightness") root.run(["brightnessctl", "-q", "-d", "intel_backlight", "set", Math.round(v * 100) + "%"])
                        osdTimer.restart()
                    }
                }
                Text {
                    text: Math.round((root.osd === "brightness" ? root.brightness / 100 : root.osd === "kbd" ? root.kbd / Math.max(root.kbdMax, 1) : (root.sink && root.sink.audio ? root.sink.audio.volume : 0)) * 100) + "%"
                    color: root.pillText; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold
                    Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight
                }
            }

            // NOTIFICATION (black pill). Outranks the media pill; the OSD outranks it.
            RowLayout {
                id: notifRow
                anchors { fill: parent; leftMargin: 14; rightMargin: 16 }
                visible: root.notif !== null && root.osd === "" && !root.centreOpen && !root.voiceShown
                spacing: 12

                NotifIcon { }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: root.notif ? (root.notif.summary || root.notif.appName || "Notification") : ""
                        color: root.notif && root.notif.urgency === NotificationUrgency.Critical ? root.danger : root.pillText
                        font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold
                        textFormat: Text.PlainText; elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.notifBody
                        color: root.pillDim
                        font.family: root.fam; font.pixelSize: 12
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                }

                // How many are still queued behind this one.
                Rectangle {
                    visible: root.notifs.length > 1
                    implicitWidth: 24; implicitHeight: 24; radius: 12
                    color: root.a(root.pillText, 0.14)
                    Text {
                        anchors.centerIn: parent
                        text: "+" + (root.notifs.length - 1)
                        color: root.pillText; font.family: root.fam; font.pixelSize: 11; font.weight: Font.DemiBold
                    }
                }
            }

            // Left click runs the notification's action, right click just clears it.
            // Outside notifRow because a MouseArea inside a RowLayout becomes a
            // layout item and would take a column of its own.
            MouseArea {
                anchors.fill: parent
                enabled: notifRow.visible
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(m) {
                    if (m.button === Qt.RightButton) root.notifClose(root.notif, true)
                    else root.notifActivate()
                }
            }

            // PANEL — the time at display size, the month under it, and the one
            // switch that decides whether any of it gets to go dark.
            ColumnLayout {
                id: centreCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                visible: root.centreOpen
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 6
                ColumnLayout {
                    id: timeCol
                    spacing: 0
                    Row {
                        spacing: 0
                        FlipDigit { value: root.hhmm.charAt(0); pixelSize: 46; color: root.text1 }
                        FlipDigit { value: root.hhmm.charAt(1); pixelSize: 46; color: root.text1 }
                        Text { text: ":"; color: root.a(root.themeFg, 0.4); font.family: root.fam; font.pixelSize: 46; font.weight: Font.DemiBold }
                        FlipDigit { value: root.hhmm.charAt(3); pixelSize: 46; color: root.text1 }
                        FlipDigit { value: root.hhmm.charAt(4); pixelSize: 46; color: root.text1 }
                    }
                    Text {
                        Layout.topMargin: 1
                        text: Qt.formatDate(clock.date, "dddd d MMMM")
                        color: root.text2; font.family: root.fam; font.pixelSize: 12
                    }
                }
                    // WEATHER — the other half of "what is it like right now",
                    // built to stand level with the clock rather than perch
                    // beside it. Opens the forecast page.
                    Module {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 6
                        radius: 18
                        visible: root.wx.temp !== ""
                        onClicked: root.centrePage = root.centrePage === "weather" ? "calendar" : "weather"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 9
                            Glyph {
                                text: root.wglyph(root.wx.desc, root.wx.localHour)
                                color: root.text1; font.pixelSize: 28
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: root.wx.temp + "\u00b0"
                                    color: root.text1; font.family: root.fam; font.pixelSize: 24; font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.wx.place
                                    color: root.text2; font.family: root.fam; font.pixelSize: 10; elide: Text.ElideRight
                                }
                            }
                            ColumnLayout {
                                spacing: 1
                                visible: root.wx.hi !== ""
                                Text { text: "H " + root.wx.hi + "\u00b0"; color: root.text2; font.family: root.fam; font.pixelSize: 10 }
                                Text { text: "L " + root.wx.lo + "\u00b0"; color: root.text2; font.family: root.fam; font.pixelSize: 10 }
                            }
                        }
                    }
                }

                Module {
                    Layout.fillWidth: true
                    visible: root.centrePage === "calendar"
                    implicitHeight: cal.implicitHeight + 24
                    hoverable: false
                    Calendar { id: cal; anchors { fill: parent; margins: 12 }
                        today: clock.date
                        accent: root.accent; fg: root.text1; dim: root.text2; fam: root.fam; accentText: root.accentText; chevL: root.ic.chevL; chevR: root.ic.chevR; icons: root.icons }
                }

                // ---- WEATHER (the forecast page, behind the header widget) ----
                // Three-hour steps for the next day, in the weather's own local
                // time — the strip starts at the slot after the place's now, not
                // after this machine's.
                Module {
                    Layout.fillWidth: true
                    visible: root.centrePage === "weather" && root.wx.hours.length > 0
                    implicitHeight: 86
                    hoverable: false
                    RowLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 0
                        Repeater {
                            model: root.centrePage === "weather" ? root.wx.hours : []
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 3
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: ("0" + modelData.hour).slice(-2)
                                    color: root.text2; font.family: root.fam; font.pixelSize: 10
                                }
                                Glyph {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.wglyph(modelData.desc, modelData.hour)
                                    color: root.text1; font.pixelSize: 17
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.temp + "\u00b0"
                                    color: root.text1; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold
                                }
                                // Only worth the pixels when it is actually likely.
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.rain >= 20 ? modelData.rain + "%" : ""
                                    color: root.accent; font.family: root.fam; font.pixelSize: 9
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.centrePage === "weather"
                    spacing: 10
                    SquareTile { icon: root.ic.thermo; label: root.wx.feels + "\u00b0"; sub: "Feels like"; implicitHeight: 70 }
                    SquareTile { icon: root.ic.humidity; label: root.wx.humidity + "%"; sub: "Humidity"; implicitHeight: 70 }
                    SquareTile { icon: root.ic.wind; label: root.wx.wind + " km/h"; sub: "Wind"; implicitHeight: 70 }
                }
                Section { visible: root.centrePage === "weather"; text: "PLACES" }
                Repeater {
                    model: root.centrePage === "weather" ? root.weatherPlaces : []
                    Row_ {
                        required property var modelData
                        required property int index
                        icon: root.ic.pin
                        label: modelData === "" ? "Here" : modelData
                        sub: modelData === "" ? "Outside the tunnel, where the machine is" : ""
                        on: root.weatherLoc === modelData
                        showCheck: true
                        onClicked: root.setWeather(index)
                    }
                }
                Row_ {
                    visible: root.centrePage === "weather" && root.weatherPlaces.length < 2
                    hoverable: false
                    icon: root.ic.chevD
                    label: "Add places"
                    sub: "~/.config/quickshell/weather-places, one per line"
                }

                // ---- NOTIFICATIONS (the centre panel's other page) ----
                Row_ {
                    visible: root.centrePage === "notifications"
                    icon: root.dnd ? root.ic.bellOff : root.ic.bell
                    label: "Do Not Disturb"; on: root.dnd; showCheck: true
                    sub: root.dnd ? "Silenced — urgent still gets through" : "Notifications show on the island"
                    onClicked: root.dnd = !root.dnd
                }
                Section { visible: root.centrePage === "notifications" && root.notifLog.length > 0; text: "RECENT" }
                Row_ {
                    visible: root.centrePage === "notifications" && root.notifLog.length === 0
                    hoverable: false
                    icon: root.ic.bell; label: "Nothing yet"; sub: "The last 10 land here"
                }
                Repeater {
                    model: root.centrePage === "notifications" ? root.notifLog : []
                    Row_ {
                        required property var modelData
                        icon: modelData.glyph !== "" ? modelData.glyph : root.ic.bell
                        label: modelData.summary
                        sub: modelData.body !== "" ? modelData.body : modelData.app
                        trailing: modelData.at
                        on: modelData.critical
                        hoverable: false
                    }
                }
                Row_ {
                    visible: root.centrePage === "notifications" && root.notifLog.length > 0
                    icon: root.ic.check; label: "Clear history"; trailing: "Clear"; action: true
                    onClicked: root.notifLog = []
                }

                // ---- STAY AWAKE + NOTIFICATIONS ----
                // The panel's two standing switches, side by side and visible on
                // both pages, so the notifications page can be left the same way
                // it was reached. Subs are kept to a word: at half width anything
                // longer elides to nothing.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Row_ {
                        // "Notifications" plus its chevron needs the wider half.
                        Layout.fillWidth: false
                        Layout.preferredWidth: 138
                        icon: root.ic.coffee
                        label: "Stay Awake"
                        on: root.stayAwake || root.autoAwake
                        sub: root.autoAwake ? (root.meetOpen ? "Meeting" : "Media")
                           : root.stayAwake ? "Held" : "Off"
                        onClicked: root.toggleStayAwake()
                    }
                    Row_ {
                        icon: root.dnd ? root.ic.bellOff : root.ic.bell
                        label: "Notifications"
                        on: root.dnd
                        sub: root.dnd ? "Silenced" : "On"
                        chevron: true
                        chevronIcon: root.centrePage === "notifications" ? root.ic.chevL : root.ic.chevR
                        onClicked: root.centrePage = root.centrePage === "notifications" ? "calendar" : "notifications"
                    }
                }
            }

            HoverHandler { id: centreHover; onHoveredChanged: root.hoverChanged("centre", hovered) }
            MouseArea {
                anchors.fill: parent
                z: -2
                onClicked: root.openIsland(root.centreOpen ? "" : "centre")
            }
        }

        // ==================== RIGHT — HARDWARE ======================
        Rectangle {
            id: hwIsland
            GlassRim { r: hwIsland.radius; opacity: root.glow }

            width: root.hwOpen ? 360 : 40
            height: root.hwOpen ? hwCol.implicitHeight + 28 : 40
            radius: root.hwOpen ? 28 : height / 2
            color: root.hwOpen ? root.glass : root.pill
            border.width: 1
            border.color: root.hwOpen ? root.edge : "transparent"
            clip: true

            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 240 } }
            Behavior on color { ColorAnimation { duration: 220 } }

            Specular { visible: root.hwOpen }

            // DOT — charge is the ring, the network is the core. One shape,
            // both facts, and the colour is the only thing that ever shouts.
            Item {
                anchors.fill: parent
                visible: !root.hwOpen
                ProgressRing {
                    anchors.fill: parent
                    value: root.battery ? root.battery.percentage : 0
                    track: root.a(root.pillText, 0.16)
                    stroke: !root.battery ? root.pillDim
                          : root.battery.state === UPowerDeviceState.Charging ? root.accent
                          : root.battery.percentage < 0.2 ? root.danger
                          : root.a(root.pillText, 0.5)
                }
                Glyph {
                    anchors.centerIn: parent
                    text: root.wifiOn ? root.ic.wifi : root.ic.wifiOff
                    color: root.wifiOn && root.ssid !== "" ? root.pillText : root.pillDim
                    font.pixelSize: 15
                }
            }

            // PANEL — everything the machine's hardware can be told to do.
            ColumnLayout {
                id: hwCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                visible: root.hwOpen
                spacing: 10

            // Power actions: four taps at the top, no page to walk into.
            RowLayout {
                Layout.fillWidth: true
                visible: root.page === ""
                spacing: 8
                Repeater {
                    model: [
                        { icon: root.ic.lock, cmd: ["omarchy", "system", "lock"] },
                        { icon: root.ic.night, cmd: ["systemctl", "suspend"] },
                        { icon: root.ic.restart, cmd: ["omarchy", "system", "reboot"] },
                        { icon: root.ic.power, cmd: ["omarchy", "system", "shutdown"] }
                    ]
                    Module {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 14
                        Glyph { anchors.centerIn: parent; text: modelData.icon; color: root.text1; font.pixelSize: 17 }
                        onClicked: { root.openIsland(""); Quickshell.execDetached(modelData.cmd) }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.page === ""
                spacing: 10

                Module {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 162
                    hoverable: false
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 10
                        ToggleRow {
                            Layout.fillWidth: true
                            icon: root.wifiOn ? root.ic.wifi : root.ic.wifiOff; label: "Wi‑Fi"; on: root.wifiOn
                            sub: root.wifiOn ? (root.ssid !== "" ? root.ssid : "Not connected") : "Off"
                            onToggled: { root.run(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"]); root.wifiOn = !root.wifiOn; wifiProbe.running = true }
                            onOpened: root.go("wifi")
                        }
                        ToggleRow {
                            Layout.fillWidth: true
                            icon: root.bt && root.bt.enabled ? root.ic.bt : root.ic.btOff; label: "Bluetooth"; on: root.bt ? root.bt.enabled : false
                            sub: {
                                if (!root.bt || !root.bt.enabled) return "Off"
                                var n = 0; for (var i = 0; i < root.bt.devices.values.length; i++) if (root.bt.devices.values[i].connected) n++
                                return n === 0 ? "On" : n + " connected"
                            }
                            onToggled: if (root.bt) root.bt.enabled = !root.bt.enabled
                            onOpened: root.go("bluetooth")
                        }
                        ToggleRow {
                            Layout.fillWidth: true
                            icon: root.sink && root.sink.audio && root.sink.audio.muted ? root.ic.volOff : root.ic.headphones
                            label: "Sound"
                            on: !(root.sink && root.sink.audio && root.sink.audio.muted)
                            sub: root.sink && root.sink.audio && root.sink.audio.muted ? "Muted" : (root.sink ? (root.sink.nickname || root.sink.description || "") : "No output")
                            onToggled: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                            onOpened: root.go("audio")
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 162
                    spacing: 10
                    Module {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        hoverable: false
                        ToggleRow {
                            anchors { fill: parent; margins: 12 }
                            icon: root.ic.fan; label: "Fans"; on: root.fanStat.profile === "performance"
                            sub: root.profileLabel(root.fanStat.profile)
                            onToggled: root.cycleProfile()
                            onOpened: root.go("fans")
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        SquareTile {
                            icon: root.ic.led; label: "Lid LEDs"; toggles: true
                            on: root.slash.enabled === true
                            sub: root.slash.enabled === true ? String(root.slash.display_mode || "On") : "Off"
                            onToggled: root.slashctl([root.slash.enabled === true ? "--disable" : "--enable"])
                            onClicked: root.go("slash")
                        }
                        SquareTile {
                            icon: root.ic.monitor; label: "Screen"
                            sub: root.refreshRate > 0 ? root.refreshRate + " Hz" : ""
                            onClicked: root.go("display")
                        }
                    }
                }
            }

            Row_ {
                visible: root.page === ""
                chevron: true
                icon: root.battery && root.battery.state === UPowerDeviceState.Charging ? root.ic.batteryChg : root.ic.battery
                on: root.battery !== null && root.battery.state === UPowerDeviceState.Charging
                label: root.battery ? Math.round(root.battery.percentage * 100) + "% battery" : "Battery"
                sub: {
                    if (!root.battery) return "No battery"
                    if (root.battery.state === UPowerDeviceState.Charging) return "Charging"
                    if (root.battery.state === UPowerDeviceState.PendingCharge || root.battery.state === UPowerDeviceState.FullyCharged) return "On power"
                    var s = root.battery.timeToEmpty
                    return s > 0 ? Math.floor(s / 3600) + "h " + Math.floor((s % 3600) / 60) + "m left" : "On battery"
                }
                onClicked: root.go("power")
            }

            SliderTile {
                visible: root.page === ""
                label: "Display"; icon: root.ic.sun
                value: root.brightness / 100
                trailing: root.brightness + "%"
                onMoved: function(v) { root.brightness = Math.round(v * 100); root.run(["brightnessctl", "-q", "-d", "intel_backlight", "set", root.brightness + "%"]) }
            }
            SliderTile {
                visible: root.page === ""
                label: "Sound"
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? root.ic.volOff : root.ic.volHigh
                muted: root.sink && root.sink.audio && root.sink.audio.muted
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                trailing: root.sink && root.sink.audio ? (root.sink.audio.muted ? "Muted" : Math.round(root.sink.audio.volume * 100) + "%") : ""
                onMoved: function(v) { if (root.sink) root.sink.audio.volume = v }
            }
            SliderTile {
                visible: root.page === ""
                label: "Keyboard Brightness"; icon: root.ic.keyboard
                value: root.kbd / Math.max(root.kbdMax, 1)
                onMoved: function(v) { root.kbd = Math.round(v * root.kbdMax); root.run(["brightnessctl", "-q", "-d", "asus::kbd_backlight", "set", String(root.kbd)]) }
            }

            PageHeader { visible: root.page === "wifi"; title: "Wi‑Fi" }
            Row_ {
                visible: root.page === "wifi"
                icon: root.wifiOn ? root.ic.wifi : root.ic.wifiOff; label: "Wi‑Fi"; on: root.wifiOn; trailing: root.wifiOn ? "On" : "Off"
                onClicked: { root.run(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"]); root.wifiOn = !root.wifiOn; wifiProbe.running = true }
            }
            Section { visible: root.page === "wifi" && root.networks.some(function(n) { return n.inUse }); text: "CONNECTED" }
            Repeater {
                model: root.page === "wifi" ? root.networks.filter(function(n) { return n.inUse }) : []
                Row_ {
                    required property var modelData
                    icon: modelData.secure ? root.ic.lock : root.ic.wifi
                    label: modelData.ssid
                    sub: "Connected · " + modelData.signal + "%"
                    on: true
                    showCheck: !hover
                    trailing: hover ? "Disconnect" : ""
                    action: true
                    onClicked: root.disconnectWifi()
                }
            }
            Section { visible: root.page === "wifi" && root.networks.some(function(n) { return !n.inUse }); text: "OTHER NETWORKS" }
            Repeater {
                model: root.page === "wifi" ? root.networks.filter(function(n) { return !n.inUse }) : []
                Row_ {
                    required property var modelData
                    icon: modelData.secure ? root.ic.lock : root.ic.wifi
                    label: modelData.ssid
                    trailing: modelData.signal + "%"
                    onClicked: root.connectWifi(modelData.ssid, "")
                }
            }
            Rectangle {
                visible: root.page === "wifi" && root.askPassFor !== ""
                Layout.fillWidth: true; implicitHeight: 40; radius: 14; color: root.tile
                border.color: root.accent; border.width: 1
                TextInput {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.text1; font.family: root.fam; font.pixelSize: 12
                    echoMode: TextInput.Password
                    focus: root.askPassFor !== ""
                    selectionColor: root.accent
                    onAccepted: { root.connectWifi(root.askPassFor, text); text = "" }
                    Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !parent.text; text: "Password for " + root.askPassFor + " · Enter to join"; color: root.text2; font.family: root.fam; font.pixelSize: 12 }
                }
            }

            // ---- BLUETOOTH ----
            PageHeader { visible: root.page === "bluetooth"; title: "Bluetooth" }
            Row_ {
                visible: root.page === "bluetooth"
                icon: root.bt && root.bt.enabled ? root.ic.bt : root.ic.btOff; label: "Bluetooth"; on: root.bt ? root.bt.enabled : false
                sub: root.bt && root.bt.discovering ? "Scanning…" : ""
                trailing: root.bt && root.bt.enabled ? "On" : "Off"
                onClicked: if (root.bt) root.bt.enabled = !root.bt.enabled
            }
            Section { visible: root.page === "bluetooth"; text: "DEVICES" }
            Repeater {
                model: root.page === "bluetooth" && root.bt ? root.bt.devices.values.filter(function(d) {
                    return d.name !== "" && !/^([0-9A-F]{2}-){5}[0-9A-F]{2}$/i.test(d.name) && (d.paired || d.connected || root.bt.discovering)
                }).sort(function(x, y) { return (y.connected - x.connected) || (y.paired - x.paired) }).slice(0, 8) : []
                Row_ {
                    required property var modelData
                    icon: root.ic.bt
                    label: modelData.name
                    sub: modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "") : modelData.paired ? "Paired" : "Available"
                    on: modelData.connected
                    trailing: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair")
                    action: true
                    onClicked: modelData.connected ? modelData.disconnect() : (modelData.paired ? modelData.connect() : modelData.pair())
                }
            }

            // ---- AUDIO ----
            PageHeader { visible: root.page === "audio"; title: "Sound" }
            Section { visible: root.page === "audio"; text: "OUTPUT" }
            Repeater {
                model: root.page === "audio" ? Pipewire.nodes.values.filter(function(n) { return n.isSink && !n.isStream && n.audio }) : []
                Row_ {
                    required property var modelData
                    icon: root.ic.headphones
                    label: modelData.nickname || modelData.description || modelData.name
                    on: Pipewire.defaultAudioSink === modelData
                    showCheck: true
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
            Section { visible: root.page === "audio"; text: "INPUT" }
            Repeater {
                model: root.page === "audio" ? Pipewire.nodes.values.filter(function(n) { return !n.isSink && !n.isStream && n.audio }) : []
                Row_ {
                    required property var modelData
                    icon: root.ic.mic
                    label: modelData.nickname || modelData.description || modelData.name
                    on: Pipewire.defaultAudioSource === modelData
                    showCheck: true
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }

            // ---- POWER ----
            PageHeader { visible: root.page === "power"; title: "Battery" }
            Row_ {
                visible: root.page === "power"
                hoverable: false
                icon: root.battery && root.battery.state === UPowerDeviceState.Charging ? root.ic.batteryChg : root.ic.battery
                on: root.battery && root.battery.state === UPowerDeviceState.Charging
                label: root.battery ? Math.round(root.battery.percentage * 100) + "%" : ""
                sub: root.battery && root.battery.state === UPowerDeviceState.Charging ? "Charging" : (root.chargeLimit > 0 ? "Charge limit " + root.chargeLimit + "%" : "On power")
            }

            // ---- FANS ----
            PageHeader { visible: root.page === "fans"; title: "Fans" }
            Section { visible: root.page === "fans"; text: "PROFILE" }
            Chips {
                visible: root.page === "fans"
                model: root.profiles
                current: root.fanStat.profile || ""
                onPicked: function(v) { root.setProfile(v) }
            }
            Section { visible: root.page === "fans"; text: "SPEEDS" }
            Repeater {
                model: root.page === "fans" ? root.fanStat.fans : []
                Row_ {
                    required property var modelData
                    hoverable: false
                    icon: root.ic.fan
                    label: String(modelData.label).replace("_fan", "").toUpperCase()
                    trailing: modelData.rpm + " rpm"
                }
            }
            Section { visible: root.page === "fans"; text: "THERMALS" }
            Row_ { visible: root.page === "fans"; hoverable: false; icon: root.ic.thermo; label: "CPU"; trailing: root.fanStat.cpu !== null && root.fanStat.cpu !== undefined ? root.fanStat.cpu + " °C" : "—" }
            Row_ { visible: root.page === "fans"; hoverable: false; icon: root.ic.gpu; label: "dGPU"; trailing: root.fanStat.dgpu || "—"; sub: root.fanStat.gpu !== null && root.fanStat.gpu !== undefined ? root.fanStat.gpu + " °C" : "" }

            // ---- SLASH LEDS ----
            PageHeader { visible: root.page === "slash"; title: "Lid LEDs" }
            Row_ {
                visible: root.page === "slash"
                icon: root.ic.led; label: "Slash"; on: root.slash.enabled === true; trailing: root.slash.enabled === true ? "On" : "Off"
                onClicked: root.slashctl([root.slash.enabled === true ? "--disable" : "--enable"])
            }
            SliderTile {
                visible: root.page === "slash"
                label: "Brightness"; icon: root.ic.sun
                value: (Number(root.slash.brightness) || 0) / 255
                onMoved: function(v) { var s = root.slash; s.brightness = Math.round(v * 255); root.slash = s; slashSettle.restart() }
            }
            Section { visible: root.page === "slash"; text: "ANIMATION" }
            Chips {
                visible: root.page === "slash"
                model: root.slashModes
                current: String(root.slash.display_mode || "")
                onPicked: function(v) { root.slashctl(["--mode", v]) }
            }
            Section { visible: root.page === "slash"; text: "INTERVAL" }
            Chips {
                visible: root.page === "slash"
                model: ["0", "1", "2", "3", "4", "5"]
                current: String(root.slash.display_interval !== undefined ? root.slash.display_interval : "")
                onPicked: function(v) { root.slashctl(["--interval", v]) }
            }
            Section { visible: root.page === "slash"; text: "SHOW" }
            Repeater {
                model: root.page === "slash" ? [
                    { key: "show_on_battery", flag: "-b", label: "On battery" },
                    { key: "show_on_boot", flag: "-B", label: "On boot" },
                    { key: "show_on_shutdown", flag: "-S", label: "On shutdown" },
                    { key: "show_on_sleep", flag: "-s", label: "On sleep" },
                    { key: "show_battery_warning", flag: "-w", label: "Low battery warning" }
                ] : []
                Row_ {
                    required property var modelData
                    label: modelData.label; on: root.slash[modelData.key] === true; showCheck: true
                    trailing: on ? "" : "Off"
                    onClicked: root.slashctl([modelData.flag, root.slash[modelData.key] === true ? "false" : "true"])
                }
            }

            // ---- DISPLAY ----
            PageHeader { visible: root.page === "display"; title: "Display" }
            SliderTile {
                visible: root.page === "display"
                label: "Brightness"; icon: root.ic.sun
                value: root.brightness / 100
                trailing: root.brightness + "%"
                onMoved: function(v) { root.brightness = Math.round(v * 100); root.run(["brightnessctl", "-q", "-d", "intel_backlight", "set", root.brightness + "%"]) }
            }
            Section { visible: root.page === "display"; text: "REFRESH RATE · " + root.monitorName }
            Chips {
                visible: root.page === "display"
                model: root.refreshRates.map(function(r) { return { value: String(r), label: r + " Hz" } })
                current: String(root.refreshRate)
                onPicked: function(v) { root.refreshRate = Number(v); displayAction.command = [Quickshell.env("HOME") + "/.config/omarchy/plugins/acs.monitor/refresh-rate", root.monitorName, v]; displayAction.running = true }
            }
            Section { visible: root.page === "display"; text: "NVIDIA dGPU" }
            Row_ {
                visible: root.page === "display"
                icon: root.ic.gpu
                label: root.dgpuControl === "on" ? "Always on" : "Automatic"
                sub: root.dgpuControl === "on" ? "Stays powered" : "Sleeps in D3cold when idle · now " + (root.dgpuStatus || "unknown")
                on: root.dgpuControl === "on"
                trailing: root.dgpuControl === "on" ? "Set automatic" : "Keep on"
                action: true
                onClicked: { displayAction.command = ["sudo", "-n", "/usr/local/bin/dgpu", root.dgpuControl === "on" ? "auto" : "on"]; displayAction.running = true }
            }

            }

            HoverHandler { id: hwHover; onHoveredChanged: root.hoverChanged("hw", hovered) }
            MouseArea {
                anchors.fill: parent
                z: -2
                onClicked: root.openIsland(root.hwOpen ? "" : "hw")
            }
        }
    }

    // Long enough to filter a cursor crossing the top of the screen: the row now
    // spans ~260px of that edge and the middle target is the clock, which is the
    // thing you cross the top of the screen to glance at. The close grace
    // outlasts any mask-change blip mid-animation.
    Timer { id: hoverOpen; interval: root.hiddenMode ? 350 : 180; onTriggered: { root.openIsland(root.hoverTarget); root.hoverOpened = true } }
    Timer { id: hoverClose; interval: 140; onTriggered: if (!root.anyHovered && root.askPassFor === "") root.openIsland("") }

    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.player !== null && root.player.isPlaying
        onTriggered: {
            var pl = root.player
            root.trackProgress = (pl && pl.positionSupported && pl.lengthSupported && pl.length > 0)
                ? Math.max(0, Math.min(1, pl.position / pl.length)) : 0
        }
    }
    onPlayerChanged: root.trackProgress = 0

    Timer { id: osdTimer; interval: 1400; onTriggered: root.osd = "" }
    Timer { id: mediaTimer; interval: 5000; onTriggered: root.mediaNotify = false }
    Timer { id: notifTimer; onTriggered: root.notifClose(root.notif, true) }
    Timer { id: fanSettle; interval: 700; onTriggered: fanProbe.running = true }
    Timer { id: idleSettle; interval: 600; onTriggered: idleProbe.running = true }
    Timer { id: slashSettle; interval: 150; onTriggered: root.slashctl(["-l", String(root.slash.brightness)]) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
}
