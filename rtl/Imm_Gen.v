module Immediate_Generator (
    input  wire [31:0] Inst,
    input  wire [2:0]  ImmSel,
    output reg  [31:0] Imm
);

    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    always @(*) begin
        case (ImmSel)
            // I-type: loads, immediate ALU operations, and JALR.
            IMM_I: Imm = {{20{Inst[31]}}, Inst[31:20]};

            // S-type: stores.
            IMM_S: Imm = {{20{Inst[31]}},
                          Inst[31:25],
                          Inst[11:7]};

            // B-type: conditional branches. The encoded offset is
            // always even, so bit zero is restored as 1'b0.
            IMM_B: Imm = {{19{Inst[31]}},
                          Inst[31],
                          Inst[7],
                          Inst[30:25],
                          Inst[11:8],
                          1'b0};

            // U-type: LUI and AUIPC.
            IMM_U: Imm = {Inst[31:12], 12'b0};

            // J-type: JAL. As with branches, bit zero is implicit.
            IMM_J: Imm = {{11{Inst[31]}},
                          Inst[31],
                          Inst[19:12],
                          Inst[20],
                          Inst[30:21],
                          1'b0};

            default: Imm = 32'b0;
        endcase
    end

endmodule
