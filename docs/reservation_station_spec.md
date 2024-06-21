# Specification

## Module: (Reservation Station)
### Inputs
ex.  
- clock
- reset
- cdb
- ID_EX_PACKET id_packet_out //obtain opt
- MAPPED_REG_PACKET mapped_reg_packet //obtain renamed rs1, rs2, rd
### Outputs
ex.
- rs_full: simple explanation  
- ready_inst: output the ready instruction

### Inside
- reg_ready_table: store the ready info of each physical register
- instr_ready_table: store the ready info of instructions.
- ...