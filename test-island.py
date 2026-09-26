#!/usr/bin/env python3
"""End-to-end checks of the island, run against the live one.

Covers the three things that can silently rot: the queue (arrive, show one,
advance, drain), the rounded artwork (Qt's clip is rectangular, so the art is
masked -- if the mask regresses the corners go square and nobody notices), and
the fallback for an icon name the theme does not have (which Qt otherwise
paints as a magenta broken-texture checkerboard).

Runs against the running island over its IPC, because the island renders with
the GPU. An offscreen Qt falls back to the software scenegraph, which cannot
run the mask shader at all, and a screenshot of the top of the screen is
blocked whenever any window is fullscreen.

    python3 test-island.py
"""
import json
import os
import subprocess
import sys
import tempfile
import time

from PIL import Image

ART = (255, 0, 255)
IDLE_PROBE = """
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    IdleMonitor { id: respecting; enabled: true; timeout: 3; respectInhibitors: true }
    IdleMonitor { id: ignoring;   enabled: true; timeout: 3; respectInhibitors: false }
    Timer {
        running: true; interval: 5000
        onTriggered: {
            console.log("RESULT respecting=" + respecting.isIdle + " ignoring=" + ignoring.isIdle)
            Qt.exit(0)
        }
    }
}
"""


def ipc(*args):
    return subprocess.run(["qs", "ipc", "call", "island", *args],
                          capture_output=True, text=True, timeout=20).stdout.strip()


def queue():
    depth, _, head = ipc("notifs").partition(" ")
    return int(depth), head


def send(*args):
    subprocess.run(["notify-send", *args], check=True, timeout=20)


def drain():
    """Clear the queue through the island rather than guessing notification ids."""
    ipc("dismiss")
    time.sleep(0.5)


def close_from_sender(): 
    """Close whatever is queued the way a sending app would, over the bus."""
    for _ in range(30):
        depth, _head = queue()
        if depth == 0:
            return
        before = depth
        for i in range(1, 200):
            subprocess.run(["gdbus", "call", "--session",
                            "--dest", "org.freedesktop.Notifications",
                            "--object-path", "/org/freedesktop/Notifications",
                            "--method", "org.freedesktop.Notifications.CloseNotification",
                            str(i)], capture_output=True, timeout=20)
        time.sleep(0.4)
        if queue()[0] == before:
            return


def wake_display():
    """A powered-down panel is not rendering, so grabToImage never completes.

    `hyprctl dispatch dpms on` does not work against this machine's Lua
    Hyprland config; omarchy's own wake does.
    """
    subprocess.run(["omarchy", "system", "wake"], capture_output=True, timeout=20)
    time.sleep(1.2)


def art_fill_ratio(png):
    """Share of the artwork's bounding box the artwork actually paints.

    A square fills its box (1.0). The island's 44px art has a 12px corner
    radius, so it should lose about 6% of the box to the four corners.
    """
    px = Image.open(png).convert("RGBA").load()
    im = Image.open(png)
    pts = [(x, y) for y in range(im.height) for x in range(im.width)
           if px[x, y][0] > 200 and px[x, y][2] > 200 and px[x, y][1] < 80]
    assert pts, "no artwork in the grab -- the image never rendered"
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    box = (max(xs) - min(xs) + 1) * (max(ys) - min(ys) + 1)
    return len(pts) / box


def idle_probe(work):
    """Ask the compositor whether an idle inhibitor is active and honoured.

    Two idle monitors, one respecting inhibitors and one ignoring them. They
    only disagree when an inhibitor is held AND Hyprland honours it, which is
    exactly what keeps Omarchy's screensaver and lock from firing.
    """
    qml = os.path.join(work, "idleprobe.qml")
    with open(qml, "w") as fh:
        fh.write(IDLE_PROBE)
    env = dict(os.environ, QT_FORCE_STDERR_LOGGING="1")
    out = subprocess.run(["quickshell", "-p", qml], env=env,
                         capture_output=True, text=True, timeout=60)
    line = [l for l in (out.stdout + out.stderr).splitlines() if "RESULT" in l]
    assert line, "idle probe produced nothing:\n%s%s" % (out.stdout, out.stderr)
    return ("respecting=true" in line[-1], "ignoring=true" in line[-1])


