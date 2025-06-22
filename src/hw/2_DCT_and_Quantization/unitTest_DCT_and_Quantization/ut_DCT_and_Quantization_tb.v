`timescale 1ns / 1ps

module DCT_with_Quantizer_tb;

    reg clk;
    reg rst;
    reg enable1;
    wire [511:0] quantized_flat;
    wire enable2;

    DCT_with_Quantizer dut (
        .Clock(clk),
        .reset(rst),
        .enable1(enable1),
        .quantized_flat(quantized_flat),
        .enable2(enable2)
    );

    integer idx;
    reg signed [7:0] temp_q;
    integer timeout;

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("=== Start Testbench ===");
        rst = 1;
        enable1 = 0;
        timeout = 0;

        #20;
        rst = 0;
        #10;
        enable1 = 1;

        while (enable2 == 0 && timeout < 5000) begin
            #10;
            timeout = timeout + 1;
        end

        if (enable2 == 0) begin
            $display("[ERROR] Timeout!");
            $finish;
        end

        #10;
        $display("=== Quantized Output ===");
        for (idx = 0; idx < 64; idx = idx + 1) begin
            temp_q = quantized_flat[(idx*8) +: 8];
            $display("Q[%0d] = %0d", idx, temp_q);
        end

        $display("=== Testbench Done ===");
        $finish;
    end

endmodule
