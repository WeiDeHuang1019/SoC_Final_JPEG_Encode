

# 系統架構說明

本系統架構基於 Zynq-7000 SoC 平台（XC7Z020），採用 AXI 總線整合 Processing System（PS）與 Programmable Logic（PL），實作 JPEG 壓縮流程中的資料搬移與處理流程。

---

## 架構總覽圖

![螢幕擷取畫面 2025-06-11 141255](https://github.com/user-attachments/assets/60488433-54b9-4855-a896-28fab3cdd992)


## 系統模組簡介

### 1. `processing_system7_0`（ZYNQ7 Processing System）

* 負責從 SD 卡載入 `.rgb` 圖檔至 DDR 記憶體。
* 透過 AXI DMA 傳送影像資料給 PL 端。
* 控制與初始化整體運作流程。
* 包含 M\_AXI\_GP0 與 S\_AXI\_HP0 介面（主從通訊）。

### 2. `axi_dma_0`（AXI Direct Memory Access）

* 實現 DDR 與 PL 之間的高效資料搬移。
* 使用 **S2MM（Stream to Memory-Mapped）** 與 **MM2S（Memory-Mapped to Stream）** 雙通道配置。
* 控制信號由 PS 透過 S\_AXI\_LITE 設定。
* 搭配 `s_axis_s2mm` / `m_axis_mm2s` 處理資料流。

### 3. `stream_loopback_0`（使用者邏輯 / 未來可取代為 JPEG 核心）

* 此為測試用 Loopback 模組，僅將輸入資料原封不動回傳。
* 實際設計中，會取代為 JPEG Encoder 核心（DCT、量化等模組）。

### 4. `axis_register_slice_0` 與 `axis_register_slice_1`

* 負責緩衝與時脈域分離，穩定 AXI4-Stream 資料傳輸。
* 放置在 DMA 與使用者邏輯之間。

### 5. `axi_smc`（AXI SmartConnect）

* 處理 AXI 總線主從仲裁與路由。
* PS 與 DMA、使用者 IP 模組之間的 AXI 互聯樞紐。

### 6. `xlconcat_0`

* 將 `s2mm_introut` 和 `mm2s_introut` 中斷信號合併為一條輸出 IRQ，提供給 PS 端中斷處理。

### 7. `ps7_0_axi_periph`、`rst_ps7_0_100M`

* 負責 AXI 總線時脈與重置信號控制。
* 統一整合 PL 中的時脈與 Reset 訊號來源。

---

## 整體資料流流程

1. **PS** 從 SD 卡讀取 `.rgb` 檔案至 DDR。
2. **AXI DMA (MM2S)** 從 DDR 取出影像資料，以 AXI4-Stream 傳送至 PL。
3. **PL（目前為 stream\_loopback\_0）** 接收資料並回傳（未來為 JPEG 壓縮核心）。
4. **AXI DMA (S2MM)** 將處理後資料寫回 DDR。
5. **PS** 透過中斷得知處理完成，並可將結果回存 SD 卡或傳輸至主機端。
