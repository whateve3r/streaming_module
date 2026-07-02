`timescale 1ns/100ps

module top (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] x_data,
    input  logic       x_valid,
    input  logic [7:0] thr_data,
    input  logic       thr_valid,
    input  logic       y_ready,
    output logic       x_ready,
    output logic       thr_ready,
    output logic [7:0] y_data,
    output logic       y_valid
);

    logic [7:0] reg_x_data, reg_thr_data;
    logic       reg_x_valid, reg_thr_valid;

    logic [7:0] reg_y_data;
    logic       reg_y_valid;

    logic pair_valid;   // есть данные в обоих регистрах
    logic out_ready;    // можно передавать результат приемнику
    logic consume;      // поглощаем (передаем в умножение/сложение) пару в этом такте

    assign pair_valid = reg_x_valid && reg_thr_valid;
    assign out_ready  = !reg_y_valid || y_ready;      
    assign consume    = pair_valid && out_ready;

   
    assign x_ready   = !reg_x_valid   || consume;
    assign thr_ready = !reg_thr_valid || consume;

    
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            reg_x_valid <= 1'b0;
        else if (x_valid && x_ready) begin
            reg_x_data  <= x_data;
            reg_x_valid <= 1'b1;
        end
        else if (consume)
            reg_x_valid <= 1'b0;
    end

    
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            reg_thr_valid <= 1'b0;
        else if (thr_valid && thr_ready) begin
            reg_thr_data  <= thr_data;
            reg_thr_valid <= 1'b1;
        end
        else if (consume)
            reg_thr_valid <= 1'b0;
    end

    
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            reg_y_valid <= 1'b0;
        else if (consume) begin
            reg_y_data  <= (reg_x_data > reg_thr_data) ? (reg_x_data * 2)
                                                       : (reg_x_data + 1);
            reg_y_valid <= 1'b1;
        end
        else if (y_ready)          
            reg_y_valid <= 1'b0;
    end

    assign y_data  = reg_y_data;
    assign y_valid = reg_y_valid;

endmodule