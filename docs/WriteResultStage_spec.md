# Module: Write Result Stage

## Responsibilities

- write results from execution stage to CDB
- act as an arbitrator between different FUs wanting to write their result at the same time

## Interface

```verilog

module #(parameter FU_NUM=3) wr_stage(
    // - FU_NUM: number of functional units WR has to arbitrate
    input clock,
    input reset,
    input CDB_DATA [FU_NUM-1:0] ex_packet_in, // result to put on CDB
    output CDB_DATA cdb,
    output [FU_NUM-1:0] written // one bit for each FU unit letting it know if its been chosen for WR or has to wait
);

```
