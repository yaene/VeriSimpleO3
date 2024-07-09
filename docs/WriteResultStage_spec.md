# Module: Write Result Stage

## Responsibilities

- write results from execution stage to CDB
- act as an arbitrator between different FUs wanting to write their result at the same time

## Interface

```verilog

module wr_stage #(parameter FU_NUM=3) (
    // - FU_NUM: number of functional units WR has to arbitrate
    input clock,
    input reset,
    input CDB_DATA [FU_NUM-1:0] ex_packet_in, // result to put on CDB
    output CDB_DATA cdb,
    output [FU_NUM-1:0] written // one bit for each FU unit letting it know if its been chosen for WR or has to wait
);

```

## Usage

The write result stage can be connected to several functional units. There should be a pipeline register (at least conceptually) between each unit and the WR stage. The functional unit puts the data it wants to write (setting valid to 1, to announce its intent to write) into that register and the WR stage will choose one of the FUs to put its data on the CDB. Whether each FU has been chosen for writing can be read at the "written" output and should be used to stall any FUs that were not chosen.

Priority is given statically in increasing order (i.e. ex_packet_in[0] has highest priority). Thus priorities between different FUs can be implemented by connecting them to the WR stage accordingly.
