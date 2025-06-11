#include "xparameters.h"
#include "xaxidma.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "ff.h"  // FatFs library

#define DMA_DEV_ID        XPAR_AXIDMA_0_DEVICE_ID

#define DDR_BASE_ADDR     0x01000000
#define TX_BUFFER_BASE    (DDR_BASE_ADDR + 0x00000000)
#define RX_BUFFER_BASE    (DDR_BASE_ADDR + 0x00100000)
#define FILE_SIZE         49152   // 128x128x3 raw image
#define FILE_NAME_IN      "image.raw"
#define FILE_NAME_OUT     "image_out.raw"

XAxiDma AxiDma;
FATFS fatfs;
FIL file;
FRESULT Res;
UINT br, bw;

int main() {
    xil_printf("\n[INFO] JPEG Loopback Simulation Start\n\r");

    // Mount SD card
    Res = f_mount(&fatfs, "0:/", 1);
    if (Res != FR_OK) {
        xil_printf("[ERROR] SD card mount failed\n\r");
        return XST_FAILURE;
    }

    // Open and read raw image file
    Res = f_open(&file, FILE_NAME_IN, FA_READ);
    if (Res != FR_OK) {
        xil_printf("[ERROR] Failed to open input file\n\r");
        return XST_FAILURE;
    }
    Res = f_read(&file, (void *)TX_BUFFER_BASE, FILE_SIZE, &br);
    f_close(&file);
    if (Res != FR_OK || br != FILE_SIZE) {
        xil_printf("[ERROR] Failed to read file or incomplete read\n\r");
        return XST_FAILURE;
    }
    xil_printf("[INFO] Input image read from SD card (%d bytes)\n\r", br);

    // Flush TX buffer and clear RX buffer
    Xil_DCacheFlushRange(TX_BUFFER_BASE, FILE_SIZE);
    memset((void *)RX_BUFFER_BASE, 0, FILE_SIZE);
    Xil_DCacheFlushRange(RX_BUFFER_BASE, FILE_SIZE);

    // Initialize AXI DMA
    XAxiDma_Config *CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (!CfgPtr) {
        xil_printf("[ERROR] No config found for DMA\n\r");
        return XST_FAILURE;
    }
    if (XAxiDma_CfgInitialize(&AxiDma, CfgPtr) != XST_SUCCESS) {
        xil_printf("[ERROR] DMA init failed\n\r");
        return XST_FAILURE;
    }
    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("[ERROR] DMA configured as SG mode\n\r");
        return XST_FAILURE;
    }

    // Start DMA S2MM (receive)
    if (XAxiDma_SimpleTransfer(&AxiDma, RX_BUFFER_BASE, FILE_SIZE, XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
        xil_printf("[ERROR] DMA S2MM failed\n\r");
        return XST_FAILURE;
    }

    // Start DMA MM2S (send)
    if (XAxiDma_SimpleTransfer(&AxiDma, TX_BUFFER_BASE, FILE_SIZE, XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) {
        xil_printf("[ERROR] DMA MM2S failed\n\r");
        return XST_FAILURE;
    }

    // Wait until DMA is done
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {}
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA)) {}

    Xil_DCacheInvalidateRange(RX_BUFFER_BASE, FILE_SIZE);
    xil_printf("[INFO] Loopback transfer completed.\n\r");

    // Write output to SD card
    Res = f_open(&file, FILE_NAME_OUT, FA_CREATE_ALWAYS | FA_WRITE);
    if (Res != FR_OK) {
        xil_printf("[ERROR] Failed to open output file\n\r");
        return XST_FAILURE;
    }
    Res = f_write(&file, (void *)RX_BUFFER_BASE, FILE_SIZE, &bw);
    f_close(&file);
    if (Res != FR_OK || bw != FILE_SIZE) {
        xil_printf("[ERROR] Failed to write to SD card\n\r");
        return XST_FAILURE;
    }

    xil_printf("[SUCCESS] Output image written to SD card (%d bytes)\n\r", bw);
    return XST_SUCCESS;
}
