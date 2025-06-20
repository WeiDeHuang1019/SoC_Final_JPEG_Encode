#include "xparameters.h"
#include "xaxidma.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "ff.h"  // FatFs library for SD card

#define DMA_DEV_ID         XPAR_AXIDMA_0_DEVICE_ID
#define DDR_BASE_ADDR      0x01000000
#define TX_BUFFER_BASE     (DDR_BASE_ADDR + 0x00000000)
#define RX_BUFFER_BASE     (DDR_BASE_ADDR + 0x00800000)
#define CHUNK_SIZE         4096  // bytes
#define FILE_NAME_IN       "image.rgb"
#define FILE_NAME_OUT      "out.rgb"

XAxiDma AxiDma;
FATFS fatfs;
FIL file;
FRESULT Res;
UINT br, bw;

int main() {
    XAxiDma_Config *CfgPtr;
    xil_printf("\n[INFO] DMA RGB Loopback Start\r\n");

    // 1. Mount SD card
    Res = f_mount(&fatfs, "0:/", 1);
    if (Res != FR_OK) {
        xil_printf("[ERROR] SD card mount failed\r\n");
        return XST_FAILURE;
    }

    // 2. Open input file
    Res = f_open(&file, FILE_NAME_IN, FA_READ);
    if (Res != FR_OK) {
        xil_printf("[ERROR] Failed to open %s\r\n", FILE_NAME_IN);
        return XST_FAILURE;
    }

    // 3. Get file size
    u32 file_size = f_size(&file);
    xil_printf("[INFO] Reading %s (%d bytes)\r\n", FILE_NAME_IN, file_size);

    // 4. Read file to TX buffer
    Res = f_read(&file, (void *)TX_BUFFER_BASE, file_size, &br);
    f_close(&file);
    if (Res != FR_OK || br != file_size) {
        xil_printf("[ERROR] File read failed\r\n");
        return XST_FAILURE;
    }

    // 5. Initialize DMA
    CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (!CfgPtr || XAxiDma_CfgInitialize(&AxiDma, CfgPtr) != XST_SUCCESS || XAxiDma_HasSg(&AxiDma)) {
        xil_printf("[ERROR] DMA init failed\r\n");
        return XST_FAILURE;
    }

    u8 *TxBuf = (u8 *)TX_BUFFER_BASE;
    u8 *RxBuf = (u8 *)RX_BUFFER_BASE;
    u32 remaining = file_size;
    u32 offset = 0;

    while (remaining > 0) {
        u32 chunk = (remaining > CHUNK_SIZE) ? CHUNK_SIZE : remaining;

        Xil_DCacheFlushRange((UINTPTR)(TxBuf + offset), chunk);
        memset((void *)(RxBuf + offset), 0, chunk);
        Xil_DCacheFlushRange((UINTPTR)(RxBuf + offset), chunk);

        XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)(RxBuf + offset), chunk, XAXIDMA_DEVICE_TO_DMA);
        XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)(TxBuf + offset), chunk, XAXIDMA_DMA_TO_DEVICE);

        while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {}
        while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA)) {}

        Xil_DCacheInvalidateRange((UINTPTR)(RxBuf + offset), chunk);

        offset += chunk;
        remaining -= chunk;
        xil_printf("[INFO] Transferred chunk offset %d (%d bytes)\r\n", offset - chunk, chunk);
    }

    // 6. Write back RX buffer to SD card
    Res = f_open(&file, FILE_NAME_OUT, FA_CREATE_ALWAYS | FA_WRITE);
    if (Res != FR_OK) {
        xil_printf("[ERROR] Cannot open output file\r\n");
        return XST_FAILURE;
    }
    Res = f_write(&file, (void *)RX_BUFFER_BASE, file_size, &bw);
    f_close(&file);
    if (Res != FR_OK || bw != file_size) {
        xil_printf("[ERROR] Write to SD failed\r\n");
        return XST_FAILURE;
    }

    xil_printf("[SUCCESS] image_out.rgb written to SD (%d bytes)\r\n", bw);
    return XST_SUCCESS;
}
