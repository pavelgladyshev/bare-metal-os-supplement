# The Tang Nano 20K as a microSD card reader and writer over its USB serial port.
#
#   make          build sdbridge.fs (needs the Gowin toolchain in ~/gowin, as Logisim's FPGA flow does)
#   make load     load it into the FPGA (until the board is unplugged)
#   make flash    write it into the board's flash (it then starts whenever the board is powered)
#   make sim      simulate it with a model of a card (needs iverilog)

GOWIN  ?= $(HOME)/gowin/bin
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
RTL     = rtl/sdbridge.v rtl/riscvSdBlockStorage.v

all: sdbridge.fs

build/sdbridge.json: $(RTL)
	mkdir -p build
	$(GOWIN)/yosys -q -l build/yosys.log -p "read_verilog $(RTL); synth_gowin -top sdbridge -json $@"

build/pnr.json: build/sdbridge.json tangnano20k.cst
	$(GOWIN)/nextpnr-himbaechel -q --json $< --write $@ --device $(DEVICE) --vopt family=$(FAMILY) \
	    --vopt cst=tangnano20k.cst --freq 27 --log build/nextpnr.log

sdbridge.fs: build/pnr.json
	$(GOWIN)/gowin_pack -d $(FAMILY) --sspi_as_gpio -o $@ $<

load: sdbridge.fs
	$(GOWIN)/openFPGALoader -b tangnano20k $<

flash: sdbridge.fs
	$(GOWIN)/openFPGALoader -b tangnano20k -f $<

sim:
	mkdir -p build
	for cfg in "1 1" "0 1" "1 0"; do set -- $$cfg; \
	  iverilog -g2012 -DHC=$$1 -DPRESENT=$$2 -o build/tb sim/tb_sdbridge.v $(RTL) sim/sd_card_model.v && \
	  echo "card: high capacity $$1, present $$2" && vvp -n build/tb | grep -E "PASSED|FAILED"; done

clean:
	rm -rf build sdbridge.fs

.PHONY: all load flash sim clean
