# Specification

## commit stage
### Interface
```
module commit_stage(
    // Input
    input         clock,                // system clock
    input         reset,                // system reset

    // From ROB
    input ROB_ENTRY head_entry,
    input head_ready,

    // Output  
    // To Memory and regfiles
    output COMMIT_PACKET  cmt_packet_out,

);
```

```
typedef struct packed {
	logic valid;
	logic wr_mem;
	logic [`XLEN-1:0] mem_address;
	logic [`XLEN-1:0] data_out;      // writeback data
	logic [2:0] mem_size;

	logic [4:0] reg_wr_idx_out;        // register writeback index
	logic       reg_wr_en_out;          // register writeback enable
}COMMIT_PACKET;

```

### Usage
#### ROB Stage
- Using the output (ROB_ENTRY head_entry, head_ready) from ROB and commit the instruction

#### Memory Stage
- If cmt_packet_out.wr_mem == 1, use cmt_packet_out for the memory process

#### Register File
- If cmt_packet_out.reg_wr_en_out, write to register file
