// tb.v
`timescale 1ns/1ps
module tt_um_tiny_4bit_alu_tb;

    reg clk;
    reg rst_n;
    reg [7:0] ui_in;
    reg [7:0] uio;
    wire [7:0] uo_out;

    // instantiate DUT
    tt_um_tiny_4bit_alu dut (
        .clk(clk),
        .rst_n(rst_n),
        .ui_in(ui_in),
        .uio(uio),
        .uo_out(uo_out)
    );

    // clock generation (50 MHz -> 20 ns period)
    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        $dumpfile("tt_um_tiny_4bit_alu_tb.vcd");
        $dumpvars(0, tt_um_tiny_4bit_alu_tb);

        // reset
        rst_n = 0;
        ui_in = 8'h00;
        uio   = 8'h00;
        #100;
        rst_n = 1;
        #100;

        // 1) REG_WRITE: write value 7 into reg[3]
        // ui_in = {B, A} = {3, 7}
        ui_in = {4'd3, 4'd7};
        uio[3:0] = 4'b1000; // REG_WRITE
        #40; // wait two clock edges (20ns each) so write commits on rising edge
        #40;

        // 2) REG_READ: read reg[3]
        ui_in = {4'd3, 4'd0};
        uio[3:0] = 4'b1001; // REG_READ
        #40; #40;
        if (uo_out[3:0] !== 4'd7) begin
            $display("ERROR: REG_READ expected 7, got %0d (uo_out=%b)", uo_out[3:0], uo_out);
            $fatal;
        end else $display("REG_READ OK: got %0d", uo_out[3:0]);

        // 3) ADD_REG: A=2 + reg[3]=7 => 9
        ui_in = {4'd3, 4'd2};
        uio[3:0] = 4'b1010; // ADD_REG
        #40; #40;
        if (uo_out[3:0] !== 4'd9) begin
            $display("ERROR: ADD_REG expected 9, got %0d (uo_out=%b)", uo_out[3:0], uo_out);
            $fatal;
        end else $display("ADD_REG OK: got %0d", uo_out[3:0]);

        // 4) SUB_REG: A=2 - reg[3]=7 => -5 => 0b1011 (11)
        ui_in = {4'd3, 4'd2};
        uio[3:0] = 4'b1011; // SUB_REG
        #40; #40;
        if (uo_out[3:0] !== 4'b1011) begin
            $display("ERROR: SUB_REG expected 4'b1011, got %b (uo_out=%b)", uo_out[3:0], uo_out);
            $fatal;
        end else $display("SUB_REG OK: got %b", uo_out[3:0]);

        // 5) Basic ADD: A=3,B=5 -> 3+5=8 => 4'b1000; expect overflow flag = 1 (signed overflow)
        ui_in = {4'd5, 4'd3};
        uio[3:0] = 4'b0000; // ADD
        #40; #40;
        if (uo_out[3:0] !== 4'b1000) begin
            $display("ERROR: ADD expected 4'b1000, got %b (uo_out=%b)", uo_out[3:0], uo_out);
            $fatal;
        end else begin
            $display("ADD OK: result=%b flags Z N V C = %b %b %b %b", uo_out[3:0], uo_out[7], uo_out[6], uo_out[5], uo_out[4]);
        end

        // 6) PASS_B: B=9,A=1
        ui_in = {4'd9, 4'd1};
        uio[3:0] = 4'b0111; // PASS_B
        #40; #40;
        if (uo_out[3:0] !== 4'd9) begin
            $display("ERROR: PASS_B expected 9, got %0d (uo_out=%b)", uo_out[3:0], uo_out);
            $fatal;
        end else $display("PASS_B OK: got %0d", uo_out[3:0]);

        $display("All tests passed.");
        #100;
        $finish;
    end

endmodule
