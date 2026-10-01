module ID_EX_reg (
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
    output reg Is_Branch_E, Is_Jump_E, Is_JALR_E, Is_Load_E
);

always @(posedge clk or negedge rst_n) begin
    if (~rst_n || bubble) begin
        PC_E <= 32'b0;
        PC_Plus4_E <= 32'b0;
        DataA_E <= 32'b0;
        DataB_E <= 32'b0;
        Imm_E <= 32'b0;
        addrA_E <= 5'b0;
        addrB_E <= 5'b0;
        addrD_E <= 5'b0;
        funct3_E <= 3'b0;
        ALUSel_E <= 4'b0;
        WBSel_E <= 2'b0;
        RegWEn_E <= 1'b0;
        BrUn_E <= 1'b0;
        ASel_E <= 1'b0;
        BSel_E <= 1'b0;
        MemRW_E <= 1'b0;
        Is_Branch_E <= 1'b0;
        Is_Jump_E <= 1'b0;
        Is_JALR_E <= 1'b0;
        Is_Load_E <= 1'b0;
    end else begin
        PC_E <= PC_D;
        PC_Plus4_E <= PC_Plus4_D;
        DataA_E <= DataA_D;
        DataB_E <= DataB_D;
        Imm_E <= Imm_D;
        addrA_E <= addrA_D;
        addrB_E <= addrB_D;
        addrD_E <= addrD_D;
        funct3_E <= funct3_D;
        ALUSel_E <= ALUSel_D;
        WBSel_E <= WBSel_D;
        RegWEn_E <= RegWEn_D;
        BrUn_E <= BrUn_D;
        ASel_E <= ASel_D;
        BSel_E <= BSel_D;
        MemRW_E <= MemRW_D;
        Is_Branch_E <= Is_Branch_D;
        Is_Jump_E <= Is_Jump_D;
        Is_JALR_E <= Is_JALR_D;
        Is_Load_E <= Is_Load_D;
    end
end

endmodule

