module RegisterFile (
    input wire clk,
    input wire reset,
    input wire reg_write,
    input wire [4:0] addrA,
    input wire [4:0] addrB,
    input wire [4:0] addrD,
    input wire [31:0] dataD,
    output wire [31:0] dataA,
    output wire [31:0] dataB
);

    reg [31:0] registers [0:31];
    integer i;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            // Reset all registers to 0
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else if (reg_write && (addrD != 5'd0)) begin
            // Write dataD to the register specified by addrD
            registers[addrD] <= dataD;
        end
    end

    assign dataA = (addrA == 5'd0) ? 32'b0 : registers[addrA];
    assign dataB = (addrB == 5'd0) ? 32'b0 : registers[addrB];   

endmodule 