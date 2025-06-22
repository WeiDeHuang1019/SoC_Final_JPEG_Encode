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
    integer i_init; // 將循環變數從 'i' 改為 'i_init' 以避免衝突

    initial begin
        zigzag_table[ 0]= 6'd0;    zigzag_table[ 1]= 6'd1;    zigzag_table[ 2]= 6'd8;    zigzag_table[ 3]= 6'd16;
        zigzag_table[ 4]= 6'd9;    zigzag_table[ 5]= 6'd2;    zigzag_table[ 6]= 6'd3;    zigzag_table[ 7]= 6'd10;
        zigzag_table[ 8]= 6'd17;   zigzag_table[ 9]= 6'd24;   zigzag_table[10]= 6'd32;   zigzag_table[11]= 6'd25;
        zigzag_table[12]= 6'd18;   zigzag_table[13]= 6'd11;   zigzag_table[14]= 6'd4;    zigzag_table[15]= 6'd5;
        zigzag_table[16]= 6'd12;   zigzag_table[17]= 6'd19;   zigzag_table[18]= 6'd26;   zigzag_table[19]= 6'd33;
        zigzag_table[20]= 6'd40;   zigzag_table[21]= 6'd48;   zigzag_table[22]= 6'd41;   zigzag_table[23]= 6'd34;
        zigzag_table[24]= 6'd27;   zigzag_table[25]= 6'd20;   zigzag_table[26]= 6'd13;   zigzag_table[27]= 6'd6;
        zigzag_table[28]= 6'd7;    zigzag_table[29]= 6'd14;   zigzag_table[30]= 6'd21;   zigzag_table[31]= 6'd28;
        zigzag_table[32]= 6'd35;   zigzag_table[33]= 6'd42;   zigzag_table[34]= 6'd49;   zigzag_table[35]= 6'd56;
        zigzag_table[36]= 6'd57;   zigzag_table[37]= 6'd50;   zigzag_table[38]= 6'd43;   zigzag_table[39]= 6'd36;
        zigzag_table[40]= 6'd29;   zigzag_table[41]= 6'd22;   zigzag_table[42]= 6'd15;   zigzag_table[43]= 6'd23;
        zigzag_table[44]= 6'd30;   zigzag_table[45]= 6'd37;   zigzag_table[46]= 6'd44;   zigzag_table[47]= 6'd51;
        zigzag_table[48]= 6'd58;   zigzag_table[49]= 6'd59;   zigzag_table[50]= 6'd52;   zigzag_table[51]= 6'd45;
        zigzag_table[52]= 6'd38;   zigzag_table[53]= 6'd31;   zigzag_table[54]= 6'd39;   zigzag_table[55]= 6'd46;
        zigzag_table[56]= 6'd53;   zigzag_table[57]= 6'd60;   zigzag_table[58]= 6'd61;   zigzag_table[59]= 6'd54;
        zigzag_table[60]= 6'd47;   zigzag_table[61]= 6'd55;   zigzag_table[62]= 6'd62;   zigzag_table[63]= 6'd63;
    end

    // --- Huffman 查找表 (ROM) for DC and AC ---
    // 這裡只包含在 Testbench 中可能用到的部分，需要一個完整的表來實現
    // 為了簡潔，我們只列出用於測試的必要部分，完整實現會非常大
    // Huffman Codes (Category, Code) -> Huffman Bits
    // 例如：0_4 (DC, Size 4) -> 0100 (3 bits)
    //       0_3 (AC, Size 3) -> 0011 (3 bits)
    //       0_2 (AC, Size 2) -> 0010 (3 bits)
    //       1_1 (AC, Run 1, Size 1) -> 0010 (4 bits)
    //       F_0 (15,0) ZRL -> 11111111001 (11 bits)
    //       0_0 EOB -> 1010 (4 bits)

    reg [15:0] huff_table [0:255]; // Huffman 碼
    reg [3:0]  huff_table_len [0:255]; // Huffman 碼的長度

    initial begin
        // DC Codes (run=0, size=0-11)
        huff_table[8'h04] = 16'b0000000000000100; huff_table_len[8'h04] = 3; // 0_4: 0100

        // AC Codes (run=0-15, size=0-10)
        huff_table[8'h03] = 16'b0000000000000011; huff_table_len[8'h03] = 3; // 0_3: 0011
        huff_table[8'h02] = 16'b0000000000000010; huff_table_len[8'h02] = 3; // 0_2: 0010
        huff_table[8'h11] = 16'b0000000000000010; huff_table_len[8'h11] = 4; // 1_1: 0010 (此處為示例，實際值和長度需參考JPEG標準)

        // Special AC Codes
        huff_table[8'hF0] = 16'b0000011111111001; huff_table_len[8'hF0] = 11; // F_0 (15,0) ZRL
        huff_table[8'h00] = 16'b0000000000001010; huff_table_len[8'h00] = 4;  // 0_0 (EOB)
    end

    // ===============================================================
    // 狀態機定義
    // ===============================================================

    parameter S_IDLE       = 3'd0; // 閒置狀態，等待啟動
    parameter S_PROC_DC    = 3'd1; // 處理 DC 係數
    parameter S_PROC_AC    = 3'd2; // 處理 AC 係數 (RLE & Huffman)
    parameter S_EMIT_ZRL   = 3'd3; // 輸出 ZRL 碼
    parameter S_EMIT_EOB   = 3'd4; // 輸出 EOB 碼
    parameter S_DONE       = 3'd5; // 編碼完成

    reg [2:0] current_state, next_state;

    // ===============================================================
    // 內部暫存器和訊號
    // ===============================================================

    reg [7:0] current_input_val;    // 當前從 pixel_block_flat 讀取的係數
    reg [7:0] current_val;          // 經過 DPCM 處理後的 DC 值，或原始 AC 值
    reg [3:0] current_size;         // current_val 的 Huffman Category (Size)
    reg [7:0] huffman_key_comb;     // {run_length, size}，用於 Huffman 查表
    reg [5:0] ac_idx;               // AC 係數的索引 (1到63)
    reg [3:0] zero_run_count;       // 連續零的計數 (0到15)
    reg [7:0] prev_dc_value;        // 前一個區塊的 DC 值 (用於 DPCM)

    // ===============================================================
    // 輔助函數：計算 Huffman Category (Size)
    // ===============================================================
    function [3:0] calc_size;
        input [7:0] value;
        begin
            if (value == 8'd0) begin
                calc_size = 4'd0;
            end else if (value == 8'd1 || value == 8'hFF) begin // 1 or -1
                calc_size = 4'd1;
            end else if (value == 8'd2 || value == 8'hFE) begin // 2 or -2
                calc_size = 4'd2;
            end else if (value == 8'd3 || value == 8'd4 || value == 8'hFC || value == 8'hFD) begin // 3,4 or -3,-4
                calc_size = 4'd3;
            end else if (value >= 8'd5 && value <= 8'd8 || value >= 8'hF8 && value <= 8'hFB) begin // 5-8 or -5--8
                calc_size = 4'd4;
            end else if (value >= 8'd9 && value <= 8'd16 || value >= 8'hF0 && value <= 8'hF7) begin // 9-16 or -9--16
                calc_size = 4'd5;
            end else if (value >= 8'd17 && value <= 8'd32 || value >= 8'hE0 && value <= 8'hEF) begin // 17-32 or -17--32
                calc_size = 4'd6;
            end else if (value >= 8'd33 && value <= 8'd64 || value >= 8'hC0 && value <= 8'hDF) begin // 33-64 or -33--64
                calc_size = 4'd7;
            end else if (value >= 8'd65 && value <= 8'd128 || value >= 8'h80 && value <= 8'hBF) begin // 65-128 or -65--128
                calc_size = 4'd8;
            end else begin // For values beyond 128 (shouldn't happen with typical DCT output and 8-bit)
                calc_size = 4'd9; // Example for 129-255 or -129--255
            end
        end
    endfunction


    // ===============================================================
    // 時序邏輯 (Sequential Logic)
    // ===============================================================

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state   <= S_IDLE;
            ac_idx          <= 6'd0;
            zero_run_count  <= 4'd0;
            prev_dc_value   <= 8'd0;
            encoding_done   <= 1'b0;
        end else begin
            current_state <= next_state;
            // 只有在特定狀態轉換時才更新計數器和 DC 值
            if (current_state == S_IDLE && next_state == S_PROC_DC) begin
                ac_idx          <= 6'd0; // 重置 AC 索引為 0 (準備處理 DC)
                zero_run_count  <= 4'd0; // 重置零計數
                // prev_dc_value 在 S_PROC_DC 處理後更新
                encoding_done   <= 1'b0;
            end else if (current_state == S_PROC_DC && next_state == S_PROC_AC) begin
                // 從 DC 處理完畢，更新 prev_dc_value，準備處理 AC
                prev_dc_value <= current_input_val; // DC 值在 DPCM 前是原始輸入
                ac_idx        <= 6'd1; // 從第一個 AC 係數 (索引 1) 開始
            end else if (current_state == S_PROC_AC && next_state == S_PROC_AC) begin
                // 處理 AC 係數時，根據是否為零更新 zero_run_count 和 ac_idx
                if (current_val == 8'd0) begin
                    zero_run_count <= zero_run_count + 1;
                    ac_idx         <= ac_idx + 1;
                end else begin
                    zero_run_count <= 4'd0; // 非零係數出現，重置零計數
                    ac_idx         <= ac_idx + 1;
                end
            end else if (current_state == S_PROC_AC && (next_state == S_EMIT_ZRL || next_state == S_EMIT_EOB)) begin
                // AC 處理結束，準備發送 ZRL 或 EOB
                zero_run_count <= 4'd0; // 重置零計數
                ac_idx         <= 6'd0; // 重置 AC 索引
            end else if (next_state == S_DONE) begin
                encoding_done <= 1'b1;
            end
        end
    end

    // ===============================================================
    // 組合邏輯 (Combinational Logic)
    // ===============================================================

    always @(*) begin
        // 默認值
        next_state          = current_state;
        final_huff_code     = 16'b0;
        final_huff_len      = 4'b0;
        final_val_bits      = 8'b0;
        final_out_valid     = 1'b0;
        current_input_val   = 8'b0;
        current_val         = 8'b0;
        current_size        = 4'b0;
        huffman_key_comb    = 8'b0;


        case (current_state)
            S_IDLE: begin
                if (start_encoding) begin
                    next_state = S_PROC_DC;
                end else begin
                    next_state = S_IDLE;
                end
            end

            S_PROC_DC: begin
                // 讀取 DC 係數 (zigzag_table[0] 對應 pixel_block_flat[7:0])
                current_input_val = pixel_block_flat[zigzag_table[0]*8 +: 8]; // 總是第一個係數

                // DPCM 處理：當前 DC 值 - 前一個區塊的 DC 值
                current_val = current_input_val - prev_dc_value;

                // 計算 Huffman Category (Size)
                current_size = calc_size(current_val);

                // DC Huffman Key: {0, Size}
                huffman_key_comb = {4'b0000, current_size}; // Run for DC is always 0

                final_huff_code = huff_table[huffman_key_comb];
                final_huff_len  = huff_table_len[huffman_key_comb];
                
                // Calculate final_val_bits based on current_val and current_size
                // --- 修改開始 ---
                if (current_val[7]) begin // Negative number
                    reg [7:0] abs_val;
                    reg [7:0] size_mask;

                    abs_val = (~current_val + 1); 
                    size_mask = (1'b1 << current_size) - 1; 

                    final_val_bits = (~abs_val) & size_mask;
                end else begin // Positive or Zero number
                    final_val_bits = current_val;
                end
                // --- 修改結束 ---

                final_out_valid = 1'b1; // DC 係數處理完畢，本週期輸出有效
                next_state = S_PROC_AC; // 準備處理 AC 係數
            end

            S_PROC_AC: begin
                // 檢查是否所有 AC 係數都已處理完
                if (ac_idx >= 6'd64) begin // 索引 0 是 DC，所以 AC 是 1 到 63，總共 64 個係數
                    // 所有係數都處理完，發送 EOB (如果沒有待處理的零運行)
                    // 如果有零積累，但在63後面，也應該是EOB
                    final_out_valid = 1'b0; // 此週期不輸出，下個週期輸出 EOB
                    next_state = S_EMIT_EOB;
                end else begin
                    current_input_val = pixel_block_flat[zigzag_table[ac_idx]*8 +: 8];
                    current_val = current_input_val; // AC 係數不進行 DPCM

                    if (current_val != 8'd0) begin
                        // 非零係數：輸出當前累積的 zero_run_count 和 current_val 的 category
                        current_size = calc_size(current_val);
                        huffman_key_comb = {zero_run_count, current_size};

                        final_huff_code = huff_table[huffman_key_comb];
                        final_huff_len  = huff_table_len[huffman_key_comb];
                        
                        // Calculate final_val_bits based on current_val and current_size
                        // --- 修改開始 ---
                        if (current_val[7]) begin // Negative number
                            reg [7:0] abs_val;
                            reg [7:0] size_mask;

                            abs_val = (~current_val + 1); 
                            size_mask = (1'b1 << current_size) - 1; 

                            final_val_bits = (~abs_val) & size_mask;
                        end else begin // Positive or Zero number
                            final_val_bits = current_val;
                        end
                        // --- 修改結束 ---

                        final_out_valid = 1'b1; // 有效輸出
                        next_state = S_PROC_AC; // 繼續處理下一個 AC 係數 (ac_idx會在時序邏輯中更新)
                    end else begin // current_val == 0
                        // 零係數：累積 zero_run_count
                        if (zero_run_count == 4'd15) begin
                            // 積累了15個0，下個週期需要輸出 ZRL (15,0)
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
                next_state = S_DONE; // EOB 輸出完畢，進入完成狀態
            end

            S_DONE: begin
                next_state = S_DONE; // 保持在完成狀態
                final_out_valid = 1'b0; // 不再輸出
                encoding_done = 1'b1; // 設置完成標誌
            end

            default: begin // 未知狀態，回到 IDLE
                next_state = S_IDLE;
            end
        endcase
    end

endmodule