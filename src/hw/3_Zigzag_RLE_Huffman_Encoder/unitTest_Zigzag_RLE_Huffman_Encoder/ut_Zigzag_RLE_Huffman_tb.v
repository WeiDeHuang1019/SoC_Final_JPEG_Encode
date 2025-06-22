`timescale 1ns / 1ps
module testbench;

    // 時脈和重置訊號
    reg clk;
    reg rst;
    reg start_encoding;
    reg [511:0] pixel_block_flat; // 64 * 8 = 512 bits

    // 輸出訊號
    wire [15:0] final_huff_code;
    wire [3:0]  final_huff_len;
    wire [7:0]  final_val_bits;
    wire        final_out_valid;
    wire        encoding_done;

    // 實例化 DUT
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

    // 時脈產生器
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz 時脈
    end

    // 測試流程
    initial begin
        $display("===== Simulation Start at %0t ns =====", $time);

        // 初始狀態
        rst = 1;
        start_encoding = 0;
        pixel_block_flat = 512'b0;

        // 測試資料設定
        pixel_block_flat[7:0]    = 8'd10;   // DC
        pixel_block_flat[15:8]   = 8'd5;    // AC1
        pixel_block_flat[23:16]  = 8'hFE;   // AC2 = -2
        pixel_block_flat[31:24]  = 8'd0;
        pixel_block_flat[39:32]  = 8'd1;
        pixel_block_flat[47:40]  = 8'd0;
        pixel_block_flat[55:48]  = 8'd0;
        pixel_block_flat[63:56]  = 8'd0;

        // Reset 保持 20ns
        #20 rst = 0;

        // 啟動編碼
        #20 start_encoding = 1;
        #10 start_encoding = 0;

        // 等待處理完成
        #1000;

        $display("===== Simulation Finished at %0t ns =====", $time);
        $finish;
    end

    // 顯示輸出監控
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

    // 可選：波形輸出（開啟可用 GTKWave 觀察）
    initial begin
        $dumpfile("jpeg_encoder_wave.vcd");
        $dumpvars(0, testbench);
    end

endmodule
