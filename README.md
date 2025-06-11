

# 基於 FPGA 的 JPEG 壓縮系統

本專案實作一個可在 Zynq SoC 平台上運行的 **硬體加速 JPEG 壓縮系統**，使用 Verilog RTL 撰寫 JPEG 編碼核心，並整合 AXI 架構、SD 卡影像讀寫、以及 PSNR / SSIM 等品質驗證工具。

---

## 專案結構

```
JPEG_Compression_Project/
├── jpeg_encoder_ip/        # JPEG 壓縮核心模組 (DCT、量化、Zigzag 等)
├── system_architecture/    # 系統架構設計與 AXI 配置
├── verification/           # 功能驗證、影像比較、SDK 程式碼
└── README.md               # 專案介紹文件（本檔案）
```

---

## 各模組說明

### 1. `jpeg_encoder_ip/`

此資料夾包含 JPEG 編碼的 RTL 設計內容，主要模組包括：

* 8×8 DCT 轉換器
* 標準量化矩陣處理與 Zigzag 掃描等
* AXI 介面封裝與控制邏輯

### 2. `system_architecture/`

此部分描述整個 JPEG 系統的硬體架構，包括：

* Vivado Block Design 圖（包含 PS 與 PL 的 AXI 連接）
* AXI4-Stream、AXI4-Lite 等通訊介面
* DDR/BRAM 配置與位址對應關係

### 3. `verification/`

驗證資料夾包含以下內容：

* Python 程式：用於影像 RGB 轉換、PSNR計算等
* SDK 程式：負責讀寫 SD 卡、呼叫 JPEG 核心
* 測試影像：原始與壓縮後圖片，用來比較品質與壓縮率

---

## 專案目標

設計一套可於 FPGA 實作的 JPEG 壓縮系統，具有下列特性：

* 整合 AXI 介面，可與 ARM 核心協同運作
* 支援 SD 卡讀取原始影像，進行壓縮後存回
* 可擴展至即時相機壓縮、邊緣裝置影像處理、AI 前處理等應用

---

## 開發環境

* **平台**：Zynq-7000 (如 EGO XZ7, XC7Z020)
* **設計工具**：Vivado 2018.3
* **語言**：Verilog RTL、C（SDK）、Python（驗證）
* **影像格式**：`.rgb`（RGB888 原始影像）

---

## 運作流程

1. 將 `.rgb` 圖片放入 SD 卡
2. 將 bitstream 與 SDK 程式燒錄至板子
3. 執行壓縮流程：讀圖 → 壓縮 → 存檔
4. 使用 `verification/python_tools` 進行壓縮品質評估

## 工作分配
**黃維得(組長)**:負責系統架構設計
**陳品妤**:JPEG壓縮核心IP
**劉豐茗**:品質與功能驗證

