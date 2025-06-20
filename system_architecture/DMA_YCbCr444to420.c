#include "xaxidma.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "ff.h"
#include "xil_cache.h"
#include "platform.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define IMG_WIDTH   2048		//輸入圖像寬度
#define IMG_HEIGHT  2048		//輸入圖像長度
#define NUM_PIXELS  (IMG_WIDTH * IMG_HEIGHT)

#define MCU_WIDTH   16
#define MCU_HEIGHT  16
#define MCU_PIXELS  (MCU_WIDTH * MCU_HEIGHT)
#define MCU_COUNT   ((IMG_WIDTH / MCU_WIDTH) * (IMG_HEIGHT / MCU_HEIGHT))

#define TX_CHUNK_SIZE 768                     // 256Y + 256Cb + 256Cr
#define RX_CHUNK_SIZE 384                     // 444 to 420 (若為444 to 444請改為768)
#define RGB_SIZE      (NUM_PIXELS * 3)        
#define TX_TOTAL_SIZE (TX_CHUNK_SIZE * MCU_COUNT)  
#define RX_TOTAL_SIZE (RX_CHUNK_SIZE * MCU_COUNT)  

#define TX_BUFFER_BASE  0x01000000
#define RX_BUFFER_BASE  0x02000000

#define rgb_data         ((u8 *)TX_BUFFER_BASE)
#define ycbcr_mcu_order  ((u8 *)RX_BUFFER_BASE)  // 暫借 RX buffer 儲存轉換結果

FATFS fatfs;
FIL file;
UINT br, bw;
XAxiDma AxiDma;

int main() {
    init_platform();
    xil_printf("[Start] RGB -> YCbCr DMA stream with 4:2:0 RX...\n");

    // 1. Mount SD
    if (f_mount(&fatfs, "0:/", 1) != FR_OK) {
        xil_printf("[Error] SD mount failed\r\n");
        return -1;
    }

    // 2. Read RGB file
    if (f_open(&file, "2048.rgb", FA_READ) != FR_OK) {
        xil_printf("[Error] open RGB failed\r\n");
        return -1;
    }
    if (f_read(&file, rgb_data, RGB_SIZE, &br) != FR_OK || br != RGB_SIZE) {
        xil_printf("[Error] read RGB failed (%d bytes)\r\n", br);
        return -1;
    }
    f_close(&file);
    xil_printf("[OK] RGB loaded (%d bytes)\r\n", br);

    // 3. Convert to planar YCbCr and MCU order
    u8 *y_plane  = ycbcr_mcu_order + 0 * NUM_PIXELS;
    u8 *cb_plane = ycbcr_mcu_order + 1 * NUM_PIXELS;
    u8 *cr_plane = ycbcr_mcu_order + 2 * NUM_PIXELS;

    for (int i = 0; i < NUM_PIXELS; i++) {
        u8 R = rgb_data[i * 3 + 0];
        u8 G = rgb_data[i * 3 + 1];
        u8 B = rgb_data[i * 3 + 2];

        float r = R, g = G, b = B;
        u8 Y  = (u8)( 0.299*r + 0.587*g + 0.114*b );
        u8 Cb = (u8)(-0.169*r - 0.331*g + 0.5*b + 128);
        u8 Cr = (u8)( 0.5*r - 0.419*g - 0.081*b + 128);

        y_plane[i] = Y;
        cb_plane[i] = Cb;
        cr_plane[i] = Cr;


    }

    // 4. Pack into MCU chunks
    u8 *mcu_buffer = rgb_data;  // reuse TX buffer
    int offset = 0;
    for (int my = 0; my < IMG_HEIGHT; my += MCU_HEIGHT) {
        for (int mx = 0; mx < IMG_WIDTH; mx += MCU_WIDTH) {
            for (int dy = 0; dy < MCU_HEIGHT; dy++) {
                for (int dx = 0; dx < MCU_WIDTH; dx++) {
                    int x = mx + dx;
                    int y = my + dy;
                    int i = y * IMG_WIDTH + x;
                    int p = dy * MCU_WIDTH + dx;
                    mcu_buffer[offset + 0 * MCU_PIXELS + p] = y_plane[i];
                    mcu_buffer[offset + 1 * MCU_PIXELS + p] = cb_plane[i];
                    mcu_buffer[offset + 2 * MCU_PIXELS + p] = cr_plane[i];
                }
            }
            offset += TX_CHUNK_SIZE;
        }
    }
    xil_printf("[OK] MCU rearranged (%d bytes)\r\n", offset);

    // 5. Initialize DMA
    XAxiDma_Config *CfgPtr = XAxiDma_LookupConfig(XPAR_AXI_DMA_0_DEVICE_ID);
    if (!CfgPtr || XAxiDma_CfgInitialize(&AxiDma, CfgPtr) != XST_SUCCESS) {
        xil_printf("[Error] DMA init failed\r\n");
        return -1;
    }
    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("[Error] SG mode not supported\r\n");
        return -1;
    }

    // 6. Setup RX buffer
    volatile u8 *rx_buf = (u8 *)RX_BUFFER_BASE;
    memset((void *)rx_buf, 0, RX_TOTAL_SIZE);
    Xil_DCacheFlushRange((UINTPTR)rx_buf, RX_TOTAL_SIZE);

    // 7. Transfer each chunk
    xil_printf("[INFO] Transferring %d MCUs...\n", MCU_COUNT);
    for (int i = 0; i < MCU_COUNT; i++) {
        volatile u8 *tx_ptr = mcu_buffer + i * TX_CHUNK_SIZE;
        volatile u8 *rx_ptr = rx_buf + i * RX_CHUNK_SIZE;
        Xil_DCacheFlushRange((UINTPTR)tx_ptr, TX_CHUNK_SIZE);

        XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)rx_ptr, RX_CHUNK_SIZE, XAXIDMA_DEVICE_TO_DMA);
        XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)tx_ptr, TX_CHUNK_SIZE, XAXIDMA_DMA_TO_DEVICE);

        while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE));
        while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA));

        if (i % 1000 == 0) xil_printf(".");
    }

    xil_printf("\n[OK] DMA done, saving...\r\n");
    Xil_DCacheInvalidateRange((UINTPTR)rx_buf, RX_TOTAL_SIZE);

    // 8. Save output
    if (f_open(&file, "output2.ycb", FA_WRITE | FA_CREATE_ALWAYS) != FR_OK) {
        xil_printf("[Error] open output.ycb failed\r\n");
        return -1;
    }
    if (f_write(&file, (void *)rx_buf, RX_TOTAL_SIZE, &bw) != FR_OK || bw != RX_TOTAL_SIZE) {
        xil_printf("[Error] write failed (%d)\r\n", bw);
        return -1;
    }
    f_close(&file);
    xil_printf("[Done] Saved to output.ycb (%d bytes)\r\n", bw);

    cleanup_platform();
    return 0;
}
