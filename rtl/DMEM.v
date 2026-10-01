module Data_Memory (
    input wire        clk,
    input wire        MemRW,
    input wire [31:0] addr,
    input wire [31:0] DataW,
    input wire [2:0]  funct3,
    output reg [31:0] DataR
);

    reg [31:0] memory [0:255];

    wire [7:0] ram_addr;
    wire [31:0] word;
    reg [7:0] selected_byte;
    reg [15:0] selected_half;

    assign ram_addr = addr[9:2];
    assign word = memory[ram_addr];

    always @(*) begin
        case (addr[1:0])
            2'b00: selected_byte = word[7:0];
            2'b01: selected_byte = word[15:8];
            2'b10: selected_byte = word[23:16];
            default: selected_byte = word[31:24];
        endcase
    
        selected_half = addr[1] ? word[31:16] : word[15:0];
    
        case (funct3)
            3'b000: DataR = {{24{selected_byte[7]}}, selected_byte}; // LB
            3'b001: DataR = {{16{selected_half[15]}}, selected_half}; // LH
            3'b010: DataR = word; // LW
            3'b100: DataR = {24'b0, selected_byte}; // LBU
            3'b101: DataR = {16'b0, selected_half}; // LHU
            default: DataR = 32'b0; // Default case
        endcase
    end

    always @(posedge clk) begin
        if (MemRW) begin
            case (funct3)
                3'b000: begin // SB
                    case (addr[1:0])
                        2'b00: memory[ram_addr][7:0] <= DataW[7:0];
                        2'b01: memory[ram_addr][15:8] <= DataW[7:0];
                        2'b10: memory[ram_addr][23:16] <= DataW[7:0];
                        default: memory[ram_addr][31:24] <= DataW[7:0];
                    endcase
                end
                3'b001: begin // SH
                    if (addr[1])
                        memory[ram_addr][31:16] <= DataW[15:0];
                    else
                        memory[ram_addr][15:0] <= DataW[15:0];
                end
                3'b010: memory[ram_addr] <= DataW;
                default: ; // Do nothing for unsupported funct3 values
            endcase
        end
    end
endmodule
