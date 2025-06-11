
---

# JPEG Encoder 核心模組說明

本資料夾包含本專案中預計設計與實作之 **JPEG 壓縮核心模組（JPEG Encoder）**，其目標為在 FPGA 上實現 JPEG 壓縮流程，整合 DCT、Quantization、Zigzag、Chrominance Downsampling 等主要模組，並透過 AXI Stream 與 DMA 完成系統整合。

---

## 模組架構（初步規劃）

JPEG Encoder 預計包含以下功能模組：

1. **Chrominance Downsampling（色度下採樣）**

   * 將原始影像從 RGB888 轉換為 YCbCr，並針對 Cb、Cr 通道進行 4:2:0 下採樣。
   * 降低色彩資訊冗餘，提升壓縮效率。
   * 常見操作為將每 2×2 區塊的 Cb、Cr 做平均，降低為 1/4 原始解析度。

2. **DCT（離散餘弦轉換）**

   * 對 Y、Cb、Cr 區塊分別進行 8×8 DCT。
   * 將像素區塊轉換為頻域表示。

3. **Quantization（量化）**

   * 對 DCT 係數使用 JPEG 標準量化矩陣進行壓縮。
   * 支援可調整品質的 Q-factor。

4. **Zigzag Scan**

   * 將 8×8 量化後的頻域係數轉換為一維向量，利於後續壓縮。

5. **Huffman Encoding**

   * 可擴充的可選模組，進一步進行 VLC 編碼，提高壓縮率。

---

## AXI 接口與整合

* **輸入格式**：AXI4-Stream 傳送 8×8 區塊（RGB 或 YCbCr）
* **輸出格式**：AXI4-Stream 輸出壓縮後資料（或 zigzag 順序資料）
* 可與 AXI DMA 搭配運作：
  `DDR → MM2S → JPEG Encoder → S2MM → DDR`


---


## 後續工作計畫

* 完成 Chrominance Downsampling RTL 初版
* 整合 DCT、Quantization 子模組
* 接上 AXI4-Stream 資料傳輸鏈
* 模組化設計、撰寫 testbench 驗證正確性與延遲

---


