import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_max_finder(dut):
    """Test the max finder: feed in 32 values up and down, expect max=16."""

    # 1) Clock @ 100 MHz (10 ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 2) Reset
    dut.rst.value = 1
    await Timer(20, units="ns")
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # 3) Prepare the 32‑element test vector: 1..16,15..1
    ascending  = list(range(1, 17))
    descending = list(range(15, 0, -1))
    test_vector = ascending + descending

    # 4) Drive inputs
    dut.din_valid.value = 0
    dut.start.value     = 0
    await RisingEdge(dut.clk)

    # Pulse start for one cycle to enter LOAD → FIND_MAX
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Now stream in all 32 values, one per cycle
    for val in test_vector:
        dut.din.value       = val
        dut.din_valid.value = 1
        await RisingEdge(dut.clk)
    # De‑assert din_valid after last word
    dut.din_valid.value = 0

    # 5) Wait for done
    # The DUT will assert done once it has read all words back and computed the max
    # We’ll give it up to, say, 1000 cycles to finish
    for _ in range(1000):
        await RisingEdge(dut.clk)
        if dut.done.value.integer == 1:
            break
    else:
        raise cocotb.result.TestFailure("max finder did not assert done in time")

    # 6) Check result
    expected = max(test_vector)
    got      = dut.max_out.value.signed_integer
    dut._log.info(f"Expected max={expected}, DUT max_out={got}")
    assert got == expected, f"MAX mismatch: got {got}, expected {expected}"
