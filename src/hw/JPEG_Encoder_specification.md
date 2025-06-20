
# JPEG 壓縮模組總覽與原理說明

本專案實作 JPEG 壓縮流程中的三大模組，包含：

- Chroma Downsampling 模組
- 2D DCT + Quantization 模組
- Zig-Zag + RLE + Huffman 編碼模組

---

## 🔲 模組 1：Chroma Downsampling 模組

### 模組功能說明

在 JPEG 壓縮中，人眼對明亮度（Luminance, Y）較敏感，對色度（Chrominance, Cb/Cr）較不敏感，因此對 Cb 與 Cr 分量進行 **4:2:0 下採樣** 可有效壓縮資料量。

本模組功能為：
- 接收 YCbCr 資料流
- 對 Cb、Cr 分量進行 **8×8 → 4×4** 下採樣
- 保留 Y 分量完整

---

### 原理與數學公式

對每個 8×8 的 Cb 或 Cr 區塊，進行 2×2 平均合併：

$$
Cb'_{i,j} = \frac{1}{4} \left( Cb_{2i,2j} + Cb_{2i,2j+1} + Cb_{2i+1,2j} + Cb_{2i+1,2j+1} \right)
$$

結果為一個 4×4 區塊（共 16 個像素）。

---

### MCU（最小編碼單元）定義

- 每個 MCU 對應 **16×16 像素**
  - Y 分量 → 切為 4 個 8×8 區塊
  - Cb/Cr → 以 2×2 合併 → 生成 8×8 色度區塊（downsampled）

---

## 🔲模組 2：2D DCT + Quantization 模組

### 模組功能說明

DCT（Discrete Cosine Transform）將像素從空間域轉換為頻域，是 JPEG 的核心步驟。對每個 8×8 區塊進行 2D DCT 後，使用標準量化表對結果進行**有損壓縮**。

---

### DCT 數學公式

#### DCT-II（8×8）：

$$
F(u,v) = \frac{1}{4} C(u) C(v) \sum_{x=0}^{7} \sum_{y=0}^{7} f(x,y) \cos\left( \frac{(2x+1)u\pi}{16} \right) \cos\left( \frac{(2y+1)v\pi}{16} \right)
$$

其中：

$$
C(w) = \begin{cases}
\frac{1}{\sqrt{2}}, & w = 0 \\
1, & w > 0
\end{cases}
$$

---

### 矩陣化表示

令 $X$ 為輸入 8×8 區塊：

$$
F = A \cdot X \cdot A^T
$$

- $A$ 為 DCT 基底矩陣
- $A^T$ 為其轉置



---

### 量化公式

將 DCT 結果除以對應的量化表 Q，再四捨五入：

$$
F_q(u,v) = \text{round} \left( \frac{F(u,v)}{Q(u,v)} \right)
$$

---

## 🔲模組 3：Zig-Zag + RLE + Huffman 編碼模組

### 模組功能說明

此模組將量化後的 8×8 區塊進行：
- **Zig-Zag 掃描**
- **Run-Length Encoding (RLE)** 壓縮 0
- **Huffman 編碼** 生成最終 bitstream

---

### DC 值編碼流程

1. 計算差值：
   $$
   DC_{\text{diff}} = DC_{curr} - DC_{prev}
   $$
2. 計算 bit size（以表示差值所需位元數）
3. 查 DC Huffman 表，以 size 為 key 查表
4. 合併：`Huffman code + Value bits`

---

### AC 值編碼流程

1. 使用 RLE：將連續 0 編為 `(Run, Value)`
2. 轉為 `(Run, Size)`，其中 Size 為 Value 的 bit 長度
3. 查 AC Huffman 表，以 `(Run << 4) + Size` 為 key
4. 合併：`Huffman code + Value bits`

---

### 範例

Zig-Zag 資料：  
`DC = 4, AC = 0, 0, -5, 0, 0, 0, 2, 0, 0, 0, 0, 0, 1...`

RLE:  
`(2, -5), (3, 2), (5, 1)`

Value bits + Size:

| Value | Bits | Size |
|-------|------|------|
| -5    | 101  | 3    |
| 2     | 10   | 2    |
| 1     | 1    | 1    |

Huffman Codes:

| (Run, Size) | Huffman |
|-------------|---------|
| (2,3)       | 11011   |
| (3,2)       | 1110010 |
| (5,1)       | 1111110 |

Bitstream 組合：

| 資料         | Huffman   | Value bits | 結果        |
|--------------|-----------|------------|-------------|
| DC: 4        | 010       | 100        | 010100      |
| AC: (2,-5)   | 11011     | 101        | 11011101    |
| AC: (3,2)    | 1110010   | 10         | 111001010   |
| AC: (5,1)    | 1111110   | 1          | 11111101    |

---

## 總結

JPEG 壓縮流程模組設計，內容包含了：

- **Chroma 下採樣**（資料壓縮1/2）
- **DCT + 量化**（轉頻率、壓縮）
- **Zig-Zag + RLE + Huffman**（最終 bitstream 壓縮）

搭配 AXI-Stream 與 DMA 傳輸，實現高速、硬體化的 JPEG 壓縮應用。
