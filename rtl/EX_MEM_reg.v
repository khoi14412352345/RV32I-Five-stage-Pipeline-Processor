module EX_MEM_reg (
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

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        ALU_out_M <= 32'b0;
        DataB_M <= 32'b0;
        PC_Plus4_M <= 32'b0;
        addrD_M <= 5'b0;
        WBSel_M <= 2'b0;
        RegWEn_M <= 1'b0;
        MemRW_M <= 1'b0;
        funct3_M <= 3'b0;
    end else begin
        ALU_out_M <= ALU_out_E;
        DataB_M <= DataB_fwd_E;
        PC_Plus4_M <= PC_Plus4_E;
        addrD_M <= addrD_E;
        WBSel_M <= WBSel_E;
        RegWEn_M <= RegWEn_E;
        MemRW_M <= MemRW_E;
        funct3_M <= funct3_E;
    end 
end

endmodule