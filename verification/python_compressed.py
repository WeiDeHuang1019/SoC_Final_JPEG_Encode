import cv2
import os
from skimage.metrics import peak_signal_noise_ratio as psnr

# === 資料夾設定 ===
original_dir = "C:\photo\original"          # 原始圖片資料夾
compressed_dir = "C:\photo\python_compressed"       # 壓縮圖片存放資料夾
jpeg_quality = 60                   # JPEG 壓縮品質（0～100）

# 若壓縮資料夾不存在則建立
os.makedirs(compressed_dir, exist_ok=True)

# 支援的原圖副檔名
valid_exts = [".png", ".bmp", ".jpg", ".jpeg"]

# === 批次處理每張圖片 ===
for filename in os.listdir(original_dir):
    name, ext = os.path.splitext(filename)
    if ext.lower() not in valid_exts:
        continue  # 忽略非圖片檔

    original_path = os.path.join(original_dir, filename)
    compressed_filename = name + "_compressed.jpg"  # ✅ 改這裡
    compressed_path = os.path.join(compressed_dir, compressed_filename)

    # 讀取原圖
    original = cv2.imread(original_path)
    if original is None:
        print(f"❌ 無法讀取原始圖檔: {filename}")
        continue

    # 壓縮並儲存為 JPEG
    success = cv2.imwrite(compressed_path, original, [int(cv2.IMWRITE_JPEG_QUALITY), jpeg_quality])
    if not success:
        print(f"❌ 壓縮失敗: {filename}")
        continue

    # 讀取壓縮後圖檔
    compressed = cv2.imread(compressed_path)
    if compressed is None:
        print(f"❌ 無法讀取壓縮圖檔: {compressed_filename}")
        continue

    # 計算 PSNR
    psnr_value = psnr(original, compressed, data_range=255)

    # 計算壓縮比
    size_original = os.path.getsize(original_path)
    size_compressed = os.path.getsize(compressed_path)
    compression_ratio = size_original / size_compressed if size_compressed != 0 else 0

    # 顯示測試結果
    print(f"\n📂 測試檔案: {filename}")
    print(f"🔊 PSNR: {psnr_value:.2f} dB")
    print(f"📦 壓縮比: {compression_ratio:.2f}:1")

    # 驗收判定
    if compression_ratio >= 10 and psnr_value >= 30:
        print("✅ 通過壓縮率與品質驗收")
    else:
        print("❌ 驗收未通過")

