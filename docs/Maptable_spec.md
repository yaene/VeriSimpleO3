# Specification

## Module: Maptable
### Inputs
- logic clock,
- logic reset,
- logic commit,
- logic [4:0] rd_commit,
- logic [`ROB_TAG_LEN-1:0] rob_entry_commit,
- INST inst, //inst from decoding stage
- logic [`ROB_TAG_LEN-1:0] rob_entry_in, // rob entry from ROB
- logic [4:0] rd, // dest_reg from decoding stage
- logic [4:0] rd_wb, // dest_reg from wb
- logic [`ROB_TAG_LEN-1:0] rob_entry_wb, // rob entry from wb
### Outputs
- MAPTABLE_PACKET maptable_packet_rs1,
- MAPTABLE_PACKET maptable_packet_rs2

### Logic
Hold the maptable. 

- Upon receiving instructions from decoding stage, first send out the `MAPTABLE_PACKET` for `rs1` and `rs2`, then update the rd entry of the maptable using the `rob_entry_in`.
- Update the `rd_wb` entry of the ready bit table using data from wb (when then `rob_tag_val` does not meet, don't update).
- Upon receiving commit signal from ROB, clear the corresponding line(same logic as wb).
- Upon recovery, clear the maptable.

### Changelog
- 6/21:
  - build a basic maptable
- 6/22:
  - modify maptable to fit P6 structure.
- 6/24:
  - add function to respond to commit signal.