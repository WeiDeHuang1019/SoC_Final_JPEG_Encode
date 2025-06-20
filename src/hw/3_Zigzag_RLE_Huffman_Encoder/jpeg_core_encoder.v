`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2025/06/20 22:52:23
// Design Name:
// Module Name: jpeg_core_encoder
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


// ============================================================================
// jpeg_core_encoder.v
// 整合了 Zigzag, RLE, Huffman 功能的 JPEG 核心編碼器
// 特點：
// 1. 單一狀態機控制，邏輯集中。
// 2. 無需中間的 Zigzag 緩衝區，節省大量暫存器資源。
// 3. 流式處理，每個週期處理一個 AC 係數，效率高。
// ============================================================================

module jpeg_core_encoder (
    input wire clk,             // 時脈訊號
    input wire rst,             // 非同步重置訊號 (高電位有效)
    input wire start_encoding,  // 啟動整個編碼流程的訊號
    input wire [511:0] pixel_block_flat, // 64 個 8-bit 輸入數據塊 (打包陣列)

    output reg [15:0] final_huff_code, // 最終輸出的 Huffman 編碼
    output reg [3:0]  final_huff_len,  // 最終 Huffman 編碼的長度
    output reg [7:0]  final_val_bits,  // 最終的數值位元 (非 Huffman 編碼部分)
    output reg        final_out_valid, // 最終輸出有效訊號
    output reg        encoding_done    // 整個區塊編碼完成訊號
);

    // ================================================================
    // 內部資源定義 (原 Zigzag, Huffman 模組的核心部分)
    // ================================================================

    // --- Zigzag 查找表 (ROM) ---
    // 此表定義了 Zigzag 掃描的順序
    reg [5:0] zigzag_table [0:63];
   
    // 將 'i' 從 initial 塊內部移到模組頂層聲明
    reg [7:0] i;

    initial begin
        zigzag_table[ 0]= 0; zigzag_table[ 1]= 1; zigzag_table[ 2]= 8; zigzag_table[ 3]=16;
        zigzag_table[ 4]= 9; zigzag_table[ 5]= 2; zigzag_table[ 6]= 3; zigzag_table[ 7]=10;
        zigzag_table[ 8]=17; zigzag_table[ 9]=24; zigzag_table[10]=32; zigzag_table[11]=25;
        zigzag_table[12]=18; zigzag_table[13]=11; zigzag_table[14]= 4; zigzag_table[15]= 5;
        zigzag_table[16]=12; zigzag_table[17]=19; zigzag_table[18]=26; zigzag_table[19]=33;
        zigzag_table[20]=40; zigzag_table[21]=48; zigzag_table[22]=41; zigzag_table[23]=34;
        zigzag_table[24]=27; zigzag_table[25]=20; zigzag_table[26]=13; zigzag_table[27]= 6;
        zigzag_table[28]= 7; zigzag_table[29]=14; zigzag_table[30]=21; zigzag_table[31]=28;
        zigzag_table[32]=35; zigzag_table[33]=42; zigzag_table[34]=49; zigzag_table[35]=56;
        zigzag_table[36]=57; zigzag_table[37]=50; zigzag_table[38]=43; zigzag_table[39]=36;
        zigzag_table[40]=29; zigzag_table[41]=22; zigzag_table[42]=15; zigzag_table[43]=23;
        zigzag_table[44]=30; zigzag_table[45]=37; zigzag_table[46]=44; zigzag_table[47]=51;
        zigzag_table[48]=58; zigzag_table[49]=59; zigzag_table[50]=52; zigzag_table[51]=45;
        zigzag_table[52]=38; zigzag_table[53]=31; zigzag_table[54]=39; zigzag_table[55]=46;
        zigzag_table[56]=53; zigzag_table[57]=60; zigzag_table[58]=61; zigzag_table[59]=54;
        zigzag_table[60]=47; zigzag_table[61]=55; zigzag_table[62]=62; zigzag_table[63]=63;
    end

    // --- Huffman 表格 (ROM) ---
    reg [15:0] huff_table [0:255];
    reg [3:0]  huff_table_len [0:255];

    // --- Huffman Size 計算函數 ---
    function [3:0] size;
        input [7:0] val;
        // 修正: 為函數內部塊命名以允許局部變量聲明
        begin : size_calc_block
            reg [7:0] abs_val; // 用於存放 val 的絕對值

            abs_val = val[7] ? (~val + 1) : val;
            case (abs_val)
                0:                 size = 0;
                1:                 size = 1;
                2, 3:              size = 2;
                4, 5, 6, 7:        size = 3;
                default: begin
                    if (abs_val < 16)      size = 4;
                    else if (abs_val < 32) size = 5;
                    else if (abs_val < 64) size = 6;
                    else if (abs_val < 128)size = 7;
                    else                   size = 8;
                end
            endcase
        end
    endfunction

    // --- Huffman 表格初始化 ---
    initial begin
        // 'i' 已經在模組頂層聲明
        for (i = 0; i < 256; i = i + 1) begin
            huff_table[i] = 16'h0000;
            huff_table_len[i] = 4'h0;
        end
        // (run, size) -> key = {run[3:0], size[3:0]}
        // EOB (End of Block) - (0,0) key=8'h00
        huff_table[8'h00] = 16'b0000000000001010; huff_table_len[8'h00] = 4;
        // ZRL (Zero Run Length) - (15,0) key=8'hF0
        huff_table[8'hF0] = 16'b0000011111110010; huff_table_len[8'hF0] = 11;
       
        // (DC or AC Huffman Table for Luminance - 範例值)
        huff_table[8'h01] = 16'b0000000000000000; huff_table_len[8'h01] = 2; // (0,1) -> 00
        huff_table[8'h02] = 16'b0000000000000010; huff_table_len[8'h02] = 3; // (0,2) -> 010
        huff_table[8'h03] = 16'b0000000000000011; huff_table_len[8'h03] = 3; // (0,3) -> 011
        huff_table[8'h04] = 16'b0000000000000100; huff_table_len[8'h04] = 3; // (0,4) -> 100
        huff_table[8'h05] = 16'b0000000000000101; huff_table_len[8'h05] = 3; // (0,5) -> 101
        huff_table[8'h06] = 16'b0000000000000110; huff_table_len[8'h06] = 3; // (0,6) -> 110
        huff_table[8'h07] = 16'b0000000000000111; huff_table_len[8'h07] = 4; // (0,7) -> 1110
        huff_table[8'h08] = 16'b0000000000001000; huff_table_len[8'h08] = 5; // (0,8) -> 11110
        huff_table[8'h09] = 16'b0000000000001001; huff_table_len[8'h09] = 6; // (0,9) -> 111110
        huff_table[8'h0A] = 16'b0000000000001010; huff_table_len[8'h0A] = 7; // (0,10) -> 1111110
       
        huff_table[8'h11] = 16'b0000000000001011; huff_table_len[8'h11] = 4; // (1,1)
        huff_table[8'h12] = 16'b0000000000001100; huff_table_len[8'h12] = 5; // (1,2)
        huff_table[8'h13] = 16'b0000000000001101; huff_table_len[8'h13] = 6; // (1,3)
        huff_table[8'h14] = 16'b0000000000001110; huff_table_len[8'h14] = 7; // (1,4)
        huff_table[8'h15] = 16'b0000000000001111; huff_table_len[8'h15] = 8; // (1,5)
       
        // ... 此處應填入完整的 JPEG 標準 Huffman 表 ...
    end

    // ================================================================
    // 狀態機與控制邏輯
    // ================================================================

    // --- 狀態定義 (使用 parameter 代替 typedef enum) ---
    parameter S_IDLE        = 3'b000; // 空閒狀態
    parameter S_PROC_DC     = 3'b001; // 處理 DC 係數
    parameter S_PROC_AC     = 3'b010; // 處理 AC 係數 (主循環)
    parameter S_EMIT_ZRL    = 3'b011; // 輸出 ZRL (16個連續的0)
    parameter S_EMIT_EOB    = 3'b100; // 輸出 EOB (End of Block)
    parameter S_DONE        = 3'b101; // 編碼完成

    reg [2:0] current_state, next_state; // 狀態暫存器

    // --- 內部計數器與變數 ---
    reg [5:0] ac_idx;           // AC 係數索引 (1 to 63)
    reg [3:0] zero_run_count;   // 連續 0 的計數器 (0 to 15)

    // --- 組合邏輯：計算當前週期的輸出 ---
    wire [7:0] current_val;     // 當前經 Zigzag 排序後的值
    wire [3:0] current_size;    // 當前值的 Category/Size
    wire [7:0] huffman_key;     // 用於查找 Huffman 表的 Key

    // 從打包陣列中提取正確的 8-bit 值
    assign current_val = pixel_block_flat[ (zigzag_table[ac_idx]*8) +: 8 ];
    assign current_size = size(current_val);
    assign huffman_key = {zero_run_count, current_size};

    // --- 狀態暫存器更新 (序向邏輯) ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= S_IDLE;
            ac_idx <= 0; // 從 0 開始，DC 在 0 處處理，AC 從 1 開始掃描
            zero_run_count <= 0;
        end else begin
            current_state <= next_state;
           
            // 根據次態更新計數器
            case (next_state)
                S_IDLE: begin // 返回 IDLE 時重置所有計數器
                    ac_idx <= 0;
                    zero_run_count <= 0;
                end
                S_PROC_DC: begin // 進入 DC 處理，AC 索引從 1 開始
                    ac_idx <= 1;
                    zero_run_count <= 0;
                end
                S_PROC_AC: begin // 保持在 AC 處理
                    if (current_state == S_PROC_AC || current_state == S_EMIT_ZRL) begin
                        // 僅在從 S_PROC_AC 或 S_EMIT_ZRL 轉換時更新計數器
                        if (current_val != 0) begin
                            // 找到非零 AC，計數器重置，索引遞增
                            ac_idx <= ac_idx + 1;
                            zero_run_count <= 0;
                        end else begin // current_val == 0
                            if (zero_run_count == 4'd15) begin // 達到 15 個連續 0
                                // ZRL 情況，計數器重置，索引遞增
                                ac_idx <= ac_idx + 1;
                                zero_run_count <= 0;
                            end else begin
                                // 普通 0，計數器遞增，索引遞增
                                ac_idx <= ac_idx + 1;
                                zero_run_count <= zero_run_count + 1;
                            end
                        end
                    end
                end
                // 其他狀態不改變計數器 (或已經在組合邏輯中確定了輸出)
            endcase
        end
    end

    // --- 次態與輸出邏輯 (組合邏輯) ---
    always @(*) begin
        // 預設輸出值
        next_state = current_state;
        final_huff_code = 16'h0000;
        final_huff_len = 4'h0;
        final_val_bits = 8'h00;
        final_out_valid = 1'b0;
        encoding_done = 1'b0;

        case (current_state)
            S_IDLE: begin
                if (start_encoding) begin
                    next_state = S_PROC_DC;
                end
            end

            S_PROC_DC: begin
                // DC 係數的 run 固定為 0，索引為 0
                // 從 pixel_block_flat 中提取 pixel_block[0]
                final_huff_code = huff_table[{4'h0, size(pixel_block_flat[7:0])}]; // pixel_block[0] 變為 pixel_block_flat[7:0]
                final_huff_len  = huff_table_len[{4'h0, size(pixel_block_flat[7:0])}];
                final_val_bits  = pixel_block_flat[7:0];
                final_out_valid = 1'b1;
                next_state = S_PROC_AC; // 處理完 DC 後進入 AC 處理
            end

            S_PROC_AC: begin
                // 檢查是否處理完所有 63 個 AC 係數 (ac_idx 從 1 到 63)
                if (ac_idx > 63) begin // 已經掃描完所有 63 個 AC (索引 1 到 63)
                    // 如果 ac_idx 到達 64，表示所有 AC 都掃描完了
                    if (zero_run_count > 0) begin // 且最後還有連續的 0 未被輸出，則需要輸出 EOB
                        next_state = S_EMIT_EOB;
                    end else begin // 沒有未輸出的 0，直接跳到 EOB
                         next_state = S_EMIT_EOB;
                    end
                end else begin // 還在處理 AC 係數
                    if (current_val != 0) begin
                        // 找到一個非零的 AC 係數，輸出 (run, size) 的 Huffman 碼
                        final_huff_code = huff_table[huffman_key];
                        final_huff_len  = huff_table_len[huffman_key];
                        final_val_bits  = current_val;
                        final_out_valid = 1'b1;
                        next_state = S_PROC_AC; // 狀態保持，等待計數器更新
                    end else begin // current_val == 0
                        if (zero_run_count == 4'd15) begin
                            // 累積了15個0，下個週期需要輸出 ZRL (15,0)
                            next_state = S_EMIT_ZRL;
                            // 此週期不輸出，下個週期才輸出 ZRL
                            final_out_valid = 1'b0;
                        end else begin
                            // 只是普通的0，不產生輸出，繼續掃描
                            final_out_valid = 1'b0;
                            next_state = S_PROC_AC;
                        end
                    end
                end
            end

            S_EMIT_ZRL: begin
                // 輸出 ZRL (run=15, size=0) 的碼
                final_huff_code = huff_table[8'hF0];
                final_huff_len  = huff_table_len[8'hF0];
                final_val_bits  = 8'h00; // ZRL 不帶數值
                final_out_valid = 1'b1;
                next_state = S_PROC_AC; // 輸出完 ZRL 後繼續處理 AC (如果還有 AC)
            end
           
            S_EMIT_EOB: begin
                // 輸出 EOB (run=0, size=0) 的碼
                final_huff_code = huff_table[8'h00];
                final_huff_len  = huff_table_len[8'h00];
                final_val_bits  = 8'h00; // EOB 不帶數值
                final_out_valid = 1'b1;
                next_state = S_DONE;
            end

            S_DONE: begin
                encoding_done = 1'b1;
                final_out_valid = 1'b0; // 完成後，輸出不再有效
                next_state = S_IDLE; // 返回空閒狀態，等待下一個區塊
            end

            default: begin
                next_state = S_IDLE; // 防禦性編程
            end
        endcase
    end

endmodule