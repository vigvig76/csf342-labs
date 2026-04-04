// ALUOp: 000=ADD, 001=SUB, 010=AND, 011=OR,
//        100=XOR, 101=INC_A_4, 110=PASS_A, 111=PASS_B
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  alu_op,
    output reg  [31:0] result
);

    always @(*) begin
        case (alu_op)
            3'b000: result = a + b;         // ADD
            3'b001: result = a - b;         // SUB
            3'b010: result = a & b;         // AND
            3'b011: result = a | b;         // OR
            3'b100: result = a ^ b;         // XOR
            3'b101: result = a + 32'd4;     // INC_A_4 (PC + 4)
            3'b110: result = a;             // PASS_A
            3'b111: result = b;             // PASS_B
            default: result = 32'b0;
        endcase
    end

endmodule





// Top-level microprogrammed datapath
// All components connected via a shared 32-bit bus with tri-state buffers
module datapath (
    input  wire        clk,
    input  wire        rst,

    // Control signals (from controller)
    input  wire        IRLd,
    input  wire [2:0]  RegSel,     // 000=PC, 001=RA, 010=rd, 011=rs1, 100=rs2
    input  wire        RegWr,
    input  wire        RegEn,
    input  wire        ALd,
    input  wire        BLd,
    input  wire [2:0]  ALUOp,      // 000=ADD, 001=SUB, 010=AND, 011=OR, 100=XOR, 101=INC_A_4, 110=PASS_A, 111=PASS_B
    input  wire        ALUEn,
    input  wire        MALd,
    input  wire        MemWr,
    input  wire        MemEn,
    input  wire [2:0]  ImmSel,     // 000=I, 001=S, 010=B, 011=U, 100=J
    input  wire        ImmEn,

    // Status signals (to controller)
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output wire        zero,
    output wire        busy
);

    // Shared 32-bit bus
    wire [31:0] bus;

    // Internal wires
    wire [31:0] ir_out;
    wire [31:0] a_out, b_out;
    wire [31:0] alu_result;
    wire [31:0] imm_out;
    wire [31:0] ma_out;
    wire [5:0]  reg_addr;
    wire [31:0] reg_rd_data;
    wire [31:0] mem_rd_data;

    // IR fields
    wire [4:0] ir_rd  = ir_out[11:7];
    wire [4:0] ir_rs1 = ir_out[19:15];
    wire [4:0] ir_rs2 = ir_out[24:20];

    // Status signals
    assign opcode = ir_out[6:0];
    assign funct3 = ir_out[14:12];
    assign funct7 = ir_out[31:25];
    assign zero   = (b_out == 32'b0);

    // Instruction Register
    register IR (
        .clk(clk), .rst(rst), .load(IRLd), .d(bus), .q(ir_out)
    );

    // Immediate Select + tri-state
    imm_select IMM_SELECT (
        .ir(ir_out), .imm_sel(ImmSel), .imm_out(imm_out)
    );
    tristate_buffer IMM_BUF (
        .en(ImmEn), .d(imm_out), .y(bus)
    );

    // A Register
    register A_REG (
        .clk(clk), .rst(rst), .load(ALd), .d(bus), .q(a_out)
    );

    // B Register
    register B_REG (
        .clk(clk), .rst(rst), .load(BLd), .d(bus), .q(b_out)
    );

    // ALU + tri-state
    alu ALU_UNIT (
        .a(a_out), .b(b_out), .alu_op(ALUOp), .result(alu_result)
    );
    tristate_buffer ALU_BUF (
        .en(ALUEn), .d(alu_result), .y(bus)
    );

    // Register address mux
    reg_addr_mux REG_ADDR_MUX (
        .reg_sel(RegSel), .ir_rd(ir_rd), .ir_rs1(ir_rs1), .ir_rs2(ir_rs2), .reg_addr(reg_addr)
    );

    // Register File + tri-state
    regfile REG_FILE (
        .clk(clk), .rst(rst), .addr(reg_addr), .wr_en(RegWr), .wr_data(bus), .rd_data(reg_rd_data)
    );
    tristate_buffer REG_BUF (
        .en(RegEn), .d(reg_rd_data), .y(bus)
    );

    // MA Register
    register MA_REG (
        .clk(clk), .rst(rst), .load(MALd), .d(bus), .q(ma_out)
    );

    // Memory + tri-state
    memory MEM (
        .clk(clk), .rst(rst), .addr(ma_out), .wr_en(MemWr), .wr_data(bus), .rd_data(mem_rd_data), .busy(busy)
    );
    tristate_buffer MEM_BUF (
        .en(MemEn), .d(mem_rd_data), .y(bus)
    );

endmodule





// Immediate extraction and sign-extension
// ImmSel: 000=I-type, 001=S-type, 010=B-type, 011=U-type, 100=J-type
module imm_select (
    input  wire [31:0] ir,
    input  wire [2:0]  imm_sel,
    output reg  [31:0] imm_out
);

    always @(*) begin
        case (imm_sel)
            3'b000: imm_out = {{20{ir[31]}}, ir[31:20]};                                // I-type
            3'b001: imm_out = {{20{ir[31]}}, ir[31:25], ir[11:7]};                       // S-type
            3'b010: imm_out = {{19{ir[31]}}, ir[31], ir[7], ir[30:25], ir[11:8], 1'b0};  // B-type
            3'b011: imm_out = {ir[31:12], 12'b0};                                        // U-type
            3'b100: imm_out = {{11{ir[31]}}, ir[31], ir[19:12], ir[20], ir[30:21], 1'b0};// J-type
            default: imm_out = 32'b0;
        endcase
    end

