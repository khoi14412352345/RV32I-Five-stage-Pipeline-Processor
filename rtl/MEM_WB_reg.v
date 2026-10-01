module MEM_WB_reg (
    input clk, rst_n,
    input [31:0] DataR_M, ALU_out_M, PC_Plus4_M,
    input [4:0] addrD_M,
    input [1:0] WBSel_M,
    input RegWEn_M,
    output reg [31:0] DataR_W, ALU_out_W, PC_Plus4_W,
    output reg [4:0] addrD_W,
    output reg [1:0] WBSel_W,
    output reg RegWEn_W
);

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        DataR_W <= 32'b0;
        ALU_out_W <= 32'b0;
        PC_Plus4_W <= 32'b0;
        addrD_W <= 5'b0;
        WBSel_W <= 2'b0;
        RegWEn_W <= 1'b0;
    end else begin
        DataR_W <= DataR_M;
        ALU_out_W <= ALU_out_M;
        PC_Plus4_W <= PC_Plus4_M;
        addrD_W <= addrD_M;
        WBSel_W <= WBSel_M;
        RegWEn_W <= RegWEn_M;
    end 
end

endmodule
