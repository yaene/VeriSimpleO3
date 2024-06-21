//////////////////////////////////////////////
//
// Datapath control signals
//
//////////////////////////////////////////////
typedef struct packed {
	logic ready;
	// logic [`XLEN-1:0] value;
} REG_READY_ENTRY;


typedef struct packed {
	logic valid;
	logic ready;
	logic birthday;
	ID_EX_PACKET inst;
} INSTR_READY_ENTRY;