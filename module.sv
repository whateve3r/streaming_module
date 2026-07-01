`timescale 1ns/100ps

module top (
    input logic [7:0] x_data,
    input logic x_valid,

    input logic [7:0] thr_data,
    input logic thr_valid,

    input y_ready,

    output x_ready, thr_ready,

    output logic [7:0] y_data,
    output logic y_valid     
);

    assign x_ready   = y_ready;
    assign thr_ready = y_ready;

    assign y_valid = x_valid && thr_valid;

    assign y_data = (x_data > thr_data) ? x_data * 2 : x_data + 1;
endmodule