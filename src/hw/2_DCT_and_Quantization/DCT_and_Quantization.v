`timescale 1ns / 1ps

module DCT_and_Quantization (
    input Clock,
    input reset,
    input enable1,
    output reg [511:0] quantized_flat,
    output reg enable2
);

// Internal buffers
reg signed [7:0] pixel [0:7][0:7];
reg signed [15:0] DCT [0:7][0:7];
reg signed [31:0] temp1 [0:7][0:7];
reg signed [31:0] result [0:7][0:7];
reg signed [7:0] quantized [0:7][0:7];
reg signed [7:0] Q [0:7][0:7];
reg [8:0] state = 0;

integer i, j;
reg signed [47:0] acc;  // 增加位寬
reg signed [31:0] tmp;
reg signed [31:0] half_q;

initial begin
    // Pixel input
    pixel[0][0]=52; pixel[0][1]=55; pixel[0][2]=61; pixel[0][3]=66; pixel[0][4]=70; pixel[0][5]=61; pixel[0][6]=64; pixel[0][7]=73;
    pixel[1][0]=63; pixel[1][1]=59; pixel[1][2]=55; pixel[1][3]=90; pixel[1][4]=109; pixel[1][5]=85; pixel[1][6]=69; pixel[1][7]=72;
    pixel[2][0]=62; pixel[2][1]=59; pixel[2][2]=68; pixel[2][3]=113; pixel[2][4]=144; pixel[2][5]=104; pixel[2][6]=66; pixel[2][7]=73;
    pixel[3][0]=63; pixel[3][1]=58; pixel[3][2]=71; pixel[3][3]=122; pixel[3][4]=154; pixel[3][5]=106; pixel[3][6]=70; pixel[3][7]=69;
    pixel[4][0]=67; pixel[4][1]=61; pixel[4][2]=68; pixel[4][3]=104; pixel[4][4]=126; pixel[4][5]=88; pixel[4][6]=68; pixel[4][7]=70;
    pixel[5][0]=79; pixel[5][1]=65; pixel[5][2]=60; pixel[5][3]=70; pixel[5][4]=77; pixel[5][5]=68; pixel[5][6]=58; pixel[5][7]=75;
    pixel[6][0]=85; pixel[6][1]=71; pixel[6][2]=64; pixel[6][3]=59; pixel[6][4]=55; pixel[6][5]=61; pixel[6][6]=65; pixel[6][7]=83;
    pixel[7][0]=87; pixel[7][1]=79; pixel[7][2]=69; pixel[7][3]=68; pixel[7][4]=65; pixel[7][5]=76; pixel[7][6]=78; pixel[7][7]=94;

    // DCT matrix (scaled *10000) - 修正版本
    DCT[0][0]=3536; DCT[0][1]=3536; DCT[0][2]=3536; DCT[0][3]=3536; DCT[0][4]=3536; DCT[0][5]=3536; DCT[0][6]=3536; DCT[0][7]=3536;
    DCT[1][0]=4904; DCT[1][1]=4157; DCT[1][2]=2778; DCT[1][3]=975; DCT[1][4]=-975; DCT[1][5]=-2778; DCT[1][6]=-4157; DCT[1][7]=-4904;
    DCT[2][0]=4619; DCT[2][1]=1913; DCT[2][2]=-1913; DCT[2][3]=-4619; DCT[2][4]=-4619; DCT[2][5]=-1913; DCT[2][6]=1913; DCT[2][7]=4619;
    DCT[3][0]=4157; DCT[3][1]=-975; DCT[3][2]=-4904; DCT[3][3]=-2778; DCT[3][4]=2778; DCT[3][5]=4904; DCT[3][6]=975; DCT[3][7]=-4157;
    DCT[4][0]=3536; DCT[4][1]=-3536; DCT[4][2]=-3536; DCT[4][3]=3536; DCT[4][4]=3536; DCT[4][5]=-3536; DCT[4][6]=-3536; DCT[4][7]=3536;
    DCT[5][0]=2778; DCT[5][1]=-4904; DCT[5][2]=975; DCT[5][3]=4157; DCT[5][4]=-4157; DCT[5][5]=-975; DCT[5][6]=4904; DCT[5][7]=-2778;
    DCT[6][0]=1913; DCT[6][1]=-4619; DCT[6][2]=4619; DCT[6][3]=-1913; DCT[6][4]=-1913; DCT[6][5]=4619; DCT[6][6]=-4619; DCT[6][7]=1913;
    DCT[7][0]=975; DCT[7][1]=-2778; DCT[7][2]=4157; DCT[7][3]=-4904; DCT[7][4]=4904; DCT[7][5]=-4157; DCT[7][6]=2778; DCT[7][7]=-975;

    // Quantization Table
    Q[0][0]=16; Q[0][1]=11; Q[0][2]=10; Q[0][3]=16; Q[0][4]=24; Q[0][5]=40; Q[0][6]=51; Q[0][7]=61;
    Q[1][0]=12; Q[1][1]=12; Q[1][2]=14; Q[1][3]=19; Q[1][4]=26; Q[1][5]=58; Q[1][6]=60; Q[1][7]=55;
    Q[2][0]=14; Q[2][1]=13; Q[2][2]=16; Q[2][3]=24; Q[2][4]=40; Q[2][5]=57; Q[2][6]=69; Q[2][7]=56;
    Q[3][0]=14; Q[3][1]=17; Q[3][2]=22; Q[3][3]=29; Q[3][4]=51; Q[3][5]=87; Q[3][6]=80; Q[3][7]=62;
    Q[4][0]=18; Q[4][1]=22; Q[4][2]=37; Q[4][3]=56; Q[4][4]=68; Q[4][5]=109; Q[4][6]=103; Q[4][7]=77;
    Q[5][0]=24; Q[5][1]=35; Q[5][2]=55; Q[5][3]=64; Q[5][4]=81; Q[5][5]=104; Q[5][6]=113; Q[5][7]=92;
    Q[6][0]=49; Q[6][1]=64; Q[6][2]=78; Q[6][3]=87; Q[6][4]=103; Q[6][5]=121; Q[6][6]=120; Q[6][7]=101;
    Q[7][0]=72; Q[7][1]=92; Q[7][2]=95; Q[7][3]=98; Q[7][4]=112; Q[7][5]=100; Q[7][6]=103; Q[7][7]=99;
end

// FSM - 關鍵修正
always @(posedge Clock or posedge reset) begin
    if (reset) begin
        state <= 0;
        enable2 <= 0;
    end else if (enable1) begin
        if (state < 64) begin
            // 第一次DCT變換: temp1 = DCT * (pixel - 128)^T
            // 注意: 這裡計算的是 temp1[i][j] = sum(DCT[i][k] * (pixel[k][j] - 128))
            i = state / 8;
            j = state % 8;
            acc = 0;
            
            // 計算一行與一列的內積
            acc = $signed(DCT[i][0]) * ($signed(pixel[0][j]) - 32'sd128) +
                  $signed(DCT[i][1]) * ($signed(pixel[1][j]) - 32'sd128) +
                  $signed(DCT[i][2]) * ($signed(pixel[2][j]) - 32'sd128) +
                  $signed(DCT[i][3]) * ($signed(pixel[3][j]) - 32'sd128) +
                  $signed(DCT[i][4]) * ($signed(pixel[4][j]) - 32'sd128) +
                  $signed(DCT[i][5]) * ($signed(pixel[5][j]) - 32'sd128) +
                  $signed(DCT[i][6]) * ($signed(pixel[6][j]) - 32'sd128) +
                  $signed(DCT[i][7]) * ($signed(pixel[7][j]) - 32'sd128);
            
            // 四捨五入除法
            if (acc >= 0)
                temp1[i][j] <= (acc + 32'sd5000) / 32'sd10000;
            else
                temp1[i][j] <= (acc - 32'sd5000) / 32'sd10000;
                
        end else if (state < 128) begin
            // 第二次DCT變換: result = temp1 * DCT^T
            // 計算 result[i][j] = sum(temp1[i][k] * DCT[j][k])
            i = (state - 64) / 8;
            j = (state - 64) % 8;
            acc = 0;
            
            acc = $signed(temp1[i][0]) * $signed(DCT[j][0]) +
                  $signed(temp1[i][1]) * $signed(DCT[j][1]) +
                  $signed(temp1[i][2]) * $signed(DCT[j][2]) +
                  $signed(temp1[i][3]) * $signed(DCT[j][3]) +
                  $signed(temp1[i][4]) * $signed(DCT[j][4]) +
                  $signed(temp1[i][5]) * $signed(DCT[j][5]) +
                  $signed(temp1[i][6]) * $signed(DCT[j][6]) +
                  $signed(temp1[i][7]) * $signed(DCT[j][7]);
            
            // 四捨五入除法
            if (acc >= 0)
                result[i][j] <= (acc + 32'sd5000) / 32'sd10000;
            else
                result[i][j] <= (acc - 32'sd5000) / 32'sd10000;
                
        end else if (state < 192) begin
            // 量化步驟
            i = (state - 128) / 8;
            j = (state - 128) % 8;
            tmp = result[i][j];
            half_q = $signed(Q[i][j]) >>> 1;  // Q/2
            
            // 修正的量化四捨五入
            if (tmp >= 0)
                quantized[i][j] <= (tmp + half_q) / $signed(Q[i][j]);
            else
                quantized[i][j] <= (tmp - half_q) / $signed(Q[i][j]);
                
        end else if (state < 256) begin
            // 輸出平坦化數組 - 修正輸出順序
            i = (state - 192) / 8;
            j = (state - 192) % 8;
            quantized_flat[(state - 192)*8 +: 8] <= quantized[i][j];
            
            if (state == 255) 
                enable2 <= 1;
        end
        
        state <= state + 1;
    end
end

endmodule