import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_softmax(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.enable.value = 0
    dut.rst.value = 0
    await Timer(10, units="ns")
    dut.enable.value = 1
    await Timer(10, units="ns")
    dut.rst.value = 1
    await Timer(20, units="ns")
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # The input vector, values between -200 and +200
    input_vec = [
        -200, -150, -100, -50, 0, 50, 100, 150,
        200, -180, -120, -70, -20, 30, 80, 130,
        180, -190, -140, -90, -40, 10, 60, 110,
        160, -170, -110, -60, -10, 40, 90, 140
    ]

    dut.in_valid.value = 1
    for val in input_vec:
        dut.x_in.value = val
        await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    # Wait for outputs and print y_out when out_valid is high
    for _ in range(500):
        await RisingEdge(dut.clk)