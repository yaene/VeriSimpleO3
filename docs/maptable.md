# Specification

## Module: maptable
### Inputs
- logic clock,
- logic reset,
- logic commit,
- INST inst, //inst from decoding stage
- logic [`ROB_TAG_LEN-1:0] rob_tag_entry_in, // rob entry from ROB
- logic [4:0] rd, // dest_reg from decoding stage
- logic [4:0] rd_commit, // dest_reg from CDB
- logic [`ROB_TAG_LEN-1:0] rob_tag_entry_commit, // rob entry from CDB
### Outputs
- MAPTABLE_PACKET maptable_packet_rs1,
- MAPTABLE_PACKET maptable_packet_rs2

### Logic
Hold the maptable. 

- Upon receiving instructions from decoding stage, first send out the `MAPTABLE_PACKET` for `rs1` and `rs2`, then update the rd entry of the maptable using the `rob_tag_entry_in`.
- Upon receiving commit signal, update the rd entry of the ready bit table using data from CDB (when then rob_tag does not meet, don't update).
- Upon recovery, clear the maptable.

### Changelog
- 6/21:
  - build a basic maptable
- 6/22:
  - modify maptable to fit P6 structure.