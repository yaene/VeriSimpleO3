# Specification

## Module: maptable
### Inputs
- clock
- reset
- inst:
  - inst.rs1 [4:0]
  - inst.rs2 [4:0]
  - inst.rd [4:0]
- commit
- old_phys_rd [4:0]
- recover (TBD)
### Outputs
- MAPPED_REG_PACKET:
  - phys_rs1 [4:0]
  - phys_rs2 [4:0]
  - old_phys_rd [4:0]
  - new_phys_rd [4:0]

### Logic
Hold the maptable and free list. 
```
# at decode:
mapped_reg_packet.phys_rs1 = maptable[inst.rs1]
mapped_reg_packet.phys_rs2 = maptable[inst.rs2]
mapped_reg_packet.old_phys_rd = maptable[inst.rd]
new_reg = new_phys_reg() # get one register from free list queue
maptable[inst.rd] = new_reg
mapped_reg_packet.new_phys_rd = new_reg

# at commit:
free_phys_reg(old_phys_rd) # add this reg to free list queue

# at recovery: free all the old_phys_rd of instructions that are to be flushed.
```
- Upon receiving instructions without commit signal, allocate a physical register for output register by changing maptable and deque one register from free list.
- Upon receiving instructions with commit signal, free the old physical register for output.
- Upon recovery, free all the old_phys_rd of instructions that are to be flushed.

### Changelog
- 6/21:
  - build a basic maptable