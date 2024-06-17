# Milestone 1: Initial High-level Architecture
For milestone 1, we are going to implement **core components (Reorder Buffer, Reservation Stations, Map Table)** of a Scalar Intel P6 Style (using Tomasulo Algorithm + ROB) Out-of-Order pipeline without advanced features such as speculations.

Below diagram is our basic architecture for milestone 1. 

![Alt text](./highlevel_arch.drawio.svg)

* Note: *Round blocks* refer to logic modules, and *rectangular blocks* refer to modules that hold values. + Blue colored line is *Common Data Bus*.

1. **IF stage**: fetches the instruction to Issue State through IF/ISSUE Register. We can reuse the codes given from the lab3 material.
2. **Issue stage**: 
    - perform register renaming 
    - issue instructions into Reservation Station and Reorder Buffer.
        - Separately issue Load/Store instructions and other instructions to different reservation stations.
    - stall when Reservation Station or Reorder Buffer are full
    - stall when a branch instruction is executed (for milestone 1)
    - *can be divided into several stages if needed*
3. **Reorder Buffer**: 
    - hold instruction in order. (obtained from Issue stage)
    - Check for resulting values from each instructions and holds values. (via CDB)
    - Deliver the completed instruction to the commit stage.
    - give information of whether store instructions are finished to Load Buffer.
    - Free instruction after it commits.
    - No recovery for milestone 1.
4. **Map Table**: map physical registers and architectural registers. Free it after the instruction commits (Keep track ROB).
5. **Reservation Stations**: There will be two Reservation Stations, one for load/store instructions and one for other instructions.
    - hold a instruction and wait for operands ready.
    - deliver instruction to functional units (address calculation unit and execution unit) after operands are ready.
6. **Address Calculation Unit**: Functional Unit for address calculation.
7. **Execution Unit**: ALU  
8. **Load Buffer**: stall unitl every previous store instructions are completed (keep track ROB).
9. **Write Result Stage**:  
    - Put data into Common Data Bus
10. **Commit Stage**: write data into memory or register file.
11. **Register File**: Register File
12 **Common Data Bus**: Get data from Write Result stage and connect to Reorder Buffer and Reservation Stations.