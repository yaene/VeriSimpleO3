/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  mem_stage.v                                         //
//                                                                     //
//  Description :  memory access (MEM) stage of the pipeline;          //
//                 this stage accesses memory for stores and loads,    // 
//                 and selects the proper next PC value for branches   // 
//                 based on the branch condition computed in the       //
//                 previous stage.                                     // 
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __MEM_STAGE_V__
`define __MEM_STAGE_V__

`timescale 1ns/100ps

module mem_stage(
	input         clock,              // system clock
	input         reset,              // system reset

	input  [`XLEN-1:0] Dmem2proc_data,	// input from system


	input LB_PACKET lb_packet_out,			// from load buffer
	input logic  read_mem,					// form load buffer

	input COMMIT_PACKET  cmt_packet_out,	// from commit stage
	
	
	output mem_busy,					//to load buffer
	
	output logic [`XLEN-1:0] mem_result_out,      // outgoing instruction result (to MEM/WB)
	output logic [1:0] proc2Dmem_command,
	output MEM_SIZE proc2Dmem_size,
	output logic [`XLEN-1:0] proc2Dmem_addr,      // Address sent to data-memory
	output logic [`XLEN-1:0] proc2Dmem_data      // Data sent to data-memory
);



	// Determine the command that must be sent to mem
	assign proc2Dmem_command =
	                        (cmt_packet_out.wr_mem & cmt_packet_out.valid) ? BUS_STORE :
							(read_mem) ? BUS_LOAD :
	                        BUS_NONE;

	// FIXME:
	assign proc2Dmem_size = MEM_SIZE'(cmt_packet_out.mem_size[1:0]);	//only the 2 LSB to determine the size;
	assign mem_busy = (proc2Dmem_command!=BUS_NONE);


	// The memory address is calculated by the ALU
	assign proc2Dmem_data = cmt_packet_out.data_out;

	assign proc2Dmem_addr = cmt_packet_out.mem_address;	
	// Assign the result-out for next stage
	always_comb begin
		mem_result_out = cmt_packet_out.data_out;
		if (read_mem) begin //read memory, load
			if (~cmt_packet_out.mem_size[2]) begin //is this an signed/unsigned load?
				if (cmt_packet_out.mem_size[1:0] == 2'b0)
					mem_result_out = {{(`XLEN-8){Dmem2proc_data[7]}}, Dmem2proc_data[7:0]};
				else if  (cmt_packet_out.mem_size[1:0] == 2'b01) 
					mem_result_out = {{(`XLEN-16){Dmem2proc_data[15]}}, Dmem2proc_data[15:0]};
				else mem_result_out = Dmem2proc_data;
			end else begin
				if (cmt_packet_out.mem_size[1:0] == 2'b0)
					mem_result_out = {{(`XLEN-8){1'b0}}, Dmem2proc_data[7:0]};
				else if  (cmt_packet_out.mem_size[1:0] == 2'b01)
					mem_result_out = {{(`XLEN-16){1'b0}}, Dmem2proc_data[15:0]};
				else mem_result_out = Dmem2proc_data;
			end
		end
	end
	//if we are in 32 bit mode, then we should never load a double word sized data
	assert property (@(negedge clock) (`XLEN == 32) && read_mem |-> proc2Dmem_size != DOUBLE);

endmodule // module mem_stage
`endif // __MEM_STAGE_V__
