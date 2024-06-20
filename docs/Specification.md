# Specification

## Module: (ex Reorder Buffer)

### Inputs

ex.

- clock
- reset
- cdb
- ...

### Outputs

ex.

- rob_full: simple explanation  
   `simple usage`
- insn_commit: ...  
   `...`
- ...

## Reorder Buffer (ROB)

### Interface

```verilog
module rob(
input clock,
input reset,
input alloc_enable,                       // should a new slot be allocated
input alloc_wr_mem,                       // is instn to be allocated a store?
input [`XLEN-1:0] alloc_value_in,         // value to store if available during issue (store instructions)
input [`ROB_TAG_LEN-1:0] alloc_store_dep, // else ROB providing value of store
input alloc_value_in_valid,               // whether store value is available at issue
input [4:0] dest_reg,                     // dest register of new instruction
input CDB_DATA cdb_data,                  // data on CDB
input [`ROB_TAG_LEN-1:0] read_rob_tag,    // rob entry to read value from
input [`XLEN-1:0] load_address,           // to check for any pending stores
input [`ROB_TAG_LEN-1:0] load_rob_tag,    // rob entry of load to check for pending stores

output full,                              // is ROB full?
output [`ROB_TAG_LEN-1:0] alloc_slot,     // rob tag of new instruction
output [`XLEN-1:0] read_value,            // ROB[read_rob_tag].value
output pending_stores,                    // whether there are any pending stores before load
output ROB_ENTRY head_entry,              // the entry of the next instn to commit
output head_ready);                       // whether instruction at head is ready to commit
```

### Usage

#### Issue Stage

- loading a value from ROB:
  1. set read_rob_tag to rob entry you want to read
  2. observe value at _read_value_ output (asynchronously)
- allocating a slot for a new instruction:
  1. observe whether the buffer is _full_
  2. set _alloc_enable_ to 1
  3. set _alloc_value_in_, _alloc_value_in_valid_, _alloc_store_dep_, _dest_reg_ as necessary
  4. the values will be written in rob slot _alloc_slot_ at next clock cycle

#### Write Result Stage

- writing result to ROB:
  1. set valid bit, the tag and result of the instruction in write result to the CDB
  2. the interested ROB entries (including dependent stores) will read the value on next cycle

#### Commit Stage

- getting next instruction to commit in order:
  1. observe whether instruction is ready to commit at _head_ready_
  2. if yes, use rob entry exposed at _head_entry_ to write value back to register or memory

### Implementation Details

- ROB automatically frees slot of commited instruction one cycle after it becomes ready (ROB expects commit stage to consume instruction in one cycle)
- all usages above can be done at the same time
- the next free slot can be the one occupied by current head, given the head commits in the current cycle
- if a store depending on instruction N is issued to ROB in same cycle as N writes its result, ROB will automatically forward result from N to ROB entry of issued store

### Changelog

- 6/20:
  - added reorder buffer interface and usage description
