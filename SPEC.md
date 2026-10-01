# RISCV Pipeline Implementation Guide

## Objective

This lab converts the verified top-level core RISCV_Single_Cycle(clk, rst_n) into a five-stage RV32I pipeline consisting of IF, ID, EX, MEM, and WB. Reuse the verified oldd execution modules, add the four inter-stage pipeline registers and hazard-control blocks specified in this manual, and preserve the architectural behavior already supported by the Single_Cycle.

## Tasks

In this lab, you will perform the following tasks:

- Partition RISCV_Single_Cycle into five stages and insert the four inter-stage pipeline registers: IF_ID_reg, ID_EX_reg, EX_MEM_reg, and MEM_WB_reg.
- Design forward_unit.y to forward available results from the EX/MEM and MEM/WB stages to dependent ALU, branch-comparison, and store-data operands, thereby eliminating most data-hazard stalls.
- Design hazard_detect.y to detect a true load-use dependency, hold the PC and IF/ID register for one cycle, and insert a bubble into ID/EX.
- Move branch and jump decision logic out of main_decoder into a new Branch_Resolve module, and implement redirect and flush handling for taken branches, JAL, and JALR.
- Reuse the ALU, IMEM, DMEM, RegisterFile, Immediate Generator, ALU decoder, and Branch Comparator from the verified Single_Cycle Processordesign. Preserve their existing interfaces unless this manual explicitly requires an additional stage-carried signal, such as funct3_M.
- Design a self-checking top-level regression testbench and rerun the applicable architectural tests for the behavior verified in the Single_Cycle Processordesign. The completed pipeline must pass these tests without manually inserted NOPs.

## Naming Convention

The single-cycle design uses the suffix _top for top-level signals, such as DataA_top and ALU_out_top. In the pipeline design, a signal is given the suffix of the stage in which it is valid or registered: _F (IF), _D (ID), _E (EX), _M (MEM), or _W (WB). For example, DataA_top becomes DataA_D when read from the RegisterFile in ID and fwd_DataA_E after forwarding in EX.

## Required Design and Grading Interface

The completed submission must provide the top-level module RISCV_Pipeline and must instantiate the required pipeline and hazard-control modules listed below. Module names and port interfaces are part of the lab contract so that the modules can be unit-tested and integrated consistently.

- Required modules: IF_ID_reg, ID_EX_reg, EX_MEM_reg, MEM_WB_reg, forward_unit, hazard_detect, and Branch_Resolve.
- For each required module, preserve the documented port names, directions, widths, and functional behavior.
- Instance names and unlisted internal wire names are not part of the grading contract. Students may choose their own instance names and may add helper modules.   
- Grading must not depend on hierarchical paths to a particular instance name. Structural criteria are checked by source or hierarchy review; functional criteria are checked through module-level directed tests and top-level architectural behavior.

## Module Inventory — What Changes and What Doesn't

As in Lab 6: green entries below are reused as-is; white entries need new design work.

| Your file | Module | New stage(s) | Change required |
|---|---|---|---|
| Program_Counter.v | Program_Counter | IF | Add hold/enable support; EX redirect has priority over load-use stall. |
| IMEM.v | Instruction_Memory | IF | None — reused as-is. |
| Imm_Gen.v | Immediate_Generator | ID | None — reused as-is, runs once in ID. |
| RegisterFile.v | RegisterFile | ID (read) / WB (write) | Reuse one instance; add external WB-to-ID write-through bypass. |
| main_decoder.v | main_decoder | ID (decode flags) | Remove PCSel; expose instruction-class and UsesRs1/UsesRs2 flags. |
| ALU_decoder.v | ALU_decoder | ID | None — reused as-is (depends only on funct3/funct7/i_type/arithmetic). |
| control_unit.v | control_unit | ID | Pass instruction-class/use flags and declare internal nets explicitly. |
| Branch_Comp.v | Branch_Comp | EX | None structurally, but its operand_0/operand_1 inputs must come from the forwarding muxes (Part 5), not raw DataA_D/DataB_D. |
| ALU.v | ALU | EX | None — reused as-is. |
| DMEM.v | Data_Memory | MEM | Reuse the Single_Cycle Processor behavior; funct3 must be available in MEM. |
| (new) | IF_ID_reg / ID_EX_reg / EX_MEM_reg / MEM_WB_reg | boundaries | New — Part 2. |
| forward_unit | EX | New — Part 5. |
| hazard_detect | ID/EX boundary | New — Part 6. |
| Branch_Resolve | EX | New — Part 7, carved out of main_decoder. |

