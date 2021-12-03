`include "defs.v"

module rvcpu(
  input clk,
  input rst_n,
  output [31:0] imem_addr,
  input [31:0] imem_q,
  output dmem_en,
  output [31:0] dmem_addr,
  output [31:0] dmem_d,
  output [3:0] dmem_we,
  input [31:0] dmem_q
);
  `define ALU_ADD 0
  `define ALU_AND 1
  `define ALU_OR  2
  `define ALU_XOR 3
  `define ALU_SLL 4
  `define ALU_SRL 5
  `define ALU_SRA 6
  `define ALU_CMPLT 7
  `define ALU_CMPLTU 9
  `define ALU_CMPEQ 10

  `define MULT_UU 0
  `define MULT_SS 1
  `define MULT_SU 2

  `define STATE_IF    2'h0
  `define STATE_EXEC  2'h1
  `define STATE_MEM   2'h2
  `define STATE_HALT  2'h3

  // --- decoder
  wire [31:0] inst = imem_q;
  wire [6:0] opcode = inst[6:0];
  wire [4:0] rd = inst[11:7];
  wire [2:0] funct3 = inst[14:12];
  wire [4:0] rs1 = inst[19:15];
  wire [4:0] rs2 = inst[24:20];
  wire [6:0] funct7 = inst[31:25];
  reg [31:0] imm;
  wire [4:0] shamt = imm[4:0];

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

  reg [1:0] state;

  reg [31:0] regs[0:31];
  wire signed [31:0] rs1_q = (rs1 == 0) ? 32'b0 : regs[rs1];
  wire signed [31:0] rs2_q = (rs2 == 0) ? 32'b0 : regs[rs2];

  reg [63:0] cycle;

  reg [31:0] pc;
  wire [31:0] pc_next = pc + 32'h4;
  reg signed [31:0] pc_adder_base;
  reg signed [31:0] pc_adder_offset;
  wire [31:0] pc_adder_out = pc_adder_base + pc_adder_offset;

  // --- alu
  reg [3:0] alu_op;
  reg signed [31:0] alu_opr1;
  reg signed [31:0] alu_opr2;
  reg signed [31:0] alu_out0;
  wire alu_inv = (opcode == `OPC_BRANCH) && funct3[0];
  wire signed [31:0] alu_out = alu_inv ? !alu_out0 : alu_out0;

  always @(*) begin
    case (alu_op)
      `ALU_ADD:    alu_out0 = alu_opr1 + alu_opr2;
      `ALU_AND:    alu_out0 = alu_opr1 & alu_opr2;
      `ALU_OR:     alu_out0 = alu_opr1 | alu_opr2;
      `ALU_XOR:    alu_out0 = alu_opr1 ^ alu_opr2;
      `ALU_SLL:    alu_out0 = alu_opr1 << alu_opr2[4:0];
      `ALU_SRL:    alu_out0 = alu_opr1 >> alu_opr2[4:0];
      `ALU_SRA:    alu_out0 = alu_opr1 >>> alu_opr2[4:0];
      `ALU_CMPLT:  alu_out0 = alu_opr1 < alu_opr2;
      `ALU_CMPLTU: alu_out0 = $unsigned(alu_opr1) < $unsigned(alu_opr2);
      `ALU_CMPEQ:  alu_out0 = alu_opr1 == alu_opr2;
      default:     alu_out0 = 32'bx;
  	endcase
  end

  // --- multiplier
  reg [1:0] mult_op;
  reg signed [31:0] mult_opr1;
  reg signed [31:0] mult_opr2;
  reg signed [63:0] mult_out0;
  wire mult_hi = (funct3 != 3'b0);
  wire signed [63:0] mult_out = mult_hi ? mult_out0[63:32] : mult_out0[31:0];

  always @(*) begin
    case (mult_op)
      `MULT_SS: mult_out0 = mult_opr1 * mult_opr2;
      `MULT_UU: mult_out0 = $unsigned(mult_opr1) * $unsigned(mult_opr2);
      `MULT_SU: mult_out0 = mult_opr1 * $signed({1'b0, mult_opr2});
      default:  mult_out0 = 64'bx;
    endcase
  end

  assign imem_addr = pc;
  assign dmem_en = (state == `STATE_EXEC) && (opcode == `OPC_LOAD || opcode == `OPC_STORE);
  assign dmem_addr = {alu_out[31:2], 2'b00};

  reg [31:0] wr_data;
  assign dmem_d = wr_data;
  always @(*) begin
    case (funct3)
      `FUNCT_SB:
        case (alu_out[1:0])
          0: wr_data = {24'b0, rs2_q[7:0]};
          1: wr_data = {16'b0, rs2_q[7:0], 8'b0};
          2: wr_data = {8'b0, rs2_q[7:0], 16'b0};
          3: wr_data = {rs2_q[7:0], 24'b0};
        endcase
      `FUNCT_SH: wr_data = alu_out[1] ? {rs2_q[15:0], 16'b0} : rs2_q;
      `FUNCT_SW: wr_data = rs2_q;
      default:   wr_data = 32'bx;
    endcase
  end

  reg [3:0] we_byte;
  assign dmem_we = (state == `STATE_EXEC && opcode == `OPC_STORE) ? we_byte : 4'b0;
  always @(*) begin
    case (funct3)
      `FUNCT_SB: we_byte = 4'b0001 << alu_out[1:0];
      `FUNCT_SH: we_byte = alu_out[1] ? 4'b1100 : 4'b0011;
      `FUNCT_SW: we_byte = 4'b1111;
      default:   we_byte = 4'bx;
    endcase
  end

  always @(*) begin
    pc_adder_base = 32'bx;
    pc_adder_offset = 32'bx;
    alu_opr1 = 32'bx;
    alu_opr2 = 32'bx;
    alu_op = 4'bx;
    mult_opr1 = 64'bx;
    mult_opr2 = 64'bx;
    mult_op = 2'bx;
    if (opcode == `OPC_OP_IMM) begin
      alu_opr1 = rs1_q;
      alu_opr2 = imm;
      case (funct3)
        `FUNCT_ADDI: alu_op = `ALU_ADD;
        `FUNCT_SLTI: alu_op = `ALU_CMPLT;
        `FUNCT_SLTIU: alu_op = `ALU_CMPLTU;
        `FUNCT_ANDI: alu_op = `ALU_AND;
        `FUNCT_ORI: alu_op = `ALU_OR;
        `FUNCT_XORI: alu_op = `ALU_XOR;
        `FUNCT_SLLI: alu_op = `ALU_SLL;
        `FUNCT_SRLI_SRAI: alu_op = imm[10] ? `ALU_SRA : `ALU_SRL;
        default: alu_op = 4'bx;
      endcase
    end
    else if (opcode == `OPC_LUI) begin
      alu_opr1 = 32'b0;
      alu_opr2 = imm;
      alu_op = `ALU_ADD;
    end
    else if (opcode == `OPC_AUIPC) begin
      alu_opr1 = pc;
      alu_opr2 = imm;
      alu_op = `ALU_ADD;
    end
    else if (opcode == `OPC_OP) begin
      if (funct7[0] == 1'b0) begin
        alu_opr1 = rs1_q;
        alu_opr2 = rs2_q;
        case (funct3)
          `FUNCT_ADD_SUB: begin
            alu_op = `ALU_ADD;
            if (funct7[5]) alu_opr2 = -rs2_q;
          end
          `FUNCT_SLT: alu_op = `ALU_CMPLT;
          `FUNCT_SLTU: alu_op = `ALU_CMPLTU;
          `FUNCT_AND: alu_op = `ALU_AND;
          `FUNCT_OR: alu_op = `ALU_OR;
          `FUNCT_XOR: alu_op = `ALU_XOR;
          `FUNCT_SLL: alu_op = `ALU_SLL;
          `FUNCT_SRL_SRA: alu_op = funct7[5] ? `ALU_SRA : `ALU_SRL;
          default: alu_op = 4'bx;
        endcase
      end
      else begin
        mult_opr1 = rs1_q;
        mult_opr2 = rs2_q;
        case (funct3)
          `FUNCT_MUL: mult_op = `MULT_SS;
          `FUNCT_MULH: mult_op = `MULT_SS;
          `FUNCT_MULHSU: mult_op = `MULT_SU;
          `FUNCT_MULHU: mult_op = `MULT_UU;
          default: mult_op = 2'bx;
        endcase
      end
    end
    else if (opcode == `OPC_JAL) begin
      pc_adder_base = pc;
      pc_adder_offset = imm;
      alu_opr1 = pc;
      alu_opr2 = 32'h4;
      alu_op = `ALU_ADD;
    end
    else if (opcode == `OPC_JALR) begin
      pc_adder_base = rs1_q;
      pc_adder_offset = imm;
      alu_opr1 = pc;
      alu_opr2 = 32'h4;
      alu_op = `ALU_ADD;
    end
    else if (opcode == `OPC_BRANCH) begin
      pc_adder_base = pc;
      pc_adder_offset = imm;
      alu_opr1 = rs1_q;
      alu_opr2 = rs2_q;
      case (funct3)
        `FUNCT_BEQ: alu_op = `ALU_CMPEQ;
        `FUNCT_BNE: alu_op = `ALU_CMPEQ;
        `FUNCT_BLT: alu_op = `ALU_CMPLT;
        `FUNCT_BLTU: alu_op = `ALU_CMPLTU;
        `FUNCT_BGE: alu_op = `ALU_CMPLT;
        `FUNCT_BGEU: alu_op = `ALU_CMPLTU;
        default: alu_op = 4'bx;
      endcase
    end
    else if (opcode == `OPC_LOAD || opcode == `OPC_STORE || opcode == `OPC_MISC_MEM) begin
      alu_opr1 = rs1_q;
      alu_opr2 = imm;
      alu_op = `ALU_ADD;
    end
  end

  reg [31:0] dmem_q_ext;

  always @(*) begin
    case (funct3)
      `FUNCT_LB:
        case (alu_out[1:0])
          0: dmem_q_ext = {{24{dmem_q[7]}}, dmem_q[7:0]};
          1: dmem_q_ext = {{24{dmem_q[15]}}, dmem_q[15:8]};
          2: dmem_q_ext = {{24{dmem_q[23]}}, dmem_q[23:16]};
          3: dmem_q_ext = {{24{dmem_q[31]}}, dmem_q[31:24]};
        endcase
      `FUNCT_LH:
        case (alu_out[1])
          0: dmem_q_ext = {{16{dmem_q[15]}}, dmem_q[15:0]};
          1: dmem_q_ext = {{16{dmem_q[31]}}, dmem_q[31:16]};
        endcase
      `FUNCT_LW:
        dmem_q_ext = dmem_q;
      `FUNCT_LBU:
        case (alu_out[1:0])
          0: dmem_q_ext = {24'b0, dmem_q[7:0]};
          1: dmem_q_ext = {24'b0, dmem_q[15:8]};
          2: dmem_q_ext = {24'b0, dmem_q[23:16]};
          3: dmem_q_ext = {24'b0, dmem_q[31:24]};
        endcase
      `FUNCT_LHU:
        case (alu_out[1])
          0: dmem_q_ext = {16'b0, dmem_q[15:0]};
          1: dmem_q_ext = {16'b0, dmem_q[31:16]};
        endcase
      default:
        dmem_q_ext = 32'bx;
    endcase
  end

  // --- state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= `STATE_IF;
      pc <= 32'b0;
      cycle <= 64'b0;
    end
    else begin
      cycle <= cycle + 64'b1;

      if (state == `STATE_IF) begin
        state <= `STATE_EXEC;
      end
      else if (state == `STATE_EXEC) begin
        state <= is_mem_stage_required ? `STATE_MEM : `STATE_IF;
        if (opcode == `OPC_OP_IMM || opcode == `OPC_LUI || opcode == `OPC_AUIPC
          || opcode == `OPC_OP || opcode == `OPC_JAL || opcode == `OPC_JALR || opcode == `OPC_SYSTEM) begin

          pc <= (opcode == `OPC_JAL || opcode == `OPC_JALR) ? pc_adder_out : pc_next;

          regs[rd] <= (opcode == `OPC_OP && funct7[0]) ? mult_out : alu_out;
          if (opcode == `OPC_SYSTEM && funct3 == `FUNCT_CSRRS && rs1 == 0) begin
            case (imm[11:0])
              `CSR_CYCLE: regs[rd] <= cycle[31:0];
              `CSR_CYCLEH: regs[rd] <= cycle[63:32];
            endcase
          end

          if (opcode == `OPC_SYSTEM && funct3 == `FUNCT_PRIV)
            state <= `STATE_HALT;
        end
        else if (opcode == `OPC_BRANCH) begin
          pc <= alu_out ? pc_adder_out : pc_next;
        end
        else if (opcode == `OPC_MISC_MEM) begin
          pc <= pc_next;
        end
      end
      else if (state == `STATE_MEM) begin
        state <= `STATE_IF;
        pc <= pc_next;
        if (opcode == `OPC_LOAD)
          regs[rd] <= dmem_q_ext;
      end
      else begin
        state <= `STATE_HALT;
      end
    end
  end
endmodule

