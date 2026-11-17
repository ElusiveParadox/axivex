# AXIVEX: A Modular 4x4 Systolic-Array Accelerator for Matrix Multiplication

**Course:** Modern Computer Architecture • B.Tech (CS&AI)  
**Project:** Project 12 — Systolic Array Matrix Multiplication Accelerator (AXIVEX)  
**Authors:**
- **Sushant Guri** (Roll No: [Roll 1]) — *Processing Element & Top-Level Integration*
- **Manjeet** (Roll No: [Roll 2]) — *4x4 Systolic Mesh & Output Buffering*
- **Aryan** (Roll No: [Roll 3]) — *Input Buffers & Skew Scheduler*
- **Vidhi Singhal** (Roll No: [Roll 4]) — *Python Golden Model & Reference Suite*
- **ElusiveParadox** (Roll No: [Roll 5]) — *Architecture, MAC Unit & Synthesis Flow*

---

## Abstract
AXIVEX is a synthesizable Verilog implementation of a 4x4 output-stationary systolic array that computes $C = A \times B$ for signed INT8 matrices with INT32 accumulation. This paper describes the array architecture, transaction interface, verification methodology, browser Digital Twin, and open-source synthesis results. The RTL passes exhaustive MAC-unit checks, directed unit and system tests, and a 128-transaction seeded random regression against an independent Python model. Mutation testing detects all 18 non-equivalent injected faults. RTL simulation measures 13 cycles from accepted start to completion, including a 10-cycle compute window in which the 16 processing elements perform 64 multiply-accumulate operations. Yosys mapping to Xilinx 7-series primitives reports 16 DSP48E1 blocks, 1,399 FDRE registers, and 202 LUTs.

**Index Terms—** systolic array, matrix multiplication, FPGA, Verilog, output-stationary dataflow, INT8.

---

## 1. Introduction and Motivation
Matrix multiplication dominates neural-network inference. A sequential engine with one multiply-accumulate (MAC) unit needs $M \times N \times K$ cycles for an $M \times K$ by $K \times N$ product; a spatial array performs many MACs per cycle and reuses each operand as it moves between neighbouring processing elements (PEs). AXIVEX is a small, fully verified instance of this idea, built to be inspected, simulated and synthesized with free tools only.

---

## 2. Literature Review
Kung argued that systolic architectures, regular arrays in which data flows rhythmically through many PEs, allow multiple computations per memory access and so suit compute-bound problems without raising I/O requirements (Kung, 1982). The Google TPU is a prominent production example: its core is a 65,536-MAC 8-bit matrix unit (Jouppi et al., 2017). Gemmini is an open-source generator of systolic accelerators with selectable dataflows and a full software stack (Genc et al., 2021). Eyeriss analyses dataflows for convolutional networks and proposes the row-stationary dataflow (Chen et al., 2016).

---

## 3. Existing Approaches and Limitations
General-purpose cores execute matrix products with few MACs per cycle and repeated operand movement. Large accelerators are valuable in production but can be difficult to inspect at the level of individual operand transfers and accumulator updates. AXIVEX provides a smaller cycle-accurate implementation whose RTL, independent reference model, test traces, and visualization describe the same fixed-size computation.

---

## 4. Problem Statement
Design, implement and verify in synthesizable Verilog a 4x4 array computing $C_{4\times 4} = A_{4\times 4} \times B_{4\times 4}$ with signed INT8 inputs and signed INT32 accumulation using 16 PEs, output-stationary dataflow, east-moving A and south-moving B.

---

## 5. Proposed Solution
### High-Level Architecture
The AXIVEX design comprises nine synthesizable Verilog modules:
1. `axivex_top`: Top-level integration and transaction interface.
2. `matrix_data_interface`: Host data packing and unpacking.
3. `input_buffers`: Latching 128-bit packed inputs A and B.
4. `skew_scheduler`: Delaying input rows and columns to form the diagonal systolic wavefront.
5. `systolic_array_4x4`: 16-PE 2D mesh with nearest-neighbor routing.
6. `processing_element`: Output-stationary PE with local 32-bit accumulation.
7. `mac_unit`: Signed INT8xINT8 multiplication and accumulation.
8. `array_controller`: 5-state synchronous FSM controlling the 13-cycle execution window.
9. `output_buffer`: Result capture and retirement buffer.

---

## 6. Measured Performance & Results

| Metric | Value | Evidence |
| :--- | :---: | :--- |
| **PE Count** | 16 | Architecture |
| **Peak MAC Capacity** | 16 MAC/cycle | Architecture |
| **MAC Operations per Job** | 64 | Measured in RTL |
| **Start-to-Done Latency** | **13 cycles** | Measured in RTL |
| &nbsp;&nbsp;• Load/Start Cycle | 1 cycle | Measured |
| &nbsp;&nbsp;• CLEAR State | 1 cycle | Measured |
| &nbsp;&nbsp;• RUN (Compute Window) | 10 cycles | Measured ($3N - 2$) |
| &nbsp;&nbsp;• RETIRE State | 1 cycle | Measured |
| **Sequential Baseline Cycles** | 64 compute (67 total) | Modelled |
| **Compute-Only Speedup** | **6.40×** | 64 / 10 cycles |
| **End-to-End Speedup** | **5.15×** | 67 / 13 cycles |
| **Yosys FPGA Primitives (XC7)** | 16 DSP48E1, 1,399 FDRE, 202 LUTs | Yosys Synthesis Report |

---

## 7. Individual Contributions
The project was designed, implemented, and verified through coordinated teamwork across five members:
- **Sushant Guri:** Implemented the output-stationary Processing Element (`processing_element.v`), integrated the top-level accelerator interface (`axivex_top.v`), authored directed and seeded random test vectors, and developed the cycle-accurate simulation engine for the Digital Twin.
- **Manjeet:** Built the 4x4 systolic array mesh (`systolic_array_4x4.v`), array control and output buffering (`output_buffer.v`), authored unit testbenches for MAC and PE, and developed the matrix control UI in the Digital Twin.
- **Aryan:** Engineered the input buffer pipelines and skew scheduler (`skew_scheduler.v`), verified array dataflow timing (`tb_systolic_array.sv`), and created the architecture and mesh visualization interfaces.
- **Vidhi Singhal:** Developed the Python matrix multiplication golden model (`matrix_model.py`), unit tests, and designed the clock controls, overview, and register monitoring pages of the Digital Twin.
- **ElusiveParadox:** Defined the system microarchitecture and pipeline timing, implemented the signed fixed-width MAC unit (`mac_unit.v`), set up the Yosys synthesis and Artix-7 constraints, authored mutation testing regressions, and compiled the IEEE technical report.

---

## 8. Conclusion
A 4x4 output-stationary systolic multiplier was implemented and verified in simulation against an independent reference model. Its measured transaction latency is 13 cycles, with a ten-cycle compute window for 64 MACs. Yosys produces a reproducible mapping to 16 DSP48E1 blocks, 1,399 FDRE registers, and 202 LUTs. The Digital Twin provides a cycle-level view of the same computation.
