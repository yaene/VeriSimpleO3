# Specification

## Memory stage
### Interface
```verilog
module mem_stage(
	input         clock,              // system clock
	input         reset,              // system reset

	input  [`XLEN-1:0] Dmem2proc_data,	// input from system


	input LB_PACKET lb_packet_in,			// from load buffer
	input logic  read_mem,					// form load buffer

	input COMMIT_PACKET  cmt_packet_in,	// from commit stage
	
	
	output mem_busy,					//to load buffer
	
	output EX_WR_PACKET lb_ex_packet_out,
	output logic [1:0] proc2Dmem_command,
	output MEM_SIZE proc2Dmem_size,
	output logic [`XLEN-1:0] proc2Dmem_addr,      // Address sent to data-memory
	output logic [`XLEN-1:0] proc2Dmem_data      // Data sent to data-memory
);
```
```verilog
typedef struct packed {
	logic valid;
	logic [`XLEN-1:0] NPC;
	INST inst;
    logic [`ROB_TAG_LEN-1:0] rob_tag; // identifies instruction that produced value
    logic [`XLEN-1:0] value;
} EX_WR_PACKET;
```

### Usage
#### Load Buffer
- Get ```LB_PACKET lb_packet_out``` and ```read_mem``` form load buffer

#### Commit
- Get ```COMMIT_PACKET  cmt_packet_out``` 


#### Write result
- If read_mem==1, go to write result stage, output data from ```EX_WR_PACKET lb_ex_packet_out``` 