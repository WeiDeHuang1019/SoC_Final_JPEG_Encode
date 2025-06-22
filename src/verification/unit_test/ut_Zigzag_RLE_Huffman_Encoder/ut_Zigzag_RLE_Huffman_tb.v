`timescale 1ns / 1ps
module testbench;

    // �ɯߩM���m�T��
    reg clk;
    reg rst;
    reg start_encoding;
    reg [511:0] pixel_block_flat; // 64 * 8 = 512 bits

    // ��X�T��
    wire [15:0] final_huff_code;
    wire [3:0]  final_huff_len;
    wire [7:0]  final_val_bits;
    wire        final_out_valid;
    wire        encoding_done;

    // ��Ҥ� DUT
    jpeg_core_encoder u_jpeg_encoder (
        .clk             (clk),
        .rst             (rst),
        .start_encoding  (start_encoding),
        .pixel_block_flat(pixel_block_flat),
        .final_huff_code (final_huff_code),
        .final_huff_len  (final_huff_len),
        .final_val_bits  (final_val_bits),
        .final_out_valid (final_out_valid),
        .encoding_done   (encoding_done)
    );

    // �ɯ߲��;�
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz �ɯ�
    end

    // ���լy�{
    initial begin
        $display("===== Simulation Start at %0t ns =====", $time);

        // ��l���A
        rst = 1;
        start_encoding = 0;
        pixel_block_flat = 512'b0;

        // ���ո�Ƴ]�w
        pixel_block_flat[7:0]    = 8'd10;   // DC
        pixel_block_flat[15:8]   = 8'd5;    // AC1
        pixel_block_flat[23:16]  = 8'hFE;   // AC2 = -2
        pixel_block_flat[31:24]  = 8'd0;
        pixel_block_flat[39:32]  = 8'd1;
        pixel_block_flat[47:40]  = 8'd0;
        pixel_block_flat[55:48]  = 8'd0;
        pixel_block_flat[63:56]  = 8'd0;

        // Reset �O�� 20ns
        #20 rst = 0;

        // �Ұʽs�X
        #20 start_encoding = 1;
        #10 start_encoding = 0;

        // ���ݳB�z����
        #1000;

        $display("===== Simulation Finished at %0t ns =====", $time);
        $finish;
    end

    // ��ܿ�X�ʱ�
    initial begin
        $monitor("T=%0t | state=%0d | AC_idx=%0d | ZeroRun=%0d | val=%0d | size=%0d | key=%h | HuffCode=%h | len=%d | val_bits=%h | valid=%b | done=%b",
            $time,
            u_jpeg_encoder.current_state,
            u_jpeg_encoder.ac_idx,
            u_jpeg_encoder.zero_run_count,
            u_jpeg_encoder.current_val,
            u_jpeg_encoder.current_size,
            u_jpeg_encoder.huffman_key_comb,
            final_huff_code,
            final_huff_len,
            final_val_bits,
            final_out_valid,
            encoding_done
        );
    end

    // �i��G�i�ο�X�]�}�ҥi�� GTKWave �[��^
    initial begin
        $dumpfile("jpeg_encoder_wave.vcd");
        $dumpvars(0, testbench);
    end

endmodule
