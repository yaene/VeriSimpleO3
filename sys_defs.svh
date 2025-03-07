/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.vh                                         //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__
//////////////////////////////////////////////
//
// Memory/testbench attribute definitions
//
//////////////////////////////////////////////

`define NUM_MEM_TAGS           8
`define MEM_LATENCY_IN_CYCLES  0//( $urandom_range(0, 5) )

`define MEM_SIZE_IN_BYTES      (64*1024)
`define MEM_64BIT_LINES        (`MEM_SIZE_IN_BYTES/8)

//you can change the clock period to whatever, 10 is just fine
`define VERILOG_CLOCK_PERIOD   10.0
`define XLEN 32
`define BIRTHDAY_SIZE 3
`define RS_DEPTH 4
`define MAX_BIRTHDAY ((1 << `BIRTHDAY_SIZE) - 1)

typedef union packed {
    logic [7:0][7:0] byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;

//////////////////////////////////////////////
// Exception codes
// This mostly follows the RISC-V Privileged spec
// except a few add-ons for our infrastructure
// The majority of them won't be used, but it's
// good to know what they are
//////////////////////////////////////////////

typedef enum logic [3:0] {
	INST_ADDR_MISALIGN  = 4'h0,
	INST_ACCESS_FAULT   = 4'h1,
	ILLEGAL_INST        = 4'h2,
	BREAKPOINT          = 4'h3,
	LOAD_ADDR_MISALIGN  = 4'h4,
	LOAD_ACCESS_FAULT   = 4'h5,
	STORE_ADDR_MISALIGN = 4'h6,
	STORE_ACCESS_FAULT  = 4'h7,
	ECALL_U_MODE        = 4'h8,
	ECALL_S_MODE        = 4'h9,
	NO_ERROR            = 4'ha, //a reserved code that we modified for our purpose
	ECALL_M_MODE        = 4'hb,
	INST_PAGE_FAULT     = 4'hc,
	LOAD_PAGE_FAULT     = 4'hd,
	HALTED_ON_WFI       = 4'he, //another reserved code that we used
	STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

//////////////////////////////////////////////
//
// Datapath control signals
//
//////////////////////////////////////////////

//
// ALU opA input mux selects
//
typedef enum logic [1:0] {
	OPA_IS_RS1  = 2'h0,
	OPA_IS_NPC  = 2'h1,
	OPA_IS_PC   = 2'h2,
	OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

//
// ALU opB input mux selects
//
typedef enum logic [3:0] {
	OPB_IS_RS2    = 4'h0,
	OPB_IS_I_IMM  = 4'h1,
	OPB_IS_S_IMM  = 4'h2,
	OPB_IS_B_IMM  = 4'h3,
	OPB_IS_U_IMM  = 4'h4,
	OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

//
// Destination register select
//
typedef enum logic [1:0] {
	DEST_RD = 2'h0,
	DEST_NONE  = 2'h1
} DEST_REG_SEL;

//
// ALU function code input
// probably want to leave these alone
//
typedef enum logic [4:0] {
	ALU_ADD     = 5'h00,
	ALU_SUB     = 5'h01,
	ALU_SLT     = 5'h02,
	ALU_SLTU    = 5'h03,
	ALU_AND     = 5'h04,
	ALU_OR      = 5'h05,
	ALU_XOR     = 5'h06,
	ALU_SLL     = 5'h07,
	ALU_SRL     = 5'h08,
	ALU_SRA     = 5'h09,
	ALU_MUL     = 5'h0a,
	ALU_MULH    = 5'h0b,
	ALU_MULHSU  = 5'h0c,
	ALU_MULHU   = 5'h0d,
	ALU_DIV     = 5'h0e,
	ALU_DIVU    = 5'h0f,
	ALU_REM     = 5'h10,
	ALU_REMU    = 5'h11
} ALU_FUNC;

//////////////////////////////////////////////
//
// Assorted things it is not wise to change
//
//////////////////////////////////////////////

//
// actually, you might have to change this if you change VERILOG_CLOCK_PERIOD
// JK you don't ^^^
//
`define SD #1


// the RISCV register file zero register, any read of this register always
// returns a zero value, and any write to this register is thrown away
//
`define ZERO_REG 5'd0

//
// Memory bus commands control signals
//
typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

`ifndef CACHE_MODE
typedef enum logic [1:0] {
	BYTE = 2'h0,
	HALF = 2'h1,
	WORD = 2'h2,
	DOUBLE = 2'h3
} MEM_SIZE;
`endif
//
// useful boolean single-bit definitions
//
`define FALSE  1'h0
`define TRUE  1'h1

// RISCV ISA SPEC
typedef union packed {
	logic [31:0] inst;
	struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r; //register to register instructions
	struct packed {
		logic [11:0] imm;
		logic [4:0]  rs1; //base
		logic [2:0]  funct3;
		logic [4:0]  rd;  //dest
		logic [6:0]  opcode;
	} i; //immediate or load instructions
	struct packed {
		logic [6:0] off; //offset[11:5] for calculating address
		logic [4:0] rs2; //source
		logic [4:0] rs1; //base
		logic [2:0] funct3;
		logic [4:0] set; //offset[4:0] for calculating address
		logic [6:0] opcode;
	} s; //store instructions
	struct packed {
		logic       of; //offset[12]
		logic [5:0] s;   //offset[10:5]
		logic [4:0] rs2;//source 2
		logic [4:0] rs1;//source 1
		logic [2:0] funct3;
		logic [3:0] et; //offset[4:1]
		logic       f;  //offset[11]
		logic [6:0] opcode;
	} b; //branch instructions
	struct packed {
		logic [19:0] imm;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} u; //upper immediate instructions
	struct packed {
		logic       of; //offset[20]
		logic [9:0] et; //offset[10:1]
		logic       s;  //offset[11]
		logic [7:0] f;	//offset[19:12]
		logic [4:0] rd; //dest
		logic [6:0] opcode;
	} j;  //jump instructions
`ifdef ATOMIC_EXT
	struct packed {
		logic [4:0] funct5;
		logic       aq;
		logic       rl;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} a; //atomic instructions
`endif
`ifdef SYSTEM_EXT
	struct packed {
		logic [11:0] csr;
		logic [4:0]  rs1;
		logic [2:0]  funct3;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} sys; //system call instructions
`endif

} INST; //instruction typedef, this should cover all types of instructions

//
// Basic NOP instruction.  Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
//
`define NOP 32'h00000013

// Branch Prediction Unit
`define PREDICTOR_COUNTER_BITS 2
`define PREDICTOR_ENTRIES 512
`define PREDICTOR_INDEX_BITS $clog2(`PREDICTOR_ENTRIES)
`define GLOBAL_HIST_BITS `PREDICTOR_INDEX_BITS

`define BTB_ENTRIES 1024
`define BTB_INDEX_BITS $clog2(`BTB_ENTRIES)
`define BTB_TAG_BITS  (`XLEN-`BTB_INDEX_BITS)

typedef struct packed {
	logic valid;
	logic [`BTB_TAG_BITS-1:0] tag;
	logic [`XLEN-1:0] target_pc;
} BTB_ENTRY;

// ROB
// assuming 4 bits will be enough (max 16 ROB entries)
`define ROB_TAG_LEN 4

typedef struct packed {
	logic valid; // needed to distinguish empty entries
	logic [`XLEN-1:0] NPC; 
	INST inst; 
	logic wr_mem; // is a store
	logic [4:0] dest_reg; // destination register
	logic [`XLEN-1:0] dest_addr; // destination address (store)
	logic [`XLEN-1:0] value; // instruction result
	logic [`ROB_TAG_LEN-1:0] store_dep;
	logic [2:0] mem_size;
	logic value_ready;
	logic address_ready;
	logic spec;
} ROB_ENTRY;


// Common Data Bus
typedef struct packed {
	logic valid;
    logic [`ROB_TAG_LEN-1:0] rob_tag; // identifies instruction that produced value
    logic [`XLEN-1:0] value;
} CDB_DATA;

// Map table

typedef struct packed {
	logic [`ROB_TAG_LEN - 1:0] rob_tag_val;
	logic rob_tag_ready;
} MAPTABLE_PACKET;

typedef struct packed{
    logic valid;
	logic [`XLEN-1:0] NPC;
	INST inst;
    logic [`XLEN-1:0] address;
    logic [`ROB_TAG_LEN-1:0] rd_tag;
    logic [2:0] mem_size;
	logic spec;
} LB_PACKET;

//////////////////////////////////////////////
//
// IF Packets:
// Data that is exchanged between the IF and the ID stages  
//
//////////////////////////////////////////////

typedef struct packed {
	logic valid; // If low, the data in this struct is garbage
    INST  inst;  // fetched instruction out
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC 
	logic predict_taken; // to detect mispredictions
	logic [`XLEN-1:0] predict_target_pc;
} IF_ID_PACKET;

typedef struct packed {
	IF_ID_PACKET if_packet;
	logic [3:0] recorded_response;
} IQ_PACKET;

`define IQ_SIZE 4 // size of instruction queue
`define IQ_INDEX_SIZE $clog2(`IQ_SIZE) // size of instruction queue index (head/tail)

//////////////////////////////////////////////
//
// ID Packets:
// Data that is exchanged from ID to EX stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value                                  
	                                                                                
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index      
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       predict_taken; // did we predict branch taken for this inst?
	logic [`XLEN-1:0] predict_target_pc;
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
	logic		spec;
} ID_EX_PACKET;

