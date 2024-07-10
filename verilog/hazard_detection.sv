`timescale 1ns/100ps
module hazard_detection_unit (
    input rs_ld_st_full,
	input rs_alu_full,
    input rob_full,
    input lb_full,
    input is_ld_st_inst,
    input is_valid_inst,

    output if_enable,
    output if_is_enable,
    output if_is_flush, // branch misprediction
    output rob_enable,
    output rs_ld_st_enable,
	output rs_ld_exec_stall,
	output rs_alu_enable,
    output rs_alu_exec_stall,
    output lb_exec_stall,
    output alu_wr_enable,
    output lb_wr_enable,
    output acu_wr_enable
);

    assign is_struct_hazard = rob_full
        | (is_ld_st_inst & rs_ld_st_full)
        | (~is_ld_st_inst & rs_alu_full);
    
    assign rs_ld_st_enable = ~is_struct_hazard & is_valid_inst & is_ld_st_inst;
    assign rs_alu_enable = ~is_struct_hazard & is_valid_inst & ~is_ld_st_inst;

    //  assign if_enable = ~is_struct_hazard & ~

endmodule
