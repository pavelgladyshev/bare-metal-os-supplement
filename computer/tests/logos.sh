#!/bin/sh
# Tests of the simulated computer (../computer.circ) by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# logOS on this circuit: boots Belfield, Blackrock and Glendalough twice, on the computer.circ of
# their own tree and on ../computer.circ with the tree's bootloader in its ROM, types the same
# commands at both shells (with ../../tools/run_logisim.py) and compares the two sessions.
# They must be the same, character for character.
#
#   ./logos.sh <Logisim jar> <circuit>          (make logos does it)
#
# The trees are logOS folders in which "make all" has been run, one for each version (clone
# https://github.com/pavelgladyshev/logos three times and check out 1.x-belfield, 2.x-blackrock
# and 3.x-glendalough); this script copies them and changes nothing in them. Name the ones to
# test in the environment, for example:
#
#   BELFIELD=~/logos-belfield BLACKROCK=~/logos-blackrock GLENDALOUGH=~/logos-glendalough make logos
#
# A version whose variable is empty is left out. A tree that is only checked out and not built
# can be given as BELFIELD_GIT instead of BELFIELD: its HEAD is copied and built in build/.
BELFIELD_GIT=${BELFIELD_GIT-}
BELFIELD=${BELFIELD-}
BLACKROCK=${BLACKROCK-}
GLENDALOUGH=${GLENDALOUGH-}
# A session of each kernel recorded earlier on its own circuit, to compare with as well (optional)
BELFIELD_SESSION=${BELFIELD_SESSION-}
BLACKROCK_SESSION=${BLACKROCK_SESSION-}
GLENDALOUGH_SESSION=${GLENDALOUGH_SESSION-}

[ $# -eq 2 ] || { echo "usage: $0 <Logisim jar> <circuit>"; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
JAR=$(realpath "$1"); CIRCUIT=$(realpath "$2")
[ -f "$JAR" ] || { echo "$0: no Logisim jar at $1"; exit 2; }
B=$HERE/build/logos
DRIVER=$HERE/../../tools/run_logisim.py
rm -rf "$B"; mkdir -p "$B"

# What Logisim prints is the session; Java's own lines about its preferences are not part of it
session() { grep -v -e 'java\.util\.prefs' -e '^WARNING: .*[Pp]ref' -e '^INFO: .*[Pp]ref' "$1"; }

run() {  # name, tree, command file, earlier session
  name=$1; tree=$2; cmds=$3; earlier=$4
  mkdir -p "$B/$name/own" "$B/$name/new"
  for f in computer.circ boot-rom.txt block_storage.bin; do
    cp "$tree/$f" "$B/$name/own/" && cp "$tree/$f" "$B/$name/new/" || { echo "FAIL  $name: no $f in $tree" > "$B/$name.result"; return; }
  done
  # the new circuit with the ROM contents of the tree's own circuit
  python3 - "$CIRCUIT" "$tree/computer.circ" "$B/$name/new/computer.circ" <<'PY' || { echo "FAIL  $name: no ROM contents" > "$B/$name.result"; return; }
import re, sys
new, own, out = sys.argv[1:4]
pattern = r'(<a name="contents">)(.*?)(</a>)'
contents = re.search(pattern, open(own).read(), re.S).group(2)
text, n = re.subn(pattern, lambda m: m.group(1) + contents + m.group(3), open(new).read(), count=1, flags=re.S)
assert n == 1
open(out, "w").write(text)
PY
  python3 "$DRIVER" --jar "$JAR" "$B/$name/own" "$B/$name/run-own" "$cmds" > "$B/$name/run-own.out" 2>&1 &
  own_pid=$!
  python3 "$DRIVER" --jar "$JAR" "$B/$name/new" "$B/$name/run-new" "$cmds" > "$B/$name/run-new.out" 2>&1
  new_status=$?
  wait $own_pid; own_status=$?
  if [ $own_status -ne 0 ] || [ $new_status -ne 0 ]; then
    echo "FAIL  $name: a session did not finish (own circuit: $own_status, computer.circ: $new_status)" > "$B/$name.result"; return
  fi
  session "$B/$name/run-own/session.log" > "$B/$name/own.session"
  session "$B/$name/run-new/session.log" > "$B/$name/new.session"
  lines=$(wc -l < "$B/$name/new.session")
  if ! cmp -s "$B/$name/own.session" "$B/$name/new.session"; then
    echo "FAIL  $name: the sessions differ (diff build/logos/$name/own.session build/logos/$name/new.session)" > "$B/$name.result"; return
  fi
  note=""
  if [ -n "$earlier" ]; then
    session "$earlier" > "$B/$name/earlier.session"
    if cmp -s "$B/$name/earlier.session" "$B/$name/new.session"; then note=", and the same as $earlier"
    else echo "FAIL  $name: the session differs from $earlier (build/logos/$name/earlier.session)" > "$B/$name.result"; return; fi
  fi
  echo "PASS  $name: $lines lines, the same on both circuits$note" > "$B/$name.result"
}

if [ -z "$BELFIELD" ] && [ -n "$BELFIELD_GIT" ]; then
  BELFIELD=$B/belfield-tree
  mkdir -p "$BELFIELD"
  git -C "$BELFIELD_GIT" archive HEAD | tar -x -C "$BELFIELD" || exit 2
  make -C "$BELFIELD" all > "$B/belfield-build.log" 2>&1 || { echo "$0: Belfield did not build (build/logos/belfield-build.log)"; exit 2; }
fi

if [ -z "$BELFIELD" ] && [ -z "$BLACKROCK" ] && [ -z "$GLENDALOUGH" ]; then
  echo "$0: name at least one logOS tree: BELFIELD=..., BLACKROCK=..., GLENDALOUGH=... (see the top of this file)"; exit 2
fi

[ -n "$BELFIELD" ] && run belfield "$BELFIELD" "$HERE/logos-belfield.cmds" "$BELFIELD_SESSION" &
[ -n "$BLACKROCK" ] && run blackrock "$BLACKROCK" "$HERE/logos-ten.cmds" "$BLACKROCK_SESSION" &
[ -n "$GLENDALOUGH" ] && run glendalough "$GLENDALOUGH" "$HERE/logos-ten.cmds" "$GLENDALOUGH_SESSION" &
wait
cat "$B"/*.result
! grep -q FAIL "$B"/*.result
