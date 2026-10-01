 module control_unit (
    input  wire [4:0] opcode_eff,
    input  wire       funct7_fif,
    input  wire [2:0] funct3,

    output wire [2:0] Imm_Sel,
    output wire       RegWEn,
    output wire       BrUn,
    output wire       ASel,
    output wire       BSel,
    output wire [3:0] ALU_Sel,
    output wire       MemRW,
    output wire [1:0] WBSel,

    output wire       Is_Branch,
    output wire       Is_Jump,
    output wire       Is_JALR,
    output wire       Is_Load,
    output wire       UsesRs1,
    output wire       UsesRs2
);

    wire arithmetic;
    wire i_type;
    wire pass_b;

    main_decoder main_decoder_inst (
        .opcode_eff (opcode_eff),
        .funct3     (funct3),
        .ImmSel     (Imm_Sel),
        .RegWEn     (RegWEn),
        .BrUn       (BrUn),
        .ASel       (ASel),
        .BSel       (BSel),
        .MemRW      (MemRW),
        .WBSel      (WBSel),
        .arithmetic (arithmetic),
        .i_type     (i_type),
        .pass_b     (pass_b),
        .Is_Branch  (Is_Branch),
        .Is_Jump    (Is_Jump),
        .Is_JALR    (Is_JALR),
        .Is_Load    (Is_Load),
        .UsesRs1    (UsesRs1),
        .UsesRs2    (UsesRs2)
    );

    ALU_decoder ALU_decoder_inst (
        .arithmetic (arithmetic),
        .pass_b     (pass_b),
        .funct3     (funct3),
        .funct7_fif (funct7_fif),
        .i_type     (i_type),
        .ALUsel     (ALU_Sel)
    );

endmodule
