`timescale 1ns/100ps

module top (
    input logic clk,
    input logic rst,

    input logic [7:0] x_data,
    input logic x_valid,

    input logic [7:0] thr_data,
    input logic thr_valid,

    input logic y_ready,

    output logic x_ready, thr_ready,

    output logic [7:0] y_data,
    output logic y_valid     
);
    logic [7:0] reg_x_data,    reg_thr_data;
    logic       reg_x_valid,   reg_thr_valid; // есть ли данные в регистре

    logic [7:0] reg_mul_data,  reg_sum_data; 
    logic       reg_mul_valid, reg_sum_valid; // есть ли данные в регистре

    logic       mul_valid,     sum_valid;
    logic       mul_ready,     sum_ready;

    logic       mux_mul_ready, mux_sum_ready;

    logic       sel,           reg_sel;
    logic       comparison_valid;

    logic       branch_ready;

    assign x_ready   = !reg_x_valid   || (reg_x_valid && reg_thr_valid && branch_ready);
    assign thr_ready = !reg_thr_valid || (reg_x_valid && reg_thr_valid && branch_ready);

    always_ff @(posedge clk or posedge rst)
    begin
        if (rst)
            reg_x_valid <= 0;
        
        else if (x_valid && x_ready) 
        begin
            reg_x_data <= x_data;
            reg_x_valid <= 1;
        end

        else if (reg_x_valid && reg_thr_valid && branch_ready)
            reg_x_valid <= 0;
    end

        always_ff @(posedge clk or posedge rst)
    begin
        if (rst)
            reg_thr_valid <= 0;
        
        else if (thr_valid && thr_ready) 
        begin
            reg_thr_data <= thr_data;
            reg_thr_valid <= 1;
        end
        
        else if (reg_thr_valid && reg_x_valid && branch_ready)
            reg_thr_valid <= 0;
    end

    assign comparison_valid = reg_x_valid && reg_thr_valid;
    assign sel = reg_x_data > reg_thr_data;

    assign mul_valid = comparison_valid && sel;
    assign sum_valid = comparison_valid && !sel;

    assign branch_ready = sel ? mul_ready : sum_ready;

    always_ff @(posedge clk or posedge rst)
    begin
        if (rst)
            reg_mul_valid <= 0;
        
        else if (mul_valid && mul_ready) 
        begin
            reg_mul_data <= reg_x_data * 2;
            reg_mul_valid <= 1;
        end
        
        else if (reg_mul_valid && mux_mul_ready)
            reg_mul_valid <= 0;
    end

    always_ff @(posedge clk or posedge rst)
    begin
        if (rst)
            reg_sum_valid <= 0;

        else if (sum_valid && sum_ready) 
        begin
            reg_sum_data <= reg_x_data + 1;
            reg_sum_valid <= 1;
        end

        else if (reg_sum_valid && mux_sum_ready)
            reg_sum_valid <= 0; 
    end
    
    assign mul_ready = !reg_mul_valid || mux_mul_ready;
    assign sum_ready = !reg_sum_valid || mux_sum_ready;

    always_ff @(posedge clk or posedge rst)
    begin
        if (rst)
            reg_sel <= 0;

        else if (comparison_valid && branch_ready)
            reg_sel <= sel;
    end

    assign mux_sum_ready = y_ready && !reg_sel;
    assign mux_mul_ready = y_ready && reg_sel;

    assign y_data  = reg_sel ? reg_mul_data : reg_sum_data;
    assign y_valid = reg_sel ? reg_mul_valid : reg_sum_valid;
endmodule