`define OPC_OP_IMM   7'b0010011
`define OPC_LUI      7'b0110111
`define OPC_AUIPC    7'b0010111
`define OPC_OP       7'b0110011
`define OPC_JAL      7'b1101111
`define OPC_JALR     7'b1100111
`define OPC_BRANCH   7'b1100011
`define OPC_LOAD     7'b0000011
`define OPC_STORE    7'b0100011
`define OPC_MISC_MEM 7'b0001111
`define OPC_SYSTEM   7'b1110011

`define FUNCT_ADDI   3'b000
`define FUNCT_SLTI   3'b010
`define FUNCT_SLTIU  3'b011
`define FUNCT_ANDI   3'b111
`define FUNCT_ORI    3'b110
`define FUNCT_XORI   3'b100
`define FUNCT_SLLI   3'b001
`define FUNCT_SRLI_SRAI  3'b101
`define FUNCT_ADD_SUB    3'b000
`define FUNCT_SLT    3'b010 `define FUNCT_SLTU   3'b011
`define FUNCT_AND    3'b111
`define FUNCT_OR     3'b110
`define FUNCT_XOR    3'b100
`define FUNCT_SLL    3'b001
`define FUNCT_SRL_SRA    3'b101
`define FUNCT_BEQ    3'b000
`define FUNCT_BNE    3'b001
`define FUNCT_BLT    3'b100
`define FUNCT_BGE    3'b101
`define FUNCT_BLTU   3'b110
`define FUNCT_BGEU   3'b111
`define FUNCT_LB     3'b000
`define FUNCT_LH     3'b001
`define FUNCT_LW     3'b010
`define FUNCT_LBU    3'b100
`define FUNCT_LHU    3'b101
`define FUNCT_SB     3'b000
`define FUNCT_SH     3'b001
`define FUNCT_SW     3'b010
`define FUNCT_FENCE  3'b000
`define FUNCT_PRIV   3'b000
`define FUNCT_MUL    3'b000
`define FUNCT_MULH   3'b001
`define FUNCT_MULHSU 3'b010
`define FUNCT_MULHU  3'b011
`define FUNCT_DIV    3'b100
`define FUNCT_DIVU   3'b101
`define FUNCT_REM    3'b110
`define FUNCT_REMU   3'b111
`define FUNCT_CSRRS  3'b010

`define FUNCT_ECALL   12'b0
`define FUNCT_EBREAK  12'b1

`define CSR_CYCLE     12'hc00
`define CSR_CYCLEH    12'hc80
