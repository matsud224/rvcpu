`include "defs.v"

module imem(
  input clk,
  input [31:0] addr,
  output reg [31:0] q
);
  reg [31:0] rom[0:16384-1];

  always @(posedge clk) begin
    q <= rom[addr];
  end

  initial begin
    $readmemh("rom.txt", rom);
  end
endmodule

module dmem(
  input clk,
  input [31:0] addr,
  input [31:0] d,
  input we,
  output reg [31:0] q
);
  reg [31:0] ram[0:4096-1];

  always @(posedge clk) begin
    if (we)
      ram[addr] <= d;
    q <= ram[addr];
  end
endmodule

module rvcpu(
  input clk,
  input rst_n,
  output [31:0] imem_addr,
  input [31:0] imem_q,
  output [31:0] dmem_addr,
  output [31:0] dmem_d,
  output dmem_we,
  input [31:0] dmem_q,
  output halted
);
  // --- decoder
  wire [31:0] inst = imem_q;
  wire [6:0] opcode = inst[6:0];
  wire [4:0] rd = inst[11:7];
  wire [2:0] funct3 = inst[14:12];
  wire [4:0] rs1 = inst[19:15];
  wire [4:0] rs2 = inst[24:20];
  wire [6:0] funct7 = inst[31:25];
  reg signed [31:0] imm;

  wire is_mem_stage_required = (opcode == `OPC_LOAD || opcode == `OPC_STORE);

  always @(*) begin
    if (opcode == `OPC_OP_IMM || opcode == `OPC_JALR || opcode == `OPC_LOAD || opcode == `OPC_SYSTEM)
      imm = {{21{inst[31]}}, inst[30:20]}; // I-type
    else if (opcode == `OPC_LUI || opcode == `OPC_AUIPC)
      imm = {inst[31:12], 12'b0}; // U-type
    else if (opcode == `OPC_JAL)
      imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0}; // J-type
    else if (opcode == `OPC_BRANCH)
      imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0}; // I-type
    else if (opcode == `OPC_STORE)
      imm = {{21{inst[31]}}, inst[30:25], inst[11:8], inst[7]}; // S-type
    else
      imm = 32'bx;
  end

  // --- state machine
  `define STATE_IF    3'h0
  `define STATE_EXEC  3'h1
  `define STATE_MEM   3'h2
  `define STATE_HALT  3'h3

  reg [2:0] state;

  reg signed [31:0] regs[0:31];
  wire signed [31:0] rs1_q = (rs1 == 0) ? 0 : regs[rs1];
  wire signed [31:0] rs2_q = (rs2 == 0) ? 0 : regs[rs2];

  reg signed [31:0] pc;

  assign imem_addr = pc;
  assign dmem_addr = (state == `STATE_EXEC && (opcode == `OPC_LOAD || `OPC_STORE)) ? (rs1_q + imm) : 32'bz;
  assign dmem_d = rs2_q;
  assign dmem_we = (state == `STATE_EXEC && opcode == `OPC_STORE);

  wire halted = (state == `STATE_HALT);

  integer i;
  wire signed [31:0] pc_rel  = pc + imm;
  wire [4:0] shamt = imm[4:0];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= `STATE_IF;
      pc <= 0;
      for (i=0; i<32; i++)
        regs[i] <= 0;
    end
    else begin
      if (state == `STATE_IF) begin
        state <= `STATE_EXEC;
      end
      else if (state == `STATE_EXEC) begin
        state <= is_mem_stage_required ? `STATE_MEM : `STATE_IF;
        pc <= pc + 4;
        if (opcode == `OPC_OP_IMM)
          case (funct3)
            `FUNCT_ADDI: regs[rd] <= rs1_q + imm;
            `FUNCT_SLTI: regs[rd] <= rs1_q < imm;
            `FUNCT_SLTIU: regs[rd] <= $unsigned(rs1_q) < $unsigned(imm);
            `FUNCT_ANDI: regs[rd] <= rs1_q & imm;
            `FUNCT_ORI: regs[rd] <= rs1_q | imm;
            `FUNCT_XORI: regs[rd] <= rs1_q ^ imm;
            `FUNCT_SLLI: regs[rd] <= rs1_q << shamt;
            `FUNCT_SRLI: regs[rd] <= rs1_q >> shamt;
            `FUNCT_SRAI: regs[rd] <= rs1_q >>> shamt;
          endcase
        else if (opcode == `OPC_LUI)
          regs[rd] <= imm;
        else if (opcode == `OPC_AUIPC)
          regs[rd] <= pc + imm;
        else if (opcode == `OPC_OP)
          case (funct3)
            `FUNCT_ADD: regs[rd] <= rs1_q + rs2_q;
            `FUNCT_SLT: regs[rd] <= rs1_q < rs2_q;
            `FUNCT_SLTU: regs[rd] <= $unsigned(rs1_q) < $unsigned(rs2_q);
            `FUNCT_AND: regs[rd] <= rs1_q & rs2_q;
            `FUNCT_OR: regs[rd] <= rs1_q | rs2_q;
            `FUNCT_XOR: regs[rd] <= rs1_q ^ rs2_q;
            `FUNCT_SLL: regs[rd] <= rs1_q << rs2_q;
            `FUNCT_SRL: regs[rd] <= rs1_q >> rs2_q;
            `FUNCT_SRA: regs[rd] <= rs1_q >>> rs2_q;
            `FUNCT_SUB: regs[rd] <= rs1_q - rs2_q;
          endcase
        else if (opcode == `OPC_JAL) begin
          regs[rd] <= pc;
          pc <= pc_rel;
        end
        else if (opcode == `OPC_JALR) begin
          regs[rd] <= pc;
          pc <= rs1_q + imm;
        end
        else if (opcode == `OPC_BRANCH)
          case (funct3)
            `FUNCT_BEQ: if (rs1_q == rs2_q) pc <= pc_rel;
            `FUNCT_BNE: if (rs1_q != rs2_q) pc <= pc_rel;
            `FUNCT_BLT: if (rs1_q < rs2_q) pc <= pc_rel;
            `FUNCT_BLTU: if ($unsigned(rs1_q) < $unsigned(rs2_q)) pc <= pc_rel;
            `FUNCT_BGE: if (rs1_q >= rs2_q) pc <= pc_rel;
            `FUNCT_BGEU: if ($unsigned(rs1_q) >= $unsigned(rs2_q)) pc <= pc_rel;
          endcase
        else if (opcode == `OPC_MISC_MEM)
          regs[0] <= 0;  // pass
        else
          state <= `STATE_HALT;  // unimplemented instruction
      end
      else if (state == `STATE_MEM) begin
        state <= `STATE_IF;
        if (opcode == `OPC_LOAD) regs[rd] <= dmem_q;
      end
      else
        state <= `STATE_HALT;
    end
  end
endmodule

module rvcpu_top(
  input clk,
  input rst_n,
  output halted
);
  wire [31:0] imem_addr, imem_q, dmem_addr, dmem_d, dmem_q;
  wire dmem_we;

  imem imem0(clk, imem_addr, imem_q);
  dmem dmem0(clk, dmem_addr, dmem_d, dmem_we, dmem_q);
  rvcpu cpu0(clk, rst_n, imem_addr, imem_q, dmem_addr, dmem_d, dmem_we, dmem_q, halted);
endmodule
