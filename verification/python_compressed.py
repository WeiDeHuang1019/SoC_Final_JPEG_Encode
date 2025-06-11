import os
import cv2
import numpy as np
from PIL import Image
from skimage.metrics import peak_signal_noise_ratio as psnr

# ====== 設定區 ======
original_png_path = r"C:\photo\original\kodim01.png"   # 輸入 PNG 圖片（未壓縮）
compressed_jpeg_path = r"C:\photo\python_compressed\kodim_compress.jpg"  # 產生的 JPEG 路徑
jpeg_quality = 60                            # JPEG 壓縮品質（10~100）

# ====== Step 1: PNG → JPEG 壓縮 ======
def compress_png_to_jpeg(png_path, jpeg_path, quality):
    img = Image.open(png_path)
    img = img.convert("RGB")  # 確保轉成 RGB 格式
    img.save(jpeg_path, "JPEG", quality=quality)
    print(f"✅ 壓縮完成：{jpeg_path}（quality={quality}）")

# ====== Step 2: 計算 PSNR & 壓縮比 ======
def calculate_psnr_and_compression_ratio(original_path, jpeg_path):
    original = cv2.imread(original_path)
    compressed = cv2.imread(jpeg_path)

    if original is None or compressed is None:
        print("❌ 讀取圖檔失敗")
        return

    # 自動調整尺寸（避免大小不一致）
    if original.shape != compressed.shape:
        compressed = cv2.resize(compressed, (original.shape[1], original.shape[0]))

    # PSNR 計算
    psnr_value = psnr(original, compressed, data_range=255)

    # 檔案大小與壓縮比
    size_original = os.path.getsize(original_path)
    size_jpeg = os.path.getsize(jpeg_path)
    compression_ratio = size_original / size_jpeg

    # 顯示結果
    print(f"🔊 PSNR：{psnr_value:.2f} dB")
    print(f"📦 壓縮比：{compression_ratio:.2f}:1")

    return psnr_value, compression_ratio

# ====== 執行流程 ======
compress_png_to_jpeg(original_png_path, compressed_jpeg_path, jpeg_quality)
calculate_psnr_and_compression_ratio(original_png_path, compressed_jpeg_path)
