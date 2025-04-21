import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

@cocotb.test()
async def test_fifo(dut):
    """Test the restoring_divider module."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(10, units="ns")
    
    dut.rst_n.value = 1

    await Timer(10, units="ns")
    
    dut.rst_n.value = 0
    dut.empty.value = 1
    dut.full.value = 0
    await Timer(10, units="ns")
    
    # apply test inputs: divide 11 by 3
    dut.empty.value = 0
    dut.write_en.value = 1
    dut.data_in.value = 3  

    await Timer(10, units="ns")
    dut.read_en.value = 1
    dut.data_in.value = 5 

    await Timer(10, units="ns")
    dut.data_in.value = 9

    await Timer(10, units="ns")
    dut.data_in.value = 2
    
    await Timer(10, units="ns")
    dut.write_en.value = 0
    dut.read_en.value = 1

    await Timer(10, units="ns")
    dut.read_en.value = 1

    await Timer(10, units="ns")
    dut.read_en.value = 1

    await Timer(10, units="ns")
    dut.read_en.value = 1
