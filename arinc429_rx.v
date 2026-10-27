`timescale 1ns/1ps
// ARINC 429 word receiver
//
// Assumes an external line receiver has already converted the bipolar
// return-to-zero bus signal into a recovered bit stream:
//   bit_valid : 1-cycle strobe, one per received bit
//   bit_in    : the bit value
//   gap       : 1-cycle strobe when the inter-word gap (>= 4 bit times of NULL) is seen
//
// ARINC 429 sends bit 1 first. The label (bits 1-8) is sent MSB first, while the
// rest of the word is LSB first, so the label must be bit-reversed after reception.
//
// Word layout (bit numbers as in the spec):
//   1-8   label (octal)    9-10 SDI    11-29 data    30-31 SSM    32 parity (odd)

module arinc429_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bit_valid,
    input  wire        bit_in,
    input  wire        gap,
    output reg         word_ready,   // 1-cycle pulse when a full word has arrived
    output reg  [7:0]  label,
    output reg  [1:0]  sdi,
    output reg  [18:0] data,
    output reg  [1:0]  ssm,
    output reg         parity_ok,
    output reg         length_err    // gap arrived before 32 bits: word discarded
);

    reg [31:0] shreg;      // shreg[0] holds spec bit 1 once the word is complete
    reg [5:0]  count;

    // Bit-reverse the label: spec bit 1 is the label MSB.
    function [7:0] rev8(input [7:0] x);
        integer i;
        for (i = 0; i < 8; i = i + 1) rev8[i] = x[7 - i];
    endfunction

    wire [31:0] next_word = {bit_in, shreg[31:1]};   // shift in from the top

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shreg      <= 32'd0;
            count      <= 6'd0;
            word_ready <= 1'b0;
            label      <= 8'd0;
            sdi        <= 2'd0;
            data       <= 19'd0;
            ssm        <= 2'd0;
            parity_ok  <= 1'b0;
            length_err <= 1'b0;
        end else begin
            word_ready <= 1'b0;
            length_err <= 1'b0;

            if (gap) begin
                // A gap mid-word means bits were lost: drop the partial word.
                if (count != 0) length_err <= 1'b1;
                count <= 6'd0;
            end else if (bit_valid) begin
                shreg <= next_word;
                if (count == 6'd31) begin
                    count      <= 6'd0;
                    word_ready <= 1'b1;
                    label      <= rev8(next_word[7:0]);
                    sdi        <= next_word[9:8];
                    data       <= next_word[28:10];
                    ssm        <= next_word[30:29];
                    parity_ok  <= ^next_word;          // odd parity: XOR of all 32 bits = 1
                end else begin
                    count <= count + 6'd1;
                end
            end
        end
    end

endmodule
