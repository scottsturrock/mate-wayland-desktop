#!/bin/sh
# Starts the desktop on an invisible (headless) display, takes a screenshot
# and reports which components are running. No real screen is needed, so it
# works over SSH and in CI. It runs on its own private D-Bus session so that
# nothing done inside the test (such as Log Out) can reach your real session.
#
# Usage: tests/headless-check.sh [output-directory]
set -u

here=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-$here/tests/out}
mkdir -p "$out"
log="${XDG_STATE_HOME:-$HOME/.local/state}/mate-wayland-desktop"
rm -f "$log"/*.log

before=$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$')

env -u WAYLAND_DISPLAY -u DISPLAY \
    WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
    MATE_WAYLAND_DESKTOP_NESTED=1 MATE_WAYLAND_DESKTOP_DIR="$here" XDG_CURRENT_DESKTOP=MATE XDG_MENU_PREFIX=mate- \
    dbus-run-session -- labwc -C "$here/labwc" >"$out/labwc.log" 2>&1 &
labwc_pid=$!
sleep 10

display=$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$' | grep -vxF "$before" | head -1)
if [ -z "$display" ]; then
    echo "FAIL: labwc did not start; see $out/labwc.log"
    exit 1
fi
export WAYLAND_DISPLAY=$display

# Open a window so the window list has something to show.
mate-terminal >/dev/null 2>&1 &
sleep 4
timeout 15 grim "$out/desktop.png" && echo "screenshot: $out/desktop.png"

status=0
for p in labwc mate-panel mate-settings-daemon caja; do
    if pgrep -f "(^|/)$p( |\$)" >/dev/null; then
        echo "running: $p"
    else
        echo "NOT running: $p"
        [ "$p" = caja ] || status=1
    fi
done

echo "--- warnings from component logs"
grep -H -i -E 'warning|error|critical|fail' "$log"/*.log 2>/dev/null | cut -c1-220

if [ -z "${KEEP:-}" ]; then
    pkill -f "labwc -C $here/labwc" 2>/dev/null
fi
exit $status
