

##  模組名稱：`jpeg_core_encoder`

---

### 1️⃣ Input（輸入）

| 名稱                 | 寬度       | 說明                             |
| ------------------ | -------- | ------------------------------ |
| `clk`              | 1        | 系統時脈                           |
| `rst`              | 1        | 非同步 reset，active high          |
| `start_encoding`   | 1        | 啟動一筆 JPEG 區塊編碼流程的觸發信號          |
| `pixel_block_flat` | 512 bits | 扁平化的一個 8×8 區塊（共 64 筆 8-bit 資料） |

---

### 2️⃣ Output（輸出）

| 名稱                | 寬度      | 說明                              |
| ----------------- | ------- | ------------------------------- |
| `final_huff_code` | 16 bits | Huffman code 對應的位元字串            |
| `final_huff_len`  | 4 bits  | Huffman code 的實際長度（bit）         |
| `final_val_bits`  | 8 bits  | 除 Huffman code 外之數值 bits（以補碼表示） |
| `final_out_valid` | 1 bit   | 輸出資料有效旗標                        |
| `encoding_done`   | 1 bit   | 本 8×8 區塊編碼完成旗標                  |

---

### 3️⃣ Method（運作方式）

此模組整合以下 JPEG 編碼步驟：

####  Zig-Zag 掃描

* 內建 64 項查找表 ROM，根據順序取出像素值（無需外部排序）
* `pixel_block_flat` 作為連續打包輸入，透過 `zigzag_table` 對應位置擷取值

####  Run-Length Encoding (RLE)

* 偵測連續 0 的數量
* 若 0 達 16 筆，產生 ZRL (Zero Run Length) 訊號

####  Huffman 編碼

* 查表方式查詢 `(Run, Size)` → Huffman code（16-bit ROM）
* DC 編碼使用差分 + category 計算

####  狀態機控制

* 單一 FSM 控制整個過程，共六個狀態（S\_IDLE、S\_PROC\_DC、S\_PROC\_AC、S\_EMIT\_ZRL、S\_EMIT\_EOB、S\_DONE）
* 每個 clock cycle 處理一筆係數（流式結構）

---

### 4️⃣ Use Case（應用場景）

| 場景                   | 說明                                      |
| -------------------- | --------------------------------------- |
|  JPEG 編碼器的後端       | 負責將已經 DCT 與量化後的 8×8 區塊轉換為 bitstream     |
|  多 MCU 串流壓縮        | 搭配 AXI-Stream 或 FIFO 輸入，可進行多區塊連續處理      |
|  單元測試驗證            | 可與 Python 驗證腳本對照 bitstream 正確性          |
|  AXI pipeline 壓縮架構 | 未來可封裝為 AXI-Stream slave/producer 串接其他模組 |

---

### 5️⃣ Attributes（模組特性）

| 特性           | 說明                                     |
| ------------ | -------------------------------------- |
|  **智慧結構**  | 單一 FSM 控制整合 ZigZag、RLE、Huffman，資源效率高   |
|  **高效處理**  | 每個時脈週期輸出一組係數編碼，支持連續處理                  |
|  **低資源需求** | 無需中間緩衝 ZigZag 結果，節省暫存器                 |
|  **可重複啟動** | 每處理完一個 block，可重新接受 `start_encoding` 指令 |
|  **可拓展性強** | Huffman 表格可擴充支援 DC/AC 不同通道與色彩分量        |

---


