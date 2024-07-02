# Specification

## Module: Load Buffer (simple)

### Interface
```verilog
module load_buffer (
    input clock,
    input reset,
    input LB_PACKET lb_packet_in,
    input alloc_enable,
    input pending_stores, // from ROB, whether there are pending stores
    input mem_busy, // from MEM, whether MEM is available

    output LB_PACKET lb_packet_out,
    output logic full, // to ACU, whether Load Buffer is available
    output [`XLEN-1:0] load_address, // to ROB
    output [`ROB_TAG_LEN-1:0] load_rob_tag, // to ROB
    output logic read_mem // going to read mem
)
```

### Usage
#### Address Calculation Unit
- set **alloc_enable = 1** when ALU try to allocate instruction to the load buffer
- the instruction should be valid **lb_packet_in.valid = 1**
- if **full = FALSE**, load **LB_PACKET** to load buffer
    - LB_PACKET:
        ```
        typedef struct packed {
            logic valid;
            logic [`XLEN-1:0] address;
            logic [`ROB_TAG_LEN-1:0] rd_tag;
            logic [2:0] mem_size; // id_ex_packet_in.inst.r.funct3
        } LB_PACKET;
        ```
#### Reorder Buffer
1. Receive **load_address** and **load_rob_tag** from load buffer
2. Set **pending_stores = 1**, if there are earlier store instructions sharing same address with the load instruction
#### Mem Stage
1. Set **mem_busy = 1**, if mem stage is busy with other tasks
2. access to memory and load value if **read_mem = 1** & mem_busy != 0.

