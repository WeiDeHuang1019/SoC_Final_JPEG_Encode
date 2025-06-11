#include "xparameters.h"
#include "xaxidma.h"
#include "xil_printf.h"
#include "xil_cache.h"

#define DMA_DEV_ID        XPAR_AXIDMA_0_DEVICE_ID

#define DDR_BASE_ADDR     0x01000000
#define TX_BUFFER_BASE    (DDR_BASE_ADDR + 0x00000000)
#define RX_BUFFER_BASE    (DDR_BASE_ADDR + 0x00100000)
#define BUFFER_LENGTH     256  // 傳輸 256 Bytes

#define TEST_START_VALUE  0xC0

int main() {
    XAxiDma AxiDma;
    XAxiDma_Config *CfgPtr;
    int status;

    xil_printf("AXI DMA Loopback Test Start...\r\n");

    // 1. 取得 DMA 設定
    CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (!CfgPtr) {
        xil_printf("ERROR: No config found for DMA ID %d\r\n", DMA_DEV_ID);
        return XST_FAILURE;
    }

    // 2. 初始化 DMA
    status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: DMA initialization failed\r\n");
        return XST_FAILURE;
    }

    // 3. 確認 DMA 是 simple 模式（非 SG）
    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("ERROR: Device configured as Scatter-Gather, not Simple mode\r\n");
        return XST_FAILURE;
    }

    // 4. 準備資料
    u8 *TxBufferPtr = (u8 *)TX_BUFFER_BASE;
    u8 *RxBufferPtr = (u8 *)RX_BUFFER_BASE;

    for (int i = 0; i < BUFFER_LENGTH; i++) {
        TxBufferPtr[i] = (u8)(TEST_START_VALUE + i);
        RxBufferPtr[i] = 0; // 清空接收 buffer
    }

    Xil_DCacheFlushRange((UINTPTR)TxBufferPtr, BUFFER_LENGTH);
    Xil_DCacheFlushRange((UINTPTR)RxBufferPtr, BUFFER_LENGTH);

    // 5. 啟動 S2MM（接收資料）
    status = XAxiDma_SimpleTransfer(&AxiDma,
                                    (UINTPTR)RxBufferPtr,
                                    BUFFER_LENGTH,
                                    XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: DMA S2MM transfer failed\r\n");
        return XST_FAILURE;
    }

    // 6. 啟動 MM2S（傳送資料）
    status = XAxiDma_SimpleTransfer(&AxiDma,
                                    (UINTPTR)TxBufferPtr,
                                    BUFFER_LENGTH,
                                    XAXIDMA_DMA_TO_DEVICE);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: DMA MM2S transfer failed\r\n");
        return XST_FAILURE;
    }

    // 7. 等待傳輸完成
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {}
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA)) {}

    Xil_DCacheInvalidateRange((UINTPTR)RxBufferPtr, BUFFER_LENGTH);

    // 8. 驗證結果
    for (int i = 0; i < BUFFER_LENGTH; i++) {
        if (RxBufferPtr[i] != TxBufferPtr[i]) {
            xil_printf("Mismatch at index %d: sent 0x%02X, received 0x%02X\r\n",
                       i, TxBufferPtr[i], RxBufferPtr[i]);
            return XST_FAILURE;
        }
    }

    xil_printf("AXI DMA Loopback Test PASSED!\r\n");
    return XST_SUCCESS;
}
