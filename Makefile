# Simulation parameters
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Use the correct file path and module name
VERILOG_SOURCES += $(PWD)/divider.sv

# Enable SystemVerilog support for Icarus Verilog
IVERILOG_ARGS += -g2012

test_pe:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s weight_stationary_pe -s dump -g2012 src/weight_stationary_pe.sv tests/dump_pe.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_pe vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_param_sys_array:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s parameterized_systolic_array -s dump -g2012 src/weight_stationary_pe.sv src/parameterized_systolic_array.sv tests/dump_param_sys_array.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_param_sys_array vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_divider:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s divider -s dump src/divider.sv tests/dump_divider.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_divider vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_fifo:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s fifo -s dump src/fifo.sv tests/dump_fifo.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_fifo vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_exp:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s exp -s dump src/exp.sv tests/dump_exp.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_exp vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_max:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s max -s dump src/fifo.sv src/max.sv tests/dump_max.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_max vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

# Other targets
clean::
	rm -rf __pycache__
	rm -rf sim_build 
	rm -f results.xml
	rm -f pe.vcd