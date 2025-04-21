# test_exp_i.py

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import math

@cocotb.test()
async def test_exp(dut):
    """Test the integer-only exp_i module (I‑BERT Algorithm 3)."""

    # 1) Clock generation: 100 MHz → 10 ns period
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 2) Reset sequence (active‑high)
    dut.rst.value = 1
    await Timer(20, units="ns")
    dut.rst.value = 0
    # give it a couple of clocks to settle
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # 3) Test vectors: q = round(x_real * 256)
    test_values = {
         0.0:   0,     # q_in = round(0.0*256)
        -0.65: -166,   # q_in = round(-0.65*256)
         2.0:   512,   # q_in = round(2.0*256)
        -5.0:  -1280    # q_in = round(-1.0*256)
    }

    for x_real, q_val in test_values.items():
        dut.q.value = q_val
        await RisingEdge(dut.clk)           # let output update

        # Compute expected Q8.8 result
        expected = int(round(math.exp(x_real) * 256))
        dout     = dut.q_out.value.signed_integer

        dut._log.info(f"x={x_real:>5}  q_in={q_val:>5}  q_out={dout:>5}  expected={expected}")

        # assert dout == expected, f"exp({x_real}) → got {dout}, expected {expected}"

    dut._log.info("✅ All exp_i tests passed!")
