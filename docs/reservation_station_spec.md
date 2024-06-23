# Specification

## Module: (ReservationStation)
### Inputs

- clock
- reset
- cdb: Common data bus packet
- ID_EX_PACKET id_packet_out 
- MAPPED_REG_PACKET maptable_packet_rs1: rs1 rob_tag_value
- MAPPED_REG_PACKET maptable_packet_rs2: rs2 rob_tag_value
- MAPPED_REG_PACKET maptable_packet_rd: rd rob_tag_value

### Outputs

- rs_full: signal indicating whether the reservation station is full  
- INSTR_READY_ENTRY ready_inst_entry: output ready instruction entry

### Logic
Hold a instruction and wait for all operands ready. Then deliver ready instr to functional units.
- `Reset`: If reset signal is received, clear all RS slots and set all slots invalid, and set `rs_full` as 0;
- `Dispatch`: allocate a free slot (valid = 0) to a new instruction. If no free slot is avaiable, set `rs_full` as 1, else 0;
- `Fill information in RS for the new slot`: once a free slot is successfully allocated, set `valid`, `instr`,`rd_tag`,`rs1_tag`, `rs2_tag`, `rs1_value`,`rs2_value`,`rs1_ready`,`rs2_ready`,`ready`,`birthday`.
  - `valid`: if allocated, valid = 1. Reset to 0 when the slot is released or RS is rest.
  - ID_EX_PACKET `instr`: ID_EX_PACKET, for execution usage
  - [`ROB_TAG_LEN-1:0] `rd_tag`: alloc_slot from ROB
  - `rs1_tag`: renamed rs1 ROB tag. If zero, then no tag is renamed for the reg. 
  - `rs2_tag`: renamed rs2 ROB tag.  If zero, then no tag is renamed for the reg. 
  - `rs1_value`: rs1 value, obtained from ID_EX_PACKET.rs1_value
  - `rs2_value`: rs2 value, obtained from ID_EX_PACKET.rs2_value
  - `rs1_ready`: If `rs1_tag` is zero, then the value can be directly obtained from regfile, and it is set to be 1. Else, it equals to `maptable_packet_rs1.rob_tag_ready`
  - `rs2_ready`: If `rs2_tag` is zero, then the value can be directly obtained from regfile, and it is set to be 1. Else, it equals to `maptable_packet_rs2.rob_tag_ready`
  - `ready`: 
    - For ST instruction, set to 1 when rs2_ready == 1
    - For LD instruction, set to 1 when rs1_ready == 1
    - For other instructions, set to 1 when (rs1_ready == 1 && rs2_ready == 1)
  - `birthday`: the oldest instruction allocated to RS has birthday = 0, and increase by 1 for each later new allocated instruction
- `Wait for CDB`
  - fill rs1/rs2 value when cdb.rob_tag maps with the rs1/rs2 tag
- `Output ready RS slot with the oldest birthday`
  - check the ready bit of each slot, and output the ready RS slot with the oldest birthday


### Changelog
- 6/21:
    - build basic parts of reservation station
- 6/23:
    - add rs1&rs2 value to RS
    - apply new output mapping packet from maptable outputs
    - enable ST/LD & others seperation with different instantiation