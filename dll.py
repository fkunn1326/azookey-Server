# swiftのdllをコピーするやつ
import shutil

# Copy additional files
source_folder = r'C:\Users\fukuda\AppData\Local\Programs\Swift\Runtimes\0.0.0\usr\bin'
destination_folder = r'D:\azookey-service\.build\x86_64-unknown-windows-msvc\release'
shutil.copytree(source_folder, destination_folder, dirs_exist_ok=True)