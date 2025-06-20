#include "xparameters.h"
#include "xaxidma.h"
#include "xil_printf.h"
#include "xil_cache.h"

#define DMA_DEV_ID         XPAR_AXIDMA_0_DEVICE_ID
#define DDR_BASE_ADDR      0x01000000
#define TX_BUFFER_BASE     (DDR_BASE_ADDR + 0x00000000)
#define RX_BUFFER_BASE     (DDR_BASE_ADDR + 0x00400000) // 避免重疊

#define TEST_START_VALUE   0xC0000000
#define TOTAL_WORD_COUNT   2073600      // 總共測試 64KB 資料
#define CHUNK_WORD_COUNT   2048       // 每次傳送 8KB（2048 個 u32）

int main() {
    XAxiDma AxiDma;
    XAxiDma_Config *CfgPtr;
    int status;

    xil_printf("\n[INFO] AXI DMA Chunked Loopback Test Start\r\n");

    // 初始化 DMA
    CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (!CfgPtr || XAxiDma_CfgInitialize(&AxiDma, CfgPtr) != XST_SUCCESS || XAxiDma_HasSg(&AxiDma)) {
        xil_printf("[ERROR] DMA initialization failed\r\n");
        return XST_FAILURE;
    }

    u32 *TxBuf = (u32 *)TX_BUFFER_BASE;
    u32 *RxBuf = (u32 *)RX_BUFFER_BASE;
    int fail_count = 0;

    for (int offset = 0; offset < TOTAL_WORD_COUNT; offset += CHUNK_WORD_COUNT) {
        int chunk = CHUNK_WORD_COUNT;
        if (offset + chunk > TOTAL_WORD_COUNT) chunk = TOTAL_WORD_COUNT - offset;

        int buffer_len = chunk * sizeof(u32);

        // 準備資料
        for (int i = 0; i < chunk; i++) {
            TxBuf[i] = TEST_START_VALUE + offset + i;
            RxBuf[i] = 0;
        }

        Xil_DCacheFlushRange((UINTPTR)TxBuf, buffer_len);
        Xil_DCacheFlushRange((UINTPTR)RxBuf, buffer_len);

        // 啟動 DMA 傳輸
        status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)RxBuf, buffer_len, XAXIDMA_DEVICE_TO_DMA);
        if (status != XST_SUCCESS) {
            xil_printf("[FAIL] DMA S2MM transfer failed at offset %d\r\n", offset);
            fail_count++;
            continue;
        }

        status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)TxBuf, buffer_len, XAXIDMA_DMA_TO_DEVICE);
        if (status != XST_SUCCESS) {
            xil_printf("[FAIL] DMA MM2S transfer failed at offset %d\r\n", offset);
            fail_count++;
            continue;
        }

        while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {}
        while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA)) {}

        Xil_DCacheInvalidateRange((UINTPTR)RxBuf, buffer_len);

        int chunk_fail = 0;
        for (int i = 0; i < chunk; i++) {
            if (RxBuf[i] != TxBuf[i]) {
                xil_printf("[ERROR] Mismatch at offset %d, index %d: sent 0x%08X, got 0x%08X\r\n",
                           offset, i, TxBuf[i], RxBuf[i]);
                chunk_fail = 1;
                fail_count++;
                break;
            }
        }

        if (!chunk_fail) {
            xil_printf("[PASS] Chunk offset %5d OK (%d bytes)\r\n", offset, buffer_len);
        }
    }

    if (fail_count == 0) {
        xil_printf("\n[SUCCESS] All chunks passed loopback test!\r\n");
    } else {
        xil_printf("\n[SUMMARY] %d chunk(s) failed\r\n", fail_count);
    }

    xil_printf("[INFO] Loopback Test Complete\r\n");
    return XST_SUCCESS;
}
