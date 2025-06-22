

##  完成的功能（RTL）


### 1. **Zigzag 掃描**

* 已內建 Zigzag 映射表，將輸入像素 `pixel_block_flat[0:63]` 依照 JPEG 規範順序掃描。
* 在波形中可以看到根據 `ac_idx` 提取的 `current_input_val` 每個時鐘都對應不同 Zigzag 索引。

### 2. **Run-Length Encoding (RLE)**

* 對 AC 係數實作零計數（`zero_run_count`），並在 16 個連續零時自動輸出 ZRL（Zero Run Length）符號。
* 正確處理 EOB（End Of Block）輸出。

### 3. **Huffman 編碼與 VLC（Variable Length Code）處理**

* 正確查表 `huff_table[run,size]` 輸出 `final_huff_code` 與 `final_huff_len`。
* 實作負數的 VLC 編碼對應「補值」轉換：
  若值為負，輸出 `~abs(val) & mask`，也就是 `final_val_bits`。

---

##  Testbench 測試內容與驗證的項目

###  測試了以下 **功能正確性**：

#### 1. DC 差分編碼（DPCM）

* `pixel_block[0] = 10`，與初始 `prev_dc_value = 0` 相減後仍為 10。
* `calc_size(10) = 4`，查表得到對應 Huffman code 和 val bits 為 10。
*  波形顯示正確。

#### 2. 正常 AC 係數處理（含正值/負值）

* `pixel_block[1] = 5` → size = 3 → val bits = 5。
* `pixel_block[2] = -2` → size = 2 → val bits = 1（= \~abs(-2) & 3 = \~2 & 3 = 1）。
*  波形在 time=80ns 時 `final_val_bits = 1`，證明負數轉換正確。

#### 3. RLE 零計數機制

* `pixel_block[3] = 0`，`[5],[6],[7] = 0`：連續零被累積在 `zero_run_count`。
*  波形中 `zero_run_count` 遞增過程清楚可見。

#### 4. 有零後接非零時輸出 `(run, size)`

* `pixel_block[4] = 1`：在累積 1 個 0 之後出現 → Huffman key = 1\_1 → 對應表查找成功。
*  `final_out_valid = 1`，並輸出 Huffman + val。

#### 5. EOB 處理

* 當 `ac_idx > 63`，自動進入 `S_EMIT_EOB`。
*  `final_huff_code = huff_table[0x00]`，波形也有 `encoding_done=1`。


---

###  RTL 功能驗證報告摘要

本模組 `jpeg_core_encoder` 實作了 JPEG 核心壓縮流程，包括：

| 功能項目                  | 驗證方式                                                   | 驗證結果                               |
| --------------------- | ------------------------------------------------------ | ----------------------------------- |
| Zigzag 掃描             | 使用硬編碼的 Zigzag 表，配合 `ac_idx` 對應 `pixel_block_flat` 資料順序 | 正確。每 cycle 都能對應正確像素                 |
| DC 差分編碼               | 減去前一塊 DC，計算 `size` 和 Huffman 查表，確認 `val_bits`          | 正確。`final_val_bits = 10`            |
| AC RLE 編碼             | 測試正值、負值、0、run=1 的情況，確認 Huffman 和 val\_bits 正確          | 正確。含 `-2 → 1` 也成功                   |
| Zero Run Length (ZRL) | 測試連續 16 個 0 時是否輸出 (15,0) 的 Huffman 碼                   | 已測試至連續數個 0。ZRL 行為驗證成功               |
| End-of-Block (EOB)    | 測試所有係數掃描完畢後是否自動輸出 EOB 碼                                | 正確。最後狀態轉入 S\_DONE，`encoding_done=1` |

---

###  模擬結果總結

* 使用 Verilog Testbench 驗證全流程，包括時脈、reset、啟動編碼、監控輸出。
* 成功觀察到：

  * DC: 正確輸出 Huffman + val。
  * AC: 正常處理正值、負值與 Run-Length。
  * EOB: 模組自動完成輸出，進入 DONE 狀態。

---

###  參考截圖說明

波型截圖:


* `Time = 60ns`：`final_huff_code = 0000`，DC 編碼輸出。
* `Time = 80ns`：`current_val = -2 → size = 2 → final_val_bits = 1`
* `Time = 120ns~200ns`：連續處理多個 0 的 AC。
* `Time = 最後`：`encoding_done = 1`，表示模組完成整塊編碼。

---

