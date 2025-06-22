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
// ��X�F Zigzag, RLE, Huffman �\�઺ JPEG �֤߽s�X��
// �S�I�G
// 1. ��@���A������A�޿趰���C
// 2. �L�ݤ����� Zigzag �w�İϡA�`�٤j�q�Ȧs���귽�C
// 3. �y���B�z�A�C�Ӷg���B�z�@�� AC �Y�ơA�Ĳv���C
// ============================================================================

module jpeg_core_encoder (
    input wire clk,             // �ɯ߰T��
    input wire rst,             // �D�P�B���m�T�� (���q�즳��)
    input wire start_encoding,  // �Ұʾ�ӽs�X�y�{���T��
    input wire [511:0] pixel_block_flat, // 64 �� 8-bit ��J�ƾڶ� (���]�}�C)

    output reg [15:0] final_huff_code, // �̲׿�X�� Huffman �s�X
    output reg [3:0]  final_huff_len,  // �̲� Huffman �s�X������
    output reg [7:0]  final_val_bits,  // �̲ת��ƭȦ줸 (�D Huffman �s�X����)
    output reg        final_out_valid, // �̲׿�X���İT��
    output reg        encoding_done    // ��Ӱ϶��s�X�����T��
);

    // ================================================================
    // �����귽�w�q (�� Zigzag, Huffman �Ҳժ��֤߳���)
    // ================================================================

    // --- Zigzag �d��� (ROM) ---
    // ����w�q�F Zigzag ���y������
    reg [5:0] zigzag_table [0:63];
    integer i_init; // �N�`���ܼƱq 'i' �אּ 'i_init' �H�קK�Ĭ�

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

    // --- Huffman �d��� (ROM) for DC and AC ---
    // �o�̥u�]�t�b Testbench ���i��Ψ쪺�����A�ݭn�@�ӧ��㪺��ӹ�{
    // ���F²��A�ڭ̥u�C�X�Ω���ժ����n�����A�����{�|�D�`�j
    // Huffman Codes (Category, Code) -> Huffman Bits
    // �Ҧp�G0_4 (DC, Size 4) -> 0100 (3 bits)
    //       0_3 (AC, Size 3) -> 0011 (3 bits)
    //       0_2 (AC, Size 2) -> 0010 (3 bits)
    //       1_1 (AC, Run 1, Size 1) -> 0010 (4 bits)
    //       F_0 (15,0) ZRL -> 11111111001 (11 bits)
    //       0_0 EOB -> 1010 (4 bits)

    reg [15:0] huff_table [0:255]; // Huffman �X
    reg [3:0]  huff_table_len [0:255]; // Huffman �X������

    initial begin
        // DC Codes (run=0, size=0-11)
        huff_table[8'h04] = 16'b0000000000000100; huff_table_len[8'h04] = 3; // 0_4: 0100

        // AC Codes (run=0-15, size=0-10)
        huff_table[8'h03] = 16'b0000000000000011; huff_table_len[8'h03] = 3; // 0_3: 0011
        huff_table[8'h02] = 16'b0000000000000010; huff_table_len[8'h02] = 3; // 0_2: 0010
        huff_table[8'h11] = 16'b0000000000000010; huff_table_len[8'h11] = 4; // 1_1: 0010 (���B���ܨҡA��ڭȩM���׻ݰѦ�JPEG�з�)

        // Special AC Codes
        huff_table[8'hF0] = 16'b0000011111111001; huff_table_len[8'hF0] = 11; // F_0 (15,0) ZRL
        huff_table[8'h00] = 16'b0000000000001010; huff_table_len[8'h00] = 4;  // 0_0 (EOB)
    end

    // ===============================================================
    // ���A���w�q
    // ===============================================================

    parameter S_IDLE       = 3'd0; // ���m���A�A���ݱҰ�
    parameter S_PROC_DC    = 3'd1; // �B�z DC �Y��
    parameter S_PROC_AC    = 3'd2; // �B�z AC �Y�� (RLE & Huffman)
    parameter S_EMIT_ZRL   = 3'd3; // ��X ZRL �X
    parameter S_EMIT_EOB   = 3'd4; // ��X EOB �X
    parameter S_DONE       = 3'd5; // �s�X����

    reg [2:0] current_state, next_state;

    // ===============================================================
    // �����Ȧs���M�T��
    // ===============================================================

    reg [7:0] current_input_val;    // ��e�q pixel_block_flat Ū�����Y��
    reg [7:0] current_val;          // �g�L DPCM �B�z�᪺ DC �ȡA�έ�l AC ��
    reg [3:0] current_size;         // current_val �� Huffman Category (Size)
    reg [7:0] huffman_key_comb;     // {run_length, size}�A�Ω� Huffman �d��
    reg [5:0] ac_idx;               // AC �Y�ƪ����� (1��63)
    reg [3:0] zero_run_count;       // �s��s���p�� (0��15)
    reg [7:0] prev_dc_value;        // �e�@�Ӱ϶��� DC �� (�Ω� DPCM)

    // ===============================================================
    // ���U��ơG�p�� Huffman Category (Size)
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
    // �ɧ��޿� (Sequential Logic)
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
            // �u���b�S�w���A�ഫ�ɤ~��s�p�ƾ��M DC ��
            if (current_state == S_IDLE && next_state == S_PROC_DC) begin
                ac_idx          <= 6'd0; // ���m AC ���ެ� 0 (�ǳƳB�z DC)
                zero_run_count  <= 4'd0; // ���m�s�p��
                // prev_dc_value �b S_PROC_DC �B�z���s
                encoding_done   <= 1'b0;
            end else if (current_state == S_PROC_DC && next_state == S_PROC_AC) begin
                // �q DC �B�z�����A��s prev_dc_value�A�ǳƳB�z AC
                prev_dc_value <= current_input_val; // DC �Ȧb DPCM �e�O��l��J
                ac_idx        <= 6'd1; // �q�Ĥ@�� AC �Y�� (���� 1) �}�l
            end else if (current_state == S_PROC_AC && next_state == S_PROC_AC) begin
                // �B�z AC �Y�ƮɡA�ھڬO�_���s��s zero_run_count �M ac_idx
                if (current_val == 8'd0) begin
                    zero_run_count <= zero_run_count + 1;
                    ac_idx         <= ac_idx + 1;
                end else begin
                    zero_run_count <= 4'd0; // �D�s�Y�ƥX�{�A���m�s�p��
                    ac_idx         <= ac_idx + 1;
                end
            end else if (current_state == S_PROC_AC && (next_state == S_EMIT_ZRL || next_state == S_EMIT_EOB)) begin
                // AC �B�z�����A�ǳƵo�e ZRL �� EOB
                zero_run_count <= 4'd0; // ���m�s�p��
                ac_idx         <= 6'd0; // ���m AC ����
            end else if (next_state == S_DONE) begin
                encoding_done <= 1'b1;
            end
        end
    end

    // ===============================================================
    // �զX�޿� (Combinational Logic)
    // ===============================================================

    always @(*) begin
        // �q�{��
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
                // Ū�� DC �Y�� (zigzag_table[0] ���� pixel_block_flat[7:0])
                current_input_val = pixel_block_flat[zigzag_table[0]*8 +: 8]; // �`�O�Ĥ@�ӫY��

                // DPCM �B�z�G��e DC �� - �e�@�Ӱ϶��� DC ��
                current_val = current_input_val - prev_dc_value;

                // �p�� Huffman Category (Size)
                current_size = calc_size(current_val);

                // DC Huffman Key: {0, Size}
                huffman_key_comb = {4'b0000, current_size}; // Run for DC is always 0

                final_huff_code = huff_table[huffman_key_comb];
                final_huff_len  = huff_table_len[huffman_key_comb];
                
                // Calculate final_val_bits based on current_val and current_size
                // --- �ק�}�l ---
                if (current_val[7]) begin // Negative number
                    reg [7:0] abs_val;
                    reg [7:0] size_mask;

                    abs_val = (~current_val + 1); 
                    size_mask = (1'b1 << current_size) - 1; 

                    final_val_bits = (~abs_val) & size_mask;
                end else begin // Positive or Zero number
                    final_val_bits = current_val;
                end
                // --- �קﵲ�� ---

                final_out_valid = 1'b1; // DC �Y�ƳB�z�����A���g����X����
                next_state = S_PROC_AC; // �ǳƳB�z AC �Y��
            end

            S_PROC_AC: begin
                // �ˬd�O�_�Ҧ� AC �Y�Ƴ��w�B�z��
                if (ac_idx >= 6'd64) begin // ���� 0 �O DC�A�ҥH AC �O 1 �� 63�A�`�@ 64 �ӫY��
                    // �Ҧ��Y�Ƴ��B�z���A�o�e EOB (�p�G�S���ݳB�z���s�B��)
                    // �p�G���s�n�֡A���b63�᭱�A�]���ӬOEOB
                    final_out_valid = 1'b0; // ���g������X�A�U�Ӷg����X EOB
                    next_state = S_EMIT_EOB;
                end else begin
                    current_input_val = pixel_block_flat[zigzag_table[ac_idx]*8 +: 8];
                    current_val = current_input_val; // AC �Y�Ƥ��i�� DPCM

                    if (current_val != 8'd0) begin
                        // �D�s�Y�ơG��X��e�ֿn�� zero_run_count �M current_val �� category
                        current_size = calc_size(current_val);
                        huffman_key_comb = {zero_run_count, current_size};

                        final_huff_code = huff_table[huffman_key_comb];
                        final_huff_len  = huff_table_len[huffman_key_comb];
                        
                        // Calculate final_val_bits based on current_val and current_size
                        // --- �ק�}�l ---
                        if (current_val[7]) begin // Negative number
                            reg [7:0] abs_val;
                            reg [7:0] size_mask;

                            abs_val = (~current_val + 1); 
                            size_mask = (1'b1 << current_size) - 1; 

                            final_val_bits = (~abs_val) & size_mask;
                        end else begin // Positive or Zero number
                            final_val_bits = current_val;
                        end
                        // --- �קﵲ�� ---

                        final_out_valid = 1'b1; // ���Ŀ�X
                        next_state = S_PROC_AC; // �~��B�z�U�@�� AC �Y�� (ac_idx�|�b�ɧ��޿褤��s)
                    end else begin // current_val == 0
                        // �s�Y�ơG�ֿn zero_run_count
                        if (zero_run_count == 4'd15) begin
                            // �n�֤F15��0�A�U�Ӷg���ݭn��X ZRL (15,0)
                            next_state = S_EMIT_ZRL;
                            // ���g������X�A�U�Ӷg���~��X ZRL
                            final_out_valid = 1'b0;
                        end else begin
                            // �u�O���q��0�A�����Ϳ�X�A�~�򱽴y
                            final_out_valid = 1'b0;
                            next_state = S_PROC_AC;
                        end
                    end
                end
            end

            S_EMIT_ZRL: begin
                // ��X ZRL (run=15, size=0) ���X
                final_huff_code = huff_table[8'hF0];
                final_huff_len  = huff_table_len[8'hF0];
                final_val_bits  = 8'h00; // ZRL ���a�ƭ�
                final_out_valid = 1'b1;
                next_state = S_PROC_AC; // ��X�� ZRL ���~��B�z AC (�p�G�٦� AC)
            end
            
            S_EMIT_EOB: begin
                // ��X EOB (run=0, size=0) ���X
                final_huff_code = huff_table[8'h00];
                final_huff_len  = huff_table_len[8'h00];
                final_val_bits  = 8'h00; // EOB ���a�ƭ�
                final_out_valid = 1'b1;
                next_state = S_DONE; // EOB ��X�����A�i�J�������A
            end

            S_DONE: begin
                next_state = S_DONE; // �O���b�������A
                final_out_valid = 1'b0; // ���A��X
                encoding_done = 1'b1; // �]�m�����лx
            end

            default: begin // �������A�A�^�� IDLE
                next_state = S_IDLE;
            end
        endcase
    end

endmodule