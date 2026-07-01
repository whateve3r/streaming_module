`timescale 1ns/100ps

module testbench;

    logic [7:0] x_data, thr_data;
    logic       x_valid, thr_valid, y_ready;
    logic       x_ready, thr_ready, y_valid;
    logic [7:0] y_data;

    top dut (
        .x_data   (x_data),
        .x_valid  (x_valid),
        .thr_data (thr_data),
        .thr_valid(thr_valid),
        .y_ready  (y_ready),
        .x_ready  (x_ready),
        .thr_ready(thr_ready),
        .y_data   (y_data),
        .y_valid  (y_valid)
    );

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, testbench);
    end


    initial begin

        // test 1
        x_data=10; thr_data=8; x_valid=1; thr_valid=1; y_ready=1;
        #10;
        assert(y_data  == 20) 
        assert(y_valid == 1)   
        assert(x_ready == 1)   


        // test 2
        x_data=3; thr_data=5;
        #10;
        assert(y_data  == 4)   


        // test 3
        x_valid=0;
        #10;
        assert(y_valid == 0)   


        // test 4
        x_valid=1; y_ready=0;
        #10;
        assert(x_ready   == 0) 
        assert(thr_ready == 0)

        $display("Finished");
        $finish;
    end

endmodule