/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  testbench.v                                         //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

import "DPI-C" function void print_header(string str);
import "DPI-C" function void print_cycles();
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
import "DPI-C" function void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                                       int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
import "DPI-C" function void print_membus(int proc2mem_command, int mem2proc_response,
                                          int proc2mem_addr_hi, int proc2mem_addr_lo,
						 			     int proc2mem_data_hi, int proc2mem_data_lo);
import "DPI-C" function void print_close();


module testbench;

	// variables used in the testbench
	logic        clock;
	logic        reset;
	logic [31:0] clock_count;
	logic [31:0] instr_count;
	int          wb_fileno;
	
	logic [1:0]  proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0] proc2mem_data;
	logic  [3:0] mem2proc_response;
	logic [63:0] mem2proc_data;
	logic  [3:0] mem2proc_tag;
`ifndef CACHE_MODE
	MEM_SIZE     proc2mem_size;
`endif
	logic  [3:0] pipeline_completed_insts;
	EXCEPTION_CODE   pipeline_error_status;
	logic  [4:0] pipeline_commit_wr_idx;
	logic [`XLEN-1:0] pipeline_commit_wr_data;
	logic        pipeline_commit_wr_en;
	logic [`XLEN-1:0] pipeline_commit_NPC;
	
	
	logic [`XLEN-1:0] if_NPC_out;
	logic [31:0] if_IR_out;
	logic        if_valid_inst_out;
	logic [`XLEN-1:0] if_is_NPC;
	logic [31:0] if_is_IR;
	logic        if_is_valid_inst;
	logic [`XLEN-1:0] rs_alu_NPC;
	logic [31:0] rs_alu_IR;
	logic        rs_alu_valid_inst;
	logic [`XLEN-1:0] rs_acu_NPC;
	logic [31:0] rs_acu_IR;
	logic        rs_acu_valid_inst;
	logic [`XLEN-1:0] lb_NPC;
	logic [31:0] lb_IR;
	logic        lb_valid_inst;
	logic [`XLEN-1:0] ex_wr_NPC;
	logic [31:0] ex_wr_IR;
	logic        ex_wr_valid_inst;
	logic [`XLEN-1:0] commit_NPC;
	logic [31:0] commit_IR;
	logic        commit_valid_inst;

    //counter used for when pipeline infinite loops, forces termination
    logic [63:0] debug_counter;
	// Instantiate the Pipeline
	pipeline core(
		// Inputs
		.clock             (clock),
		.reset             (reset),
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag),
		
		
		// Outputs
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
		.proc2mem_size     (proc2mem_size),
		
		.pipeline_completed_insts(pipeline_completed_insts),
		.pipeline_error_status(pipeline_error_status),
		.pipeline_commit_wr_data(pipeline_commit_wr_data),
		.pipeline_commit_wr_idx(pipeline_commit_wr_idx),
		.pipeline_commit_wr_en(pipeline_commit_wr_en),
		.pipeline_commit_NPC(pipeline_commit_NPC),

		.if_NPC_out(if_NPC_out),
		.if_IR_out(if_IR_out),
		.if_valid_inst_out(if_valid_inst_out),
		.if_is_NPC_out(if_is_NPC),
		.if_is_IR_out(if_is_IR),
		.if_is_valid_inst_out(if_is_valid_inst),
		.rs_alu_NPC_out(rs_alu_NPC),
		.rs_alu_IR_out(rs_alu_IR),
		.rs_alu_valid_inst_out(rs_alu_valid_inst),
		.rs_acu_NPC_out(rs_acu_NPC),
		.rs_acu_IR_out(rs_acu_IR),
		.rs_acu_valid_inst_out(rs_acu_valid_inst),
		.lb_NPC_out(lb_NPC),
		.lb_IR_out(lb_IR),
		.lb_valid_inst_out(lb_valid_inst),
		.ex_wr_NPC_out(ex_wr_NPC),
		.ex_wr_IR_out(ex_wr_IR),
		.ex_wr_valid_inst_out(ex_wr_valid_inst),
		.commit_NPC_out(commit_NPC),
		.commit_IR_out(commit_IR),
		.commit_valid_inst_out(commit_valid_inst)
	);
	
	
	// Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk               (clock),
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size     (proc2mem_size),
`endif

		// Outputs

		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);
	
	// Generate System Clock
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
	
	// Task to display # of elapsed clock edges
	task show_clk_count;
		real cpi;
		
		begin
			cpi = (clock_count + 1.0) / instr_count;
			$display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
			          clock_count+1, instr_count, cpi);
			$display("@@  %4.2f ns total time to execute\n@@\n",
			          clock_count*`VERILOG_CLOCK_PERIOD);
		end
	endtask  // task show_clk_count 
	
	// Show contents of a range of Unified Memory, in both hex and decimal
	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;
		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1)
				if (memory.unified_memory[k] != 0) begin
					$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k], 
				                                            memory.unified_memory[k]);
					showing_data=1;
				end else if(showing_data!=0) begin
					$display("@@@");
					showing_data=0;
				end
			$display("@@@");
		end
	endtask  // task show_mem_with_decimal
	
	initial begin
		$dumpvars;
	
		clock = 1'b0;
		reset = 1'b0;
		
		// Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);
		
		$readmemh("program.mem", memory.unified_memory);
		
		@(posedge clock);
		@(posedge clock);
		`SD;
		// This reset is at an odd time to avoid the pos & neg clock edges
		
		reset = 1'b0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);
		
		wb_fileno = $fopen("writeback.out");
		
		//Open header AFTER throwing the reset otherwise the reset state is displayed
		print_header("                                                                                                           D-MEM Bus &\n");
		print_header("Cycle:      IF      |     IS      |     ALU     |     ACU     |     LD      |     WR      |     CMT        Reg Result");
	end


	// Count the number of posedges and number of instructions completed
	// till simulation ends
	always @(posedge clock) begin
		if(reset) begin
			clock_count <= `SD 0;
			instr_count <= `SD 0;
		end else begin
			clock_count <= `SD (clock_count + 1);
			instr_count <= `SD (instr_count + pipeline_completed_insts);
		end
	end  
	
	
	always @(negedge clock) begin
        if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			         $realtime);
            debug_counter <= 0;
        end else begin
			`SD;
			`SD;
			
			 // print the piepline stuff via c code to the pipeline.out
			 print_cycles();
			 print_stage(" ", if_IR_out, if_NPC_out[31:0], {31'b0,if_valid_inst_out});
			 print_stage("|", if_is_IR, if_is_NPC[31:0], {31'b0,if_is_valid_inst});
			 print_stage("|", rs_alu_IR, rs_alu_NPC[31:0], {31'b0,rs_alu_valid_inst});
			 print_stage("|", rs_acu_IR, rs_acu_NPC[31:0], {31'b0,rs_acu_valid_inst});
			 print_stage("|", lb_IR, lb_NPC[31:0], {31'b0,lb_valid_inst});
			 print_stage("|", ex_wr_IR, ex_wr_NPC[31:0], {31'b0,ex_wr_valid_inst});
			 print_stage("|", commit_IR, commit_NPC[31:0], {31'b0,commit_valid_inst});
			 print_reg(32'b0, pipeline_commit_wr_data[31:0],
				{27'b0,pipeline_commit_wr_idx}, {31'b0,pipeline_commit_wr_en});
			 print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
				32'b0, proc2mem_addr[31:0],
				proc2mem_data[63:32], proc2mem_data[31:0]);
			
			
			 // print the writeback information to writeback.out
			if(pipeline_completed_insts>0) begin
				if(pipeline_commit_wr_en)
					$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
						pipeline_commit_NPC-4,
						pipeline_commit_wr_idx,
						pipeline_commit_wr_data);
				else
					$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC-4);
			end
			
			// deal with any halting conditions
			if(pipeline_error_status != NO_ERROR || debug_counter > 50000000) begin
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
				show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
				// 8Bytes per line, 16kB total
				
				$display("@@  %t : System halted\n@@", $realtime);
				
				case(pipeline_error_status)
					LOAD_ACCESS_FAULT:  
						$display("@@@ System halted on memory error");
					HALTED_ON_WFI:          
						$display("@@@ System halted on WFI instruction");
					ILLEGAL_INST:
						$display("@@@ System halted on illegal instruction");
					default: 
						$display("@@@ System halted on unknown error code %x", 
							pipeline_error_status);
				endcase
				$display("@@@\n@@");
				show_clk_count;
				print_close(); // close the pipe_print output file
				$fclose(wb_fileno);
				#100 $finish;
			end
            debug_counter <= debug_counter + 1;
		end  // if(reset)   
	end 

endmodule  // module testbench
