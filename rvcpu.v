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
  input [3:0] we,
  output reg [31:0] q
);
  reg [31:0] ram[0:4096-1];

  reg [7:0] d0, d1, d2, d3;

  always @(*) begin
    d0 = we[0] ? d[7:0] : ram[addr][7:0];
    d1 = we[1] ? d[15:8] : ram[addr][15:8];
    d2 = we[2] ? d[23:16] : ram[addr][23:16];
    d3 = we[3] ? d[31:24] : ram[addr][31:24];
  end

  always @(posedge clk) begin
    ram[addr] <= {d3, d2, d1, d0};
    q <= {d3, d2, d1, d0};
  end
endmodule

module rvcpu(
  input clk,
  input rst_n,
  output [31:0] imem_addr,
  input [31:0] imem_q,
  output [31:0] dmem_addr,
  output [31:0] dmem_d,
  output [3:0] dmem_we,
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

  assign halted = (state == `STATE_HALT);

  integer i;
  wire signed [31:0] pc_rel  = pc + imm;
  wire signed [31:0] rs1_rel  = rs1_q + imm;
  wire [4:0] shamt = imm[4:0];

  assign imem_addr = pc;
  assign dmem_addr = (state == `STATE_EXEC && (opcode == `OPC_LOAD || opcode == `OPC_STORE)) ? {rs1_rel[31:2], 2'b00} : 32'b0;

  reg [31:0] dmem_d;
  assign dmem_d = wr_data;
  always @(*) begin
    case (funct3)
      `FUNCT_SB: wr_data = rs2_q[7:0] << {rs1_rel[1:0], 3'b0};
      `FUNCT_SH: wr_data = rs2_q[15:0] << {rs1_rel[1], 4'b0};
      `FUNCT_SW: wr_data = rs2_q;
      default:   wr_data = 32'bx;
    endcase
  end

  reg [3:0] we_byte;
  assign dmem_we = (state == `STATE_EXEC && opcode == `OPC_STORE) ? we_byte : 4'b0;
  always @(*) begin
    case (funct3)
      `FUNCT_SB: we_byte = 4'b1 << rs1_rel[1:0];
      `FUNCT_SH: we_byte = rs1_rel[1] ? 4'b1100 : 4'b0011;
      `FUNCT_SW: we_byte = 4'b1111;
      default:   we_byte = 4'bx;
    endcase
  end

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
            `FUNCT_SRLI_SRAI:
              if (!imm[10]) regs[rd] <= rs1_q >> shamt;
              else regs[rd] <= rs1_q >>> shamt;
          endcase
        else if (opcode == `OPC_LUI)
          regs[rd] <= imm;
        else if (opcode == `OPC_AUIPC)
          regs[rd] <= pc_rel;
        else if (opcode == `OPC_OP)
          case (funct3)
            `FUNCT_ADD_SUB:
              if (!funct7[5]) regs[rd] <= rs1_q + rs2_q;
              else regs[rd] <= rs1_q - rs2_q;
            `FUNCT_SLT: regs[rd] <= rs1_q < rs2_q;
            `FUNCT_SLTU: regs[rd] <= $unsigned(rs1_q) < $unsigned(rs2_q);
            `FUNCT_AND: regs[rd] <= rs1_q & rs2_q;
            `FUNCT_OR: regs[rd] <= rs1_q | rs2_q;
            `FUNCT_XOR: regs[rd] <= rs1_q ^ rs2_q;
            `FUNCT_SLL: regs[rd] <= rs1_q << rs2_q[4:0];
            `FUNCT_SRL_SRA:
              if (!funct7[5]) regs[rd] <= rs1_q >> rs2_q[4:0];
              else regs[rd] <= rs1_q >>> rs2_q[4:0];
          endcase
        else if (opcode == `OPC_JAL) begin
          regs[rd] <= pc + 4;
          pc <= pc_rel;
        end
        else if (opcode == `OPC_JALR) begin
          regs[rd] <= pc + 4;
          pc <= {rs1_rel[31:1], 1'b0};
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
        else if (opcode == `OPC_LOAD || opcode == `OPC_STORE || opcode == `OPC_MISC_MEM)
          regs[0] <= 0;  // pass
        else
          state <= `STATE_HALT;  // unimplemented instruction
      end
      else if (state == `STATE_MEM) begin
        state <= `STATE_IF;
        if (opcode == `OPC_LOAD)
          case (funct3)
            `FUNCT_LB:
              case (rs1_rel[1:0])
                0: regs[rd] <= {{24{dmem_q[7]}}, dmem_q[7:0]};
                1: regs[rd] <= {{24{dmem_q[15]}}, dmem_q[15:8]};
                2: regs[rd] <= {{24{dmem_q[23]}}, dmem_q[23:16]};
                3: regs[rd] <= {{24{dmem_q[31]}}, dmem_q[31:24]};
              endcase
            `FUNCT_LH:
              case (rs1_rel[1])
                0: regs[rd] <= {{16{dmem_q[15]}}, dmem_q[15:0]};
                1: regs[rd] <= {{16{dmem_q[31]}}, dmem_q[31:16]};
              endcase
            `FUNCT_LW:
              regs[rd] <= dmem_q;
            `FUNCT_LBU:
              case (rs1_rel[1:0])
                0: regs[rd] <= {24'b0, dmem_q[7:0]};
                1: regs[rd] <= {24'b0, dmem_q[15:8]};
                2: regs[rd] <= {24'b0, dmem_q[23:16]};
                3: regs[rd] <= {24'b0, dmem_q[31:24]};
              endcase
            `FUNCT_LHU:
              case (rs1_rel[1])
                0: regs[rd] <= {16'b0, dmem_q[15:0]};
                1: regs[rd] <= {16'b0, dmem_q[31:16]};
              endcase
          endcase
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
  wire [3:0] dmem_we;

  imem imem0(clk, imem_addr, imem_q);
  dmem dmem0(clk, dmem_addr, dmem_d, dmem_we, dmem_q);
  rvcpu cpu0(clk, rst_n, imem_addr, imem_q, dmem_addr, dmem_d, dmem_we, dmem_q, halted);
endmodule
