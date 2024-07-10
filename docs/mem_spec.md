# Specification

## Memory stage
### Interface
```
module mem_stage(
	input         clock,              // system clock
	input         reset,              // system reset

    // input from system
	input  [`XLEN-1:0] Dmem2proc_data,	

    // from load 
	input LB_PACKET lb_packet_out,			buffer
	input logic  read_mem,			

    // from commit stage
	input COMMIT_PACKET  cmt_packet_out,	
	
	
	output mem_busy,					//to load buffer
	
	output logic [`XLEN-1:0] mem_result_out,      // outgoing instruction result (to MEM/WB)
	output logic [1:0] proc2Dmem_command,
	output MEM_SIZE proc2Dmem_size,
	output logic [`XLEN-1:0] proc2Dmem_addr,      // Address sent to data-memory
	output logic [`XLEN-1:0] proc2Dmem_data      // Data sent to data-memory
);
```


### Usage
#### Load Buffer
- Get ```LB_PACKET lb_packet_out``` and ```read_mem``` form load buffer

#### Commit
- Get ```COMMIT_PACKET  cmt_packet_out``` 


#### Write result
- If read_mem==1, go to write result stage, output data from ```COMMIT_PACKET  cmt_packet_out``` 