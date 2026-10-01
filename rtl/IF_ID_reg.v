module IF_ID_reg (
    input clk, rst_n, stall, flush,
    input [31:0] PC_in, PC_Plus4_in, Instr_in,
    output reg [31:0] PC_D, PC_Plus4_D, Instr_D
);

always @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush) begin
        PC_D <= 32'b0;
        PC_Plus4_D <= 32'b0;
        Instr_D <= 32'h00000013; // NOP instruction, addi x0, x0, 0
    end else if (~stall) begin
        PC_D <= PC_in;
        PC_Plus4_D <= PC_Plus4_in;
        Instr_D <= Instr_in;
    end
end

endmodule