# swiftのdllをコピーするやつ
import shutil

# files
source_files = [
    r"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin\cublas64_12.dll",
    r"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin\cublasLt64_12.dll",
    r"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin\cudart64_12.dll",
    "./llama.dll",
    "./zenz-v2-Q5_K_M.gguf"
]

# Copy additional files
source_folder = r'C:\Users\fukuda\AppData\Local\Programs\Swift\Runtimes\0.0.0\usr\bin'
destination_folder = r'D:\azookey-service\.build\x86_64-unknown-windows-msvc\release'
shutil.copytree(source_folder, destination_folder, dirs_exist_ok=True)

# Copy files
for file in source_files:
    shutil.copy(file, destination_folder)