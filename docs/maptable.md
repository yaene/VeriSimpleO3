# Specification

## Module: maptable
### Inputs
ex.  
- clock
- reset
- inst:
  - inst.rs1 [4:0]
  - inst.rs2 [4:0]
  - inst.rd [4:0]
- commit
- recover (TBD)
### Outputs
- inst:
  - inst.phys_rs1 [4:0]
  - inst.phys_rs2 [4:0]
  - inst.old_phys_rd [4:0]
  - inst.new_phys_rd [4:0]

### Logic
Hold the maptable and free list. 
```
# at decode:
inst.phys_rs1 = maptable[inst.rs1]
inst.phys_rs2 = maptable[inst.rs2]
inst.old_phys_rd = maptable[inst.rd]
new_reg = new_phys_reg() # get one register from free list queue
maptable[inst.rd] = new_reg
inst.phys_rd = new_reg

# at commit:
free_phys_reg(inst. old_phys_rd) # add this reg to free list queue

# at recovery: free all the old_phys_rd of instructions that are to be flushed.
```
- Upon receiving instructions without commit signal, allocate a physical register for output register by changing maptable and deque one register from free list.
- Upon receiving instructions with commit signal, free the old physical register for output.
- Upon recovery, free all the old_phys_rd of instructions that are to be flushed.

### Changelog
- 6/21:
  - build a basic maptable