import numpy as np
from scipy.fftpack import dct, idct

def jpeg_dct_quantization(block):
    # 1. DC shift: center around 0
    block = block.astype(np.int32) - 128

    # 2. 2D DCT (type-II)
    dct_rows = dct(block, axis=0, norm='ortho')
    dct_2d = dct(dct_rows, axis=1, norm='ortho')

    # 3. Standard Luminance Quantization Table
    Q = np.array([
        [16,11,10,16,24,40,51,61],
        [12,12,14,19,26,58,60,55],
        [14,13,16,24,40,57,69,56],
        [14,17,22,29,51,87,80,62],
        [18,22,37,56,68,109,103,77],
        [24,35,55,64,81,104,113,92],
        [49,64,78,87,103,121,120,101],
        [72,92,95,98,112,100,103,99],
    ])

    # 4. Quantization (rounded to nearest int)
    quantized = np.round(dct_2d / Q).astype(np.int8)

    return dct_2d, quantized, Q

if __name__ == "__main__":
    # Original 8x8 block from Verilog initial
    pixel_block = np.array([
        [52, 55, 61, 66, 70, 61, 64, 73],
        [63, 59, 55, 90,109, 85, 69, 72],
        [62, 59, 68,113,144,104, 66, 73],
        [63, 58, 71,122,154,106, 70, 69],
        [67, 61, 68,104,126, 88, 68, 70],
        [79, 65, 60, 70, 77, 68, 58, 75],
        [85, 71, 64, 59, 55, 61, 65, 83],
        [87, 79, 69, 68, 65, 76, 78, 94]
    ], dtype=np.uint8)

    # Run DCT + Quantization
    dct_result, quantized, Q = jpeg_dct_quantization(pixel_block)

    # Print results
    print("\n--- DCT Result ---")
    print(np.round(dct_result).astype(np.int32))

    print("\n--- Quantized Matrix ---")
    print(quantized)

    print("\n--- Flattened Output (row-major) ---")
    flat = quantized.flatten()
    for i in range(64):
        print(f"Q[{i}] = {int(flat[i])}")
