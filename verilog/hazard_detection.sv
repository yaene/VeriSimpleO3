`timescale 1ns/100ps
module hazard_detection_unit (
    input clock,
    input reset,
    input rs_ld_st_full,
	input rs_alu_full,
    input rob_full,
    input lb_full,
    input is_ld_st_inst,
    input is_valid_inst,
    input commit_wr_mem,
    input lb_read_mem,
    input is_branch,
    input alu_branch,
    input ex_take_branch,
    input alu_wr_valid,
    input alu_wr_written,
    input lb_wr_valid,
    input lb_wr_written,
    input acu_wr_valid,
    input acu_wr_written,
    input acu_wr_mem,
    input acu_rd_mem,

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

    logic is_stall;
    logic branch_in_exec;
    logic if_mem_hazard;

    assign is_stall = rob_full
        | (is_ld_st_inst & rs_ld_st_full)
        | (~is_ld_st_inst & rs_alu_full)
        | branch_in_exec;

    assign if_mem_hazard = commit_wr_mem | lb_read_mem;

    assign rs_ld_st_enable = ~is_stall & is_valid_inst & is_ld_st_inst;
    assign rs_alu_enable = ~is_stall & is_valid_inst & ~is_ld_st_inst;
    assign rob_enable = ~is_stall & is_valid_inst;

    assign if_enable = ~( if_mem_hazard | is_stall);
    assign if_is_enable = ~is_stall;
    assign if_is_flush = ex_take_branch | (if_mem_hazard & ~is_stall);

    assign alu_wr_enable = ~alu_wr_valid | alu_wr_written;
    assign lb_wr_enable = ~lb_wr_valid | lb_wr_written;
    assign acu_wr_enable = ~acu_wr_valid | acu_wr_written;

    assign rs_ld_exec_stall = (acu_wr_mem & ~acu_wr_enable) 
        | (acu_rd_mem  & ~lb_full);

    assign rs_alu_exec_stall = ~alu_wr_enable;
    assign lb_exec_stall = (commit_wr_mem | ~lb_wr_enable);

    always_ff @(posedge clock) begin
        if (reset) begin
            branch_in_exec <= `FALSE;
        end else begin
            // branch in exec if it is just about to leave IS
            if (is_branch && rs_alu_enable) begin
                branch_in_exec <= `TRUE;
            end
            // check exec_stall to make sure it is only set to false
            // once for the same branch
            else if (alu_branch && !rs_alu_exec_stall) begin
                branch_in_exec <= `FALSE;
            end
        end
    end
    
endmodule
