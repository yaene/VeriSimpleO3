# Specification

## Top Module 1: (alu_execution_unit)
### Interface
```
module alu_execution_unit(
	input INSTR_READY_ENTRY ready_inst_entry, // output ready instruction entry from RS

	output CDB_DATA alu_cdb_output, // CDB data output from ALU execution unit
    output take_branch, // indicates whether the branch will be taken
    output [`XLEN-1:0] branch_target_PC // targeted branch PC when taking branch
);
```


### Usage
#### Write Result Stage
- Using the output CDB_DATA from alu_execution unit for next step arbitration if the instruction is not a branch instruction, with CDB data valid bit = 1, and with corresponding value and rob_tag.

#### Issue Stage
- Using the take_branch signal and target branch_target_PC from alu_execution unit if take_branch=1


## Top Module 2 (address_calculation_unit)
### Interface
```
module address_calculation_unit(
    input INSTR_READY_ENTRY ready_inst_entry, // output ready instruction entry from RS

    output CDB_DATA store_result, // output address result for writing, for store instruction
    output LB_PACKET load_buffer_packet // output packet for load buffer usage
);
```
### Usage
#### Load Buffer
- Using the load_buffer_packet directly if the instruction is load, with rd_mem = 1

#### Write Result Stage
- Using the CDB_DATA for next step arbitration if the instruction is store, with wr_mem = 1

### Changelog
- 7/4:
    - build basic logic parts of Functional units: ALU, Store/Load
