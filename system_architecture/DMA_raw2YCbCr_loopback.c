#include "ff.h"           // FATFS 函式庫
#include "xil_printf.h"   // Xilinx UART 輸出
#include "platform.h"

FATFS fatfs;       // FATFS 物件
FIL file;          // 檔案物件
UINT br;           // 實際讀取 byte 數
#define IMG_SIZE 49152   // 128*128*3

u8 buffer[IMG_SIZE];     // 暫存影像資料
u8 ycbcr_buf[IMG_SIZE];  // 儲存轉換後的 YCbCr 資料

int main() {
    init_platform();     // 初始化 UART 與平台

    // 掛載 SD 卡
    if (f_mount(&fatfs, "0:/", 1) != FR_OK) {
        xil_printf("SD卡掛載失敗\r\n");
        return -1;
    }

    xil_printf("SD卡掛載成功\r\n");

    // 開啟檔案
    if (f_open(&file, "image.rgb", FA_READ) != FR_OK) {
        xil_printf("找不到檔案 image.rgb\r\n");
        return -1;
    }

    // 讀取內容到 buffer
    if (f_read(&file, buffer, IMG_SIZE, &br) != FR_OK) {
        xil_printf("讀取檔案失敗\r\n");
        f_close(&file);
        return -1;
    }

    f_close(&file);
    xil_printf("成功讀取 image.rgb，總共 %u bytes\r\n", br);

    // 印出前 16 bytes 做確認
    xil_printf("前 16 bytes: ");
    for (int i = 0; i < 16; i++) {
        xil_printf("%02X ", buffer[i]);
    }
    xil_printf("\r\n");

    // ==============================
    // RGB → YCbCr 轉換開始
    // 使用整數近似公式實作：不使用浮點
    // ==============================
    for (int i = 0; i < IMG_SIZE; i += 3) {
        u8 R = buffer[i];
        u8 G = buffer[i+1];
        u8 B = buffer[i+2];

        // Y = 0.299 R + 0.587 G + 0.114 B
        // Cb = -0.169 R - 0.331 G + 0.5 B + 128
        // Cr = 0.5 R - 0.419 G - 0.081 B + 128
        // 用整數近似處理，避免浮點
        u8 Y  = (  77 * R + 150 * G +  29 * B ) >> 8;
        u8 Cb = ((-43 * R -  85 * G + 128 * B) >> 8) + 128;
        u8 Cr = ((128 * R - 107 * G -  21 * B) >> 8) + 128;

        ycbcr_buf[i]   = Y;
        ycbcr_buf[i+1] = Cb;
        ycbcr_buf[i+2] = Cr;
    }

    xil_printf("RGB 轉換為 YCbCr 完成\r\n");

    // ==============================
    // 可選功能：印出前 16 bytes 的 YCbCr 結果
    // ==============================
    xil_printf("YCbCr 前 16 bytes: ");
    for (int i = 0; i < 16; i++) {
        xil_printf("%02X ", ycbcr_buf[i]);
    }
    xil_printf("\r\n");

    cleanup_platform();
    return 0;
}