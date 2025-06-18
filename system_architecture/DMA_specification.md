以下是你這套 **基於 AXI DMA 傳輸 YCbCr MCU 區塊（Chunk-based）** 的「**規格書說明格式**」，適合放入報告或驗收文件：

---

## 📦 DMA 傳輸規格（MCU-based AXI DMA Streaming）

### 📘 模組名稱

`AXI_DMA_MCU_Stream`

---

### 🔧 傳輸方式

**Chunk-based AXI4-Stream 傳輸**（無 SG 模式）
每次傳送 **一個 MCU 區塊**（含 Y/Cb/Cr 資料）為單位，大小固定。

---

### 🟦 傳輸情境與目的

用於 JPEG 壓縮前置處理流程，將 `RGB` 轉換為 `YCbCr`，再進行：

* MCU 分塊重排（16×16 區塊）
* FPGA 硬體端進行 Chrominance Downsampling（4:2:0）
* 再將資料傳回記憶體以便儲存或後續壓縮處理

此方式最適合用於硬體加速前處理（如 DCT、Quantization、JPEG-Encoding 之前的影像準備）。

---

### 🟢 傳輸單位（Chunk）

每個 chunk 對應 **一個 MCU 區塊**，格式如下：

| 項目   | TX Input（傳給硬體）               | RX Output（從硬體接回）           |
| ---- | ---------------------------- | -------------------------- |
| 大小   | `768 bytes`                  | `384 bytes`                |
| 結構   | `Y[256] + Cb[256] + Cr[256]` | `Y[256] + Cb[64] + Cr[64]` |
       |

---

### 🔌 AXI DMA 傳輸流程

| 步驟 | 操作                                  |
| -- | ----------------------------------- |
| 1  | PS 端讀取 `image.rgb` 並轉成 YCbCr        |
| 2  | 依照 MCU 分塊排序重組  |
| 3  | 每次將 `768 bytes` 傳給硬體                |
| 4  | 硬體做 chroma downsampling（4:2:0）      |
| 5  | 回傳 `384 bytes`（Y:256, Cb:64, Cr:64） |
| 6  | PS 收集後重組完整             |
| 7  | 儲存為 `.ycb` 檔案供後續壓縮使用                |

---

### 📥 輸入格式（TX to FPGA）

輸入.rgb檔
與其圖像之長度、寬度

---

### 📤 輸出格式（RX from FPGA）

| 區段 | 位元組範圍      | 說明                    |
| -- | ---------- | --------------------- |
| Y  | 0 \~ 255   | 保留原始 Luminance（16×16） |
| Cb | 256 \~ 319 | Downsampled Cb（8×8）   |
| Cr | 320 \~ 383 | Downsampled Cr（8×8）   |

---

### 📎 備註

* DMA 模式：**Simple Mode**
* 支援圖片尺寸需為 `16 × 16` 的整數倍，避免 MCU 邊界錯誤
* 適用於 JPEG 壓縮前資料準備


---
