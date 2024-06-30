# Specification

## Module: issue_stage
### Inputs

### Outputs

### Logic
Each clock cycle, get one instruction from IF stage if no stalls. Decode it and send the decoded instruction to maptable, reorder buffer, and reservation station. All operations except fetching from IF reg should by asynchronous since we have a issue stage register to synchronize all of them and we want to do all operations in one cycle.
- how to detect stall? signal from RS and ROB: rs_full, rob_full. This signal should be clock triggered to avoid latch.
- Signals sent to maptable: inst.
- Signals received from maptable: maptable_packet_rs1/2(not sure, should be the one corresponding to store)
- Signals sent to rob: 
  - `alloc_enable`: if no stall, then set to true to allocate a new entry.
  - `alloc_wr_mem`: whether inst is a store.
  - `alloc_value_in`/`alloc_value_in_valid`/`alloc_store_dep`: should get information from maptable. Get `alloc_value_in` from regfile. If tag is zero, then  and set `alloc_value_in_valid` to 1. Else, set `alloc_store_dep` to tag value and `alloc_value_in_valid` to 0.
  - `dest_reg`: from inst directly.
- Signals received from rob:
  - `full`
- Signals sent to rs:
  - ID_EX_PACKET
  - `enable`
- Signals received from rs:
  - `rs_full`
Other signals that are required for rs, rob, and maptable should be connected outside the issue module, i.e., they should be directly connected.

### Changelog