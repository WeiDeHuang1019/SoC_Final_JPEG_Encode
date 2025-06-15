#include "xaxidma.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "ff.h"
#include "xil_cache.h"
#include "platform.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define IMG_WIDTH   16
#define IMG_HEIGHT  16
#define NUM_PIXELS  (IMG_WIDTH * IMG_HEIGHT)

#define RGB_SIZE    (NUM_PIXELS * 3)   // 768 bytes
#define YCBCR_SIZE  (NUM_PIXELS * 3)   // 768 bytes Planar: Y[256], Cb[256], Cr[256]
#define OUT_SIZE    (384)

#define TX_BUFFER_BASE  0x01000000
#define RX_BUFFER_BASE  0x02000000

FATFS fatfs;
FIL file;
UINT br, bw;

XAxiDma AxiDma;

u8 rgb_data[RGB_SIZE];
u8 ycbcr_planar[YCBCR_SIZE];

void rgb_to_ycbcr(u8 R, u8 G, u8 B, u8 *Y, u8 *Cb, u8 *Cr) {
    float r = R;
    float g = G;
    float b = B;
    *Y  = (u8)( 0.299*r + 0.587*g + 0.114*b );
    *Cb = (u8)(-0.169*r - 0.331*g + 0.5*b + 128);
    *Cr = (u8)( 0.5*r - 0.419*g - 0.081*b + 128);
}

int main() {
    init_platform();
    xil_printf("Starting RGB to YCbCr + DMA planar stream...\r\n");

    // 1. Mount SD card
    if (f_mount(&fatfs, "0:/", 1) != FR_OK) {
        xil_printf("Failed to mount SD card\r\n");
        return -1;
    }

    // 2. Read RGB file
    if (f_open(&file, "img1616.rgb", FA_READ) != FR_OK) {
        xil_printf("Failed to open RGB file\r\n");
        return -1;
    }
    if (f_read(&file, rgb_data, RGB_SIZE, &br) != FR_OK || br != RGB_SIZE) {
        xil_printf("Failed to read image.rgb (%d bytes read)\r\n", br);
        return -1;
    }
    f_close(&file);
    xil_printf("Read image.rgb successfully (%d bytes)\r\n", br);

    // 3. RGB to Planar YCbCr
    for (int i = 0; i < NUM_PIXELS; i++) {
        u8 R = rgb_data[i * 3 + 0];
        u8 G = rgb_data[i * 3 + 1];
        u8 B = rgb_data[i * 3 + 2];

        u8 Y, Cb, Cr;
        rgb_to_ycbcr(R, G, B, &Y, &Cb, &Cr);

        ycbcr_planar[0 * NUM_PIXELS + i] = Y;
        ycbcr_planar[1 * NUM_PIXELS + i] = Cb;
        ycbcr_planar[2 * NUM_PIXELS + i] = Cr;
    }

    xil_printf("YCbCr planar conversion complete\r\n");

    // 4. Copy to TX buffer (volatile to avoid optimization)
    volatile u8 *tx_buf = (volatile u8 *)TX_BUFFER_BASE;
    volatile u8 *rx_buf = (volatile u8 *)RX_BUFFER_BASE;

    memcpy((void *)tx_buf, ycbcr_planar, YCBCR_SIZE);
    memset((void *)rx_buf, 0x00, YCBCR_SIZE);  // Clear RX buffer

    Xil_DCacheFlush();
    Xil_DCacheFlushRange((UINTPTR)tx_buf, YCBCR_SIZE);
    Xil_DCacheFlushRange((UINTPTR)rx_buf, YCBCR_SIZE);

    // 5. DMA init
    XAxiDma_Config *CfgPtr = XAxiDma_LookupConfig(XPAR_AXI_DMA_0_DEVICE_ID);
    if (!CfgPtr || XAxiDma_CfgInitialize(&AxiDma, CfgPtr) != XST_SUCCESS) {
        xil_printf("DMA init failed\r\n");
        return -1;
    }

    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("DMA is in SG mode, unsupported in Simple Mode flow\r\n");
        return -1;
    }

    xil_printf("Starting DMA transfer...\r\n");

    if (XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)rx_buf, OUT_SIZE, XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
        xil_printf("RX DMA failed\r\n");
        return -1;
    }

    if (XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)tx_buf, YCBCR_SIZE, XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) {
        xil_printf("TX DMA failed\r\n");
        return -1;
    }

    xil_printf("Waiting for DMA to finish...\r\n");

    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE));
    xil_printf("TX done\r\n");

    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA));
    xil_printf("RX done\r\n");

    Xil_DCacheInvalidateRange((UINTPTR)rx_buf, OUT_SIZE);

    // 6. Save output
    if (f_open(&file, "out1616.ycb", FA_WRITE | FA_CREATE_ALWAYS) != FR_OK) {
        xil_printf("Failed to open out.ycb for writing\r\n");
        return -1;
    }
    if (f_write(&file, (void *)rx_buf, OUT_SIZE, &bw) != FR_OK || bw != OUT_SIZE) {
        xil_printf("Failed to write YCbCr to SD\r\n");
        return -1;
    }
    f_close(&file);
    xil_printf("YCbCr saved to out1616.ycb (%d bytes)\r\n", bw);

    cleanup_platform();
    return 0;
}