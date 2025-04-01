import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


def pack_weights_4x4_16bit(weights):
    """
    Pack a 4x4 list of 16-bit weights (weights[i][j]) into a single 256-bit integer.
    w_in[(i*4 + j)*16 +: 16] = weights[i][j].
    """
    big_val = 0
    for i in range(4):
        for j in range(4):
            w_ij = weights[i][j] & 0xFFFF
            shift_amount = 16 * (i * 4 + j)  # each weight is 16 bits
            big_val |= (w_ij << shift_amount)
    return big_val


def pack_inputs_4_16bit(x0, x1, x2, x3):
    """
    Pack 4 inputs (16 bits each) into a 64-bit bus.
    x_in[i*16 +: 16] = x_i.
    """
    big_val = 0
    big_val |= (x0 & 0xFFFF)
    big_val |= ((x1 & 0xFFFF) << 16)
    big_val |= ((x2 & 0xFFFF) << 32)
    big_val |= ((x3 & 0xFFFF) << 48)
    return big_val


def log_y_out(dut, cycle):
    """
    Extract and log the four 16-bit outputs from y_out at the given cycle.
    """
    full_y_out = dut.y_out.value.integer  # 64-bit integer
    col0 = full_y_out & 0xFFFF
    col1 = (full_y_out >> 16) & 0xFFFF
    col2 = (full_y_out >> 32) & 0xFFFF
    col3 = (full_y_out >> 48) & 0xFFFF
    cocotb.log.info(f"Cycle {cycle}:")
    cocotb.log.info(f"   Bottom Row, Col0 = 0x{col0:04X} ({col0})")
    cocotb.log.info(f"   Bottom Row, Col1 = 0x{col1:04X} ({col1})")
    cocotb.log.info(f"   Bottom Row, Col2 = 0x{col2:04X} ({col2})")
    cocotb.log.info(f"   Bottom Row, Col3 = 0x{col3:04X} ({col3})")


@cocotb.test()
async def test_systolic_array_4x4_16bit(dut):
    """
    Testbench for a 4x4 systolic array with 16-bit data.
    - w_in is 256 bits (16 weights × 16 bits).
    - x_in is 64 bits (4 inputs × 16 bits).
    - y_out is 64 bits (4 outputs × 16 bits).
    Logs the four 16-bit outputs separately at each clock cycle.
    """
    # Create a 10 ns period clock on dut.clk
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.reset.value        = 1
    dut.load_weights.value = 0
    dut.start.value        = 0
    dut.w_in.value         = 0
    dut.x_in.value         = 0
    dut.done.value         = 0

    # Wait under reset
    await Timer(20, units="ns")
    dut.reset.value = 0
    await RisingEdge(dut.clk)  # Wait for one clock cycle after reset

    # Example 4x4 weights, each up to 16 bits
    weights_4x4 = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9, 10, 11, 12],
        [13, 14, 15, 16]
    ]

    # Load the weights (256 bits total)
    dut.load_weights.value = 1
    dut.w_in.value = pack_weights_4x4_16bit(weights_4x4)
    await RisingEdge(dut.clk)  # Load weights on clock edge

    # Deassert load_weights, start the computation
    dut.load_weights.value = 0
    dut.start.value        = 1

    # Initialize cycle counter
    cycle = 0

    # Drive inputs and log outputs at each cycle
    input_sequence = [
        (1, 0, 0, 0),
        (2, 5, 0, 0),
        (3, 6, 9, 0),
        (4, 7, 10, 13),
        (0, 8, 11, 14),
        (0, 0, 12, 15),
        (0, 0, 0, 16),
    ]

    for x0, x1, x2, x3 in input_sequence:
        dut.x_in.value = pack_inputs_4_16bit(x0, x1, x2, x3)
        await RisingEdge(dut.clk)
        log_y_out(dut, cycle)
        cycle += 1

    # Give it time to process (5 additional cycles)
    for _ in range(5):
        dut.x_in.value = pack_inputs_4_16bit(0, 0, 0, 0)
        await RisingEdge(dut.clk)
        log_y_out(dut, cycle)
        cycle += 1

    # Send zeros to indicate no further data and log
    dut.x_in.value = pack_inputs_4_16bit(0, 0, 0, 0)
    await RisingEdge(dut.clk)
    log_y_out(dut, cycle)
    cycle += 1

    # Give more time for final calculations (5 cycles)
    for _ in range(5):
        dut.x_in.value = pack_inputs_4_16bit(0, 0, 0, 0)
        await RisingEdge(dut.clk)
        log_y_out(dut, cycle)
        cycle += 1

    # Optionally assert done and log final state
    dut.done.value = 1
    await RisingEdge(dut.clk)
    log_y_out(dut, cycle)