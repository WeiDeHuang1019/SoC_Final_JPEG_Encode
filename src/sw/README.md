##  資料流與 SDK 執行流程說明

本系統資料處理流程如下：

1. **SD 卡讀取圖片**
   - 使用 FatFs 函式 `f_open` 與 `f_read` 讀入一張 `.rgb` 圖片（RGB888 格式）。
   - 圖片資料會載入至 DDR 中的 TX 緩衝區 (`TX_BUFFER_BASE`)。

2. **RGB 轉換與 MCU 排序**
   - 將 RGB 資料轉換成 planar 格式的 Y, Cb, Cr 三通道。
   - 接著依據 MCU (Minimum Coded Unit) 16×16 區塊大小，將 Y, Cb, Cr 依序排列為 768 bytes/MCU（Y=256, Cb=256, Cr=256）。

3. **DMA 傳輸 - TX（DMA_TO_DEVICE）**
   - 使用 `XAxiDma_SimpleTransfer()` 以分段方式將每個 MCU 傳送至 PL（硬體電路）。
   - 每傳送一次 768 bytes 至硬體 IP。
   - DMA 使用 non-SG (Simple Mode) 模式，支援簡單的 burst 傳輸。

4. **硬體模組處理圖像**
   - PL 端包含一連串的硬體模組（如 chroma downsampling），進行 JPEG 編碼前處理。(***截至期末系統只成功整合"chroma downsampling"模組***)。
   

5. **DMA 接收 - RX（DEVICE_TO_DMA）**
   - 處理後的資料由 PL 傳回 PS，透過 `XAxiDma_SimpleTransfer()` 將處理完的資料接收進 RX buffer。
   

6. **將處理後資料寫回 SD 卡**
   - 資料從 RX buffer 寫入 SD 卡中，代表已完成 JPEG 壓縮處理步驟。

---

###  SDK 程式補充說明（摘要）

| 區段 | 功能 |
|------|------|
| `f_open` / `f_read` | 從 SD 卡讀入 `.rgb` 原圖 |
| RGB 轉換 | 使用浮點公式轉換為 YCbCr |
| MCU 打包 | 每塊 MCU 768 bytes，重新排序 |
| `XAxiDma_SimpleTransfer` | 啟動 AXI DMA 傳送 / 接收 |
| `Xil_DCacheFlushRange` | 確保資料一致性 |
| `f_write` | 將 `.ycb` 結果寫回 SD 卡 |

➡️ 每個 MCU 分批傳送，支援高解析度壓縮流程。