typedef struct packed {
	logic valid;
	logic [`XLEN-1:0] NPC;
	INST inst;
    logic [`ROB_TAG_LEN-1:0] rob_tag; // identifies instruction that produced value
    logic [`XLEN-1:0] value;
	logic spec;
} EX_WR_PACKET;

typedef struct packed {
	logic valid;
	logic ready;
    logic [`ROB_TAG_LEN-1:0] rd_tag;
    logic [`ROB_TAG_LEN-1:0] rs1_tag;
    logic [`ROB_TAG_LEN-1:0] rs2_tag;
    logic rs1_ready;
    logic rs2_ready;
    logic [`XLEN-1:0] rs1_value;
    logic [`XLEN-1:0] rs2_value;
	logic [`BIRTHDAY_SIZE-1:0] birthday;
	ID_EX_PACKET instr;
	logic spec;
} INSTR_READY_ENTRY;

typedef struct packed {
	logic valid;
	logic [`XLEN-1:0] NPC;
	INST inst;
	logic [`XLEN-1:0] data_out;
	logic [2:0] mem_size;
	logic wr_mem;
	logic [`XLEN-1:0] mem_address;
	logic [4:0] reg_wr_idx_out;
	logic  reg_wr_en_out;
	logic [`ROB_TAG_LEN-1:0] rob_tag;
} COMMIT_PACKET;

`endif // __SYS_DEFS_VH__
