`include "defs.v"


module i_stage(
  input [31:] pc,
  output [31:0] imem_addr,
  input [31:0] imem_q,
  output [31:0] out_inst
);
  assign imem_addr = pc;
  assign inst = imem_q;

endmodule


module d_stage(
  output [4:0] rs1,
  output [4:0] rs2,
  input [31:0] rs1_q,
  input [31:0] rs2_q,
  input [31:0] inst,
  output reg [1:0] out_unit,
  output reg [3:0] out_alu_op,
  output reg [1:0] out_mult_op,
  output reg [3:0] out_mem_wbyte,
  output reg [31:0] out_opr1,
  output reg [31:0] out_opr2,
  output reg [4:0] out_rs1,
  output reg [4:0] out_rs2,
  output reg [4:0] out_rd,
  output reg [31:0] out_dest_addr,
  output reg out_need_wb
);
  wire [6:0] opcode = inst[6:0];
  wire [4:0] rd = inst[11:7];
  wire [2:0] funct3 = inst[14:12];
  assign rs1 = inst[19:15];
  assign rs2 = inst[24:20];
  wire [6:0] funct7 = inst[31:25];
  reg [31:0] imm;
  wire [4:0] shamt = imm[4:0];

  reg signed [31:0] dest_adder_base;
  reg signed [31:0] dest_adder_offset;
  wire [31:0] dest_adder_out = dest_adder_base + dest_adder_offset;

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

  always @(*) begin
    dest_adder_base = 32'bx;
    dest_adder_offset = 32'bx;
    out_unit = 2'bx;
    out_opr1 = 32'bx;
    out_opr2 = 32'bx;
    out_alu_op = 4'bx;
    out_mult_op = 2'bx;
    out_dest_addr = 32'bx;
    if (opcode == `OPC_OP_IMM) begin
      out_unit = `UNIT_ALU;
      out_opr1 = rs1_q;
      out_opr2 = imm;
      case (funct3)
        `FUNCT_ADDI: out_alu_op = `ALU_ADD;
        `FUNCT_SLTI: out_alu_op = `ALU_CMPLT;
        `FUNCT_SLTIU: out_alu_op = `ALU_CMPLTU;
        `FUNCT_ANDI: out_alu_op = `ALU_AND;
        `FUNCT_ORI: out_alu_op = `ALU_OR;
        `FUNCT_XORI: out_alu_op = `ALU_XOR;
        `FUNCT_SLLI: out_alu_op = `ALU_SLL;
        `FUNCT_SRLI_SRAI: out_alu_op = imm[10] ? `ALU_SRA : `ALU_SRL;
        default: out_alu_op = 4'bx;
      endcase
    end
    else if (opcode == `OPC_LUI) begin
      out_opr1 = 32'b0;
      out_opr2 = imm;
      out_alu_op = `ALU_ADD;
    end
    else if (opcode == `OPC_AUIPC) begin
      out_opr1 = pc;
      out_opr2 = imm;
      out_alu_op = `ALU_ADD;
    end
    else if (opcode == `OPC_OP) begin
      if (funct7[0] == 1'b0) begin
        unit = `UNIT_ALU;
        out_opr1 = rs1_q;
        out_opr2 = rs2_q;
        case (funct3)
          `FUNCT_ADD_SUB: begin
            out_alu_op = `ALU_ADD;
            if (funct7[5]) out_opr2 = -rs2_q;
          end
          `FUNCT_SLT: out_alu_op = `ALU_CMPLT;
          `FUNCT_SLTU: out_alu_op = `ALU_CMPLTU;
          `FUNCT_AND: out_alu_op = `ALU_AND;
          `FUNCT_OR: out_alu_op = `ALU_OR;
          `FUNCT_XOR: out_alu_op = `ALU_XOR;
          `FUNCT_SLL: out_alu_op = `ALU_SLL;
          `FUNCT_SRL_SRA: out_alu_op = funct7[5] ? `ALU_SRA : `ALU_SRL;
          default: out_alu_op = 4'bx;
        endcase
      end
      else begin
        unit = `UNIT_MUL;
        out_opr1 = rs1_q;
        out_opr2 = rs2_q;
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
      dest_adder_base = pc;
      dest_adder_offset = imm;
      out_dest_addr = dest_adder_out;
    end
    else if (opcode == `OPC_JALR) begin
      dest_adder_base = rs1_q;
      dest_adder_offset = imm;
      out_dest_addr = dest_adder_out;
    end
    else if (opcode == `OPC_BRANCH) begin
      dest_adder_base = pc;
      dest_adder_offset = imm;
      out_opr1 = rs1_q;
      out_opr2 = rs2_q;
      out_dest_addr = dest_adder_out;
      case (funct3)
        `FUNCT_BEQ: out_alu_op = `ALU_CMPEQ;
        `FUNCT_BNE: out_alu_op = `ALU_CMPEQ;
        `FUNCT_BLT: out_alu_op = `ALU_CMPLT;
        `FUNCT_BLTU: out_alu_op = `ALU_CMPLTU;
        `FUNCT_BGE: out_alu_op = `ALU_CMPLT;
        `FUNCT_BGEU: out_alu_op = `ALU_CMPLTU;
        default: out_alu_op = 4'bx;
      endcase
    end
    else if (opcode == `OPC_LOAD || opcode == `OPC_STORE || opcode == `OPC_MISC_MEM) begin
      dest_adder_base = rs1_q;
      dest_adder_offset = imm;
      out_dest_addr = dest_adder_out;
    end
  end

  always @(*) begin
    case (funct3)
      `FUNCT_SB: out_mem_wbyte = 4'b0001 << dest_adder_out[1:0];
      `FUNCT_SH: out_mem_wbyte = dest_adder_out[1] ? 4'b1100 : 4'b0011;
      `FUNCT_SW: out_mem_wbyte = 4'b1111;
      default:   out_mem_wbyte = 4'bx;
    endcase
  end

endmodule


module e_stage(
  output dmem_en,
  output [31:0] dmem_addr,
  output [31:0] dmem_d,
  output [3:0] dmem_we,
  input [31:0] dmem_q
  input [1:0] unit,
  input [3:0] alu_op,
  input [1:0] mult_op,
  input [3:0] mem_wbyte,
  input [31:0] opr1,
  input [31:0] opr2,
  input [4:0] rs1,
  input [4:0] rs2,
  input [4:0] rd,
  input [31:0] dest_addr,
  input need_wb,
  output [4:0] out_rd,
  output [31:0] out_data
  output out_need_wb
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

  `define UNIT_ALU 0
  `define UNIT_MUL 1
  `define UNIT_MEM 2

  // --- alu
  reg signed [31:0] alu_out0;
  wire alu_inv = (opcode == `OPC_BRANCH) && funct3[0];
  wire signed [31:0] alu_out = alu_inv ? !alu_out0 : alu_out0;

  always @(*) begin
    case (alu_op)
      `ALU_ADD:    alu_out0 = opr1 + opr2;
      `ALU_AND:    alu_out0 = opr1 & opr2;
      `ALU_OR:     alu_out0 = opr1 | opr2;
      `ALU_XOR:    alu_out0 = opr1 ^ opr2;
      `ALU_SLL:    alu_out0 = opr1 << opr2[4:0];
      `ALU_SRL:    alu_out0 = opr1 >> opr2[4:0];
      `ALU_SRA:    alu_out0 = opr1 >>> opr2[4:0];
      `ALU_CMPLT:  alu_out0 = opr1 < opr2;
      `ALU_CMPLTU: alu_out0 = $unsigned(opr1) < $unsigned(opr2);
      `ALU_CMPEQ:  alu_out0 = opr1 == opr2;
      default:     alu_out0 = 32'bx;
  	endcase
  end

  // --- multiplier
  reg signed [63:0] mult_out0;
  wire mult_hi = (funct3 != 3'b0);
  wire signed [63:0] mult_out = mult_hi ? mult_out0[63:32] : mult_out0[31:0];

  always @(*) begin
    case (mult_op)
      `MULT_SS: mult_out0 = opr1 * opr2;
      `MULT_UU: mult_out0 = $unsigned(opr1) * $unsigned(opr2);
      `MULT_SU: mult_out0 = opr1 * $signed({1'b0, opr2});
      default:  mult_out0 = 64'bx;
    endcase
  end

  assign dmem_en = (unit == `UNIT_MEM);
  assign dmem_addr = {dest_addr[31:2], 2'b00};

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

  assign dmem_we = mem_wbyte;
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

endmodule


module w_stage(
  input [4:0] rd,
  input [31:0] data,
  input need_wb,
  output [4:0] out_rd,
  output [31:0] out_rd_d,
  output out_we
);
  assign out_rd = rd;
  assign out_rd_d = data;
  assign out_we = need_wb;

endmodule


module regfile(
  input [4:0] rs1,
  input [4:0] rs2,
  output signed [31:0] rs1_q,
  output signed [31:0] rs2_q,
  input [4:0] rd,
  input [4:0] rd_d,
  input we
);
  reg [31:0] regs[0:31];
  wire signed [31:0] rs1_q = (rs1 == 0) ? 32'b0 : regs[rs1];
  wire signed [31:0] rs2_q = (rs2 == 0) ? 32'b0 : regs[rs2];

  always @(posedge clk) begin
    if (we)
      regs[rd] <= rd_d;
  end

endmodule


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
  wire [4:0] rf_rs1, rf_rs2, rf_rd;
  wire [31:0] rf_rs1_q, rf_rs2_q, rf_rd_d;
  wire rf_we;
  regfile rf(rf_rs1, rf_rs2, rf_rs1_q, rf_rs2_q,
    rf_rd, rf_rd_d, rf_we);

  reg [63:0] cycle;

  reg [31:0] pc;
  wire [31:0] pc_next = pc + 32'h4;

  reg ID_valid;
  reg [31:0] ID_inst;

  reg DE_valid;
  reg DE_require_wb;
  reg [1:0] DE_unit;
  reg [3:0] DE_alu_op;
  reg [1:0] DE_mult_op;
  reg [3:0] DE_mem_wbyte;
  reg [31:0] DE_opr1;
  reg [31:0] DE_opr2;
  reg [4:0] DE_rs1;
  reg [4:0] DE_rs2;
  reg [4:0] DE_rd;
  reg [31:0] DE_dest_addr;
  reg DE_need_wb;

  reg EW_valid;
  reg [4:0] EW_rd;
  reg [31:0] EW_data;
  reg EW_need_wb;

  i_stage istage(pc, imem_addr, imem_q, ID_inst);

  d_stage dstage(rf_rs1, rf_rs2, rf_rs1_q, rf_rs2_q,
    ID_inst,
    DE_unit, DE_alu_op, DE_mult_op, DE_opr1, DE_opr2, DE_rs1, DE_rs2, DE_rd,
    DE_dest_addr, DE_need_wb);

  e_stage estage(dmem_addr, dmem_d, dmem_we, dmem_q,
    DE_unit, DE_alu_op, DE_mult_op, DE_mem_wbyte, DE_opr1, DE_opr2, DE_rs1, DE_rs2, DE_rd,
    DE_dest_addr, DE_need_wb,
    EW_rd, EW_data, EW_need_wb);

  w_stage wstage(EW_rd, EW_data, EW_need_wb, rf_rd, rf_rd_d, rf_we);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= 32'b0;
      cycle <= 64'b0;
      ID_valid <= 0;
      DE_valid <= 0;
      EW_valid <= 0;
    end
    else begin
      cycle <= cycle + 64'b1;

      // I stage
      pc <= pc + 32'h4;
      ID_valid <= 1;
      ID_inst <= imem_q;

      // D stage
      DE_valid <= ID_valid;
      DE_unit <= unit;
      DE_alu_op <= alu_op;
      DE_mult_op <= alu_op;
      DE_rs1 <= ;
      DE_rs2 <= ;
      DE_opr1 <= ;
      DE_opr2 <= ;

      // E stage
      EW_valid <= DE_valid;
      EW_we <= DE_require_wb;
      EW_rd <= DE_rd;
      EW_out <=

      if (opcode == `OPC_OP_IMM || opcode == `OPC_LUI || opcode == `OPC_AUIPC
        || opcode == `OPC_OP || opcode == `OPC_JAL || opcode == `OPC_JALR || opcode == `OPC_SYSTEM) begin

        pc <= (opcode == `OPC_JAL || opcode == `OPC_JALR) ? dest_adder_out : pc_next;

        if (opcode == `OPC_SYSTEM && funct3 == `FUNCT_CSRRS && rs1 == 0) begin
          case (imm[11:0])
            `CSR_CYCLE: regs[rd] <= cycle[31:0];
            `CSR_CYCLEH: regs[rd] <= cycle[63:32];
          endcase
        end
        else
          regs[rd] <= (opcode == `OPC_OP && funct7[0]) ? mult_out : alu_out;

        if (opcode == `OPC_SYSTEM && funct3 == `FUNCT_PRIV)
          state <= `STATE_HALT;
      end
      else if (opcode == `OPC_BRANCH) begin
        pc <= alu_out ? dest_adder_out : pc_next;
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

    // W stage
  end
endmodule

