module RISCV_Pipeline (
    input wire clk,
    input wire rst_n
);

    localparam [1:0] WB_MEM = 2'b00;
    localparam [1:0] WB_ALU = 2'b01;
    localparam [1:0] WB_PC4 = 2'b10;

    // IF stage
    wire [31:0] PC_F;
    wire [31:0] PC_Plus4_F;
    wire [31:0] PC_in_F;
    wire [31:0] Instr_F;

    // ID stage
    wire [31:0] PC_D;
    wire [31:0] PC_Plus4_D;
    wire [31:0] Instr_D;
    wire [31:0] Imm_D;
    wire [31:0] rf_DataA_D;
    wire [31:0] rf_DataB_D;
    wire [31:0] DataA_D;
    wire [31:0] DataB_D;
    wire [2:0]  ImmSel_D;
    wire [3:0]  ALUSel_D;
    wire [1:0]  WBSel_D;
    wire        RegWEn_D;
    wire        BrUn_D;
    wire        ASel_D;
    wire        BSel_D;
    wire        MemRW_D;
    wire        Is_Branch_D;
    wire        Is_Jump_D;
    wire        Is_JALR_D;
    wire        Is_Load_D;
    wire        UsesRs1_D;
    wire        UsesRs2_D;

    // EX stage
    wire [31:0] PC_E;
    wire [31:0] PC_Plus4_E;
    wire [31:0] DataA_E;
    wire [31:0] DataB_E;
    wire [31:0] Imm_E;
    wire [31:0] fwd_DataA_E;
    wire [31:0] fwd_DataB_E;
    wire [31:0] Mux_ALU_DataA_E;
    wire [31:0] Mux_ALU_DataB_E;
    wire [31:0] ALU_out_E;
    wire [31:0] Target_E;
    wire [4:0]  addrA_E;
    wire [4:0]  addrB_E;
    wire [4:0]  addrD_E;
    wire [2:0]  funct3_E;
    wire [3:0]  ALUSel_E;
    wire [1:0]  WBSel_E;
    wire [1:0]  fwdA;
    wire [1:0]  fwdB;
    wire        RegWEn_E;
    wire        BrUn_E;
    wire        ASel_E;
    wire        BSel_E;
    wire        MemRW_E;
    wire        Is_Branch_E;
    wire        Is_Jump_E;
    wire        Is_JALR_E;
    wire        Is_Load_E;
    wire        BrEq_E;
    wire        BrLt_E;
    wire        PCSel_E;

    // MEM stage
    wire [31:0] ALU_out_M;
    wire [31:0] DataB_M;
    wire [31:0] PC_Plus4_M;
    wire [31:0] ForwardData_M;
    wire [31:0] DataR_M;
    wire [4:0]  addrD_M;
    wire [2:0]  funct3_M;
    wire [1:0]  WBSel_M;
    wire        RegWEn_M;
    wire        MemRW_M;

    // WB stage
    wire [31:0] DataR_W;
    wire [31:0] ALU_out_W;
    wire [31:0] PC_Plus4_W;
    wire [31:0] DataD_W;
    wire [4:0]  addrD_W;
    wire [1:0]  WBSel_W;
    wire        RegWEn_W;

    // Pipeline control
    wire stall_load;
    wire flush_ifid;
    wire bubble_idx;

    // -------------------- IF stage --------------------
    assign PC_Plus4_F = PC_F + 32'd4; 
    assign PC_in_F = PCSel_E ? Target_E : PC_Plus4_F;
    assign flush_ifid = PCSel_E;
    assign bubble_idx = PCSel_E || stall_load;

    Program_Counter PC_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .stall    (stall_load),
        .redirect (PCSel_E),
        .PC_in    (PC_in_F),
        .PC_out   (PC_F)
    );

    // IMEM is word-indexed; the architectural PC is byte-addressed.
    Instruction_Memory IMEM_inst (
        .addr ({2'b0, PC_F[31:2]}),
        .inst (Instr_F)
    );

    // -------------------- IF/ID register --------------------
    IF_ID_reg IF_ID_reg_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall        (stall_load),
        .flush        (flush_ifid),
        .PC_in        (PC_F),
        .PC_Plus4_in  (PC_Plus4_F),
        .Instr_in     (Instr_F),
        .PC_D         (PC_D),
        .PC_Plus4_D   (PC_Plus4_D),
        .Instr_D      (Instr_D)
    );

    // -------------------- ID stage --------------------
    control_unit control_unit_inst (
        .opcode_eff (Instr_D[6:2]),
        .funct7_fif (Instr_D[30]),
        .funct3     (Instr_D[14:12]),
        .Imm_Sel    (ImmSel_D),
        .RegWEn     (RegWEn_D),
        .BrUn       (BrUn_D),
        .ASel       (ASel_D),
        .BSel       (BSel_D),
        .ALU_Sel    (ALUSel_D),
        .MemRW      (MemRW_D),
        .WBSel      (WBSel_D),
        .Is_Branch  (Is_Branch_D),
        .Is_Jump    (Is_Jump_D),
        .Is_JALR    (Is_JALR_D),
        .Is_Load    (Is_Load_D),
        .UsesRs1    (UsesRs1_D),
        .UsesRs2    (UsesRs2_D)
    );

    Immediate_Generator Imm_Gen_inst (
        .Inst   (Instr_D),
        .ImmSel (ImmSel_D),
        .Imm    (Imm_D)
    );

    // The register file is read in ID and written in WB.
    RegisterFile Reg_inst (
        .clk       (clk),
        .reset     (rst_n),
        .reg_write (RegWEn_W),
        .addrA     (Instr_D[19:15]),
        .addrB     (Instr_D[24:20]),
        .addrD     (addrD_W),
        .dataD     (DataD_W),
        .dataA     (rf_DataA_D),
        .dataB     (rf_DataB_D)
    );

    // Explicit write-through handles a WB write and ID read on the same edge.
    assign DataA_D = (RegWEn_W && (addrD_W != 5'd0) &&
                      (addrD_W == Instr_D[19:15])) ? DataD_W : rf_DataA_D;
    assign DataB_D = (RegWEn_W && (addrD_W != 5'd0) &&
                      (addrD_W == Instr_D[24:20])) ? DataD_W : rf_DataB_D;

    hazard_detect hazard_detect_inst (
        .Is_Load_E  (Is_Load_E),
        .addrD_E    (addrD_E),
        .addrA_D    (Instr_D[19:15]),
        .addrB_D    (Instr_D[24:20]),
        .UsesRs1_D  (UsesRs1_D),
        .UsesRs2_D  (UsesRs2_D),
        .stall_load (stall_load)
    );

    // -------------------- ID/EX register --------------------
    // A redirect or a load-use dependency inserts a side-effect-free bubble.
    ID_EX_reg ID_EX_reg_inst (
        .clk           (clk),
        .rst_n         (rst_n),
        .bubble        (bubble_idx),
        .PC_D          (PC_D),
        .PC_Plus4_D    (PC_Plus4_D),
        .DataA_D       (DataA_D),
        .DataB_D       (DataB_D),
        .Imm_D         (Imm_D),
        .addrA_D       (Instr_D[19:15]),
        .addrB_D       (Instr_D[24:20]),
        .addrD_D       (Instr_D[11:7]),
        .funct3_D      (Instr_D[14:12]),
        .ALUSel_D      (ALUSel_D),
        .WBSel_D       (WBSel_D),
        .RegWEn_D      (RegWEn_D),
        .BrUn_D        (BrUn_D),
        .ASel_D        (ASel_D),
        .BSel_D        (BSel_D),
        .MemRW_D       (MemRW_D),
        .Is_Branch_D   (Is_Branch_D),
        .Is_Jump_D     (Is_Jump_D),
        .Is_JALR_D     (Is_JALR_D),
        .Is_Load_D     (Is_Load_D),
        .PC_E          (PC_E),
        .PC_Plus4_E    (PC_Plus4_E),
        .DataA_E       (DataA_E),
        .DataB_E       (DataB_E),
        .Imm_E         (Imm_E),
        .addrA_E       (addrA_E),
        .addrB_E       (addrB_E),
        .addrD_E       (addrD_E),
        .funct3_E      (funct3_E),
        .ALUSel_E      (ALUSel_E),
        .WBSel_E       (WBSel_E),
        .RegWEn_E      (RegWEn_E),
        .BrUn_E        (BrUn_E),
        .ASel_E        (ASel_E),
        .BSel_E        (BSel_E),
        .MemRW_E       (MemRW_E),
        .Is_Branch_E   (Is_Branch_E),
        .Is_Jump_E     (Is_Jump_E),
        .Is_JALR_E     (Is_JALR_E),
        .Is_Load_E     (Is_Load_E)
    );

    // -------------------- EX stage --------------------
    forward_unit forward_unit_inst (
        .addrA_E  (addrA_E),
        .addrB_E  (addrB_E),
        .addrD_M  (addrD_M),
        .addrD_W  (addrD_W),
        .RegWEn_M (RegWEn_M),
        .RegWEn_W (RegWEn_W),
        .fwdA     (fwdA),
        .fwdB     (fwdB)
    );

    // EX/MEM has priority over MEM/WB, as encoded by forward_unit.
    assign fwd_DataA_E = (fwdA == 2'b10) ? ForwardData_M :
                         (fwdA == 2'b01) ? DataD_W : DataA_E;
    assign fwd_DataB_E = (fwdB == 2'b10) ? ForwardData_M :
                         (fwdB == 2'b01) ? DataD_W : DataB_E;

    assign Mux_ALU_DataA_E = ASel_E ? PC_E : fwd_DataA_E;
    assign Mux_ALU_DataB_E = BSel_E ? Imm_E : fwd_DataB_E;

    ALU ALU_inst (
        .ALU_Sel   (ALUSel_E),
        .operand_0 (Mux_ALU_DataA_E),
        .operand_1 (Mux_ALU_DataB_E),
        .result    (ALU_out_E)
    );

    Branch_Comp Branch_Comp_inst (
        .operand_0 (fwd_DataA_E),
        .operand_1 (fwd_DataB_E),
        .BrUn      (BrUn_E),
        .BrEq      (BrEq_E),
        .BrLT      (BrLt_E)
    );

    Branch_Resolve Branch_Resolve_inst (
        .Is_Branch_E (Is_Branch_E),
        .Is_Jump_E   (Is_Jump_E),
        .funct3_E    (funct3_E),
        .BrEq_E      (BrEq_E),
        .BrLt_E      (BrLt_E),
        .PCSel_E     (PCSel_E)
    );

    // JALR alone requires bit zero of the computed target to be cleared.
    assign Target_E = Is_JALR_E ? {ALU_out_E[31:1], 1'b0} : ALU_out_E;

    // -------------------- EX/MEM register --------------------
    EX_MEM_reg EX_MEM_reg_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .ALU_out_E    (ALU_out_E),
        .DataB_fwd_E  (fwd_DataB_E),
        .PC_Plus4_E   (PC_Plus4_E),
        .addrD_E      (addrD_E),
        .WBSel_E      (WBSel_E),
        .RegWEn_E     (RegWEn_E),
        .MemRW_E      (MemRW_E),
        .funct3_E     (funct3_E),
        .ALU_out_M    (ALU_out_M),
        .DataB_M      (DataB_M),
        .PC_Plus4_M   (PC_Plus4_M),
        .addrD_M      (addrD_M),
        .WBSel_M      (WBSel_M),
        .RegWEn_M     (RegWEn_M),
        .MemRW_M      (MemRW_M),
        .funct3_M     (funct3_M)
    );

    // Loads are forwarded from WB after the interlock; links can forward in M.
    assign ForwardData_M = (WBSel_M == WB_PC4) ? PC_Plus4_M : ALU_out_M;

    // -------------------- MEM stage --------------------
    Data_Memory DMEM_inst (
        .clk    (clk),
        .MemRW  (MemRW_M),
        .addr   (ALU_out_M),
        .DataW  (DataB_M),
        .funct3 (funct3_M),
        .DataR  (DataR_M)
    );

    // -------------------- MEM/WB register --------------------
    MEM_WB_reg MEM_WB_reg_inst (
        .clk         (clk),
        .rst_n       (rst_n),
        .DataR_M     (DataR_M),
        .ALU_out_M   (ALU_out_M),
        .PC_Plus4_M  (PC_Plus4_M),
        .addrD_M     (addrD_M),
        .WBSel_M     (WBSel_M),
        .RegWEn_M    (RegWEn_M),
        .DataR_W     (DataR_W),
        .ALU_out_W   (ALU_out_W),
        .PC_Plus4_W  (PC_Plus4_W),
        .addrD_W     (addrD_W),
        .WBSel_W     (WBSel_W),
        .RegWEn_W    (RegWEn_W)
    );

    // -------------------- WB stage --------------------
    assign DataD_W = (WBSel_W == WB_MEM) ? DataR_W :
                     (WBSel_W == WB_ALU) ? ALU_out_W :
                                           PC_Plus4_W;

endmodule
