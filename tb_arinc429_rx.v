`timescale 1ns/1ps
// Self-checking testbench for arinc429_rx.
// Builds ARINC 429 words, sends them bit by bit (bit 1 first), and checks every output field.

module tb_arinc429_rx;

    reg clk = 0, rst_n = 0, bit_valid = 0, bit_in = 0, gap = 0;
    wire        word_ready, parity_ok, length_err;
    wire [7:0]  label;
    wire [1:0]  sdi, ssm;
    wire [18:0] data;

    arinc429_rx dut (.clk(clk), .rst_n(rst_n), .bit_valid(bit_valid), .bit_in(bit_in),
                     .gap(gap), .word_ready(word_ready), .label(label), .sdi(sdi),
                     .data(data), .ssm(ssm), .parity_ok(parity_ok), .length_err(length_err));

    always #5 clk = ~clk;   // 100 MHz system clock

    integer pass = 0, fail = 0;

    function [7:0] rev8(input [7:0] x);
        integer i;
        for (i = 0; i < 8; i = i + 1) rev8[i] = x[7 - i];
    endfunction

    // Build the 32-bit word in spec order (index 0 = bit 1) and set odd parity.
    function [31:0] build(input [7:0] lbl, input [1:0] s, input [18:0] d, input [1:0] m);
        reg [31:0] w;
        begin
            w[7:0]   = rev8(lbl);       // label goes out MSB first
            w[9:8]   = s;
            w[28:10] = d;
            w[30:29] = m;
            w[31]    = ~^w[30:0];       // makes the total number of 1s odd
            build    = w;
        end
    endfunction

    task send_bits(input [31:0] w, input integer nbits);
        integer i;
        for (i = 0; i < nbits; i = i + 1) begin
            @(negedge clk); bit_valid = 1; bit_in = w[i];
            @(negedge clk); bit_valid = 0;
            repeat (3) @(negedge clk);           // idle cycles between bits
        end
    endtask

    task send_gap;
        begin
            @(negedge clk); gap = 1;
            @(negedge clk); gap = 0;
        end
    endtask

    task check_word(input [7:0] lbl, input [1:0] s, input [18:0] d, input [1:0] m,
                    input corrupt, input [255:0] name);
        reg [31:0] w;
        begin
            w = build(lbl, s, d, m);
            if (corrupt) w[15] = ~w[15];         // flip one data bit -> parity must fail
            fork
                send_bits(w, 32);
                begin
                    @(posedge word_ready); #1;
                    // A corrupted word only needs to be flagged; its data is wrong on purpose.
                    if (corrupt ? (parity_ok == 0)
                                : (label == lbl && sdi == s && data == d && ssm == m && parity_ok == 1)) begin
                        pass = pass + 1;
                        $display("PASS  %0s  label=%o sdi=%b data=%h ssm=%b parity_ok=%b",
                                 name, label, sdi, data, ssm, parity_ok);
                    end else begin
                        fail = fail + 1;
                        $display("FAIL  %0s  got label=%o sdi=%b data=%h ssm=%b parity_ok=%b",
                                 name, label, sdi, data, ssm, parity_ok);
                    end
                end
            join
            send_gap;
        end
    endtask

    initial begin
        $dumpfile("arinc429_rx.vcd");
        $dumpvars(0, tb_arinc429_rx);
        repeat (3) @(negedge clk); rst_n = 1;

        check_word(8'o203, 2'b00, 19'h1A2B3, 2'b11, 0, "label 203 normal word");
        check_word(8'o310, 2'b01, 19'h00000, 2'b00, 0, "all-zero data");
        check_word(8'o377, 2'b11, 19'h7FFFF, 2'b11, 0, "all-ones fields");
        check_word(8'o001, 2'b10, 19'h55555, 2'b01, 0, "alternating data");
        check_word(8'o203, 2'b00, 19'h1A2B3, 2'b11, 1, "corrupted bit -> parity error");

        // Truncated word: 20 bits then a gap. Must raise length_err and produce no word.
        fork
            begin send_bits(build(8'o100, 0, 19'h12345, 0), 20); send_gap; end
            begin
                @(posedge length_err); #1;
                pass = pass + 1; $display("PASS  truncated word -> length_err");
            end
        join

        // Receiver must still work after an error.
        check_word(8'o150, 2'b01, 19'h0ABCD, 2'b10, 0, "recovery after error");

        $display("\n%0d passed, %0d failed", pass, fail);
        $finish;
    end

    initial begin
        #2_000_000 $display("TIMEOUT"); $finish;
    end

endmodule
