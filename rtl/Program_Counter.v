module Program_Counter (
    input wire clk,
    input wire rst_n,
    input wire stall,
    input wire redirect,
    input wire [31:0] PC_in,
    output reg [31:0] PC_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            PC_out <= 32'b0;
        else if (redirect)
            PC_out <= PC_in;
        else if (~stall)
            PC_out <= PC_in;
    end

endmodule