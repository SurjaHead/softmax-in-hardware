import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

@cocotb.test()
async def test_restoring_divider(dut):
    """Test the restoring_divider module."""
    
    # Create and start a clock with a period of 10 ns
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Wait for a few clock cycles
    await Timer(10, units="ns")
    
    # Assert reset (active low)
    dut.rst_n.value = 0
    dut.start.value   = 0
    dut.dividend.value = 0
    dut.divisor.value  = 0
    await Timer(10, units="ns")
    
    # Deassert reset to allow the divider to operate
    dut.rst_n.value = 1
    await Timer(10, units="ns")
    
    # Apply test inputs: divide 11 by 3
    dut.dividend.value = 11
    dut.divisor.value  = 3
    dut.start.value    = 1  # Start the division operation
    await Timer(10, units="ns")
    dut.start.value = 0   # Pulse the start signal
    
    # Wait until the divider indicates completion via the done signal
    while int(dut.done.value) == 0:
        await RisingEdge(dut.clk)
    
    # Read and log the results
    quotient  = int(dut.quotient.value)
    remainder = int(dut.remainder.value)
    dut._log.info(f"Test completed: quotient = {quotient}, remainder = {remainder}")
    
    # Check the expected results: for 11/3, quotient should be 3 and remainder should be 2
    assert quotient == 3, f"Quotient is {quotient}, expected 3"
    assert remainder == 2, f"Remainder is {remainder}, expected 2"
    
    # Allow some time to observe outputs before finishing the test
    await Timer(10, units="ns")
