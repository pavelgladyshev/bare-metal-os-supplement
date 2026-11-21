#!/bin/sh
# make check-template: every project's Makefile must have the common part of template/Makefile
# (from the line "# --- Common part" to the line "# --- End of the common part ---", byte for
# byte), and the projects that use the template's linker script must have it unchanged.
# Usage: check_template.sh MAKEFILE_PROJECT... -- LDS_PROJECT...
# By Pavel Gladyshev, licensed under Creative Commons Attribution International license 4.0

top=$(cd "$(dirname "$0")/.." && pwd)
status=0
tmp=$(mktemp)
trap 'rm -f "$tmp" "$tmp.t" "$tmp.p"' EXIT

common() {
    sed -n '/^# --- Common part/,/^# --- End of the common part ---$/p' "$1"
}

if [ -z "$(common "$top/template/Makefile")" ]; then
    echo "NOT OK  template/Makefile has no common part (the lines between '# --- Common part' and '# --- End of the common part ---')"
    exit 1
fi

while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    p=$1; shift
    if [ "$(common "$top/$p/Makefile")" = "$(common "$top/template/Makefile")" ] &&
       [ -n "$(common "$top/$p/Makefile")" ]; then
        echo "ok      $p/Makefile: the common part is the template's"
    else
        echo "NOT OK  $p/Makefile: the common part differs from template/Makefile's"
        common "$top/template/Makefile" > "$tmp.t"
        common "$top/$p/Makefile" > "$tmp.p"
        diff "$tmp.t" "$tmp.p" | head -10
        status=1
    fi
done
[ "$1" = "--" ] && shift

for p in "$@"; do
    if cmp -s "$top/$p/logisim.lds" "$top/template/logisim.lds"; then
        echo "ok      $p/logisim.lds: the same as the template's"
    else
        echo "NOT OK  $p/logisim.lds differs from template/logisim.lds"
        status=1
    fi
done
exit $status
