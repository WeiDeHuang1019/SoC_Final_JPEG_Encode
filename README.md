

# 基於 FPGA 的 JPEG 壓縮系統

本專案實作一個可在 Zynq SoC 平台上運行的 **硬體加速 JPEG 壓縮系統**，使用 Verilog RTL 撰寫 JPEG 編碼核心，並整合 AXI 架構、SD 卡影像讀寫、以及 PSNR等品質驗證工具。

---
BREAK DOWN
![螢幕擷取畫面 2025-06-20 201540](https://github.com/user-attachments/assets/8a93c548-5285-4dfe-909a-55bb45f8eb58)


---

## 專案結構

```
JPEG_Compression_Project/
├── src/              # 硬體與軟體程式碼、API規格書
├── demo/             # 實際Demo影片與介紹
├── specification.md  # 五大規格書
└── README.md         # 專案介紹文件（本檔案）
```


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
* **圖像格式**：`.rgb`（RGB888 原始影像）

---

## 運作流程

1. 將 `.rgb` 圖片放入 SD 卡
2. 將 bitstream 與 SDK 程式燒錄至板子
3. 執行壓縮流程：讀圖 → 壓縮 → 存檔
4. 使用 `verification/python_tools` 進行壓縮品質評估

## 🔧 目前進度
截至期末，
目前已成功完成 **Chroma Downsampling 模組整合與驗證**及**DMA+AXI Stream系統架構**，能將 RGB 原始圖像轉換為 **4:2:0 格式的 YCbCr**，解析度支援達 **2048×2048**以上，並使用 **AXI-Stream + DMA** 架構進行分段式傳輸，每次傳送 768 筆資料（對應一個 16×16 MCU 區塊）。

目前 **DCT + 量化**、**Zigzag + RLE + Huffman 編碼模組** 已完成 Verilog 端 API 介面規劃與功能模組的單元測試，但尚未整合進完整電路架構。
![螢幕擷取畫面 2025-06-22 123513](https://github.com/user-attachments/assets/d7ef316d-230f-4e71-985e-7bea2ff07388)

---

## 工作分配

**黃維得(組長)**:負責系統架構設計、Chroma_Downsampling單元測試  
**陳品妤**:JPEG壓縮理論研究、DCT_and_Quantization單元測試  
**劉豐茗**:品質與功能驗證、Zigzag_RLE_Huffman_Encoder單元測試  

