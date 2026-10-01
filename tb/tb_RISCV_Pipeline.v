`timescale 1ns/1ps

module tb_RISCV_Pipeline;
    localparam [31:0] NOP = 32'h00000013; // addi x0, x0, 0

    reg clk;
    reg rst_n;

    integer i;
    integer test_cycles;
    integer test_stalls;
    integer test_errors;
    integer total_cycles;
    integer total_stalls;
    integer tests_run;
    integer tests_failed;

    RISCV_Pipeline dut (
        .clk   (clk),
        .rst_n (rst_n)
    );

    always #5 clk = ~clk;

    // Count cycles and true load-use stalls for the currently running test.
    always @(posedge clk) begin
        if (rst_n) begin
            test_cycles = test_cycles + 1;
            total_cycles = total_cycles + 1;
            if (dut.stall_load) begin
                test_stalls = test_stalls + 1;
                total_stalls = total_stalls + 1;
            end
        end
    end

    // -------------------- RV32I instruction encoders --------------------
    function [31:0] enc_r;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            enc_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
        end
    endfunction

    function [31:0] enc_i;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_i = {imm, rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] enc_s;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            enc_s = {imm[11:5], rs2, rs1, funct3,
                     imm[4:0], 7'b0100011};
        end
    endfunction

    function [31:0] enc_b;
        input [12:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            enc_b = {imm[12], imm[10:5], rs2, rs1, funct3,
                     imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    function [31:0] enc_u;
        input [19:0] imm;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_u = {imm, rd, opcode};
        end
    endfunction

    function [31:0] enc_j;
        input [20:0] imm;
        input [4:0] rd;
        begin
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12],
                     rd, 7'b1101111};
        end
    endfunction

    // -------------------- Common testbench helpers --------------------
    task prepare_test;
        begin
            rst_n = 1'b0;
            @(negedge clk);

            // Default unused instruction words to real NOPs and clear DMEM.
            for (i = 0; i < 256; i = i + 1) begin
                dut.IMEM_inst.memory[i] = NOP;
                dut.DMEM_inst.memory[i] = 32'b0;
            end

            test_cycles = 0;
            test_stalls = 0;
            test_errors = 0;
        end
    endtask

    task start_test;
        begin
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task run_until_halt;
        input [31:0] halt_pc;
        input integer max_cycles;
        integer waited;
        begin
            waited = 0;
            while ((dut.PC_F !== halt_pc) && (waited < max_cycles)) begin
                @(negedge clk);
                waited = waited + 1;
            end

            if (waited == max_cycles) begin
                $display("    timeout waiting for halt PC %h", halt_pc);
                test_errors = test_errors + 1;
            end else begin
                // Drain all older instructions through WB before checking state.
                repeat (6) @(negedge clk);
            end
        end
    endtask

    task check_reg;
        input [4:0] addr;
        input [31:0] expected;
        begin
            if (dut.Reg_inst.registers[addr] !== expected) begin
                $display("    register x%0d: got %h, expected %h",
                         addr, dut.Reg_inst.registers[addr], expected);
                test_errors = test_errors + 1;
            end
        end
    endtask

    task check_mem;
        input [7:0] word_addr;
        input [31:0] expected;
        begin
            if (dut.DMEM_inst.memory[word_addr] !== expected) begin
                $display("    memory[%0d]: got %h, expected %h",
                         word_addr, dut.DMEM_inst.memory[word_addr], expected);
                test_errors = test_errors + 1;
            end
        end
    endtask

    task check_stalls;
        input integer expected;
        begin
            if (test_stalls !== expected) begin
                $display("    load-use stalls: got %0d, expected %0d",
                         test_stalls, expected);
                test_errors = test_errors + 1;
            end
        end
    endtask

    task report_test;
        input [8*32-1:0] test_name;
        begin
            tests_run = tests_run + 1;
            if (test_errors == 0) begin
                $display("%-32s PASS    %0d       %0d",
                         test_name, test_cycles, test_stalls);
            end else begin
                tests_failed = tests_failed + 1;
                $display("%-32s FAIL    %0d       %0d",
                         test_name, test_cycles, test_stalls);
            end
        end
    endtask

    // -------------------- Part 2: pipeline registers --------------------
    task test_part2_nop_padded;
        begin
            prepare_test;

            // The only intentionally NOP-padded test in this regression.
            dut.IMEM_inst.memory[0]  = enc_i(12'd1, 5'd0, 3'b000, 5'd1, 7'b0010011);
            dut.IMEM_inst.memory[1]  = NOP;
            dut.IMEM_inst.memory[2]  = NOP;
            dut.IMEM_inst.memory[3]  = NOP;
            dut.IMEM_inst.memory[4]  = enc_r(7'd0, 5'd1, 5'd1, 3'b000, 5'd2);
            dut.IMEM_inst.memory[5]  = NOP;
            dut.IMEM_inst.memory[6]  = NOP;
            dut.IMEM_inst.memory[7]  = NOP;
            dut.IMEM_inst.memory[8]  = enc_r(7'd0, 5'd2, 5'd2, 3'b000, 5'd3);
            dut.IMEM_inst.memory[9]  = NOP;
            dut.IMEM_inst.memory[10] = NOP;
            dut.IMEM_inst.memory[11] = NOP;
            dut.IMEM_inst.memory[12] = enc_r(7'd0, 5'd3, 5'd3, 3'b000, 5'd4);
            dut.IMEM_inst.memory[13] = enc_j(21'd0, 5'd0);

            start_test;
            run_until_halt(32'd52, 200);

            check_reg(5'd1, 32'd1);
            check_reg(5'd2, 32'd2);
            check_reg(5'd3, 32'd4);
            check_reg(5'd4, 32'd8);
            check_stalls(0);
            report_test("PART2_PIPE_REG_NOP_PADDED");
        end
    endtask

    // -------------------- Part 5: forwarding --------------------
    task test_part5_forwarding;
        begin
            prepare_test;

            // No NOPs between dependent ALU instructions or the store.
            dut.IMEM_inst.memory[0] = enc_i(12'd1, 5'd0, 3'b000, 5'd1, 7'b0010011);
            dut.IMEM_inst.memory[1] = enc_r(7'd0, 5'd1, 5'd1, 3'b000, 5'd2);
            dut.IMEM_inst.memory[2] = enc_r(7'd0, 5'd2, 5'd2, 3'b000, 5'd3);
            dut.IMEM_inst.memory[3] = enc_r(7'd0, 5'd3, 5'd3, 3'b000, 5'd4);
            dut.IMEM_inst.memory[4] = enc_i(12'd16, 5'd0, 3'b000, 5'd5, 7'b0010011);
            dut.IMEM_inst.memory[5] = enc_i(12'd42, 5'd0, 3'b000, 5'd6, 7'b0010011);
            dut.IMEM_inst.memory[6] = enc_s(12'd0, 5'd6, 5'd5, 3'b010);
            dut.IMEM_inst.memory[7] = enc_j(21'd0, 5'd0);

            start_test;
            run_until_halt(32'd28, 200);

            check_reg(5'd4, 32'd8);
            check_mem(8'd4, 32'd42);
            check_stalls(0);
            report_test("PART5_FORWARDING_NO_NOPS");
        end
    endtask

    // -------------------- Part 6: load-use interlock --------------------
    task test_part6_load_use;
        begin
            prepare_test;

            dut.IMEM_inst.memory[0] = enc_i(12'd21, 5'd0, 3'b000, 5'd2, 7'b0010011);
            dut.IMEM_inst.memory[1] = enc_s(12'd0, 5'd2, 5'd0, 3'b010);
            dut.IMEM_inst.memory[2] = enc_i(12'd0, 5'd0, 3'b010, 5'd5, 7'b0000011);
            dut.IMEM_inst.memory[3] = enc_r(7'd0, 5'd5, 5'd5, 3'b000, 5'd6);
            dut.IMEM_inst.memory[4] = enc_j(21'd0, 5'd0);

            start_test;
            run_until_halt(32'd16, 200);

            check_reg(5'd5, 32'd21);
            check_reg(5'd6, 32'd42);
            check_stalls(1);
            report_test("PART6_LOAD_USE_NO_NOPS");
        end
    endtask

    // -------------------- Part 7: branch/jump flushing --------------------
    task test_part7_control_flow;
        begin
            prepare_test;

            dut.IMEM_inst.memory[0]  = enc_i(12'd1, 5'd0, 3'b000, 5'd1, 7'b0010011);
            dut.IMEM_inst.memory[1]  = enc_b(13'd8, 5'd0, 5'd1, 3'b000);                 // BEQ not taken
            dut.IMEM_inst.memory[2]  = enc_i(12'd1, 5'd1, 3'b000, 5'd2, 7'b0010011);
            dut.IMEM_inst.memory[3]  = enc_b(13'd12, 5'd2, 5'd2, 3'b000);                // BEQ taken -> 24
            dut.IMEM_inst.memory[4]  = enc_i(12'd99, 5'd0, 3'b000, 5'd3, 7'b0010011);   // flushed
            dut.IMEM_inst.memory[5]  = enc_s(12'd0, 5'd3, 5'd0, 3'b010);                 // flushed
            dut.IMEM_inst.memory[6]  = enc_b(13'd8, 5'd2, 5'd2, 3'b000);                 // taken -> 32
            dut.IMEM_inst.memory[7]  = enc_i(12'd99, 5'd0, 3'b000, 5'd4, 7'b0010011);   // flushed
            dut.IMEM_inst.memory[8]  = enc_b(13'd8, 5'd0, 5'd2, 3'b001);                 // BNE taken -> 40
            dut.IMEM_inst.memory[9]  = enc_i(12'd99, 5'd0, 3'b000, 5'd5, 7'b0010011);   // flushed
            dut.IMEM_inst.memory[10] = enc_j(21'd12, 5'd6);                              // JAL -> 52, link=44
            dut.IMEM_inst.memory[11] = enc_i(12'd99, 5'd0, 3'b000, 5'd7, 7'b0010011);   // flushed
            dut.IMEM_inst.memory[12] = enc_s(12'd4, 5'd7, 5'd0, 3'b010);                 // flushed
            dut.IMEM_inst.memory[13] = enc_i(12'd37, 5'd6, 3'b000, 5'd8, 7'b0010011);   // x8=81
            dut.IMEM_inst.memory[14] = enc_i(12'd0, 5'd8, 3'b000, 5'd9, 7'b1100111);    // JALR -> 80, link=60
            dut.IMEM_inst.memory[15] = enc_i(12'd99, 5'd0, 3'b000, 5'd10, 7'b0010011);  // flushed
            dut.IMEM_inst.memory[16] = enc_s(12'd8, 5'd10, 5'd0, 3'b010);               // flushed
            dut.IMEM_inst.memory[17] = enc_i(12'd1, 5'd0, 3'b000, 5'd10, 7'b0010011);   // unreachable
            dut.IMEM_inst.memory[18] = enc_i(12'd2, 5'd0, 3'b000, 5'd10, 7'b0010011);   // unreachable
            dut.IMEM_inst.memory[19] = enc_i(12'd3, 5'd0, 3'b000, 5'd10, 7'b0010011);   // unreachable
            dut.IMEM_inst.memory[20] = enc_i(12'd20, 5'd9, 3'b000, 5'd11, 7'b0010011);  // x11=80
            dut.IMEM_inst.memory[21] = enc_j(21'd0, 5'd0);

            start_test;
            run_until_halt(32'd84, 200);

            check_reg(5'd2, 32'd2);
            check_reg(5'd3, 32'd0);
            check_reg(5'd4, 32'd0);
            check_reg(5'd5, 32'd0);
            check_reg(5'd6, 32'd44);
            check_reg(5'd7, 32'd0);
            check_reg(5'd8, 32'd81);
            check_reg(5'd9, 32'd60);
            check_reg(5'd10, 32'd0);
            check_reg(5'd11, 32'd80);
            check_mem(8'd0, 32'd0);
            check_mem(8'd1, 32'd0);
            check_mem(8'd2, 32'd0);
            check_stalls(0);
            report_test("PART7_BRANCH_JUMP_FLUSH");
        end
    endtask

    // -------- Exact instruction vectors from tb_RISCV_Single_Cycle --------
    // Each isolated instruction receives seven cycles so it can reach WB.
    task lab6_register_instruction;
        input [8*32-1:0] test_name;
        input [31:0] instruction;
        input [4:0] rs1_index;
        input [31:0] rs1_value;
        input [4:0] rs2_index;
        input [31:0] rs2_value;
        input [4:0] rd_index;
        input [31:0] expected_result;
        begin
            prepare_test;
            dut.IMEM_inst.memory[0] = instruction;
            start_test;
            if (rs1_index != 5'd0)
                dut.Reg_inst.registers[rs1_index] = rs1_value;
            if (rs2_index != 5'd0)
                dut.Reg_inst.registers[rs2_index] = rs2_value;
            repeat (7) @(negedge clk);
            check_reg(rd_index, expected_result);
            check_reg(5'd0, 32'd0);
            check_stalls(0);
            report_test(test_name);
        end
    endtask

    task lab6_load_instruction;
        input [8*32-1:0] test_name;
        input [2:0] funct3;
        input [11:0] byte_offset;
        input [31:0] memory_word;
        input [31:0] expected_result;
        begin
            prepare_test;
            dut.IMEM_inst.memory[0] =
                enc_i(byte_offset, 5'd1, funct3, 5'd3, 7'b0000011);
            start_test;
            dut.Reg_inst.registers[1] = 32'd0;
            dut.DMEM_inst.memory[0] = memory_word;
            repeat (7) @(negedge clk);
            check_reg(5'd3, expected_result);
            check_stalls(0);
            report_test(test_name);
        end
    endtask

    task lab6_store_instruction;
        input [8*32-1:0] test_name;
        input [2:0] funct3;
        input [11:0] byte_offset;
        input [31:0] original_word;
        input [31:0] store_value;
        input [31:0] expected_word;
        begin
            prepare_test;
            dut.IMEM_inst.memory[0] =
                enc_s(byte_offset, 5'd2, 5'd1, funct3);
            start_test;
            dut.Reg_inst.registers[1] = 32'd0;
            dut.Reg_inst.registers[2] = store_value;
            dut.DMEM_inst.memory[0] = original_word;
            repeat (7) @(negedge clk);
            check_mem(8'd0, expected_word);
            check_stalls(0);
            report_test(test_name);
        end
    endtask

    task lab6_branch_instruction;
        input [8*32-1:0] test_name;
        input [2:0] funct3;
        input [31:0] rs1_value;
        input [31:0] rs2_value;
        input [31:0] expected_pc;
        integer step;
        integer branch_seen;
        reg expected_taken;
        begin
            prepare_test;
            dut.IMEM_inst.memory[0] = enc_b(13'd8, 5'd2, 5'd1, funct3);
            start_test;
            dut.Reg_inst.registers[1] = rs1_value;
            dut.Reg_inst.registers[2] = rs2_value;
            expected_taken = (expected_pc == 32'd8);
            branch_seen = 0;
            for (step = 0; step < 7; step = step + 1) begin
                @(negedge clk);
                if (dut.Is_Branch_E) begin
                    branch_seen = 1;
                    if (dut.PCSel_E !== expected_taken) begin
                        $display("    branch decision: got %b, expected %b",
                                 dut.PCSel_E, expected_taken);
                        test_errors = test_errors + 1;
                    end
                    if (dut.Target_E !== 32'd8) begin
                        $display("    branch target: got %h, expected 00000008",
                                 dut.Target_E);
                        test_errors = test_errors + 1;
                    end
                end
            end
            if (branch_seen == 0) begin
                $display("    branch never reached EX");
                test_errors = test_errors + 1;
            end
            check_stalls(0);
            report_test(test_name);
        end
    endtask

    task lab6_lui;
        begin
            prepare_test;
            dut.IMEM_inst.memory[0] = enc_u(20'h12345, 5'd3, 7'b0110111);
            start_test;
            for (i = 1; i < 32; i = i + 1)
                dut.Reg_inst.registers[i] = 32'hdeadbeef;
            repeat (7) @(negedge clk);
            check_reg(5'd3, 32'h12345000);
            check_stalls(0);
            report_test("LUI");
        end
    endtask

    task lab6_auipc;
        begin
            prepare_test;
            dut.IMEM_inst.memory[8] = enc_u(20'h01000, 5'd3, 7'b0010111);
            @(negedge clk);
            dut.PC_inst.PC_out = 32'h00000020;
            rst_n = 1'b1;
            repeat (7) @(negedge clk);
            check_reg(5'd3, 32'h01000020);
            check_stalls(0);
            report_test("AUIPC");
        end
    endtask

    task lab6_jump;
        input [8*32-1:0] test_name;
        input [31:0] instruction;
        input [4:0] base_index;
        input [31:0] base_value;
        input [31:0] expected_target;
        integer step;
        integer jump_seen;
        begin
            prepare_test;
            dut.IMEM_inst.memory[0] = instruction;
            start_test;
            if (base_index != 5'd0)
                dut.Reg_inst.registers[base_index] = base_value;
            jump_seen = 0;
            for (step = 0; step < 9; step = step + 1) begin
                @(negedge clk);
                if (dut.Is_Jump_E) begin
                    jump_seen = 1;
                    if (dut.PCSel_E !== 1'b1) begin
                        $display("    jump did not assert PCSel_E");
                        test_errors = test_errors + 1;
                    end
                    if (dut.Target_E !== expected_target) begin
                        $display("    jump target: got %h, expected %h",
                                 dut.Target_E, expected_target);
                        test_errors = test_errors + 1;
                    end
                end
            end
            if (jump_seen == 0) begin
                $display("    jump never reached EX");
                test_errors = test_errors + 1;
            end
            check_reg(5'd3, 32'd4);
            check_stalls(0);
            report_test(test_name);
        end
    endtask

    task lab6_x0_check;
        begin
            prepare_test;
            dut.IMEM_inst.memory[0] =
                enc_i(12'd123, 5'd0, 3'b000, 5'd0, 7'b0010011);
            start_test;
            repeat (7) @(negedge clk);
            check_reg(5'd0, 32'd0);
            check_stalls(0);
            report_test("x0_WRITE_PROTECTION");
        end
    endtask

    task run_exact_lab6_regression;
        begin
            // Register-register ALU vectors.
            lab6_register_instruction("ADD",
                enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3),
                5'd1, 32'h7ffffff0, 5'd2, 32'h00000020,
                5'd3, 32'h80000010);
            lab6_register_instruction("SUB",
                enc_r(7'b0100000, 5'd2, 5'd1, 3'b000, 5'd3),
                5'd1, 32'd5, 5'd2, 32'd13, 5'd3, 32'hfffffff8);
            lab6_register_instruction("SLL",
                enc_r(7'b0000000, 5'd2, 5'd1, 3'b001, 5'd3),
                5'd1, 32'd1, 5'd2, 32'd31, 5'd3, 32'h80000000);
            lab6_register_instruction("SLT",
                enc_r(7'b0000000, 5'd2, 5'd1, 3'b010, 5'd3),
                5'd1, 32'hffffffff, 5'd2, 32'd1, 5'd3, 32'd1);
            lab6_register_instruction("SLTU",
                enc_r(7'b0000000, 5'd2, 5'd1, 3'b011, 5'd3),
                5'd1, 32'd1, 5'd2, 32'hffffffff, 5'd3, 32'd1);
            lab6_register_instruction("XOR",
                enc_r(7'b0000000, 5'd2, 5'd1, 3'b100, 5'd3),
                5'd1, 32'ha5a5a5a5, 5'd2, 32'h5a5a5a5a,
                5'd3, 32'hffffffff);
            lab6_register_instruction("SRL",
                enc_r(7'b0000000, 5'd2, 5'd1, 3'b101, 5'd3),
                5'd1, 32'h80000000, 5'd2, 32'd1, 5'd3, 32'h40000000);
            lab6_register_instruction("SRA",
                enc_r(7'b0100000, 5'd2, 5'd1, 3'b101, 5'd3),
                5'd1, 32'h80000000, 5'd2, 32'd1, 5'd3, 32'hc0000000);
            lab6_register_instruction("OR",
                enc_r(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd3),
                5'd1, 32'haaaa0000, 5'd2, 32'h00005555,
                5'd3, 32'haaaa5555);
            lab6_register_instruction("AND",
                enc_r(7'b0000000, 5'd2, 5'd1, 3'b111, 5'd3),
                5'd1, 32'hf0f0aaaa, 5'd2, 32'h0ff0ff00,
                5'd3, 32'h00f0aa00);

            // Immediate ALU vectors.
            lab6_register_instruction("ADDI",
                enc_i(12'hff8, 5'd1, 3'b000, 5'd3, 7'b0010011),
                5'd1, 32'd5, 5'd0, 32'd0, 5'd3, 32'hfffffffd);
            lab6_register_instruction("SLTI",
                enc_i(12'h000, 5'd1, 3'b010, 5'd3, 7'b0010011),
                5'd1, 32'hffffffff, 5'd0, 32'd0, 5'd3, 32'd1);
            lab6_register_instruction("SLTIU",
                enc_i(12'hfff, 5'd1, 3'b011, 5'd3, 7'b0010011),
                5'd1, 32'd1, 5'd0, 32'd0, 5'd3, 32'd1);
            lab6_register_instruction("XORI",
                enc_i(12'h0ff, 5'd1, 3'b100, 5'd3, 7'b0010011),
                5'd1, 32'ha5a5a5a5, 5'd0, 32'd0, 5'd3, 32'ha5a5a55a);
            lab6_register_instruction("ORI",
                enc_i(12'h0ff, 5'd1, 3'b110, 5'd3, 7'b0010011),
                5'd1, 32'h12340000, 5'd0, 32'd0, 5'd3, 32'h123400ff);
            lab6_register_instruction("ANDI",
                enc_i(12'h0f0, 5'd1, 3'b111, 5'd3, 7'b0010011),
                5'd1, 32'hffffffff, 5'd0, 32'd0, 5'd3, 32'h000000f0);
            lab6_register_instruction("SLLI",
                enc_i(12'h01f, 5'd1, 3'b001, 5'd3, 7'b0010011),
                5'd1, 32'd1, 5'd0, 32'd0, 5'd3, 32'h80000000);
            lab6_register_instruction("SRLI",
                enc_i(12'h001, 5'd1, 3'b101, 5'd3, 7'b0010011),
                5'd1, 32'h80000000, 5'd0, 32'd0, 5'd3, 32'h40000000);
            lab6_register_instruction("SRAI",
                enc_i(12'h401, 5'd1, 3'b101, 5'd3, 7'b0010011),
                5'd1, 32'h80000000, 5'd0, 32'd0, 5'd3, 32'hc0000000);

            // Load and store vectors.
            lab6_load_instruction("LB", 3'b000, 12'd3,
                32'h80ff7f01, 32'hffffff80);
            lab6_load_instruction("LH", 3'b001, 12'd2,
                32'h80ff7f01, 32'hffff80ff);
            lab6_load_instruction("LW", 3'b010, 12'd0,
                32'h89abcdef, 32'h89abcdef);
            lab6_load_instruction("LBU", 3'b100, 12'd2,
                32'h80ff7f01, 32'h000000ff);
            lab6_load_instruction("LHU", 3'b101, 12'd2,
                32'h80ff7f01, 32'h000080ff);
            lab6_store_instruction("SB", 3'b000, 12'd1,
                32'haabbccdd, 32'h11223344, 32'haabb44dd);
            lab6_store_instruction("SH", 3'b001, 12'd2,
                32'haabbccdd, 32'h11223344, 32'h3344ccdd);
            lab6_store_instruction("SW", 3'b010, 12'd0,
                32'haabbccdd, 32'h11223344, 32'h11223344);

            // Every branch vector, taken and not taken.
            lab6_branch_instruction("BEQ_TAKEN", 3'b000, 32'd5, 32'd5, 32'd8);
            lab6_branch_instruction("BEQ_NOT_TAKEN", 3'b000, 32'd5, 32'd6, 32'd4);
            lab6_branch_instruction("BNE_TAKEN", 3'b001, 32'd5, 32'd6, 32'd8);
            lab6_branch_instruction("BNE_NOT_TAKEN", 3'b001, 32'd5, 32'd5, 32'd4);
            lab6_branch_instruction("BLT_TAKEN", 3'b100,
                32'hffffffff, 32'd1, 32'd8);
            lab6_branch_instruction("BLT_NOT_TAKEN", 3'b100,
                32'd1, 32'hffffffff, 32'd4);
            lab6_branch_instruction("BGE_TAKEN", 3'b101,
                32'd1, 32'hffffffff, 32'd8);
            lab6_branch_instruction("BGE_NOT_TAKEN", 3'b101,
                32'hffffffff, 32'd1, 32'd4);
            lab6_branch_instruction("BLTU_TAKEN", 3'b110,
                32'd1, 32'hffffffff, 32'd8);
            lab6_branch_instruction("BLTU_NOT_TAKEN", 3'b110,
                32'hffffffff, 32'd1, 32'd4);
            lab6_branch_instruction("BGEU_TAKEN", 3'b111,
                32'hffffffff, 32'd1, 32'd8);
            lab6_branch_instruction("BGEU_NOT_TAKEN", 3'b111,
                32'd1, 32'hffffffff, 32'd4);

            lab6_lui;
            lab6_auipc;
            lab6_jump("JAL", enc_j(21'd8, 5'd3),
                      5'd0, 32'd0, 32'd8);
            lab6_jump("JALR",
                      enc_i(12'd5, 5'd1, 3'b000, 5'd3, 7'b1100111),
                      5'd1, 32'h00000020, 32'h00000024);
            lab6_x0_check;
        end
    endtask

    // -------------------- Regression entry point --------------------
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        test_cycles = 0;
        test_stalls = 0;
        test_errors = 0;
        total_cycles = 0;
        total_stalls = 0;
        tests_run = 0;
        tests_failed = 0;

        if ($test$plusargs("VCD")) begin
            $dumpfile("tb_RISCV_Pipeline.vcd");
            $dumpvars(0, tb_RISCV_Pipeline);
        end

        $display("");
        $display("RISCV_Pipeline self-checking regression");
        $display("TEST                             RESULT  CYCLES  LOAD_USE_STALLS");
        $display("----------------------------------------------------------------");

        test_part2_nop_padded;
        test_part5_forwarding;
        test_part6_load_use;
        test_part7_control_flow;
        run_exact_lab6_regression;

        $display("----------------------------------------------------------------");
        if (tests_failed == 0)
            $display("OVERALL                          PASS    %0d       %0d",
                     total_cycles, total_stalls);
        else
            $display("OVERALL                          FAIL    %0d       %0d",
                     total_cycles, total_stalls);
        $display("Tests: %0d passed, %0d failed",
                 tests_run - tests_failed, tests_failed);
        $display("");

        $finish;
    end
endmodule
