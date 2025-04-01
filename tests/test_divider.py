import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

@cocotb.test()
async def test_restoring_divider(dut):
    """Test the restoring_divider module."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(10, units="ns")
    
    dut.rst_n.value = 0
    dut.start.value   = 0
    dut.dividend.value = 0
    dut.divisor.value  = 0
    await Timer(10, units="ns")
    
    dut.rst_n.value = 1
    await Timer(10, units="ns")
    
    # apply test inputs: divide 11 by 3
    dut.dividend.value = 11
    dut.divisor.value  = 3
    dut.start.value    = 1  
    await Timer(10, units="ns")
    dut.start.value = 0
    
    while int(dut.done.value) == 0:
        await RisingEdge(dut.clk)
    
    # read and log the results
    quotient  = int(dut.quotient.value)
    remainder = int(dut.remainder.value)
    dut._log.info(f"Test completed: quotient = {quotient}, remainder = {remainder}")
    
    # check the expected results: for 11/3, quotient should be 3 and remainder should be 2
    assert quotient == 3, f"Quotient is {quotient}, expected 3"
    assert remainder == 2, f"Remainder is {remainder}, expected 2"
    
    await Timer(10, units="ns")