## Learning Objectives

- Partition RISCV_Single_Cycle into five stages without changing which module does what.
- Design pipeline registers that carry out existing signals (DataA/DataB/Imm/ALU_out/etc.) between stages under their new _F/D/E/M/W names.
- Resolve structural, data, and control hazards. Forwarded rs1/rs2 values must feed the ALU, Branch_Comp, and store-data path; PC-relative targets must use PC_E; taken control flow must redirect IF and squash younger instructions.
- Split main_decoder's embedded PCSel logic out of ID and into a new EX-stage module, since it depends on BrEq/BrLT which can't be finalized until EX in this design.
- You may reuse the Single_Cycle Processorarchitectural checks, but the pipeline testbench must use a larger timeout and must report total cycles and load-use stall cycles. Do not make pass/fail depend on single-cycle timing.
- Build a regression flow that confirms the pipelined core matches your single-cycle core's architectural results.

## Checkoff Overview

| Part | Topic | Points |
|---|---|---|
| 1 | Stage partitioning of RISCV_Single_Cycle.v | 5 |
| 2 | Pipeline registers (IF_ID/ID_EX/EX_MEM/MEM_WB) | 10 |
| 3 | Control signal propagation | 10 |
| 4 | Register file timing verification | 5 |
| 5 | Data forwarding | 15 |
| 6 | Hazard detection / load-use stall | 15 |
| 7 | Branch/jump resolution (Branch_Resolve split) | 15 |
| 8 | JAL/JALR + LUI write-back path | 5 |
| 9 | Structural hazard check (IMEM/DMEM) | 5 |
| 10 | Integration regression suite | 15 |

---

# Part 1: Stage Partitioning

**Objective:** Map every wire and module instance in RISCV_Single_Cycle.v to the pipeline stage it belongs in.

**Estimated time:** 30–45 minutes

## 1.1 Your Datapath, Mapped to Stages

| Stage | Your modules / signals |
|---|---|
| IF | Program_Counter (PC_F), PC_Plus4_F adder, PC redirect mux, Instruction_Memory |
| ID | control_unit, one RegisterFile read, WB-to-ID bypass, Immediate_Generator |
| EX | forward muxes, ALU using PC_E, Branch_Comp, Branch_Resolve, JALR target mask |
| MEM | Data_Memory using ALU_out_M, DataB_M, MemRW_M, and funct3_M |
| WB | Three-way DataD_W mux; RegisterFile write; MEM/WB forwarding source |

