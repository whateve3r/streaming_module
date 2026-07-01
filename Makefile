TOP        = testbench
SRC        = module.sv
TB         = testbench.sv
VVP        = sim.vvp
WAVE       = wave.vcd

IVERILOG   = iverilog
VVP_RUN    = vvp
GTKWAVE    = gtkwave

IFLAGS     = -g2012

.PHONY: all sim wave clean

all: sim

$(VVP): $(SRC) $(TB)
	$(IVERILOG) $(IFLAGS) -s $(TOP) -o $(VVP) $(TB) $(SRC)

sim: $(VVP)
	$(VVP_RUN) $(VVP)

wave: sim
	$(GTKWAVE) $(WAVE) &

clean:
	rm -f $(VVP) $(WAVE)