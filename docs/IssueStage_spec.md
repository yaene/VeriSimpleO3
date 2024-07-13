# Specification

## Module: issue_stage
### Interface
```verilog
module is_stage (         
	input clock,              // system clock
	input reset,              // system reset
	// input from Commit stage
	input wb_reg_wr_en_out,    // COMMIT_PACKET.reg_wr_en_out
	input [4:0] wb_reg_wr_idx_out,  // COMMIT_PACKET.reg_wr_idx_out
	input [`XLEN-1:0] wb_reg_wr_data_out,  // COMMIT_PACKET.data_out
	// input from IF stage
	input IF_ID_PACKET if_id_packet_in,
	// input from Maptable
    input MAPTABLE_PACKET maptable_packet_rs1,
    input MAPTABLE_PACKET maptable_packet_rs2,
	// input from ROB
	input [`XLEN-1:0] rs1_read_rob_value,
	input [`XLEN-1:0] rs2_read_rob_value, 
	
	// output to hazard detection
	output is_ld_st_inst,
	// output to RS + ROB + Maptable
	output ID_EX_PACKET id_packet_out, // rob.dest_reg, rs, maptable.inst
    // output to rob
    output alloc_wr_mem,                       // is new instruction a store?
    output [`XLEN-1:0] alloc_value_in,         // value to store if available during store issue
    output [`ROB_TAG_LEN-1:0] alloc_store_dep, // else ROB providing value of store
    output alloc_value_in_valid,               // whether store value is available at issue
	output [2:0] alloc_mem_size,
    output [`ROB_TAG_LEN-1:0] rs1_rob_tag,
	output [`ROB_TAG_LEN-1:0] rs2_rob_tag
);
```

### Logic
Each clock cycle, get one instruction from IF stage if no stalls. Decode it and send the decoded instruction to maptable, reorder buffer, and reservation station. All operations except fetching from IF reg should by asynchronous since we have a issue stage register to synchronize all of them and we want to do all operations in one cycle.
- how to detect stall? signal from RS and ROB: rs_full, rob_full. This signal should be clock triggered and saved in register to avoid latch.
- Signal sent to IF stage: 
  - `stall_if`: Stall IF stage if ROB is full, or if an instruction now in ISSUE cannot fetch into either RSs
- Signals sent to maptable: `if_id_packet_in.inst`.
- Signals received from maptable: maptable_packet_rs1/2
- Signals sent to rob: 
  - `alloc_enable`: if the instruction in Issue stage can fetch in to either two RS.
  - `alloc_wr_mem`: whether inst is a store.
  - `alloc_value_in`/`alloc_value_in_valid`/`alloc_store_dep`: should get information from maptable. Get `alloc_value_in` from regfile. If tag is zero, then  and set `alloc_value_in_valid` to 1. Else, set `alloc_store_dep` to tag value and `alloc_value_in_valid` to 0.
  - `dest_reg`: from inst directly.
- Signals received from rob:
  - `rob_full`
- Signals sent to rs:
  - ID_EX_PACKET
  - `rs_ld_st_enable`, `rs_alu_enable`: when ROB is not full and according to the INST type
- Signals received from rs:
  - `rs_ld_st_full`
  - `rs_alu_full`
Other signals that are required for rs, rob, and maptable should be connected outside the issue module, i.e., they should be directly connected.

### Changelog