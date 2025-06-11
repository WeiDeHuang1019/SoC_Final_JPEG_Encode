

---

# JPEG 壓縮系統功能驗證說明

本目錄包含本系統於 Zynq SoC 上實作 JPEG 壓縮之驗證流程與條件，透過 **Python 分析、Vivado 報告與模擬結果**，確認功能正確、效能達標且資源使用可接受。

---

## 驗收條件

### 1️. 壓縮後影像可正確解碼

* Python 使用 `cv2.imread()` 成功讀取壓縮後 JPEG 圖檔。
* 驗證能夠正常顯示影像內容，無明顯破圖或錯誤。

---

### 2️. 壓縮率達標：壓縮比 ≥ 10:1

* 測試圖檔：1920×1080 彩色影像
* 原始圖檔大小：約 6MB（RGB888）
* 壓縮後 JPEG 大小應小於 **608KB**
* 使用 `os.path.getsize()` 比較原圖與壓縮後大小

---

### 3️. 影像品質要求：PSNR ≥ 30 dB

* 使用以下 PSNR 公式比較原圖與解碼圖像品質：

  $$
  \text{MSE} = \frac{1}{mn} \sum_{i=1}^{m} \sum_{j=1}^{n} [I(i,j) - K(i,j)]^2
  $$

  $$
  \text{PSNR} = 10 \cdot \log_{10}\left(\frac{{MAX}^2}{\text{MSE}}\right)
  $$

* Python 中使用 `skimage.metrics.peak_signal_noise_ratio()` 計算 PSNR。

---

### 4️. FPGA 邏輯資源使用率 < 50%

* 使用 Vivado 完成 Implementation 後，開啟 Utilization Report。
* 驗證 LUT、FF、BRAM 等 FPGA 資源使用皆低於 50%。

---

### 5️. 延遲需求：128×128 圖片壓縮延遲 ≤ 3ms

* 透過 RTL Testbench + Vivado Simulation 模擬延遲。

* 根據模擬波形計算總週期數，使用下式計算延遲：

  $$
  \text{Latency Time} = \frac{\text{Cycle Count}}{\text{Clock Frequency (Hz)}}
  $$

* 確保壓縮一張 128x128 圖片所花費的時間不超過 3 毫秒。

---

## 驗證方式說明

| 項目      | 工具                | 驗證方式                        |
| ------- | ----------------- | --------------------------- |
| 解碼正確    | Python / OpenCV   | `cv2.imread()`              |
| 壓縮比     | Python            | `os.path.getsize()`         |
| PSNR 計算 | Python / skimage  | `peak_signal_noise_ratio()` |
| FPGA 資源 | Vivado            | Utilization Report          |
| 延遲      | Vivado Simulation | 模擬波形觀察總週期數                  |

---


