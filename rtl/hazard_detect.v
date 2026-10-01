module hazard_detect (
    input Is_Load_E,
    input [4:0] addrD_E,
    input [4:0] addrA_D,
    input [4:0] addrB_D,
    input UsesRs1_D,
    input UsesRs2_D,
    output stall_load
);

assign stall_load = Is_Load_E && (addrD_E != 5'b0) &&
        ((UsesRs1_D && (addrD_E == addrA_D)) ||
         (UsesRs2_D && (addrD_E == addrB_D)));

endmodule
