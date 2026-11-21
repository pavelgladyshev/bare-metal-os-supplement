#!/bin/sh
# Tests of the simulated computer (../computer.circ) by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# A picture of the circuit in Logisim's window, running show.S (both digits lit, a line on the
# terminal): build/screenshot.png, and build/screenshot-digits.png and
# build/screenshot-keyboard.png, which are the new parts enlarged.
#
#   xvfb-run -a -s "-screen 0 3840x1700x24" ./screenshot.sh <Logisim jar> <circuit>
#   (make screenshot does it)
#
# It runs only on a display of its own (xvfb-run), never on yours, and with Logisim's default
# preferences (kept in build/prefs), so that the picture shows the window as Logisim first opens
# it. It needs xdotool and ImageMagick. CSR_PANEL=supervisor shows the CPU with its panel of CSRs.
case "$DISPLAY" in :0|:0.0|"") echo "screenshot.sh: run me with xvfb-run (DISPLAY is '$DISPLAY')"; exit 1;; esac
[ $# -eq 2 ] || { echo "usage: xvfb-run -a -s '-screen 0 3840x1700x24' $0 <Logisim jar> <circuit>"; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
JAR=$(realpath "$1"); CIRCUIT=$(realpath "$2"); B=$HERE/build
OUT=${OUT-$B/screenshot}
mkdir -p "$B/prefs"

# a copy of the circuit with the program in its ROM (and the CPU's panel of CSRs, if asked for)
python3 - "$CIRCUIT" "$B/show.txt" "$B/show.circ" "${CSR_PANEL-none}" <<'PY' || exit 2
import re, sys
circuit, image, out, panel = sys.argv[1:5]
words = open(image).read().split()[2:]                      # after "v2.0 raw"
rows = [" ".join("%x" % int(w, 16) for w in words[i:i + 8]) for i in range(0, len(words), 8)]
text, n = re.subn(r'(<a name="contents">addr/data: 14 32\n).*?(</a>)',
                  lambda m: m.group(1) + "\n".join(rows) + "\n" + m.group(2), open(circuit).read(), count=1, flags=re.S)
assert n == 1, "the ROM's contents were not found"
if panel != "none":
    tag = 'name="RV32IM CPU">'
    assert text.count(tag) == 1
    text = text.replace(tag, tag + '<a name="csrPanel" val="%s"/>' % panel)
open(out, "w").write(text)
PY

cd "$B" || exit 2
java -Djava.util.prefs.userRoot="$B/prefs" -jar "$JAR" --no-splash show.circ > screenshot.log 2>&1 &
PID=$!
WIN=""
for i in $(seq 60); do                                      # the window, within a minute
  WIN=$(xdotool search --pid $PID --onlyvisible --name 'Logisim' 2>/dev/null | tail -1)
  [ -n "$WIN" ] && break
  kill -0 $PID 2>/dev/null || break
  sleep 1
done
if [ -z "$WIN" ]; then echo "screenshot.sh: Logisim's window did not open (build/screenshot.log)"; kill $PID 2>/dev/null; exit 1; fi
sleep 5
# There is no window manager here: the keys go to the window under the pointer
eval $(xdotool getwindowgeometry --shell $WIN)
xdotool mousemove $((X + WIDTH - 40)) $((Y + HEIGHT - 60))
xdotool key ctrl+k                                          # Simulate > Auto-tick: the computer runs
sleep ${RUN:-6}
xdotool key ctrl+k
sleep 2
import -window root "$OUT.png"
kill $PID; wait $PID 2>/dev/null
rm -f "$OUT-opened.png"
convert "$OUT.png" -crop ${WIDTH}x${HEIGHT}+$X+$Y +repage "$OUT.png"       # the window alone
echo "screenshot.sh: $OUT.png ($(identify -format '%wx%h' "$OUT.png"))"
# the new parts, twice the size (the places are those of a window of 1920x1700 without the panel of CSRs)
if [ "${WIDTH}x${HEIGHT}" = 1920x1700 ] && [ "${CSR_PANEL-none}" = none ]; then
  convert "$OUT.png" -crop 720x560+1200+80 +repage -resize 200% "$OUT-digits.png"
  convert "$OUT.png" -crop 760x330+490+280 +repage -resize 200% "$OUT-keyboard.png"
  echo "screenshot.sh: $OUT-digits.png, $OUT-keyboard.png"
fi
