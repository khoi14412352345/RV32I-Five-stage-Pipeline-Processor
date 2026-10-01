module Branch_Resolve (
    input Is_Branch_E, Is_Jump_E,
    input [2:0] funct3_E,
    input BrEq_E, BrLt_E, 
    output reg PCSel_E
);

always @(*) begin
    if (Is_Jump_E) begin
        PCSel_E = 1'b1; // Jump instruction, take the jump
    end else if (Is_Branch_E) begin
        if (funct3_E[2]) begin
            PCSel_E = BrLt_E ? ~funct3_E[0] : funct3_E[0]; // Branch on less than
        end else begin
            PCSel_E = BrEq_E ? ~funct3_E[0] : funct3_E[0]; // Branch on equal
        end
    end else begin
        PCSel_E = 1'b0; // Not a branch or jump, do not take the branch
    end
end

endmodule