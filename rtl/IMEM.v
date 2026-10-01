module Instruction_Memory (
    input wire [31:0] addr,
    output wire [31:0] inst
);

    reg [31:0] memory [0:255];

    assign inst = memory[addr[7:0]];

endmodule
