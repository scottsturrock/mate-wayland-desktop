#!/bin/sh
# Build the ISO and show what it is doing.
#
#   ./build.sh              build the ISO (quick if only our session or
#                           configuration changed, full if packages changed)
#   ./build.sh --fresh      rebuild the ISO's system from scratch
#   ./build.sh --packages   first rebuild the MATE packages listed in
#                           packaging/packages.conf, then the ISO
#
# Asks for the sudo password if needed. Full output goes to iso/build.log.
# Result: iso/out/mate-wayland-desktop-<release>-amd64.iso (or $OUT).
set -eu

top=$(cd "$(dirname "$0")" && pwd)
log="$top/iso/build.log"
# Not in /tmp: root may not write to another user's file there.
progress="$top/iso/.build-progress"
: > "$progress"
trap 'rm -f "$progress"' EXIT

packages=0
args=
for arg in "$@"; do
    case "$arg" in
        --packages) packages=1 ;;
        --fresh) args="--fresh" ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

sudo true
start=$(date +%s)
: > "$log"

(
    if [ "$packages" -eq 1 ]; then
        echo "Building the MATE packages (about 10 minutes)" >> "$progress"
        sudo "$top/packaging/build-all.sh" || exit 1
    fi
    # shellcheck disable=SC2086
    sudo env MWD_PROGRESS="$progress" ${OUT:+OUT="$OUT"} "$top/iso/build-iso.sh" $args
) >> "$log" 2>&1 &
job=$!

# One line per stage, and under it a live line with the latest output.
shown=0
width=$(( $(tput cols 2>/dev/null || echo 100) - 12 ))
while kill -0 "$job" 2>/dev/null; do
    total=$(wc -l < "$progress")
    if [ "$total" -gt "$shown" ]; then
        printf '\r\033[K'
        sed -n "$((shown + 1)),${total}p" "$progress" | while read -r line; do
            printf '[%s] %s\n' "$(date +%H:%M:%S)" "$line"
        done
        shown=$total
    fi
    elapsed=$(( $(date +%s) - start ))
    last=$(tail -c 2000 "$log" | tr '\r' '\n' | grep -v '^$' | tail -n 1 | cut -c1-"$width")
    printf '\r\033[K  %02d:%02d  %s' $((elapsed / 60)) $((elapsed % 60)) "$last"
    sleep 1
done
printf '\r\033[K'
total=$(wc -l < "$progress")
if [ "$total" -gt "$shown" ]; then
    sed -n "$((shown + 1)),${total}p" "$progress" | while read -r line; do
        printf '[%s] %s\n' "$(date +%H:%M:%S)" "$line"
    done
fi

elapsed=$(( $(date +%s) - start ))
if wait "$job"; then
    printf 'Finished in %d min %d s. Full log: %s\n' $((elapsed / 60)) $((elapsed % 60)) "$log"
else
    printf '\nBUILD FAILED after %d min %d s. Last lines of %s:\n\n' $((elapsed / 60)) $((elapsed % 60)) "$log"
    tail -n 25 "$log"
    exit 1
fi