endmodule





// Memory: 1024 x 32-bit, word-aligned access
module memory (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] addr,
    input  wire        wr_en,
    input  wire [31:0] wr_data,
    output wire [31:0] rd_data,
    output wire        busy
);

    reg [31:0] mem [0:1023];
    wire [9:0] word_addr = addr[11:2]; // word-aligned
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 1024; i = i + 1)
                mem[i] <= 32'b0;
        end else if (wr_en) begin
            mem[word_addr] <= wr_data;
        end
    end

    assign rd_data = mem[word_addr];
    assign busy = 1'b0; // never busy in this simple model

endmodule





// Register address mux (RegSel)
// Selects register address: 000=PC, 001=RA, 010=rd, 011=rs1, 100=rs2
module reg_addr_mux (
    input  wire [2:0] reg_sel,
    input  wire [4:0] ir_rd,
    input  wire [4:0] ir_rs1,
    input  wire [4:0] ir_rs2,
    output reg  [5:0] reg_addr
);

    always @(*) begin
        case (reg_sel)
            3'b000: reg_addr = 6'd32;          // PC
            3'b001: reg_addr = 6'd1;           // RA (x1)
            3'b010: reg_addr = {1'b0, ir_rd};  // rd
            3'b011: reg_addr = {1'b0, ir_rs1}; // rs1
            3'b100: reg_addr = {1'b0, ir_rs2}; // rs2
            default: reg_addr = 6'd0;
        endcase
    end

endmodule





// Register File: 32 GPRs + PC (at index 32)
// R0 is hardwired to zero
module regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire [5:0]  addr,       // 0-31 = GPRs, 32 = PC
    input  wire        wr_en,
    input  wire [31:0] wr_data,
    output wire [31:0] rd_data
);

    reg [31:0] registers [0:32];
    integer i;

    // Synchronous write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i <= 32; i = i + 1)
                registers[i] <= 32'b0;
        end else if (wr_en && addr != 6'd0) begin
            registers[addr] <= wr_data;
        end
    end

    // Asynchronous read, R0 always returns 0
    assign rd_data = (addr == 6'd0) ? 32'b0 : registers[addr];

endmodule





// 32-bit Register with load enable
module register (
    input  wire        clk,
    input  wire        rst,
    input  wire        load,
    input  wire [31:0] d,
    output reg  [31:0] q
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            q <= 32'b0;
        else if (load)
            q <= d;
    end

endmodule





// Tri-state buffer for driving the shared bus
module tristate_buffer (
    input  wire        en,
    input  wire [31:0] d,
    output wire [31:0] y
);

    assign y = en ? d : 32'bz;

endmodule