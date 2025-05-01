import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_fifo(dut):
    """Test the FIFO module with basic write and read operations."""
    
    # Start clock with a 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst.value = 1
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.data_in.value = 0
    
    # Apply reset
    await Timer (10, units="ns")
    dut.rst.value = 0
    await Timer (10, units="ns")
    
    # Write 4 values to the FIFO
    dut.wr_en.value = 1
    dut.data_in.value = 10
    await Timer (10, units="ns")
    
    dut.data_in.value = 20
    await Timer (10, units="ns")
    
    dut.data_in.value = 30
    await Timer (10, units="ns")
    
    dut.data_in.value = 40
    await Timer (10, units="ns")
    
    dut.wr_en.value = 0
    await Timer (10, units="ns")
    
    # Read 4 values from the FIFO
    dut.rd_en.value = 1
    await Timer (10, units="ns")
    await Timer (10, units="ns")
    await Timer (10, units="ns")
    await Timer (10, units="ns")
    dut.rd_en.value = 0
    
    # Test simultaneous write and read
    dut.wr_en.value = 1
    dut.rd_en.value = 1
    dut.data_in.value = 50
    await Timer (10, units="ns")
    
    dut.data_in.value = 60
    await Timer (10, units="ns")
    
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    await Timer (10, units="ns")
    
    # Additional wait to observe behavior
    await Timer(50, units="ns")