import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

@cocotb.test()
async def test_fifo(dut):
    """Test the restoring_divider module."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(10, units="ns")
    
    dut.rst.value = 1

    await Timer(10, units="ns")
    
    dut.rst.value = 0
    dut.x.value = 1
    dut.x_max.value = 15
    await Timer(10, units="ns")
    
    # apply test inputs: divide 11 by 3
    dut.x.value = 10
    dut.x_max.value = 10

    await Timer(10, units="ns")
    dut.x.value = -3
    dut.x_max.value = 7

    await Timer(10, units="ns")
    dut.x.value = -5
    dut.x_max.value = -3
    
    await Timer(10, units="ns")