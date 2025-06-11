# JPEG Encoder IP Specification

## 📥 Input

| 名稱               | 類型          | 說明 |
|--------------------|---------------|------|
| `s_axis_tdata`     | AXI4-Stream   | Y/Cb/Cr 資料（通常為 8-bit 或 16-bit）|
| `s_axis_tvalid`    | AXI4-Stream   | 有效資料指示 |
| `s_axis_tready`    | AXI4-Stream   | IP 準備接收資料 |
| `s_axis_tlast`     | AXI4-Stream   | 一個影像結束指示 |
| `aclk`             | Clock         | 全系統時脈 |
| `aresetn`          | Active-Low Reset | 重設信號 |
| (可選) `config_*`  | 控制訊號（AXI-Lite or input pins）| 設定品質、Q-table、image size 等參數 |

---

## 📤 Output

| 名稱               | 類型          | 說明 |
|--------------------|---------------|------|
| `m_axis_tdata`     | AXI4-Stream   | JPEG Bitstream 壓縮資料（8-bit）|
| `m_axis_tvalid`    | AXI4-Stream   | 有效輸出資料指示 |
| `m_axis_tready`    | AXI4-Stream   | 接收者準備好接資料 |
| `m_axis_tlast`     | AXI4-Stream   | 一張圖的 bitstream 結尾指示 |
| (可選) `output_length` | AXI-Lite 寄存器 | JPEG Bitstream 的總長度（Bytes）|

---

## ⚙️ Attributes

| 屬性         | 說明                                   |
|--------------|----------------------------------------|
| 支援解析度   | 1980x1024，或於SDK事先設定   |
| 色彩格式     | 接收 YCbCr（4:2:0）             |
| MCU 結構     | 每 MCU：4 個 Y block + 1 Cb + 1 Cr     |
| 傳輸介面     | 完全 AXI4-Stream 相容                  |

---

## 🛠 Parameters（可透過 AXI-Lite 設定）

| 名稱             | 預設值     | 說明                           |
|------------------|------------|--------------------------------|
| `IMAGE_WIDTH`     | 128        | 圖片寬度（像素）               |
| `IMAGE_HEIGHT`    | 128        | 圖片高度（像素）               |
| `COLOR_SUBSAMPLE` | 4:2:0      | YCbCr 子取樣格式               |
| `QUALITY_FACTOR`  | 50         | 壓縮品質參數（影響 Q-table）  |
| `DATA_WIDTH`      | 8          | `tdata` 寬度（8 or 16）        |

---

## 🧠 Method（運作方式）

1. **接收資料**  
   透過 AXI4-Stream 接收連續的 YCbCr 區塊資料

2. **DCT（離散餘弦轉換）**  
   對每個 8×8 區塊進行 2D DCT 轉換。

3. **Quantization（量化）**  
   使用 Q-table 對 DCT 結果進行量化（壓縮）。

4. **Huffman Encoding（哈夫曼編碼）**  
   將量化後的係數轉換成變長 bitstream（JPEG Bitstream）。

5. **資料輸出**  
   壓縮後資料以 AXI4-Stream 格式輸出，直到 `tlast = 1` 為止。

---

## 📘 備註

- 輸出的 bitstream 可直接寫成 `.jpg` 檔。
- 可與 AXI DMA 搭配，透過 DMA 將輸出寫入 DDR。
- 若不確定輸出長度，可根據 `tlast` 偵測結束，或使用附加 `output_length` 註冊。