def check_idle_inhibit(work):
    # Something already holding the inhibitor (media playing, say) hides the
    # compositor-side difference. The island's own detection is still testable.
    already = "inhibit=true" in ipc("awake")
    if not already:
        respecting, ignoring = idle_probe(work)
        assert respecting == ignoring, "an idle inhibitor is held that the island does not report"

    # A window whose title looks like a Google Meet call must hold the inhibitor.
    win = subprocess.Popen(["foot", "--title", "Meet - zzz-test-call",
                            "--app-id", "islandidlecheck", "sh", "-c", "sleep 30"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           start_new_session=True)
    try:
        time.sleep(3)
        state = ipc("awake")
        assert "meet=true" in state, "island did not see the Meet window: %s" % state
        assert "inhibit=true" in state, "island saw Meet but held no inhibitor: %s" % state
        if already:
            print("SKIP  something else already holds the inhibitor, so the "
                  "compositor side cannot be isolated")
        else:
            respecting, ignoring = idle_probe(work)
            if not ignoring:
                print("SKIP  session is not idle, so the compositor side cannot be observed")
            else:
                assert not respecting, "Hyprland did not honour the island's idle inhibitor"
    finally:
        win.terminate()
        win.wait(timeout=10)

    time.sleep(2)
    state = ipc("awake")
    assert "meet=false" in state, "island still sees a Meet window after it closed: %s" % state
    if not already:
        assert "inhibit=false" in state, "inhibitor was not released: %s" % state
    print("PASS  a Meet window holds the idle inhibitor and releases it on close")


def weather(place=""):
    ipc("weather", place)
    time.sleep(4)
    return ipc("weather", "")


def check_weather():
    """The weather must be for where the machine is, not where the VPN exits.

    This is the failure that would never announce itself: inside the Mullvad
    tunnel wttr.in answers for the relay, and the island shows Glasgow's rain
    while the machine sits in Bengaluru. The query is split out with
    mullvad-exclude; this checks the split is still doing something.
    """
    state = weather("here")
    assert "loc=-here-" in state, "weather would not go back to the machine's location: %s" % state
    place = state.split(" ")[0]
    assert place, "no weather came back: %s" % state

    def city(cmd):
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=20).stdout
        return json.loads(out)["city"] if out.strip() else ""

    outside = city(["mullvad-exclude", "curl", "-sf", "--max-time", "10", "https://ipinfo.io/json"])
    inside = city(["curl", "-sf", "--max-time", "10", "https://ipinfo.io/json"])
    if not outside or not inside:
        print("SKIP  no IP lookup, so the tunnel split cannot be compared")
    elif inside == outside:
        print("SKIP  the tunnel is down, so there is no wrong location to catch")
    else:
        # Names differ between providers (ipinfo says Bengaluru, wttr.in says
        # Bangalore), so the load-bearing assertion is the negative one.
        assert inside.lower() not in place.lower(), \
            "weather reports the VPN exit (%s), not the machine (%s)" % (inside, outside)

    check_forecast("here", same_timezone_as_machine=True)

    # An alternate location, saved or not, and back again.
    alt = weather("Reykjavik")
    assert alt.startswith("Reykjavik "), "alternate location did not take: %s" % alt
    assert "loc=Reykjavik" in alt, "alternate location did not stick: %s" % alt
    check_forecast("Reykjavik", same_timezone_as_machine=False)

    back = weather("here")
    assert back.startswith(place + " "), "would not return to %s: %s" % (place, back)
    print("PASS  weather is for %s, outside the tunnel (which exits in %s); "
          "alternate locations and their hourly forecasts work" % (place, inside or "-"))


