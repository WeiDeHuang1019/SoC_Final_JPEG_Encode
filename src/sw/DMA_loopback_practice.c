#include "xparameters.h"
#include "xaxidma.h"
#include "xil_printf.h"
#include "xil_cache.h"

#define DMA_DEV_ID        XPAR_AXIDMA_0_DEVICE_ID

#define DDR_BASE_ADDR     0x01000000
#define TX_BUFFER_BASE    (DDR_BASE_ADDR + 0x00000000)
#define RX_BUFFER_BASE    (DDR_BASE_ADDR + 0x00100000)

#define WORD_COUNT        64                     // 傳送 64 個 u32
#define BUFFER_LENGTH     (WORD_COUNT * 4)       // 256 bytes

#define TEST_START_VALUE  0xC0000000

int main() {
    XAxiDma AxiDma;
    XAxiDma_Config *CfgPtr;
    int status;

    xil_printf("\n[INFO] AXI DMA Loopback Test Start\n\r");

    // 1. 取得 DMA 設定
    CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (!CfgPtr) {
        xil_printf("[ERROR] No config found for DMA ID %d\r\n", DMA_DEV_ID);
        return XST_FAILURE;
    }

    // 2. 初始化 DMA
    status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (status != XST_SUCCESS) {
        xil_printf("[ERROR] DMA initialization failed\r\n");
        return XST_FAILURE;
    }

    // 3. 確認 DMA 為 Simple Mode（非 SG）
    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("[ERROR] DMA configured as Scatter-Gather\r\n");
        return XST_FAILURE;
    }

    // 4. 準備資料
    u32 *TxBufferPtr = (u32 *)TX_BUFFER_BASE;
    u32 *RxBufferPtr = (u32 *)RX_BUFFER_BASE;

    for (int i = 0; i < WORD_COUNT; i++) {
        TxBufferPtr[i] = TEST_START_VALUE + i;
        RxBufferPtr[i] = 0;
    }

    // 5. Cache flush，避免 cache 與 DDR 不一致
    Xil_DCacheFlushRange((UINTPTR)TxBufferPtr, BUFFER_LENGTH);
    Xil_DCacheFlushRange((UINTPTR)RxBufferPtr, BUFFER_LENGTH);

    // 6. 啟動 DMA 接收（S2MM）
    status = XAxiDma_SimpleTransfer(&AxiDma,
                                    (UINTPTR)RxBufferPtr,
                                    BUFFER_LENGTH,
                                    XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) {
        xil_printf("[ERROR] DMA S2MM transfer failed\r\n");
        return XST_FAILURE;
    }

    // 7. 啟動 DMA 傳送（MM2S）
    status = XAxiDma_SimpleTransfer(&AxiDma,
                                    (UINTPTR)TxBufferPtr,
                                    BUFFER_LENGTH,
                                    XAXIDMA_DMA_TO_DEVICE);
    if (status != XST_SUCCESS) {
        xil_printf("[ERROR] DMA MM2S transfer failed\r\n");
        return XST_FAILURE;
    }

    // 8. 等待傳輸完成
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {}
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA)) {}

    // 9. Cache invalidate，確保讀回的是最新資料
    Xil_DCacheInvalidateRange((UINTPTR)RxBufferPtr, BUFFER_LENGTH);

    // 10. 驗證資料
    for (int i = 0; i < WORD_COUNT; i++) {
        if (RxBufferPtr[i] != TxBufferPtr[i]) {
            xil_printf("[ERROR] Mismatch at index %d: sent 0x%08X, received 0x%08X\r\n",
                       i, TxBufferPtr[i], RxBufferPtr[i]);
            return XST_FAILURE;
        }
    }

    xil_printf("[SUCCESS] AXI DMA Loopback Test PASSED!\n\r");
    return XST_SUCCESS;
}
