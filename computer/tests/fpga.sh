#!/bin/sh
# Tests of the simulated computer (../computer.circ) by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# Logisim's FPGA flow for the Tang Nano 20K, without Logisim's window and WITHOUT loading the
# board: first the HDL only, then the whole flow (yosys, nextpnr, gowin_pack) with a stand-in
# for openFPGALoader that loads nothing. Prints the LUTs, the flip-flops and the highest clock
# frequency that nextpnr reports.
#
#   ./fpga.sh <Logisim jar> <circuit>           (make fpga does it; about ten minutes)
#
# GOWIN is the folder of the Gowin tools (bin/yosys, bin/nextpnr-himbaechel, bin/gowin_pack,
# with pyenv and share beside bin). The flow runs in build/fpga with preferences of its own
# (build/fpga/prefs), so that Logisim's own are not touched. HDLONLY=1 stops after the HDL.
GOWIN=${GOWIN-$HOME/gowin}
BOARD=SIPEED_TANG_NANO_20K
TICKS=2048000                       # Logisim's tick frequency on the board, in Hz

[ $# -eq 2 ] || { echo "usage: $0 <Logisim jar> <circuit>"; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
JAR=$(realpath "$1"); CIRCUIT=$(realpath "$2")
B=${FPGA_DIR-$HERE/build/fpga}
rm -rf "$B"; mkdir -p "$B/tools/bin" "$B/prefs/.java/.userPrefs/com/cburch/logisim"
cp "$CIRCUIT" "$B/computer.circ"

# the tools, with the stand-in loader
for t in yosys nextpnr-himbaechel gowin_pack; do ln -s "$GOWIN/bin/$t" "$B/tools/bin/$t"; done
ln -s "$GOWIN/pyenv" "$B/tools/pyenv"; ln -s "$GOWIN/share" "$B/tools/share"
cat > "$B/tools/bin/openFPGALoader" <<'STUB'
#!/bin/sh
# stand-in: says what it was asked to load, and loads nothing
for a; do last="$a"; done
[ -s "$last" ] || { echo "STAND-IN openFPGALoader: no bitstream $last"; exit 1; }
echo "STAND-IN openFPGALoader (nothing is loaded): $*"
STUB
chmod +x "$B/tools/bin/openFPGALoader"

# Logisim's preferences for this run: where it works, Verilog, and where the tools are
cat > "$B/prefs/.java/.userPrefs/com/cburch/logisim/prefs.xml" <<PREFS
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE map SYSTEM "http://java.sun.com/dtd/preferences.dtd">
<map MAP_XML_VERSION="1.0">
  <entry key="FPGAWorkspace" value="$B/ws"/>
  <entry key="hdlType" value="Verilog"/>
  <entry key="GowinToolPath" value="$B/tools/bin/"/>
</map>
PREFS

flow() {  # log file, then HDLONLY or nothing
  ( cd "$B" && env -u DISPLAY java -Djava.util.prefs.userRoot="$B/prefs" -Djava.awt.headless=true -jar "$JAR" \
      --test-fpga "$B/computer.circ" main $BOARD $2 $TICKS > "$1" 2>&1 )
}

flow "$B/hdl.log" HDLONLY; status=$?
echo "HDL only: exit status $status, $(grep -c 'Creating HDL file' "$B/hdl.log") HDL files, $(grep -c ' WARN ' "$B/hdl.log") warnings, $(grep -c ' ERROR ' "$B/hdl.log") errors ($B/hdl.log)"
[ $status -eq 0 ] || { grep ' ERROR ' "$B/hdl.log"; exit 1; }
[ -n "$HDLONLY" ] && exit 0

flow "$B/flow.log" ""; status=$?
echo "whole flow: exit status $status ($B/flow.log)"
for cell in LUT4 MUX2_LUT5 ALU DFF RAM16SDP4 BSRAM MULT36X36 IOB; do
  grep "Info: .* $cell:" "$B/flow.log" | tail -1 | sed 's/.*Info: *//; s/^[ \t]*/  /'
done
grep 'Max frequency' "$B/flow.log" | tail -1 | sed 's/.*Info: /  /'
grep -e 'STAND-IN' "$B/flow.log" | sed 's/.*Reporter - /  /'
ls -l "$B"/ws/computer/main/sandbox/toplevel.fs 2>/dev/null | awk '{print "  bitstream: " $5 " bytes"}'
[ $status -eq 0 ]