def check_forecast(label, same_timezone_as_machine):
    """The hourly strip must start after the *place's* hour, not this machine's.

    The forecast slots are stamped in the queried place's local time. Read them
    against the wrong clock and the strip silently shows hours that have already
    been and gone -- which looks perfectly plausible, which is the problem.
    """
    state = dict(kv.split("=", 1) for kv in ipc("forecast").split(" "))
    local, here = int(state["localHour"]), int(state["here"])
    slots = [int(h) for h in state["slots"].split(",") if h != ""]

    assert len(slots) == 8, "%s: forecast has %d slots, wanted 8" % (label, len(slots))
    assert all(h % 3 == 0 for h in slots), "%s: slots are not three-hourly: %s" % (label, slots)

    # Hours ascend and wrap at most once -- one midnight inside a 24h window.
    wraps = sum(1 for a, b in zip(slots, slots[1:]) if b < a)
    assert wraps <= 1, "%s: slots wrap more than once: %s" % (label, slots)

    # The first slot is the next one strictly after the place's own hour.
    expected = ((local // 3) * 3 + 3) % 24
    assert slots[0] == expected, \
        "%s: strip starts at %02d, but the place's clock says %02d so it should start at %02d" \
        % (label, slots[0], local, expected)

    if not same_timezone_as_machine and local == here:
        print("SKIP  %s happens to share this machine's hour, so the clocks cannot be told apart"
              % label)
    elif not same_timezone_as_machine:
        # The whole point: read against the machine's clock the strip would start elsewhere.
        assert slots[0] != ((here // 3) * 3 + 3) % 24, \
            "%s: strip starts where this machine's clock would put it (%02d), not the place's (%02d)" \
            % (label, here, local)


def main():
    assert ipc("notifs"), "island not running, or its IPC is gone"
    work = tempfile.mkdtemp(prefix="island-check-")
    drain()
    assert queue()[0] == 0, "queue would not drain"

    # Queue: three arrive, the newest is the one on screen.
    for name in ("Alpha", "Beta", "Gamma"):
        send("-u", "critical", name, "body")
        time.sleep(0.3)
    time.sleep(0.6)
    depth, head = queue()
    assert (depth, head) == (3, "Gamma"), "queue is %d/%s, wanted 3/Gamma" % (depth, head)

    # Dismissing one uncovers the next newest, not the oldest.
    ipc("dismissOne")
    time.sleep(0.4)
    assert queue() == (2, "Beta"), "dismissOne left %d/%s, wanted 2/Beta" % queue()

    # Critical notifications wait to be dismissed rather than expiring.
    time.sleep(9)
    assert queue() == (2, "Beta"), "a critical notification expired on its own"
    close_from_sender()
    assert queue()[0] == 0, "sender-side close left notifications behind"

    # Do not disturb silences the ordinary and lets the urgent through, and the
    # history keeps both either way.
    ipc("clearHistory")
    assert ipc("dnd") == "on", "dnd would not turn on"
    send("Quiet", "body")
    time.sleep(0.6)
    assert queue()[0] == 0, "a silenced notification reached the island"
    send("-u", "critical", "Loud", "body")
    time.sleep(0.6)
    assert queue() == (1, "Loud"), "dnd swallowed a critical notification"
    assert ipc("dnd") == "off", "dnd would not turn off"
    drain()
    assert ipc("history") == "2 entries", "history holds %s, wanted 2" % ipc("history")
    ipc("clearHistory")
    assert ipc("history") == "0 entries", "history would not clear"

    # Artwork: rounded, not square.
    src = os.path.join(work, "art.png")
    grab = os.path.join(work, "grab.png")
    Image.new("RGB", (120, 120), ART).save(src)
    send("-u", "critical", "-i", src, "Art", "rounded?")
    time.sleep(1)
    wake_display()
    ipc("grab", grab)
    time.sleep(0.8)
    ratio = art_fill_ratio(grab)
    assert ratio < 0.97, "artwork corners are square (fill %.3f)" % ratio
    assert ratio > 0.88, "artwork lost too much to the mask (fill %.3f)" % ratio
    drain()

    # An icon name the theme has no icon for must reach the glyph fallback, not
    # Qt's magenta checkerboard.
    broken = os.path.join(work, "broken.png")
    send("-u", "critical", "-i", "zzz-no-such-icon-" + str(os.getpid()), "Missing", "icon")
    time.sleep(1)
    wake_display()
    ipc("grab", broken)
    time.sleep(0.8)
    im = Image.open(broken).convert("RGBA")
    px = im.load()
    checker = sum(1 for y in range(im.height) for x in range(im.width)
                  if px[x, y][0] > 200 and px[x, y][2] > 200 and px[x, y][1] < 80)
    assert checker == 0, "unknown icon name painted %d checkerboard pixels" % checker
    drain()

    print("PASS  newest is on screen, queue advances and drains; dnd silences all but "
          "critical and the history keeps both; artwork fill %.3f (square would be 1.0); "
          "unknown icon falls back to the glyph" % ratio)

    check_idle_inhibit(work)
    check_weather()


if __name__ == "__main__":
    sys.exit(main())
