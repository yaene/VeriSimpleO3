# VeriSimpleO3
Simple out of order processor based on P6 micro architecture with advanced feature -- instruction prefetching, advanced branch prediction, speculative execution, misprediction recovery.

# Usage
To test our Out-of-Order pipeline:
1. Generate the program memory with RISC-V ISA.
2. Name your file `<filename>.mem`.
3. In [testbench/testbench.sv](testbench/testbench.sv) line 205, change `benchmark` variable to `"<filename>.mem"`.
4. You will get several results after simulating [testbench/testbench.sv](testbench/testbench.sv) in vivado:
   - `pipeline.out`: describe the pipeline process along with the clock cycle.
   - `writeback.out`: record the committed instructions.
   - `bench.csv`: record the total number of instructions and performance metrics(CPI, branch prediction accuracy).
5. In our repo, we provide some memory files that can be tested directly. They are in `test_progs/` folder.