The shared ALU computes **AUIPC**, branch, **JAL**, and **JALR** targets in EX. Its operand-A **mux** must select the current instruction address, not PC+4: **Mux_ALU_DataA_E = ASel_E? PC_E: fwd_DataA_E**. Operand B is **BSel_E? Imm_E: fwd_DataB_E**. The redirect target is **Target_E = Is_JALR_E? {ALU_out_E[31:1],1'b0}: ALU_out_E**, and IF selects PC_in_F = **PCSel_E? Target_E: PC_Plus4_F**.

Addressing convention: PC and data addresses carried between pipeline stages are byte addresses. If the supplied Instruction_Memory indexes 32-bit words, convert PC_F to a word index only at the **MEM** boundary, for example with PC_F[31:2]. Apply any corresponding conversion required by the supplied Data_Memory interface exactly once at the **DMEM** boundary. Do not shift the same address in both the top level and the memory module.

## 1.2 Tasks

1. Annotate a printout of RISCV_Single_Cycle.v with the stage each wire/instance belongs to, using the table above as a starting point.

2. For each of the four stage boundaries (IF|ID, ID|EX, EX|MEM, MEM|WB), list every signal crossing it, using your existing names as the base (e.g. Instruction_out_top crosses IF|ID; DataA_top, Imm_top, and every control_unit output cross ID|EX).

3. PC_Plus4_F is used for sequential fetch and must also be carried unchanged to WB for the JAL/JALR link value. PC_E, not PC_Plus4_E, is selected as ALU operand A for PC-relative target and AUIPC calculations.

**Deliverable:** An annotated diagram/table listing every signal crossing each of the four stage boundaries, in terms of your existing signal names.

---

# Part 2: Pipeline Registers

**Objective:** Insert IF_ID_reg, ID_EX_reg, EX_MEM_reg, and MEM_WB_reg, and rewire RISCV_Single_Cycle.y (renamed RISCV_Pipeline.y) so each stage reads only from the register upstream of it.

**Estimated time:** 2–3 hours

## 2.1 IF_ID_reg

Carries the three fields produced in IF and consumed in ID:

```verilog
module IF_ID_reg(
    input clk, rst_n, stall, flush,
    input [31:0] PC_in, PC_Plus4_in, Instr_in,
    output reg [31:0] PC_D, PC_Plus4_D, Instr_D
);

always @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush) begin
        PC_D <= 32'b0; 
        PC_Plus4_D <= 32'b0; 
        Instr_D <= 32'h00000013; // addi x0,x0,0
    end else if (!stall) begin
        PC_D <= PC_in; 
        PC_Plus4_D <= PC_Plus4_in; 
        Instr_D <= Instr_in;
    end
end

endmodule
```

**Bubble encoding:** use 32'h00000013 (addi x0,x0,0) in IF/ID and force every ID/EX side-effect control to zero when injecting a bubble. Correctness must not depend on how an illegal all-zero instruction happens to decode.

## 2.2 ID_EX_reg

Carries everything ID produces that EX, MEM, or WB still need:

```verilog
module ID_EX_reg(
    input clk, rst_n, bubble,
    input [31:0] PC_D, PC_Plus4_D, DataA_D, DataB_D, Imm_D,
    input [4:0] addrA_D, addrB_D, addrD_D,
    input [2:0] funct3_D,
    input [3:0] ALUSel_D,
    input [1:0] WBSel_D,
    input RegWEn_D, BrUn_D, ASel_D, BSel_D, MemRW_D,
    input Is_Branch_D, Is_Jump_D, Is_JALR_D, Is_Load_D,
    output reg [31:0] PC_E, PC_Plus4_E, DataA_E, DataB_E, Imm_E,
    output reg [4:0] addrA_E, addrB_E, addrD_E,
    output reg [2:0] funct3_E,
    output reg [3:0] ALUSel_E,
    output reg [1:0] WBSel_E,
    output reg RegWEn_E, BrUn_E, ASel_E, BSel_E, MemRW_E,
    input Is_Branch_E, Is_Jump_E, Is_JALR_E, Is_Load_E
);

// On reset or bubble, clear all data fields and every side-effect control.
// RegWEn_E, MemRW_E, Is_Branch_E, Is_Jump_E, Is_JALR_E, and Is_Load_E must all become zero.
endmodule
```

Expose Is_Branch, Is_Jump, Is_JALR, Is_Load, UsesRs1, and UsesRs2 from decode. UsesRs1/UsesRs2 describe the actual source operands of Instr_D and prevent false load-use stalls. Is_JALR distinguishes the masked register-indirect target from branch/JAL targets.

## 2.3 EX_MEM_reg

```verilog
module EX_MEM_reg(
    input clk, rst_n,
    input [31:0] ALU_out_E, DataB_fwd_E, PC_Plus4_E,
    input [4:0] addrD_E,
    input [1:0] WBSel_E,
    input RegWEn_E, MemRW_E,
    input [2:0] funct3_E,
    output reg [31:0] ALU_out_M, DataB_M, PC_Plus4_M,
    output reg [4:0] addrD_M,
    output reg [1:0] WBSel_M,
    output reg RegWEn_M, MemRW_M,
    output reg [2:0] funct3_M
);

// DataB_fwd_E is the *forwarded* store-data value from Part 5 –
// not the raw DataB_E – see the callout in Part 5.3.

endmodule
```

## 2.4 MEM_WB_reg

```verilog
module MEM_WB_reg(
    input clk, rst_n,
    input [31:0] ALU_out_M, DataR_M, PC_Plus4_M,
    input [4:0] addrD_M,
    input [1:0] WBSel_M,
    input RegWEn_M,
    output reg [31:0] ALU_out_W, DataR_W, PC_Plus4_W,
    output reg [4:0] addrD_W,
    output reg [1:0] WBSel_W,
    output reg RegWEn_W
);

endmodule
```

## 2.5 Re-wire RISCV_Pipeline.v

1. Rename RISCV_Single_Cycle.v to RISCV_Pipeline.v (or keep both — single-cycle as your golden reference for Part 10).

2. Instantiate the four registers above between the existing IF/ID/EX/MEM/WB blocks, exactly as you already wired control_unit, RegisterFile, ALU, Branch_Comp, and Data_Memory in the original file.

3. Initially tie the hazard inputs inactive. In the completed core, IF/ID receives the load-use stall and redirects flush controls. ID/EX receives bubble_index = PCSel_E || stall_load. EX/MEM and MEM/WB advance normally and must not be flushed by the instruction currently resolving in EX.

4. Every place the single-cycle file read a signal directly across what is now a stage boundary (e.g. control_unit reading Instruction_out_top directly) must instead read the _D/_E/_M/_W version out of the appropriate register.

## 2.6 Test

Hand-assemble a program with three NOPs between dependent instructions. Confirm PC_F advances by four and the four stage-register bundles move one stage per cycle in your waveform viewer.

**Deliverable:** Waveform showing a NOP-padded program's PC, Instr_D, and all four pipeline register outputs advancing correctly over 8+ cycles.

---

# Part 3: Control Signal Propagation

**Objective:** Confirm every control_unit output is threaded through exactly as many pipeline registers as it's needed, using the module inventory from Part 0.1.

**Estimated time:** 45–60 minutes

| Signal | Produced in | Last needed in | Registers it must cross |
|---|---|---|---|
| ImmSel_top | ID (control_unit) | ID (feeds Immediate_Generator directly) | none — stays local to ID |
| RegWEn_top | ID | WB (RegisterFile write) | ID_EX, EX_MEM, MEM_WB |
| ASel_top / BSel_top | ID | EX (ALU operand muxes) | ID_EX only |
| ALUSel_top | ID | EX (ALU) | ID_EX only |
| BrUn_top | ID | EX (Branch_Comp) | ID_EX only |
| MemRW_top | ID | MEM (Data_Memory) | ID_EX, EX_MEM |
| WBSel_top | ID | WB (DataD_top mux) | ID_EX, EX_MEM, MEM_WB |
| Is_Branch / Is_Jump / Is_JALR | ID | EX (Branch_Resolve / target mask) | ID_EX only |
| Is_Load / UsesRs1 / UsesRs2 / funct3 | ID | hazard_detect / MEM load-store control | Is_Load crosses ID_EX; UsesRs stay in ID; funct3 crosses ID_EX and EX_MEM |

Confirm this against the struct field lists you wrote into IF_ID_reg / ID_EX_reg / EX_MEM_reg / MEM_WB_reg in Part 2 — trim anything you're carrying further than this table says, and add anything missing.

**Deliverable:** A waveform showing RegWEn, MemRW, and WBSel reaching MEM/WB on the correct cycle for a mixed instruction sequence (e.g. addi, sw, lw, add).

---

# Part 4: Register File Timing

**Objective:** use exactly one RegisterFile instance and add an explicit WB-to-ID write-through bypass for a value written and decoded on the same rising edge.

**Estimated time:** 20–30 minutes

With nonblocking writes, ID_EX samples the old register-array value on the same edge that WB updates it.  
Therefore add an external write-through bypass:  
DataA_D = (RegWEn_W && addrD_W != 0 && addrD_W == addrA_D) ? DataD_W : rf_DataA_D, and likewise for DataB_D. Do not rely on event ordering.

**One instance, two stages:** instantiate RegisterFile exactly once. ID drives addrA_D/addrB_D and receives rf_DataA_D/rf_DataB_D; WB drives addrD_W/DataD_W/RegWEn_W. Apply the two write-through muxes after the register-file read ports.

1. Confirm RISC-V Pipeline.v instantiates RegisterFile once and that both WB-to-ID bypass comparisons exclude x0.

2. Test: arrange for an instruction in ID to read x5 in the same cycle that WB writes x5. Confirm DataA_D or DataB_D sees the new value 42 and that x0 still reads zero.

---

# RISCV Pipeline Implementation Guide (Continued)

## Part 4: Register File Timing (Continued)

**Deliverable:** waveform showing the WB write, the matching ID read address, and the bypassed DataA_D/DataB_D value captured correctly into ID/EX.

---

# Part 5: Data Forwarding

**Objective:** Forward ALU/memory/PC+4 results from EX_MEM_reg and MEM_WB_reg back into EX, so dependent instructions don't stall on every RAW hazard.

**Estimated time:** 2–3 hours

## 5.1 Where forwarding must be inserted in your datapath

In your single-cycle design, DataA_top/DataB_top (raw RegisterFile outputs) feed three separate places: the ASel/BSel ALU-operand muxes, Branch_Comp, and Data_Memory's DataW port (store data). All three need the forwarded value, so insert the forwarding mux upstream of all three — on DataA_D/DataB_D right as they enter EX — rather than patching each consumer separately.

```verilog
// forward_unit.v
module forward_unit(
    input [4:0] addrA_E, addrB_E,    // rs1/rs2 of the instruction now in EX
    input [4:0] addrD_M, addrD_W,    // rd of the instructions in EX_MEM / MEM_WB
    input RegWEn_M, RegWEn_W,
    output reg [1:0] fwdA, fwdB    // 00=no fwd, 10=from EX_MEM, 01=from MEM_WB
);

always @(*) begin
    fwdA = 2'b00;
    if (RegWEn_M && addrD_M != 5'b0 && addrD_M == addrA_E) fwdA = 2'b10;
    else if (RegWEn_W && addrD_W != 5'b0 && addrD_W == addrA_E) fwdA = 2'b01;

    fwdB = 2'b00;
    if (RegWEn_M && addrD_M != 5'b0 && addrD_M == addrB_E) fwdB = 2'b10;
    else if (RegWEn_W && addrD_W != 5'b0 && addrD_W == addrB_E) fwdB = 2'b01;
end
endmodule
```

## 5.2 The MEM/WB forward source must be DataD_W, not ALU_out_W

Forward the actual value produced by each older instruction. The WB source is always DataD_W. The M-stage source is ForwardData_M, which selects PC_Plus4_M for JAL/JALR and otherwise selects ALU_out_M. A load result is not available in M early enough for the immediately following EX instruction, so hazard_detect must insert one bubble.

## 5.3 Apply the forwarded values

```verilog
// in the EX stage, replace every direct use of DataA_E/DataB_E:
wire [31:0] fwd_DataA_E, fwd_DataB_E;
always @(*) begin
    case (fwdA)
    2'b10: fwd_DataA_E = ForwardData_M; // EX/MEM producer
    2'b01: fwd_DataA_E = DataD_W; // from MEM_WB_reg (Part 5.2)
    default: fwd_DataA_E = DataA_E; // straight from ID_EX_reg / RegisterFile
    endcase
end

case (fwdB)
    2'b10:    fwd_DataB_E = ForwardData_M;
    2'b01:    fwd_DataB_E = DataD_W;
    default: fwd_DataB_E = DataB_E;
endcase
end

// existing muxes now read the forwarded values:
assign Mux_ALU_DataA_E = ASel_E ? PC_E : fwd_DataA_E;
assign Mux_ALU_DataB_E = BSel_E ? Imm_E : fwd_DataB_E;

// Branch_Comp also needs the forwarded, pre-mux operands:
Branch_Comp Branch_Comp_inst(
    .operand_0 (fwd_DataA_E),
    .operand_1 (fwd_DataB_E),
    .BrUn (BrUn_E), .BrEq (BrEq_E), .BrLT (BrLt_E)
);

// and fwd_DataB_E - not DataB_E - is what EX_MEM_reg carries forward as store data
```

Priority: EX/MEM wins over MEM/WB because it is newer. Define ForwardData_M before the forwarding muxes: select PC_Plus4_M when WBSel_M denotes the link value, otherwise ALU_out_M. Loads are handled by the one-cycle load-use interlock and then forwarded from DataD_W.

## 5.4 Test

Remove NOP padding between dependent ALU instructions: addi x1,x0,1 / add x2,x1,x1 / add x3,x2,x2 / add x4,x3,x3 back-to-back. Confirm x4 == 8 with zero stalls. Also test sw x2, 0(x1) immediately after an instruction that produces x2, to confirm the forwarded store-data path (fwd_DataB_E -> EX_MEM_reg.DataB_M -> Data_Memory.DataW) is correct.

**Deliverable:** forward_unit.v, updated EX-stage wiring, and a waveform/register dump showing a 4-instruction ALU chain and a forwarded store both producing correct results with no manual NOPs.

---

# Part 6: Hazard Detection & Load-Use Stall

**Objective:** Detect a load immediately followed by a dependent instruction — the one RAW hazard forwarding can't fix — and stall one cycle.

**Estimated time:** 1.5–2 hours

A load's DataR_M is available only after the dependent instruction would need its EX operands. Freeze PC_F and IF/ID for one cycle and inject a side-effect-free bubble into ID/EX; the dependent instruction then receives DataD_W through forwarding.

## 6.1 hazard_detect.v

```verilog
module hazard_detect(
    input    Is_Load_E,    // new signal from main_decoder, Part 2.2
    input    [4:0] addrD_E,
    input    [4:0] addrA_D, addrB_D,
    input    UsesRs1_D, UsesRs2_D,
    output   stall_load
);

assign stall_load = Is_Load_E && (addrD_E != 5'b0) &&  
    ((UsesRs1_D && (addrD_E == addrA_D)) ||  
     (UsesRs2_D && (addrD_E == addrB_D)));

endmodule
```

## 6.2 Wiring

1. Add enable/stall behavior to Program_Counter. Redirect from EX has priority over load-use stall; otherwise stall holds PC_F.

2. Drive IF_ID_reg's stall input from stall_load so Instr_D, PC_D, and PC_Plus4_D are held for exactly one cycle.

3. Drive ID_EX_reg's bubble input with bubble_index = PCSel_E || stall_load. Do not hold ID/EX on a load-use dependency: the load must advance to EX/MEM while a side-effect-free bubble replaces it in EX.

4. addrA_D/addrB_D are Instr_D[19:15] and Instr_D[24:20]. Decode UsesRs1_D and UsesRs2_D from the opcode so immediate, upper-immediate, jump, and store formats do not create false dependencies.

## 6.3 Test

Run lw x5, 0(x1) immediately followed by add x6, x5, x5, no NOPs. Confirm exactly one stall cycle (PC held, bubble visible in ID_EX_reg) and x6 ends up correctly doubled.

**Deliverable:** hazard_detect.v, the stall/bubble wiring, and a waveform showing a single-cycle load-use stall with the correct final register value.

---

# Part 7: Branch & Jump Resolution

**Objective:** Split main_decoder's PCSel logic out of ID and resolve all control flow (branches, JAL, JALR) in EX, matching the fact that your design computes targets through the shared ALU.

**Estimated time:** 2.5–3.5 hours

## 7.1 Why this design resolves in EX, not ID

Branch_Comp and the shared ALU both operate in EX on forwarded values. Branch_Resolve produces PCSel_E, while the ALU produces ALU_out_E. For JALR only, clear target bit 0. Resolving all branches and jumps in EX gives a two-younger-instruction squash on a taken redirect.

## 7.2 Extract Branch_Resolve from main_decoder

Move PCSel generation out of main_decoder. Decode only instruction-class flags in ID and let Branch_Resolve use Is_Branch_E, Is_Jump_E, funct3_E, BrEq_E, and BrLt_E in EX.

```verilog
// Branch_Resolve.v – replaces the B-Type PCSel case in main_decoder
module Branch_Resolve(
    input    Is_Branch_E, Is_Jump_E, // class flags from ID/EX
    input [2:0] funct3_E,
    input    BrEq_E, BrLt_E,    // from Branch_Comp, now running in EX
    output reg PCSel_E
);

always @(*) begin
    if (Is_Jump_E) begin
        PCSel_E = 1'b1;    // JAL / JALR: always taken
    end else if (Is_Branch_E) begin
        if (funct3_E[2]) begin    // BLT/BGE/BLTU/BGEU
            PCSel_E = BrLt_E ? ~funct3_E[0] : funct3_E[0];
        end else begin    // beq / bne
            PCSel_E = BrEq_E ? ~funct3_E[0] : funct3_E[0];
        end
    end else begin
        PCSel_E = 1'b0;
    end
end
endmodule
```

This is a direct port of your existing lines 90–108 in main_decoder.v — the logic is unchanged, only relocated and re-fed from EX-stage, forwarded signals instead of ID-stage ones.

## 7.3 Update main_decoder and control_unit

1. In main_decoder.v, remove PCSel and add Is_Branch, Is_Jump, Is_JALR, Is_Load, UsesRs1, and UsesRs2.  
   Is_Jump is true for JAL and JALR; Is_JALR is true only for opcode 11001111.

2. In control_unit.v, pass the new class/use flags to the top level and declare every internal connection explicitly; do not rely on implicit nets.

3. Thread Is_Branch_D, Is_Jump_D, Is_JALR_D, funct3_D, and all required control fields through ID/EX.  
   Carry funct3_E through EX/MEM as funct3_M for byte/halfword load/store behavior.

## 7.4 Wire PC_in_top and flush logic

```verilog
assign Target_E = Is_JALR_E ? {ALU_out_E[31:1], 1'b0} : ALU_out_E;
assign PC_in_F = PCSel_E ? Target_E : PC_Plus4_F;

// on a taken branch/jump (PCSel_E == 1), two wrong-path instructions exist:
// one already latched into IF_ID_reg, one just fetched this cycle into IF.
assign flush_ifid = PCSel_E; // force IF_ID_reg to a bubble
assign bubble_idx = PCSel_E || stall_load; // redirect or load-use bubble
```

**Priority and squash contract: reset has highest priority, followed by EX redirect, load-use stall, then normal advance. A taken branch/JAL/JALR redirects PC_F and flushes IF/ID plus ID/EX. Never flush EX/MEM for the resolving instruction, because JAL/JALR must still write its link register.**

## 7.5 Test

- Not-taken branch immediately followed by dependent instructions — confirm no flush, normal execution.
- Taken branch: confirm the two younger instructions are squashed, the branch advances into EX/MEM, and PC_F redirects to Target_E.
- Back-to-back taken branches with nothing between them.
- Test JAL and JALR to forward and backward targets; for JALR also test an odd rs1+immediate sum and confirm Target_E[0] is zero.

**Deliverable:** Branch_Resolve.v, the updated main_decoder.v/control_unit.v ports, PC_in_F redirect and flush/bubble wiring, and waveforms for all four cases in 7.5.

---

# Part 8: JAL/JALR and LUI Write-Back

**Objective:** verify JAL/JALR link write-back, JALR target alignment, and LUI write-back through the normal ALU-result path.

**Estimated time:** 45–75 minutes

## 8.1 JAL/JALR

PC_Plus4_F must be carried through IF/ID, ID/EX, EX/MEM, and MEM/WB so WBSel_W can select it as DataD_W for JAL/JALR.

1. Confirm PC_Plus4 is a field of all four pipeline registers.
2. Test: jal x1, target followed several instructions later by an instruction reading x1 — confirm x1 holds the address of the instruction after the jal.

## 8.2 LUI through the ALU path

LUI uses the corrected Single_Cycle ProcessorALU PASS_B operation: BSel_D=1, ALUSel_D=PASS_B, and WBSel_D selects the ALU result. Therefore no separate Imm_M/Imm_W path and no fourth WB source are required.

The WB mux has three architectural sources: DataR_W, ALU_out_W, and PC_Plus4_W. DataD_W is also the MEM/WB forwarding source. Verify that a dependent instruction receives a preceding LUI result from the normal ALU forwarding path.

```verilog
// Three architectural WB sources; LUI is already ALU_out_W.
assign DataD_W = (WBSel_W == 2'b00) ? DataR_W : 
                 (WBSel_W == 2'b01) ? ALU_out_W : 
                 PC_Plus4_W;

// LUI reaches WB as ALU_out_W; WBSel 2'b11 is unused.
```

When LUI, AUIPC, JAL, or JALR is supported by the verified Single_Cycle Processordesign, the pipelined implementation must preserve its architectural result and dependency behavior.

**Deliverable:** waveforms confirming JAL/JALR write the correct link address, JALR clears target bit 0, and LUI writes and forwards its immediate value correctly.

---

# Part 9: Structural Hazard Check

**Objective:** Confirm IF and MEM can access memory in the same cycle without colliding.

**Estimated time:** 15–20 minutes

Your design already uses two separate memories — Instruction_Memory (IMEM.v) and Data_Memory (DMEM.v) — rather than one shared memory with a mux. That's exactly what a pipeline needs, since IF and MEM are active every cycle for two different instructions once the pipeline is full. This part is a verification step, not new construction.

1. Confirm RISCV_Pipeline.v instantiates both Instruction_Memory and Data_Memory as distinct module instances (it does, per the original RISCV_Single_Cycle.v).

2. Test: a program where a lw/sw and an unrelated fetch happen the same cycle (true for nearly every cycle once full) — confirm neither access is corrupted in the waveform.

---

# Part 10: Integration & Regression Testing

**Objective:** Validate the fully assembled RISCV_Pipeline against the same test programs used for RISCV_Single_Cycle, with no manual NOP padding.

**Estimated time:** 2+ hours

1. Pipeline registers only, NOP-padded program (Part 2.6).
2. Add forwarding, remove NOPs between ALU-dependent instructions (Part 5.4).
3. Add hazard_detect, remove NOPs after loads (Part 6.3).
4. Add Branch_Resolve and flush wiring, remove NOPs around branches/jumps (Part 7.5).
5. Run the applicable Single_Cycle Processorarchitectural regression unmodified against RISCV_Pipeline. Report pass/fail per test or implemented instruction, together with total cycles and load-use stall cycles.

## 10.1 Distinguishing a timing bug from a correctness bug

- Passes with NOP padding but fails without it → the bug is in forwarding/stall/flush, not instruction semantics.
- Fails even fully NOP-padded → the bug predates this conversion; recheck the corresponding logic in RISCV_Single_Cycle.v for that instruction.
- Correct final register/memory state but more cycles than expected → hazard logic is overly conservative (e.g. hazard_detect firing on addrD_E == 0).

**Deliverable:** A regression report: pass/fail per test program, and for failures, whether it's a timing or correctness bug and why.

---

# Part 11: Debugging Guide: Common Bugs

- Flushing only data while leaving RegWEn or MemRW asserted creates wrong-path side effects. IF/ID may receive a NOP encoding, but ID/EX must clear every side-effect control.
- x0 forwarding: forward_unit or Branch_Resolve path forwards a value where addrD_M/addrD_W == 0; always gate on != 5'b0 as shown in Part 5.1.
- Forwarding from MEM/WB using ALU_out_W instead of DataD_W (Part 5.2) — silently wrong for any load whose result is being forwarded.
- Forward priority reversed — MEM/WB overriding a matching EX/MEM forward, using a stale value even though a more recent one exists.
- Instr_D == 32'b0 during a flush decoding as an I-Type Load (opcode 5'b00000) in your main_decoder rather than a true NOP — make sure flushed control fields are force-zeroed rather than relying on the all-zero instruction to decode safely (Part 2.1 callout).
- hazard_detect firing when addrD_E == 0 — wastes a stall cycle but doesn't break correctness; still worth gating out.
- Control priority must still be defined even for combinations that are normally mutually exclusive. If PCSel_E and stall_load are both asserted, redirect wins: update PC_F to Target_E, flush IF/ID, bubble ID/EX, and allow EX/MEM and MEM/WB to advance.
- The implicit i_type wire in control_unit.v — it's used in the MainDecode instantiation (i_type(i_type)) but never declared as a wire in control_unit.v; it works today only because of Verilog's implicit net declaration. Worth declaring explicitly (wire i_type); while you're already modifying this file, to avoid a silent width/type surprise later.
- LUI must use ALU_PASS_B and the ordinary ALU_result forwarding path. Do not carry a special Imm_W write-back source.

# Appendix A — Pipeline Register Field Reference

| Register | Fields |
|----------|--------|
| **IF_ID_reg** | `PC_D`, `PC_Plus4_D`, `Instr_D` |
| **ID_EX_reg** | `PC_E`, `PC_Plus4_E`, `DataA_E`, `DataB_E`, `Imm_E`, `addrA_E`, `addrB_E`, `addrD_E`, `funct3_E`, `ALUSel_E`, `WBSel_E`, `RegWEn_E`, `BrUn_E`, `ASel_E`, `BSel_E`, `MemRW_E`, `Is_Branch_E`, `Is_Jump_E`, `Is_JALR_E`, `Is_Load_E` |
| **EX_MEM_reg** | `ALU_out_M`, `DataB_M` *(forwarded store data)*, `PC_Plus4_M`, `addrD_M`, `funct3_M`, `WBSel_M`, `RegWEn_M`, `MemRW_M` |
| **MEM_WB_reg** | `ALU_out_W`, `DataR_W`, `PC_Plus4_W`, `addrD_W`, `WBSel_W`, `RegWEn_W` |

---
