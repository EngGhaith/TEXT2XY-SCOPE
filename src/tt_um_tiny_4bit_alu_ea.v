// tt_um_tiny_4bit_alu_ea.v
// 4-bit ALU with 8x4-bit register file
// Ports: clk, rst_n, ui_in[7:0] (B[7:4], A[3:0]), uio_in[7:0] (opcode in uio_in[3:0]), uo_out[7:0]
// uo_out: [7]=ZERO, [6]=SIGN, [5]=OVERFLOW, [4]=CARRY, [3:0]=result

module tt_um_tiny_4bit_alu (
    input  wire        clk,
    input  wire        rst_n,    // active low
	input  wire 	   ena,
    input  wire [7:0]  ui_in,    // {B[7:4], A[3:0]}
    input  wire [7:0]  uio_in,      // opcode in uio_in[3:0]
    output reg  [7:0]  uo_out,
	output reg  [7:0]  uio_oe,
	output reg  [7:0]  uio_out
);
	// unused bidirectional pads
	assign uio_out = 8'h00;
	assign uio_oe = 8'h00;

    // operands
    wire [3:0] A = ui_in[3:0];
    wire [3:0] B = ui_in[7:4];
    wire [3:0] opcode = uio_in[3:0];

    // internal
    reg  [4:0] result_comb;    // combinational 5-bit result (bit4 = carry)
    reg  [3:0] result_reg;     // registered low 4 bits
    reg        flag_zero;
    reg        flag_sign;
    reg        flag_overflow;
    reg        flag_carry;

    // register file: 8 x 4-bit
    reg [3:0] regfile [0:7];
    wire [2:0] reg_addr = B[2:0];
    wire [3:0] reg_read_data = regfile[reg_addr];

    // reg write request (generated combinationally, committed on clock)
    reg        reg_write_req;
    reg  [3:0] reg_write_data;

    // helpers
    wire [4:0] a5  = {1'b0, A};
    wire [4:0] b5  = {1'b0, B};
    wire [4:0] nb5 = ~b5;
    localparam [4:0] ONE5 = 5'b00001;

    // combinational ALU core
    always @(*) begin
        // defaults
        result_comb = 5'b0;
        reg_write_req = 1'b0;
        reg_write_data = 4'b0;

        case (opcode)
            4'b0000: begin // ADD
                result_comb = a5 + b5;
            end
            4'b0001: begin // SUB (A - B) as A + (~B + 1)
                result_comb = a5 + nb5 + ONE5;
            end
            4'b0010: begin // AND
                result_comb[3:0] = A & B;
                result_comb[4]   = 1'b0;
            end
            4'b0011: begin // OR
                result_comb[3:0] = A | B;
                result_comb[4]   = 1'b0;
            end
            4'b0100: begin // XOR
                result_comb[3:0] = A ^ B;
                result_comb[4]   = 1'b0;
            end
            4'b0101: begin // SHL logical by low 2 bits of B
                result_comb[3:0] = A << B[1:0];
                result_comb[4]   = 1'b0;
            end
            4'b0110: begin // SHR logical by low 2 bits of B
                result_comb[3:0] = A >> B[1:0];
                result_comb[4]   = 1'b0;
            end
            4'b0111: begin // PASS_B
                result_comb[3:0] = B;
                result_comb[4]   = 1'b0;
            end

            // Register-file related ops
            4'b1000: begin // REG_WRITE: schedule write A -> reg[addr]
                result_comb = 5'b0;
                reg_write_req  = 1'b1;
                reg_write_data = A;
            end
            4'b1001: begin // REG_READ: present reg[addr] as result
                result_comb[3:0] = reg_read_data;
                result_comb[4]   = 1'b0;
                reg_write_req = 1'b0;
            end
            4'b1010: begin // ADD_REG: A + reg[addr]
                result_comb = a5 + {1'b0, reg_read_data};
                reg_write_req = 1'b0;
            end
            4'b1011: begin // SUB_REG: A - reg[addr]
                result_comb = a5 + (~{1'b0, reg_read_data}) + ONE5;
                reg_write_req = 1'b0;
            end

            default: begin
                result_comb = 5'b0;
                reg_write_req = 1'b0;
            end
        endcase
    end

    // sequential: register result, flags and commit reg writes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg    <= 4'b0000;
            flag_zero     <= 1'b1;
            flag_sign     <= 1'b0;
            flag_overflow <= 1'b0;
            flag_carry    <= 1'b0;
            uo_out        <= 8'b0;
            // reset regfile (optional)
            regfile[0] <= 4'b0000;
            regfile[1] <= 4'b0000;
            regfile[2] <= 4'b0000;
            regfile[3] <= 4'b0000;
            regfile[4] <= 4'b0000;
            regfile[5] <= 4'b0000;
            regfile[6] <= 4'b0000;
            regfile[7] <= 4'b0000;
        end else begin
            // register low 4 bits
            result_reg <= result_comb[3:0];

            // ZERO
            if (result_comb[3:0] == 4'b0000)
                flag_zero <= 1'b1;
            else
                flag_zero <= 1'b0;

            // SIGN = MSB of 4-bit result
            flag_sign <= result_comb[3];

            // CARRY = bit 4 of result_comb
            flag_carry <= result_comb[4];

            // OVERFLOW detection
            // For ADD (opcode 0000) and SUB (0001)
            // and also for ADD_REG (1010) / SUB_REG (1011) use reg operand
            if (opcode == 4'b0000) begin
                // ADD: overflow if A_sign == B_sign && R_sign != A_sign
                if ((A[3] == B[3]) && (result_comb[3] != A[3]))
                    flag_overflow <= 1'b1;
                else
                    flag_overflow <= 1'b0;
            end else if (opcode == 4'b0001) begin
                // SUB: overflow if A_sign != B_sign && R_sign != A_sign
                if ((A[3] != B[3]) && (result_comb[3] != A[3]))
                    flag_overflow <= 1'b1;
                else
                    flag_overflow <= 1'b0;
            end else if (opcode == 4'b1010) begin
                // ADD_REG: use signed(reg)
                if ((A[3] == reg_read_data[3]) && (result_comb[3] != A[3]))
                    flag_overflow <= 1'b1;
                else
                    flag_overflow <= 1'b0;
            end else if (opcode == 4'b1011) begin
                // SUB_REG
                if ((A[3] != reg_read_data[3]) && (result_comb[3] != A[3]))
                    flag_overflow <= 1'b1;
                else
                    flag_overflow <= 1'b0;
            end else begin
                flag_overflow <= 1'b0;
            end

            // commit register write if requested
            if (reg_write_req) begin
                regfile[reg_addr] <= reg_write_data;
            end

            // drive output
            uo_out <= ena ? {flag_zero, flag_sign, flag_overflow, flag_carry, result_reg}
					: 8'b0;
        end
    end

endmodule
