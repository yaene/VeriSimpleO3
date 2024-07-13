# Hazard Handling

## Structural Hazards

### Memory

IF, store commit and load execution all need to access memory.  
Priority: Store > Load exec > IF. memory access with highest prio should proceed while others stall.

### ROB and Reservation Stations

ROB or RS might be full -> stall issue stage

### Load Buffer

Load buffer might be full -> stall load exec

## Control Hazards

Stall issue stage after branch/jump. Wait until branch/jump commits, then flush IF/IS if branch taken and update PC.

## Data Hazards

LD/ST RAW: make sure addresses of all preceding stores are computed before a load enters Load buffer. Otherwise RAW hazard can not be properly detected when load is waiting in load buffer.  
This can be done easily by restricting LD/ST RS to hold only one instruction, forcing address computation of LD/ST to happen in order.
