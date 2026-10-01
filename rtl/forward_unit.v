module forward_unit (
    input wire [4:0] addrA_E, 
    input wire [4:0] addrB_E,
    input wire [4:0] addrD_M,
    input wire [4:0] addrD_W,
    input wire RegWEn_M,
    input wire RegWEn_W,
    output reg [1:0] fwdA,
    output reg [1:0] fwdB
);

always @(*) begin
    //tranh latch
    fwdA = 2'b00;
    fwdB = 2'b00;

    if (RegWEn_M && addrD_M != 5'b0 && addrD_M == addrA_E) begin
        fwdA = 2'b10; // Forward from MEM stage
    end else if (RegWEn_W && addrD_W != 5'b0 && addrA_E == addrD_W) begin
        fwdA = 2'b01; // Forward from WB stage
    end

    if (RegWEn_M && addrD_M != 5'b0 && addrD_M == addrB_E) begin
        fwdB = 2'b10; // Forward from MEM stage
    end else if (RegWEn_W && addrD_W != 5'b0 && addrB_E == addrD_W) begin
        fwdB = 2'b01; // Forward from WB stage
    end
end

endmodule
